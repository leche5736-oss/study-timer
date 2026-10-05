import 'dart:math' as math;

import 'models.dart';

enum StatsRange { day, week, month }

extension StatsRangeLabel on StatsRange {
  String get label => switch (this) {
    StatsRange.day => '오늘',
    StatsRange.week => '이번 주',
    StatsRange.month => '이번 달',
  };
}

/// [t]가 속한 "공부 날짜" (로컬 자정). 하루가 [dayStartHour]시에 바뀌므로
/// 새벽 공부는 전날로 셉니다.
DateTime studyDate(DateTime t, [int dayStartHour = 0]) {
  final shifted = t.toLocal().subtract(Duration(hours: dayStartHour));
  return DateTime(shifted.year, shifted.month, shifted.day);
}

/// 공부 날짜 [date]가 실제로 시작되는 시각.
DateTime dayStartOf(DateTime date, [int dayStartHour = 0]) =>
    DateTime(date.year, date.month, date.day, dayStartHour);

/// 기간의 시작 시각(로컬 시간 기준). 주는 월요일부터.
DateTime rangeStart(
  StatsRange range,
  DateTime nowLocal, {
  int dayStartHour = 0,
}) {
  final today = studyDate(nowLocal, dayStartHour);
  final date = switch (range) {
    StatsRange.day => today,
    StatsRange.week => DateTime(
      today.year,
      today.month,
      today.day - (today.weekday - 1),
    ),
    StatsRange.month => DateTime(today.year, today.month, 1),
  };
  return dayStartOf(date, dayStartHour);
}

class SubjectTotal {
  final String subjectId;
  final int seconds;
  final int sessions;
  final double? avgRating;
  const SubjectTotal(
    this.subjectId,
    this.seconds,
    this.sessions,
    this.avgRating,
  );
}

/// 기간 안에 시작한 기록을 과목별로 합산해 많이 공부한 순으로 돌려줍니다.
List<SubjectTotal> totalsBySubject(
  Iterable<StudySession> sessions,
  StatsRange range,
  DateTime nowLocal, {
  int dayStartHour = 0,
}) {
  final start = rangeStart(range, nowLocal, dayStartHour: dayStartHour);
  final secs = <String, int>{};
  final counts = <String, int>{};
  final ratings = <String, List<int>>{};
  for (final s in sessions) {
    if (s.deleted || s.startedAt.toLocal().isBefore(start)) continue;
    secs[s.subjectId] = (secs[s.subjectId] ?? 0) + s.focusSeconds;
    counts[s.subjectId] = (counts[s.subjectId] ?? 0) + 1;
    if (s.focusRating != null) {
      (ratings[s.subjectId] ??= []).add(s.focusRating!);
    }
  }
  final out = secs.keys.map((id) {
    final r = ratings[id];
    final avg = r == null ? null : r.reduce((a, b) => a + b) / r.length;
    return SubjectTotal(id, secs[id]!, counts[id]!, avg);
  }).toList()..sort((a, b) => b.seconds.compareTo(a.seconds));
  return out;
}

String formatDuration(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  if (h > 0) return '$h시간 $m분 $s초';
  if (m > 0) return '$m분 $s초';
  return '$s초';
}

