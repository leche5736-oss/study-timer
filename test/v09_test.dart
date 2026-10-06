import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_timer/main.dart';
import 'package:study_timer/models.dart';
import 'package:study_timer/services/notifications.dart';
import 'package:study_timer/services/store.dart';
import 'package:study_timer/timer_logic.dart';

void main() {
  group('집중 중 과목 바꾸기', () {
    final t0 = DateTime.utc(2026, 10, 6, 9);
    DateTime at(int min) => t0.add(Duration(minutes: min));

    Future<(AppStore, void Function(DateTime))> setup() async {
      SharedPreferences.setMockInitialValues({});
      var clock = t0;
      final store = AppStore(
        await SharedPreferences.getInstance(),
        clock: () => clock,
      );
      return (store, (DateTime t) => clock = t);
    }

    test('바꾸기 전 시간은 앞 과목, 남은 시간은 새 과목으로 기록되고 블록은 이어진다', () async {
      final (store, setClock) = await setup();
      final a = store.addSubject('형법');
      final b = store.addSubject('민법');
      store.startFocus(a.id, 0); // 25분
      setClock(at(10));
      store.switchSubject(b.id);
      expect(store.timer.subjectId, b.id);
      expect(store.timer.remainingSec(at(10)), 15 * 60); // 시간은 이어짐
      setClock(at(25));
      store.tick(); // 시간이 다 되어 정리 노트로
      expect(store.timer.phase, Phase.recall);
      store.submitRecall(rating: 4);
      final bySubject = {
        for (final s in store.allSessions) s.subjectId: s.focusSeconds,
      };
      expect(bySubject, {a.id: 600, b.id: 900});
      expect(store.timer.blocksDone, 1); // 끝까지 채운 블록으로 셈
    });

    test('1분 안에 바꾸면 기록 없이 과목만 바뀐다', () async {
      final (store, setClock) = await setup();
      final a = store.addSubject('형법');
      final b = store.addSubject('민법');
      store.startFocus(a.id, 0);
      setClock(t0.add(const Duration(seconds: 30)));
      store.switchSubject(b.id);
      expect(store.allSessions, isEmpty);
      setClock(at(25));
      store.tick();
      store.submitRecall();
      expect(store.allSessions.single.subjectId, b.id);
      expect(store.allSessions.single.focusSeconds, 1500);
    });
  });

  test('휴식 끝 1분 전 미리 알림 시각', () {
    final t0 = DateTime.utc(2026, 10, 6, 9);
    var s = TimerLogic.startFocus(
      TimerState.initial(),
      subjectId: 'a',
      presetIndex: 0,
      preset: presets[0],
      sessionId: 'x',
      now: t0,
    );
    expect(Notifications.restWarnAt(s), isNull); // 집중 중에는 없음
    s = TimerLogic.finishFocus(s, t0.add(const Duration(minutes: 25)));
    final (_, rest) = TimerLogic.submitRecall(
      s,
      now: t0.add(const Duration(minutes: 25)),
    );
    expect(
      Notifications.restWarnAt(rest),
      t0.add(const Duration(minutes: 29)), // 5분 휴식이 끝나기 1분 전
    );
  });

  testWidgets('스페이스: 첫 화면에서 시작, 집중 중 일시정지와 계속', (tester) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final store = AppStore(await SharedPreferences.getInstance());
    store.addSubject('형법');
    await tester.pumpWidget(StudyTimerApp(store: store));

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(store.timer.phase, Phase.focus); // 과목이 하나면 바로 시작
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(store.timer.isRunning, isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(store.timer.isRunning, isTrue);

    // 딴생각 메모를 쓰는 중에는 스페이스가 글자로 들어감
    await tester.showKeyboard(find.byType(TextField));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(store.timer.isRunning, isTrue);
  });
}
