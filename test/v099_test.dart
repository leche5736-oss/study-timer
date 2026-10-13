import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_timer/main.dart';
import 'package:study_timer/models.dart';
import 'package:study_timer/services/store.dart';

DailyPlan _plan(AppStore store) => DailyPlan.fromJson({
  'day': store.studyDayKey,
  'note': '형법 45강 끝내기',
  'items': [
    {
      'subject': '형 법',
      'task': '형법 45강',
      'minutes': 120,
      'book': '형법총론',
      'target': 'p.58',
    },
    {'subject': '상법', 'minutes': 60},
    {'subject': '', 'task': ''}, // 빈 줄은 버림
  ],
});

void main() {
  test('오늘 계획: 목표는 계획 시간의 합, 과목은 이름으로 맞춘다', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = AppStore(prefs);
    final a = store.addSubject('형법');
    store.updateSettings(store.settings.copyWith(dailyGoalMin: 300));
    expect(store.goalMinutes, 300);

    store.setPlan(_plan(store));
    expect(store.todayPlan!.items, hasLength(2));
    expect(store.goalMinutes, 180);
    expect(store.subjectNamed('형 법')?.id, a.id);
    expect(store.plannedBook(a.id), '형법총론');

    // 껐다 켜도 남아 있음
    expect(AppStore(prefs).todayPlan?.items.first.target, 'p.58');

    // 지난 날 계획은 무시
    store.setPlan(
      DailyPlan.fromJson({
        'day': '2000-01-01',
        'items': [
          {'subject': '형법', 'minutes': 30},
        ],
      }),
    );
    expect(store.todayPlan, isNull);
    expect(store.goalMinutes, 300);
  });

  testWidgets('첫 화면의 계획 줄을 누르면 그 과목으로 바로 시작', (tester) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final store = AppStore(await SharedPreferences.getInstance());
    final a = store.addSubject('형법');
    store.addSubject('상법');
    store.setPlan(_plan(store));
    await tester.pumpWidget(StudyTimerApp(store: store));

    expect(find.text('형 법 · 형법 45강'), findsOneWidget);
    expect(find.text('형법총론 p.58'), findsOneWidget);
    expect(find.text('0:00 / 2:00'), findsOneWidget);
    expect(find.textContaining('/ 3:00'), findsOneWidget); // 목표 = 계획 합
    await tester.tap(find.text('형 법 · 형법 45강'));
    await tester.pump();
    expect(store.timer.phase, Phase.focus);
    expect(store.timer.subjectId, a.id);
  });

  testWidgets('과목 색 동그라미를 누르면 색 줄이 뜨고 고르면 바뀐다', (tester) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final store = AppStore(await SharedPreferences.getInstance());
    final s = store.addSubject('영어');
    await tester.pumpWidget(StudyTimerApp(store: store));
    await tester.tap(find.byTooltip('과목'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(ValueKey('dot-${s.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('color-${AppStore.palette[9]}')));
    await tester.pumpAndSettle();
    expect(store.subject(s.id)!.color, AppStore.palette[9]);

    // 오른쪽으로 밀어도 아무 일 없음 (책은 눌러서)
    await tester.drag(find.text('영어'), const Offset(600, 0));
    await tester.pumpAndSettle();
    expect(store.subjects, hasLength(1));
    expect(find.byKey(const Key('subject-name')), findsNothing);
  });
}
