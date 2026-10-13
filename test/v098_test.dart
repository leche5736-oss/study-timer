import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_timer/main.dart';
import 'package:study_timer/models.dart';
import 'package:study_timer/services/store.dart';

void main() {
  test('진도에 숫자만 적으면 "쪽"이 붙는다', () {
    expect(normalizeProgress(' 120 '), '120쪽');
    expect(normalizeProgress('3장 2절'), '3장 2절');
    expect(normalizeProgress('120쪽'), '120쪽');
    expect(normalizeProgress(''), '');
  });

  group('저장소', () {
    late DateTime clock;
    late AppStore store;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      clock = DateTime.utc(2026, 10, 13, 11);
      store = AppStore(
        await SharedPreferences.getInstance(),
        clock: () => clock,
      );
    });

    void study(String subjectId, String book, {String? switchTo}) {
      store.startFocus(subjectId, 0);
      clock = clock.add(const Duration(minutes: 25));
      store.tick();
      store.submitRecall(book: book, progress: '45', subjectId: switchTo);
      store.skipRest();
      clock = clock.add(const Duration(minutes: 5));
    }

    test('책은 최근에 쓴 순서로, 진도 숫자는 쪽으로 저장', () {
      final s = store.addSubject('민사법');
      store.setSubjectBooks(s.id, ['A', 'B', 'C']);
      study(s.id, 'B');
      study(s.id, 'C');
      expect(store.recentBooks(s.id), ['C', 'B', 'A']);
      expect(store.sessions.first.progress, '45쪽');
    });

    test('다른 과목 책을 고르고 과목을 바꾸면 기록 과목이 바뀐다', () {
      final a = store.addSubject('민사법');
      final b = store.addSubject('형사법');
      study(a.id, '형법총론', switchTo: b.id);
      expect(store.sessions.single.subjectId, b.id);
    });

    test('삭제한 과목을 되돌린다', () {
      final s = store.addSubject('영어');
      store.deleteSubject(s.id);
      expect(store.subjects, isEmpty);
      store.restoreSubject(s.id);
      expect(store.subjects.single.name, '영어');
    });
  });

  testWidgets('과목을 왼쪽으로 밀어 삭제하고 되돌린다', (tester) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final store = AppStore(await SharedPreferences.getInstance());
    store.addSubject('영어');
    await tester.pumpWidget(StudyTimerApp(store: store));
    await tester.tap(find.byTooltip('과목'));
    await tester.pumpAndSettle();

    await tester.drag(find.text('영어'), const Offset(-800, 0));
    await tester.pumpAndSettle();
    expect(store.subjects, isEmpty);
    await tester.tap(find.text('되돌리기'));
    await tester.pumpAndSettle();
    expect(store.subjects.single.name, '영어');
  });

  testWidgets('정리 노트: 책 시트에서 다른 과목 책을 고르면 과목을 바꿀지 묻는다', (tester) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final store = AppStore(await SharedPreferences.getInstance());
    final a = store.addSubject('민사법');
    final b = store.addSubject('형사법');
    store.setSubjectBooks(a.id, ['민법의 맥']);
    store.setSubjectBooks(b.id, ['형법총론']);
    store.startFocus(a.id, 0);
    store.finishFocus();
    await tester.pumpWidget(StudyTimerApp(store: store));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('recall-book')));
    await tester.pumpAndSettle();
    expect(find.text('다른 과목'), findsOneWidget);
    await tester.tap(find.text('형사법')); // 접힌 과목 펼치기
    await tester.pumpAndSettle();
    await tester.tap(find.text('형법총론'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('바꾸기'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('recall-progress')), '88');
    await tester.tap(find.text('저장하고 마치기'));
    await tester.pumpAndSettle();
    final saved = store.sessions.single;
    expect(saved.subjectId, b.id);
    expect(saved.book, '형법총론');
    expect(saved.progress, '88쪽');
  });
}
