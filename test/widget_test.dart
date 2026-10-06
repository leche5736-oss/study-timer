import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_timer/main.dart';
import 'package:study_timer/services/store.dart';

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
    await tester.tap(find.text('과목 추가').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '수학');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(find.text('수학'), findsOneWidget);

    await tester.tap(find.byTooltip('설정'));
    await tester.pumpAndSettle();
    expect(find.text('0.8.1'), findsOneWidget);
    Navigator.of(tester.element(find.text('0.8.1'))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('색 바꾸기'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('color-${AppStore.palette[2]}')));
    await tester.pumpAndSettle();
    expect(store.subjects.single.color, AppStore.palette[2]);

    await tester.tap(find.byIcon(Icons.timer_outlined));
    await tester.pumpAndSettle();
    expect(find.text('25:00'), findsOneWidget);
    expect(find.text('휴식 5분'), findsOneWidget);
    await tester.tap(find.text('시작'));
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

    await tester.tap(find.text('저장하고 휴식'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('휴식'), findsOneWidget);
    expect(find.text('택배 찾기'), findsOneWidget); // 휴식 때 다시 보여줌
    await tester.tap(find.text('휴식 건너뛰기'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('1블록 완료'), findsOneWidget);
    expect(find.text('딴생각 메모 1개'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.bar_chart_outlined));
    await tester.pumpAndSettle();
    expect(find.text('총 시간'), findsOneWidget);
    for (final tab in ['달력', '패턴', '분석']) {
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle();
    }
    // 기록이 적으면 분석 대신 얼마나 더 쌓아야 하는지 보여 줌
    expect(find.textContaining('더 쌓이면 볼 수 있어요'), findsNWidgets(3));
  });
}
