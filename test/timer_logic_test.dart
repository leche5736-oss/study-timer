import 'package:flutter_test/flutter_test.dart';
import 'package:study_timer/models.dart';
import 'package:study_timer/timer_logic.dart';

void main() {
  final t0 = DateTime.utc(2026, 10, 5, 9);
  DateTime at(int sec) => t0.add(Duration(seconds: sec));

  TimerState started({
    Preset preset = const Preset('25/5', 25, 5, 15),
    bool stopwatch = false,
    TimerState? from,
    String id = 's1',
  }) => TimerLogic.startFocus(
    from ?? TimerState.initial(),
    subjectId: 'math',
    presetIndex: 0,
    preset: preset,
    sessionId: id,
    now: t0,
    stopwatch: stopwatch,
  );

  test('집중 시작 후 남은 시간은 시작 시각 기준으로 계산된다', () {
    final s = started();
    expect(s.phase, Phase.focus);
    expect(s.remainingSec(at(60)), 25 * 60 - 60);
  });

  test('일시정지 동안은 시간이 흐르지 않는다', () {
    var s = TimerLogic.pause(started(), at(100));
    expect(s.remainingSec(at(1000)), 25 * 60 - 100);
    s = TimerLogic.resume(s, at(1000));
    expect(s.remainingSec(at(1010)), 25 * 60 - 110);
  });

  test('시간이 다 되면 정리 노트 단계로 넘어가고 전체 시간이 기록된다', () {
    final s = TimerLogic.tick(started(), at(25 * 60 + 5));
    expect(s.phase, Phase.recall);
    expect(s.completedFocusSec, 25 * 60);
  });

  test('일찍 끝내면 실제 집중한 시간만 기록된다', () {
    final s = TimerLogic.finishFocus(started(), at(600));
    expect(s.completedFocusSec, 600);
  });

  test('정리 노트 저장 시 기록이 생기고 휴식이 시작된다', () {
    final recall = TimerLogic.finishFocus(started(), at(25 * 60));
    final (session, rest) = TimerLogic.submitRecall(
      recall,
      now: at(25 * 60 + 30),
      focusRating: 4,
      recallNote: 'a',
    );
    expect(session.id, 's1');
    expect(session.subjectId, 'math');
    expect(session.focusSeconds, 25 * 60);
    expect(session.focusRating, 4);
    expect(session.plannedMinutes, 25);
    expect(rest.phase, Phase.rest);
    expect(rest.durationSec, 5 * 60);
    expect(rest.blocksDone, 1);
    expect(rest.lastSessionId, 's1');
  });

  test('직접 설정한 길이를 쓴다', () {
    const custom = Preset('직접', 40, 8, 20);
    final s = started(preset: custom);
    expect(s.durationSec, 40 * 60);
    final (_, rest) = TimerLogic.submitRecall(
      TimerLogic.finishFocus(s, at(40 * 60)),
      now: at(40 * 60),
    );
    expect(rest.durationSec, 8 * 60);
  });

  test('4번째 블록 뒤에는 긴 휴식', () {
    var s = TimerState.initial();
    late TimerState rest;
    for (var i = 0; i < 4; i++) {
      s = started(from: s, id: 's$i');
      s = TimerLogic.finishFocus(s, at(10));
      (_, rest) = TimerLogic.submitRecall(s, now: at(20));
      s = TimerLogic.toIdle(rest, at(30));
    }
    expect(rest.longRest, isTrue);
    expect(rest.durationSec, 15 * 60);
  });

  test('휴식이 끝나면 대기 상태로 돌아가고 과목은 유지된다', () {
    final recall = TimerLogic.finishFocus(started(), at(60));
    final (_, rest) = TimerLogic.submitRecall(recall, now: at(60));
    final idle = TimerLogic.tick(rest, at(60 + 5 * 60));
    expect(idle.phase, Phase.idle);
    expect(idle.subjectId, 'math');
  });

  group('스톱워치', () {
    test('시간이 지나도 저절로 끝나지 않고 위로 센다', () {
      final s = started(stopwatch: true);
      expect(s.endsAt(), isNull);
      final later = TimerLogic.tick(s, at(5 * 3600));
      expect(later.phase, Phase.focus);
      expect(later.elapsedSec(at(5 * 3600)), 5 * 3600);
    });

    test('끝내면 집중한 시간 전체가 기록되고 1/5만큼 쉰다', () {
      final recall = TimerLogic.finishFocus(started(stopwatch: true), at(4000));
      expect(recall.completedFocusSec, 4000);
      final (session, rest) = TimerLogic.submitRecall(recall, now: at(4000));
      expect(session.focusSeconds, 4000);
      expect(session.plannedMinutes, 0);
      expect(rest.durationSec, 13 * 60); // 66.7분 / 5 ≈ 13분
    });

    test('휴식은 5~30분 사이', () {
      expect(stopwatchRestMin(60), 5);
      expect(stopwatchRestMin(4 * 3600), 30);
    });
  });

  test('JSON으로 저장했다 불러와도 같다', () {
    final s = TimerLogic.pause(started(stopwatch: true), at(42));
    final back = TimerState.fromJson(s.toJson());
    expect(back.phase, s.phase);
    expect(back.accumulatedSec, 42);
    expect(back.isRunning, isFalse);
    expect(back.stopwatch, isTrue);
    expect(back.updatedAt, s.updatedAt);
  });

  test('예전 버전에 저장된 상태도 읽는다', () {
    final old = {
      'phase': 'focus',
      'preset_index': 1,
      'duration_sec': 3000,
      'running_since': t0.toIso8601String(),
      'updated_at': t0.toIso8601String(),
    };
    final s = TimerState.fromJson(old);
    expect(s.focusMin, 50);
    expect(s.restMin, 10);
    expect(s.stopwatch, isFalse);
  });
}
