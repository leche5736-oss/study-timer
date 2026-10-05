import 'models.dart';

enum StatsRange { day, week, month }

extension StatsRangeLabel on StatsRange {
  String get label => switch (this) {
    StatsRange.day => '오늘',
    StatsRange.week => '이번 주',
    StatsRange.month => '이번 달',
  };
}

/// 기간의 시작 시각(로컬 시간 기준). 주는 월요일부터.
DateTime rangeStart(StatsRange range, DateTime nowLocal) {
  final today = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);
  return switch (range) {
    StatsRange.day => today,
    StatsRange.week => today.subtract(Duration(days: today.weekday - 1)),
    StatsRange.month => DateTime(nowLocal.year, nowLocal.month, 1),
  };
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
  DateTime nowLocal,
) {
  final start = rangeStart(range, nowLocal);
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

String formatClock(int seconds) {
  if (seconds < 0) seconds = 0;
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

// ---------- 오늘 목표 ----------

/// 오늘(로컬 시간) 공부한 초.
int todaySeconds(Iterable<StudySession> sessions, DateTime nowLocal) =>
    totalsBySubject(
      sessions,
      StatsRange.day,
      nowLocal,
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

enum TrendUnit { week, month }

class TrendPeriod {
  final DateTime start; // 로컬
  final String label;
  final Map<String, int> secondsBySubject = {};
  TrendPeriod(this.start, this.label);
  int get total => secondsBySubject.values.fold(0, (a, b) => a + b);
}

/// 최근 [count]개 주(월요일 시작) 또는 월의 과목별 공부 시간. 오래된 것부터.
List<TrendPeriod> buildTrend(
  Iterable<StudySession> sessions,
  TrendUnit unit,
  DateTime nowLocal, {
  int count = 8,
}) {
  final periods = <TrendPeriod>[];
  if (unit == TrendUnit.week) {
    final thisWeek = rangeStart(StatsRange.week, nowLocal);
    for (var i = count - 1; i >= 0; i--) {
      final start = DateTime(
        thisWeek.year,
        thisWeek.month,
        thisWeek.day - 7 * i,
      );
      periods.add(TrendPeriod(start, '${start.month}/${start.day}'));
    }
  } else {
    for (var i = count - 1; i >= 0; i--) {
      final start = DateTime(nowLocal.year, nowLocal.month - i, 1);
      periods.add(TrendPeriod(start, '${start.month}월'));
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
    ['날짜', '과목', '시작', '끝', '집중(초)', '집중(분)', '목표(분)', '집중도', '휴식', '정리 노트'],
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
      s.recallNote,
    ]);
  }
  // 엑셀이 한글을 깨뜨리지 않게 BOM을 붙입니다.
  return '﻿${rows.map((r) => r.map(_csvCell).join(',')).join('\n')}\n';
}
