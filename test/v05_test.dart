import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_timer/models.dart';
import 'package:study_timer/services/store.dart';
import 'package:study_timer/stats.dart';

StudySession _s(
  DateTime startLocal,
  int sec, {
  String subject = 'a',
  int distractions = 0,
  int distractedSeconds = 0,
}) => StudySession(
  id: '${startLocal.toIso8601String()}-$subject',
  subjectId: subject,
  startedAt: startLocal.toUtc(),
  endedAt: startLocal.add(Duration(seconds: sec)).toUtc(),
  plannedMinutes: 0,
  focusSeconds: sec,
  distractions: distractions,
  distractedSeconds: distractedSeconds,
  updatedAt: DateTime.utc(2026),
);

void main() {
  group('딴짓 앱 감지', () {
    late DateTime clock;
    late AppStore store;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      clock = DateTime.utc(2026, 10, 5, 9);
      store = AppStore(
        await SharedPreferences.getInstance(),
        clock: () => clock,
      );
      store.updateSettings(store.settings.copyWith(blockedApps: ['YouTube']));
    });

    test('집중 중 딴짓 앱에 들어갔다 나오면 횟수와 시간이 기록된다', () {
      final math = store.addSubject('수학');
      store.startFocus(math.id, 0);
      clock = clock.add(const Duration(minutes: 5));
      expect(store.frontAppChanged('YouTube'), isTrue);
      clock = clock.add(const Duration(seconds: 90));
      expect(store.frontAppChanged('Safari'), isFalse); // 목록에 없는 앱
      expect(store.timer.distractions, 1);
      expect(store.timer.distractedSec, 90);

      // 다시 딴짓하다가 그대로 끝내면 끝낸 시각까지 셉니다.
      store.frontAppChanged('YouTube');
      clock = clock.add(const Duration(seconds: 30));
      store.finishFocus();
      store.submitRecall();
      final saved = store.sessions.single;
      expect(saved.distractions, 2);
      expect(saved.distractedSeconds, 120);
    });

    test('집중 중이 아니거나 감지를 끄면 세지 않는다', () {
      expect(store.frontAppChanged('YouTube'), isFalse);
      final math = store.addSubject('수학');
      store.startFocus(math.id, 0);
      store.pause();
      expect(store.frontAppChanged('YouTube'), isFalse);
      store.resume();
      store.updateSettings(store.settings.copyWith(watchApps: false));
      expect(store.frontAppChanged('YouTube'), isFalse);
      expect(store.timer.distractions, 0);
    });

    test('기록을 고쳐도 딴짓 기록은 남는다', () {
      final math = store.addSubject('수학');
      store.startFocus(math.id, 0);
      store.frontAppChanged('YouTube');
      clock = clock.add(const Duration(seconds: 10));
      store.finishFocus();
      store.submitRecall();
      final s = store.sessions.single;
      store.saveSession(
        id: s.id,
        subjectId: s.subjectId,
        startedAt: s.startedAt,
        focusSeconds: 600,
      );
      expect(store.sessions.single.distractions, 1);
    });
  });

  test('딴생각 메모는 저장되고 다시 열어도 남는다', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = AppStore(prefs);
    store.addThought('  택배 찾기  ');
    store.addThought('');
    store.addThought('엄마한테 전화');
    expect(store.thoughts.map((t) => t.text), ['택배 찾기', '엄마한테 전화']);
    store.toggleThought(store.thoughts.first.id);
    expect(store.openThoughts.length, 1);
    await Future<void>.delayed(Duration.zero);
    final reopened = AppStore(prefs);
    expect(reopened.thoughts.length, 2);
    reopened.clearDoneThoughts();
    expect(reopened.thoughts.single.text, '엄마한테 전화');
  });

  group('하루 시작 시각', () {
    test('새벽 공부는 전날로 센다', () {
      expect(studyDate(DateTime(2026, 10, 5, 1, 30), 5), DateTime(2026, 10, 4));
      expect(studyDate(DateTime(2026, 10, 5, 5), 5), DateTime(2026, 10, 5));
      expect(studyDate(DateTime(2026, 10, 5, 1, 30)), DateTime(2026, 10, 5));
    });

    test('오늘 공부 시간도 하루 시작 시각을 따른다', () {
      final data = [
        _s(DateTime(2026, 10, 4, 23), 3600),
        _s(DateTime(2026, 10, 5, 1), 1800),
      ];
      final now = DateTime(2026, 10, 5, 2);
      expect(todaySeconds(data, now, dayStartHour: 5), 5400);
      expect(todaySeconds(data, now), 1800);
    });
  });

  group('기간 요약', () {
    test('이번 주 합계, 하루 평균, 지난주 같은 시점 비교', () {
      final data = [
        _s(DateTime(2026, 9, 28, 20), 3600), // 지난주 월
        _s(DateTime(2026, 9, 30, 20), 3600), // 지난주 수 (비교 시점 이후)
        _s(DateTime(2026, 10, 5, 10), 7200), // 이번 주 월
        _s(DateTime(2026, 10, 6, 10), 1800), // 이번 주 화
      ];
      final sum = periodSummary(
        data,
        StatsRange.week,
        DateTime(2026, 10, 6, 12),
      );
      expect(sum.total, 9000);
      expect(sum.days, 2);
      expect(sum.dailyAverage, 4500);
      expect(sum.previous, 3600);
      expect(sum.diff, 5400);
    });

    test('지난달이 더 짧아도 지난달 안에서만 센다', () {
      final data = [
        _s(DateTime(2026, 2, 27, 10), 100),
        _s(DateTime(2026, 3, 1, 1), 50), // 이번 달
      ];
      final sum = periodSummary(
        data,
        StatsRange.month,
        DateTime(2026, 3, 31, 12),
      );
      expect(sum.previous, 100);
      expect(sum.days, 31);
    });

    test('날짜별 합계', () {
      final t = dailyTotals([
        _s(DateTime(2026, 10, 1, 22), 600),
        _s(DateTime(2026, 10, 2, 1), 300),
      ], dayStartHour: 5);
      expect(t, {DateTime(2026, 10, 1): 900});
    });
  });

  group('타임라인과 규칙성', () {
    test('하루 타임라인은 하루 시작 시각부터 분으로 센다', () {
      final segs = dayTimeline(
        [
          _s(DateTime(2026, 10, 1, 22), 3600, subject: 'x'),
          _s(DateTime(2026, 10, 2, 4, 30), 3600), // 5시에 잘림
        ],
        DateTime(2026, 10, 1),
        dayStartHour: 5,
      );
      expect(segs.length, 2);
      expect(segs[0].startMin, 17 * 60);
      expect(segs[0].endMin, 18 * 60);
      expect(segs[0].subjectId, 'x');
      expect(segs[1].startMin, 23 * 60 + 30);
      expect(segs[1].endMin, 24 * 60);
      expect(clockFromDayStart(segs[1].startMin, 5), '04:30');
    });

    test('시작·종료 평균과 흩어진 정도', () {
      final r = studyRegularity(
        [
          _s(DateTime(2026, 10, 3, 21), 3600),
          _s(DateTime(2026, 10, 4, 23), 3600),
        ],
        DateTime(2026, 10, 5, 12),
        dayStartHour: 5,
      )!;
      expect(r.days.length, 2);
      expect(clockFromDayStart(r.avgStart.round(), 5), '22:00');
      expect(clockFromDayStart(r.avgEnd.round(), 5), '23:00');
      expect(r.startSpread, 60);
    });

    test('공부한 날이 하루뿐이면 규칙성은 없다', () {
      expect(
        studyRegularity([
          _s(DateTime(2026, 10, 4, 21), 60),
        ], DateTime(2026, 10, 5)),
        isNull,
      );
    });

    test('일별 추이', () {
      final trend = buildTrend(
        [_s(DateTime(2026, 10, 5, 2), 600), _s(DateTime(2026, 10, 5, 9), 60)],
        TrendUnit.day,
        DateTime(2026, 10, 5, 12),
        count: 3,
        dayStartHour: 5,
      );
      expect(trend.map((p) => p.label), ['10/3', '10/4', '10/5']);
      expect(trend[1].total, 600);
      expect(trend[2].total, 60);
    });
  });

  test('딴짓 통계', () {
    final d = distractionStat(
      [
        _s(
          DateTime(2026, 10, 5, 9),
          3600,
          distractions: 3,
          distractedSeconds: 120,
        ),
        _s(DateTime(2026, 9, 1, 9), 3600, distractions: 9),
      ],
      [
        ThoughtNote(
          id: '1',
          text: 'x',
          createdAt: DateTime(2026, 10, 5, 9).toUtc(),
        ),
      ],
      DateTime(2026, 10, 1),
    );
    expect(d.count, 3);
    expect(d.seconds, 120);
    expect(d.perHour, 3);
    expect(d.thoughts, 1);
  });

  test('형식', () {
    expect(formatHms(66 * 3600 + 6 * 60 + 35), '66:06:35');
    expect(formatHm(4 * 3600 + 56 * 60 + 59), '4:56');
  });
}
