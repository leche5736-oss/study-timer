import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_timer/main.dart';
import 'package:study_timer/models.dart';
import 'package:study_timer/services/store.dart';
import 'package:study_timer/theme.dart';

/// 첫 화면에서 고리 밖을 눌러 시작.
Future<void> tapOutsideRing(WidgetTester tester) => tester.tapAt(
  tester.getTopLeft(find.byKey(const Key('idle-start'))) + const Offset(20, 20),
);

void main() {
  testWidgets('과목을 추가하고 집중을 시작할 수 있다', (tester) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final store = AppStore(await SharedPreferences.getInstance());
    await tester.pumpWidget(StudyTimerApp(store: store));

    expect(find.text('공부할 과목을 먼저 추가하세요'), findsOneWidget);
    await tester.tap(find.text('과목 추가'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('과목 추가')); // 목록 맨 아래 줄
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '수학');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(find.text('수학'), findsOneWidget);

    // 색 동그라미를 누르면 색 줄
    await tester.tap(find.byKey(ValueKey('dot-${store.subjects.single.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('color-${AppStore.palette[2]}')));
    await tester.pumpAndSettle();
    expect(store.subjects.single.color, AppStore.palette[2]);

    // 과목을 누르면 이름·책 시트 (색 고르기는 없음)
    await tester.tap(find.text('수학'));
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('color-${AppStore.palette[2]}')), findsNothing);
    Navigator.of(tester.element(find.byKey(const Key('subject-name')))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('내 정보'));
    await tester.pumpAndSettle();
    expect(find.text('0.9.12'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('theme-sage')));
    await tester.pumpAndSettle();
    expect(store.settings.colorTheme, 'sage');
    expect(AppColors.accent, colorThemeById('sage').accent);

    await tester.tap(find.byTooltip('타이머'));
    await tester.pumpAndSettle();
    expect(find.text('25:00'), findsOneWidget);
    expect(find.text('휴식 5분'), findsOneWidget);
    await tapOutsideRing(tester);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('25:00'), findsOneWidget);
    expect(find.text('수학'), findsOneWidget);
    expect(find.text('화면을 누르면 버튼이 나와요'), findsOneWidget);
    await tester.tap(find.text('25:00')); // 숨은 버튼 보이기
    await tester.pump();
    expect(find.text('화면을 누르면 버튼이 나와요'), findsNothing);

    await tester.enterText(find.byType(TextField), '택배 찾기');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(store.thoughts.single.text, '택배 찾기');

    await tester.tap(find.text('끝내기'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('수고했어요'), findsOneWidget);

    // 일찍 끝낸 블록은 휴식 없이 바로 마칩니다.
    await tester.tap(find.text('저장하고 마치기'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(store.timer.phase, Phase.idle);
    expect(find.textContaining('블록 완료'), findsNothing); // 일찍 끝낸 블록은 안 셈
    await tester.tap(find.byTooltip('내 정보'));
    await tester.pumpAndSettle();
    expect(find.text('딴생각 메모 (1개 남음)'), findsOneWidget);

    await tester.tap(find.byTooltip('통계'));
    await tester.pumpAndSettle();
    expect(find.text('총 시간'), findsOneWidget);
    for (final tab in ['달력', '패턴']) {
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle();
    }
    expect(find.text('분석'), findsNothing); // 분석은 Claude에게 맡김
  });

  testWidgets('과목이 여러 개면 시작을 누른 뒤 과목을 고른다', (tester) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final store = AppStore(await SharedPreferences.getInstance());
    store.addSubject('형법');
    final b = store.addSubject('상법');
    await tester.pumpWidget(StudyTimerApp(store: store));
    expect(find.text('상법'), findsNothing); // 첫 화면에는 과목 이름이 없음

    await tapOutsideRing(tester);
    await tester.pumpAndSettle();
    expect(find.text('무엇을 공부할까요?'), findsOneWidget);
    await tester.tap(find.text('상법'));
    await tester.pump();
    expect(store.timer.phase, Phase.focus);
    expect(store.timer.subjectId, b.id);
  });
}
