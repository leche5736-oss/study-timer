import 'package:flutter_test/flutter_test.dart';
import 'package:study_timer/models.dart';
import 'package:study_timer/stats.dart';

StudySession s(
  String id,
  DateTime startLocal,
  int sec, {
  int? rating,
  String subject = 'math',
  String? rest,
}) => StudySession(
  id: id,
  subjectId: subject,
  startedAt: startLocal.toUtc(),
  endedAt: startLocal.toUtc().add(Duration(seconds: sec)),
  plannedMinutes: 25,
  focusSeconds: sec,
  focusRating: rating,
  restType: rest,
  updatedAt: startLocal.toUtc(),
);

void main() {
  test('히트맵: 여러 시간에 걸친 블록은 시간마다 나뉜다', () {
    // 2026-10-05는 월요일. 9:30부터 60분 → 9시 30분 + 10시 30분
    final map = buildHeatmap([
      s('a', DateTime(2026, 10, 5, 9, 30), 3600, rating: 4),
    ], DateTime(2026, 10, 1));
    expect(map.cells[0][9].seconds, 1800);
    expect(map.cells[0][10].seconds, 1800);
    expect(map.cells[0][10].avgRating, 4);
    expect(map.maxSeconds, 1800);
  });

  test('히트맵: 기간 이전 기록은 빠진다', () {
    final map = buildHeatmap([
      s('a', DateTime(2026, 9, 1, 9), 600),
    ], DateTime(2026, 10, 1));
    expect(map.maxSeconds, 0);
  });

  test('가장 집중 잘 되는 2시간', () {
    final sessions = [
      s('a', DateTime(2026, 10, 5, 9), 3600, rating: 5),
      s('b', DateTime(2026, 10, 5, 10), 3600, rating: 5),
      s('c', DateTime(2026, 10, 5, 20), 3600, rating: 2),
      s('d', DateTime(2026, 10, 5, 21), 3600, rating: 2),
    ];
    final best = bestFocusWindow(buildHeatmap(sessions, DateTime(2026, 10)));
    expect(best!.startHour, 9);
    expect(best.avgRating, 5);
  });

  test('근거가 부족하면 추천하지 않는다', () {
    final best = bestFocusWindow(
      buildHeatmap([
        s('a', DateTime(2026, 10, 5, 9), 600, rating: 5),
      ], DateTime(2026, 10)),
    );
    expect(best, isNull);
  });

  test('주별 추이', () {
    final now = DateTime(2026, 10, 7, 12); // 수요일
    final trend = buildTrend(
      [
        s('a', DateTime(2026, 10, 6, 9), 600),
        s('b', DateTime(2026, 10, 6, 9), 300, subject: 'eng'),
        s('c', DateTime(2026, 9, 29, 9), 1200), // 지난주 월요일
        s('d', DateTime(2026, 1, 1), 999), // 범위 밖
      ],
      TrendUnit.week,
      now,
    );
    expect(trend.length, 8);
    expect(trend.last.label, '10/5');
    expect(trend.last.secondsBySubject, {'math': 600, 'eng': 300});
    expect(trend[6].secondsBySubject, {'math': 1200});
    expect(trend.take(6).every((p) => p.total == 0), isTrue);
  });

  test('월별 추이', () {
    final trend = buildTrend(
      [s('a', DateTime(2026, 8, 15), 600)],
      TrendUnit.month,
      DateTime(2026, 10, 7),
      count: 6,
    );
    expect(trend.map((p) => p.label).toList(), [
      '5월',
      '6월',
      '7월',
      '8월',
      '9월',
      '10월',
    ]);
    expect(trend[3].total, 600);
  });

  test('집중 길이 추천은 3번 이상 기록된 길이 중 집중도가 높은 것', () {
    final d = DateTime(2026, 10, 5, 9);
    final sessions = [
      for (var i = 0; i < 3; i++) s('short$i', d, 25 * 60, rating: 3),
      for (var i = 0; i < 3; i++) s('mid$i', d, 50 * 60, rating: 5),
      for (var i = 0; i < 2; i++) s('long$i', d, 90 * 60, rating: 5),
      s('tiny', d, 60, rating: 5), // 5분 미만 제외
    ];
    final rec = recommendLength(sessions)!;
    expect(rec.bucket.label, '30~60분');
    expect(focusByLength(sessions).length, 3);
    expect(focusByLength(sessions).first.count, 3);
  });

  test('휴식 방식별 다음 블록 집중도', () {
    final sessions = [
      s('a', DateTime(2026, 10, 5, 9), 1500, rest: 'quiet'),
      s('b', DateTime(2026, 10, 5, 9, 30), 1500, rating: 5, rest: 'phone'),
      s('c', DateTime(2026, 10, 5, 10), 1500, rating: 2, rest: 'quiet'),
      // 다음 블록이 2시간 넘게 뒤라 비교에서 빠짐
      s('d', DateTime(2026, 10, 5, 15), 1500, rating: 1),
    ];
    final stats = {for (final r in restComparison(sessions)) r.type: r};
    expect(stats[RestType.quiet]!.avgNextRating, 5);
    expect(stats[RestType.quiet]!.count, 1);
    expect(stats[RestType.phone]!.avgNextRating, 2);
  });

  test('오늘 공부 시간', () {
    final now = DateTime(2026, 10, 5, 20);
    expect(
      todaySeconds([
        s('a', DateTime(2026, 10, 5, 9), 600),
        s('b', DateTime(2026, 10, 4, 9), 600),
      ], now),
      600,
    );
  });

  test('CSV', () {
    final csv = sessionsCsv(
      [
        StudySession(
          id: 'x',
          subjectId: 'math',
          startedAt: DateTime(2026, 10, 5, 9).toUtc(),
          endedAt: DateTime(2026, 10, 5, 9, 25).toUtc(),
          plannedMinutes: 25,
          focusSeconds: 1500,
          focusRating: 4,
          recallNote: '미분, "도함수"',
          restType: 'walk',
          updatedAt: DateTime.utc(2026),
        ),
      ],
      (id) =>
          Subject(id: id, name: '수학', color: 0, updatedAt: DateTime.utc(2026)),
    );
    final lines = csv.split('\n')..removeLast();
    expect(lines.length, 2);
    expect(lines[0].startsWith('﻿날짜,과목'), isTrue);
    expect(
      lines[1],
      '2026-10-05,수학,2026-10-05 09:00:00,2026-10-05 09:25:00,1500,25.0,25,4,걷기/스트레칭,"미분, ""도함수"""',
    );
  });
}