/// "66:06:35" 처럼 시:분:초.
String formatHms(int seconds) {
  if (seconds < 0) seconds = 0;
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

/// "4:56" 처럼 시:분 (달력 칸처럼 좁은 곳).
String formatHm(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  return '$h:${m.toString().padLeft(2, '0')}';
}

String formatClock(int seconds) {
  if (seconds < 0) seconds = 0;
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

// ---------- 오늘 목표 ----------

/// 오늘(로컬 시간) 공부한 초.
int todaySeconds(
  Iterable<StudySession> sessions,
  DateTime nowLocal, {
  int dayStartHour = 0,
}) => totalsBySubject(
  sessions,
  StatsRange.day,
  nowLocal,
  dayStartHour: dayStartHour,
).fold(0, (a, t) => a + t.seconds);

// ---------- 시간대별 집중도 ----------

/// 요일(1=월~7=일) × 시간(0~23) 칸 하나.
class HeatCell {
  int seconds = 0;
  double _ratingWeighted = 0; // 집중도 × 초
  int _ratedSeconds = 0;

  double? get avgRating =>
      _ratedSeconds == 0 ? null : _ratingWeighted / _ratedSeconds;
}

class Heatmap {
  /// cells[weekday - 1][hour]
  final List<List<HeatCell>> cells = List.generate(
    7,
    (_) => List.generate(24, (_) => HeatCell()),
  );

  int get maxSeconds =>
      cells.expand((r) => r).fold(0, (m, c) => c.seconds > m ? c.seconds : m);

  /// 요일을 합친 시간대별 값.
  HeatCell hourTotal(int hour) {
    final out = HeatCell();
    for (final row in cells) {
      final c = row[hour];
      out.seconds += c.seconds;
      out._ratingWeighted += c._ratingWeighted;
      out._ratedSeconds += c._ratedSeconds;
    }
    return out;
  }
}

/// [since] 이후 기록을 요일×시간 칸에 나눠 담습니다.
/// 블록이 여러 시간에 걸치면 시간마다 나눠서 넣습니다.
Heatmap buildHeatmap(Iterable<StudySession> sessions, DateTime sinceLocal) {
  final map = Heatmap();
  for (final s in sessions) {
    if (s.deleted) continue;
    var t = s.startedAt.toLocal();
    if (t.isBefore(sinceLocal)) continue;
    var left = s.focusSeconds;
    while (left > 0) {
      final nextHour = DateTime(t.year, t.month, t.day, t.hour + 1);
      final chunk = nextHour.difference(t).inSeconds.clamp(1, left);
      final cell = map.cells[t.weekday - 1][t.hour];
      cell.seconds += chunk;
      if (s.focusRating != null) {
        cell._ratingWeighted += s.focusRating! * chunk;
        cell._ratedSeconds += chunk;
      }
      left -= chunk;
      t = t.add(Duration(seconds: chunk));
    }
  }
  return map;
}

/// 집중이 가장 잘 된 연속 2시간. 집중도가 기록된 시간이 각 시간당 20분 이상인 구간만 봅니다.
/// 근거가 부족하면 null.
({int startHour, double avgRating})? bestFocusWindow(Heatmap map) {
  ({int startHour, double avgRating})? best;
  for (var h = 0; h < 23; h++) {
    final a = map.hourTotal(h), b = map.hourTotal(h + 1);
    if (a._ratedSeconds < 1200 || b._ratedSeconds < 1200) continue;
    final avg =
        (a._ratingWeighted + b._ratingWeighted) /
        (a._ratedSeconds + b._ratedSeconds);
    if (best == null || avg > best.avgRating) {
      best = (startHour: h, avgRating: avg);
    }
  }
  return best;
}

// ---------- 과목별 추이 ----------

enum TrendUnit { day, week, month }

class TrendPeriod {
  final DateTime start; // 로컬
  final String label;
  final Map<String, int> secondsBySubject = {};
  TrendPeriod(this.start, this.label);
  int get total => secondsBySubject.values.fold(0, (a, b) => a + b);
}

/// 최근 [count]개 날, 주(월요일 시작) 또는 월의 과목별 공부 시간. 오래된 것부터.
List<TrendPeriod> buildTrend(
  Iterable<StudySession> sessions,
  TrendUnit unit,
  DateTime nowLocal, {
  int count = 8,
  int dayStartHour = 0,
}) {
  final h = dayStartHour;
  final periods = <TrendPeriod>[];
  final today = studyDate(nowLocal, h);
  if (unit == TrendUnit.day) {
    for (var i = count - 1; i >= 0; i--) {
      final d = DateTime(today.year, today.month, today.day - i);
      periods.add(TrendPeriod(dayStartOf(d, h), '${d.month}/${d.day}'));
    }
  } else if (unit == TrendUnit.week) {
    final thisWeek = studyDate(
      rangeStart(StatsRange.week, nowLocal, dayStartHour: h),
      h,
    );
    for (var i = count - 1; i >= 0; i--) {
      final d = DateTime(thisWeek.year, thisWeek.month, thisWeek.day - 7 * i);
      periods.add(TrendPeriod(dayStartOf(d, h), '${d.month}/${d.day}'));
    }
  } else {
    for (var i = count - 1; i >= 0; i--) {
      final d = DateTime(today.year, today.month - i, 1);
      periods.add(TrendPeriod(dayStartOf(d, h), '${d.month}월'));
    }
  }
  for (final s in sessions) {
    if (s.deleted) continue;
    final t = s.startedAt.toLocal();
    for (var i = periods.length - 1; i >= 0; i--) {
      if (!t.isBefore(periods[i].start)) {
        final end = i + 1 < periods.length ? periods[i + 1].start : null;
        if (end == null || t.isBefore(end)) {
          final m = periods[i].secondsBySubject;
          m[s.subjectId] = (m[s.subjectId] ?? 0) + s.focusSeconds;
        }
        break;
      }
    }
  }
  return periods;
}

// ---------- 맞춤 집중 길이 ----------

class LengthBucket {
  final String label;
  final int minSec; // 이상
  final int maxSec; // 이하
  final int suggestMin; // 추천할 집중 시간
  const LengthBucket(this.label, this.minSec, this.maxSec, this.suggestMin);
}

const lengthBuckets = [
  LengthBucket('30분 이하', 0, 30 * 60, 25),
  LengthBucket('30~60분', 30 * 60 + 1, 60 * 60, 50),
  LengthBucket('60분 넘게', 60 * 60 + 1, 1 << 30, 90),
];

class BucketStat {
  final LengthBucket bucket;
  final int count;
  final double avgRating;
  const BucketStat(this.bucket, this.count, this.avgRating);
}

/// 실제 집중 길이별 평균 집중도. 집중도를 남긴 기록만 셉니다.
List<BucketStat> focusByLength(Iterable<StudySession> sessions) {
  final out = <BucketStat>[];
  for (final b in lengthBuckets) {
    final rated = sessions.where(
      (s) =>
          !s.deleted &&
          s.focusRating != null &&
          s.focusSeconds >= b.minSec &&
          s.focusSeconds <= b.maxSec &&
          s.focusSeconds >= 5 * 60, // 5분 미만은 제외
    );
    if (rated.isEmpty) continue;
    final avg =
        rated.map((s) => s.focusRating!).reduce((a, b) => a + b) / rated.length;
    out.add(BucketStat(b, rated.length, avg));
  }
  return out;
}

/// 길이별로 3번 이상 기록이 있을 때, 평균 집중도가 가장 높은 길이. 없으면 null.
BucketStat? recommendLength(Iterable<StudySession> sessions) {
  final candidates = focusByLength(sessions).where((b) => b.count >= 3);
  if (candidates.isEmpty) return null;
  return candidates.reduce((a, b) => b.avgRating > a.avgRating ? b : a);
}

// ---------- 휴식 방식 비교 ----------

class RestStat {
  final RestType type;
  final int count;
  final double avgNextRating;
  const RestStat(this.type, this.count, this.avgNextRating);
}

/// 휴식 방식별로, 그 휴식 뒤 2시간 안에 시작한 다음 블록의 평균 집중도.
List<RestStat> restComparison(Iterable<StudySession> sessions) {
  final list = sessions.where((s) => !s.deleted).toList()
    ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
  final ratings = <RestType, List<int>>{};
  for (var i = 0; i + 1 < list.length; i++) {
    final type = RestType.byName(list[i].restType);
    final next = list[i + 1];
    if (type == null || next.focusRating == null) continue;
    if (next.startedAt.difference(list[i].endedAt) > const Duration(hours: 2)) {
      continue;
    }
    (ratings[type] ??= []).add(next.focusRating!);
  }
  return [
    for (final t in RestType.values)
      if (ratings[t] != null)
        RestStat(
          t,
          ratings[t]!.length,
          ratings[t]!.reduce((a, b) => a + b) / ratings[t]!.length,
        ),
  ];
}

// ---------- 기간 요약 (열품타 참고) ----------

class PeriodSummary {
  final int total; // 이번 기간 지금까지
  final int days; // 지난 날 수 (오늘 포함)
  final int previous; // 지난 기간 같은 시점까지
  const PeriodSummary(this.total, this.days, this.previous);

  int get dailyAverage => days == 0 ? 0 : total ~/ days;
  int get diff => total - previous;
}

int _sumBetween(Iterable<StudySession> sessions, DateTime from, DateTime to) {
  var sum = 0;
  for (final s in sessions) {
    if (s.deleted) continue;
    final t = s.startedAt.toLocal();
    if (!t.isBefore(from) && t.isBefore(to)) sum += s.focusSeconds;
  }
  return sum;
}

/// 이번 기간 합계·하루 평균과, 지난 기간의 같은 시점까지 합계.
/// 예: 이번 주 수요일 밤이면 지난주 월요일~수요일 같은 시각까지와 비교.
PeriodSummary periodSummary(
  Iterable<StudySession> sessions,
  StatsRange range,
  DateTime nowLocal, {
  int dayStartHour = 0,
}) {
  final h = dayStartHour;
  final start = rangeStart(range, nowLocal, dayStartHour: h);
  final startDate = studyDate(start, h);
  final prevStartDate = switch (range) {
    StatsRange.day => DateTime(
      startDate.year,
      startDate.month,
      startDate.day - 1,
    ),
    StatsRange.week => DateTime(
      startDate.year,
      startDate.month,
      startDate.day - 7,
    ),
    StatsRange.month => DateTime(startDate.year, startDate.month - 1, 1),
  };
  final prevStart = dayStartOf(prevStartDate, h);
  var prevEnd = prevStart.add(nowLocal.difference(start));
  if (prevEnd.isAfter(start)) prevEnd = start; // 지난달이 더 짧을 때
  final days = studyDate(nowLocal, h).difference(startDate).inHours ~/ 24 + 1;
  return PeriodSummary(
    _sumBetween(sessions, start, nowLocal.add(const Duration(seconds: 1))),
    days,
    _sumBetween(sessions, prevStart, prevEnd),
  );
}

/// 공부 날짜별 합계.
Map<DateTime, int> dailyTotals(
  Iterable<StudySession> sessions, {
  int dayStartHour = 0,
}) {
  final out = <DateTime, int>{};
  for (final s in sessions) {
    if (s.deleted) continue;
    final d = studyDate(s.startedAt, dayStartHour);
    out[d] = (out[d] ?? 0) + s.focusSeconds;
  }
  return out;
}

/// 하루 타임라인의 한 조각. 분은 그날 시작 시각부터 센 값 (0~1440).
class TimelineSegment {
  final int startMin;
  final int endMin;
  final String subjectId;
  const TimelineSegment(this.startMin, this.endMin, this.subjectId);
}

/// 공부 날짜 [date]의 블록들을 하루 시작 시각 기준 분 단위로.
/// 집중 시간만큼만 그립니다 (시작 시각부터).
List<TimelineSegment> dayTimeline(
  Iterable<StudySession> sessions,
  DateTime date, {
  int dayStartHour = 0,
}) {
  final from = dayStartOf(date, dayStartHour);
  final to = dayStartOf(
    DateTime(date.year, date.month, date.day + 1),
    dayStartHour,
  );
  final out = <TimelineSegment>[];
  for (final s in sessions) {
    if (s.deleted) continue;
    final a = s.startedAt.toLocal();
    final b = a.add(Duration(seconds: s.focusSeconds));
    if (!b.isAfter(from) || !a.isBefore(to)) continue;
    final sa = a.isBefore(from) ? from : a;
    final sb = b.isAfter(to) ? to : b;
    out.add(
      TimelineSegment(
        sa.difference(from).inMinutes,
        (sb.difference(from).inSeconds / 60).ceil(),
        s.subjectId,
      ),
    );
  }
  out.sort((x, y) => x.startMin.compareTo(y.startMin));
  return out;
}

/// 그날 시작 시각부터 센 [minutes]분을 "22:05" 같은 시계 표기로.
String clockFromDayStart(int minutes, [int dayStartHour = 0]) {
  final total = (dayStartHour * 60 + minutes) % (24 * 60);
  return '${(total ~/ 60).toString().padLeft(2, '0')}:'
      '${(total % 60).toString().padLeft(2, '0')}';
}

class DayRange {
  final DateTime date;
  final int firstStartMin; // 그날 시작 시각부터 센 분
  final int lastEndMin;
  const DayRange(this.date, this.firstStartMin, this.lastEndMin);
}

class Regularity {
  final List<DayRange> days; // 공부한 날만, 오래된 것부터
  final double avgStart;
  final double avgEnd;
  final double startSpread; // 표준편차 (분)
  final double endSpread;
  const Regularity(
    this.days,
    this.avgStart,
    this.avgEnd,
    this.startSpread,
    this.endSpread,
  );
}

/// 최근 [days]일 동안 공부를 시작·끝낸 시각이 얼마나 일정한지.
/// 공부한 날이 2일 미만이면 null.
Regularity? studyRegularity(
  Iterable<StudySession> sessions,
  DateTime nowLocal, {
  int days = 14,
  int dayStartHour = 0,
}) {
  final today = studyDate(nowLocal, dayStartHour);
  final list = <DayRange>[];
  for (var i = days - 1; i >= 0; i--) {
    final d = DateTime(today.year, today.month, today.day - i);
    final segs = dayTimeline(sessions, d, dayStartHour: dayStartHour);
    if (segs.isEmpty) continue;
    final end = segs.map((s) => s.endMin).reduce((a, b) => a > b ? a : b);
    list.add(DayRange(d, segs.first.startMin, end));
  }
  if (list.length < 2) return null;
  double mean(Iterable<int> v) => v.reduce((a, b) => a + b) / v.length;
  double spread(Iterable<int> v, double m) {
    final sq = v.map((x) => (x - m) * (x - m)).reduce((a, b) => a + b);
    return math.sqrt(sq / v.length);
  }

  final starts = list.map((d) => d.firstStartMin);
  final ends = list.map((d) => d.lastEndMin);
  final ms = mean(starts), me = mean(ends);
  return Regularity(list, ms, me, spread(starts, ms), spread(ends, me));
}

// ---------- 딴짓 ----------

class DistractionStat {
  final int count;
  final int seconds;
  final int focusSeconds;
  final int thoughts;
  const DistractionStat(
    this.count,
    this.seconds,
    this.focusSeconds,
    this.thoughts,
  );

  /// 공부 1시간당 딴짓 횟수.
  double get perHour => focusSeconds == 0 ? 0 : count * 3600 / focusSeconds;
}

/// [since] 이후 딴짓 횟수·시간과 딴생각 메모 수.
DistractionStat distractionStat(
  Iterable<StudySession> sessions,
  Iterable<ThoughtNote> thoughts,
  DateTime sinceLocal,
) {
  var count = 0, secs = 0, focus = 0;
  for (final s in sessions) {
    if (s.deleted || s.startedAt.toLocal().isBefore(sinceLocal)) continue;
    count += s.distractions;
    secs += s.distractedSeconds;
    focus += s.focusSeconds;
  }
  final notes = thoughts
      .where((t) => !t.createdAt.toLocal().isBefore(sinceLocal))
      .length;
  return DistractionStat(count, secs, focus, notes);
}

// ---------- CSV ----------

String _csvCell(String v) =>
    v.contains(RegExp(r'[",\n]')) ? '"${v.replaceAll('"', '""')}"' : v;

/// 기록 전체를 CSV 문자열로 (엑셀, Numbers에서 열 수 있음).
String sessionsCsv(
  Iterable<StudySession> sessions,
  Subject? Function(String id) subjectOf,
) {
  String two(int v) => v.toString().padLeft(2, '0');
  String fmt(DateTime utc) {
    final d = utc.toLocal();
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}:${two(d.second)}';
  }

  final rows = <List<String>>[
    [
      '날짜',
      '과목',
      '시작',
      '끝',
      '집중(초)',
      '집중(분)',
      '목표(분)',
      '집중도',
      '휴식',
      '딴짓(회)',
      '딴짓(초)',
      '정리 노트',
    ],
  ];
  final list = sessions.where((s) => !s.deleted).toList()
    ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
  for (final s in list) {
    rows.add([
      fmt(s.startedAt).substring(0, 10),
      subjectOf(s.subjectId)?.name ?? '(삭제된 과목)',
      fmt(s.startedAt),
      fmt(s.endedAt),
      '${s.focusSeconds}',
      (s.focusSeconds / 60).toStringAsFixed(1),
      s.plannedMinutes == 0 ? '' : '${s.plannedMinutes}',
      s.focusRating?.toString() ?? '',
      RestType.byName(s.restType)?.label ?? '',
      '${s.distractions}',
      '${s.distractedSeconds}',
      s.recallNote,
    ]);
  }
  // 엑셀이 한글을 깨뜨리지 않게 BOM을 붙입니다.
  return '﻿${rows.map((r) => r.map(_csvCell).join(',')).join('\n')}\n';
}
