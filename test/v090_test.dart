import 'package:flutter_test/flutter_test.dart';
import 'package:study_timer/models.dart';
import 'package:study_timer/services/live_activity.dart';

void main() {
  final t0 = DateTime.utc(2026, 10, 7, 9);

  test('잠금화면 타이머: 집중 중이면 끝나는 시각을 보낸다', () {
    final t = TimerState(
      phase: Phase.focus,
      durationSec: 1500,
      accumulatedSec: 300,
      runningSince: t0,
      updatedAt: t0,
    );
    final s = liveActivityState(t, '형법')!;
    expect(s['title'], '형법');
    expect(s['rest'], false);
    expect(s['paused'], false);
    final start = t0.subtract(const Duration(seconds: 300));
    expect(s['startedAt'], start.millisecondsSinceEpoch);
    expect(
      s['endsAt'],
      start.add(const Duration(seconds: 1500)).millisecondsSinceEpoch,
    );
  });

  test('잠금화면 타이머: 일시정지면 남은 시간을 고정해서 보여 준다', () {
    final t = TimerState(
      phase: Phase.focus,
      durationSec: 1500,
      accumulatedSec: 600,
      updatedAt: t0,
    );
    final s = liveActivityState(t, '상법')!;
    expect(s['paused'], true);
    expect(s['shownSec'], 900);
    // 같은 상태면 내용도 같아서 다시 보내지 않는다.
    expect(liveActivityState(t, '상법').toString(), s.toString());
  });

  test('잠금화면 타이머: 스톱워치는 끝 시각이 없고, 휴식·대기 중 처리', () {
    final sw = TimerState(
      phase: Phase.focus,
      stopwatch: true,
      runningSince: t0,
      updatedAt: t0,
    );
    expect(liveActivityState(sw, null)!['endsAt'], isNull);
    final rest = TimerState(
      phase: Phase.rest,
      longRest: true,
      durationSec: 900,
      runningSince: t0,
      updatedAt: t0,
    );
    expect(liveActivityState(rest, null)!['title'], '긴 휴식');
    expect(liveActivityState(TimerState.initial(), null), isNull);
  });
}
