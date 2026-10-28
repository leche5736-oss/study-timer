import 'package:flutter_test/flutter_test.dart';
import 'package:study_timer/models.dart';
import 'package:study_timer/stats.dart';

StudySession session(
  String subject,
  DateTime start,
  int sec, {
  int? rating,
  bool deleted = false,
}) => StudySession(
  id: '$subject$start',
  subjectId: subject,
  startedAt: start.toUtc(),
  endedAt: start.toUtc().add(Duration(seconds: sec)),
  plannedMinutes: 25,
  focusSeconds: sec,
  focusRating: rating,
  deleted: deleted,
  updatedAt: start.toUtc(),
);

void main() {
  // 2026-10-07은 수요일.
  final now = DateTime(2026, 10, 7, 20);

  final data = [
    session('math', DateTime(2026, 10, 7, 9), 1500, rating: 4),
    session('math', DateTime(2026, 10, 7, 10), 1500, rating: 2),
    session('eng', DateTime(2026, 10, 6, 9), 3000),
    session('eng', DateTime(2026, 10, 1, 9), 600),
    session('eng', DateTime(2026, 9, 30, 9), 9999),
    session('math', DateTime(2026, 10, 7, 11), 9999, deleted: true),
  ];

  test('오늘', () {
    final t = totalsBySubject(data, StatsRange.day, now);
    expect(t.length, 1);
    expect(t.first.subjectId, 'math');
    expect(t.first.seconds, 3000);
    expect(t.first.sessions, 2);
    expect(t.first.avgRating, 3);
  });

  test('이번 주는 월요일부터', () {
    final t = totalsBySubject(data, StatsRange.week, now);
    expect(
      {for (final x in t) x.subjectId: x.seconds},
      {'math': 3000, 'eng': 3000},
    );
  });

  test('이번 달', () {
    final t = totalsBySubject(data, StatsRange.month, now);
    expect(
      {for (final x in t) x.subjectId: x.seconds},
      {'math': 3000, 'eng': 3600},
    );
    expect(t.first.subjectId, 'eng');
  });

  test('시간 표시', () {
    expect(formatDuration(3723), '1시간 2분 3초');
    expect(formatDuration(300), '5분 0초');
    expect(formatDuration(45), '45초');
    expect(formatClock(65), '01:05');
  });
}
