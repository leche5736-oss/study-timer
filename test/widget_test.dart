import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_timer/main.dart';
import 'package:study_timer/services/store.dart';

void main() {
  testWidgets('과목을 추가하고 집중을 시작할 수 있다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore(await SharedPreferences.getInstance());
    await tester.pumpWidget(StudyTimerApp(store: store));

    expect(find.text('먼저 공부할 과목을 추가하세요.'), findsOneWidget);
    await tester.tap(find.text('과목 추가하러 가기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('과목 추가').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '수학');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(find.text('수학'), findsOneWidget);
    expect(find.text('공부 타이머 v0.2.0'), findsOneWidget);

    await tester.tap(find.byTooltip('색 바꾸기'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('color-${AppStore.palette[2]}')));
    await tester.pumpAndSettle();
    expect(store.subjects.single.color, AppStore.palette[2]);

    await tester.tap(find.byIcon(Icons.timer));
    await tester.pumpAndSettle();
    await tester.tap(find.text('집중 시작'));
    await tester.pump();
    expect(find.textContaining('집중 중'), findsOneWidget);
    expect(find.text('25:00'), findsOneWidget);

    await tester.tap(find.text('지금 끝내기'));
    await tester.pump();
    expect(find.text('방금 배운 것 3줄'), findsOneWidget);

    await tester.tap(find.text('저장하고 조용한 휴식 시작'));
    await tester.pump();
    expect(find.text('조용한 휴식'), findsOneWidget);
    await tester.tap(find.text('휴식 건너뛰기'));
    await tester.pump();
    expect(find.text('다음 블록 시작'), findsOneWidget);
  });
}
