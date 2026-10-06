import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_timer/main.dart';
import 'package:study_timer/models.dart';
import 'package:study_timer/phone_flip.dart';
import 'package:study_timer/services/notifications.dart';
import 'package:study_timer/services/store.dart';
import 'package:study_timer/timer_logic.dart';

void main() {
  group('폰 엎어 두기', () {
    final t0 = DateTime.utc(2026, 10, 6, 9);
    DateTime at(int sec) => t0.add(Duration(seconds: sec));

    test('엎어 둔 뒤 10초 넘게 들어 올리면 들어 올린 순간부터 딴짓', () {
      final d = FlipDetector();
      expect(d.sample(9.8, at(0)), isNull); // 아직 엎어 두지 않음: 세지 않음
      expect(d.sample(-9.8, at(1)), isNull);
      expect(d.sample(-9.8, at(3)), isNull);
      expect(d.armed, isTrue);
      expect(d.sample(9.8, at(20)), isNull); // 들어 올림
      expect(d.sample(9.8, at(25)), isNull); // 5초: 아직 아님
      final e = d.sample(9.8, at(31))!;
      expect(e.away, isTrue);
      expect(e.at, at(20));
      expect(d.sample(-9.8, at(40)), isNull);
      final back = d.sample(-9.8, at(41))!;
      expect(back.away, isFalse);
    });

    test('잠깐 들었다 놓으면 세지 않는다', () {
      final d = FlipDetector()
        ..sample(-9.8, at(0))
        ..sample(-9.8, at(2));
      expect(d.sample(0, at(10)), isNull);
      expect(d.sample(0, at(15)), isNull);
      expect(d.sample(-9.8, at(16)), isNull);
      expect(d.away, isFalse);
    });

    test('엎어 둔 뒤 다른 앱을 켜면 바로 딴짓', () {
      final d = FlipDetector();
      expect(d.appHidden(at(0)), isNull); // 엎어 두기 전에는 세지 않음
      d
        ..sample(-9.8, at(0))
        ..sample(-9.8, at(2));
      final e = d.appHidden(at(5))!;
      expect(e.away, isTrue);
      expect(d.appHidden(at(6)), isNull); // 한 번만
    });

    test('스토어에 딴짓 횟수와 시간이 쌓인다', () async {
      SharedPreferences.setMockInitialValues({});
      var clock = t0;
      final store = AppStore(
        await SharedPreferences.getInstance(),
        clock: () => clock,
      );
      final s = store.addSubject('형법');
      store.startFocus(s.id, 0);
      clock = at(100);
      store.phoneFlipped(away: true, at: at(60));
      clock = at(130);
      store.phoneFlipped(away: false, at: at(130));
      expect(store.timer.distractions, 1);
      expect(store.timer.distractedSec, 70);
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
