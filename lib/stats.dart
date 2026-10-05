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
