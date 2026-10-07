import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_timer/models.dart';
import 'package:study_timer/screens/tilt_rotate.dart';
import 'package:study_timer/services/store.dart';
import 'package:study_timer/stats.dart';
import 'package:study_timer/timer_logic.dart';

void main() {
  test('한 시간이 넘으면 시간을 앞에 붙여 보여 준다', () {
    expect(formatClock(25 * 60), '25:00');
    expect(formatClock(3 * 3600 + 30 * 60), '3:30:00');
    expect(formatClock(3600 + 5 * 60 + 9), '1:05:09');
  });

  test('타이머 모드: 정한 길이로 집중하고, 정리 노트 뒤 휴식 없이 끝난다', () {
    final t0 = DateTime.utc(2026, 10, 7, 13);
    const settings = Settings(timerMin: 210);
    var s = TimerLogic.startFocus(
      TimerState.initial(),
      subjectId: 'a',
      presetIndex: timerPresetIndex,
      preset: settings.presetAt(timerPresetIndex),
      sessionId: 's1',
      now: t0,
    );
    expect(s.durationSec, 210 * 60);
    s = TimerLogic.tick(s, t0.add(const Duration(minutes: 211)));
    expect(s.phase, Phase.recall);
    final (session, next) = TimerLogic.submitRecall(s, now: t0);
    expect(session.focusSeconds, 210 * 60);
    expect(next.phase, Phase.idle);
    expect(next.blocksDone, 0); // 블록으로 세지 않음
    expect(next.presetIndex, timerPresetIndex);
  });

  group('하루 목표 등 공유 설정 동기화', () {
    late AppStore store;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      store = AppStore(await SharedPreferences.getInstance());
    });

    test('목표를 바꾸면 바뀐 시각이 찍히고 서버에 올린다', () {
      var pushed = 0;
      store.onLocalChange = () => pushed++;
      store.updateSettings(store.settings.copyWith(dailyGoalMin: 240));
      expect(store.settings.sharedUpdatedAt, isNotNull);
      expect(pushed, 1);
      store.updateSettings(store.settings.copyWith(sound: false));
      expect(pushed, 1); // 이 기기 전용 설정은 올리지 않음
    });

    test('더 최근에 바뀐 다른 기기의 목표를 받는다 (이 기기 전용 설정은 유지)', () {
      store.updateSettings(store.settings.copyWith(sound: false));
      final remote = const Settings(
        dailyGoalMin: 300,
        timerMin: 180,
      ).copyWith(sharedUpdatedAt: DateTime.now().toUtc()).sharedJson();
      store.mergeRemote(settings: remote);
      expect(store.settings.dailyGoalMin, 300);
      expect(store.settings.timerMin, 180);
      expect(store.settings.sound, false);
      // 더 오래된 값은 무시
      store.mergeRemote(
        settings: const Settings(dailyGoalMin: 60)
            .copyWith(sharedUpdatedAt: DateTime.utc(2020))
            .sharedJson(),
      );
      expect(store.settings.dailyGoalMin, 300);
    });
  });

  test('폰 기울기로 가로 돌리기 판단', () {
    expect(tiltTurns(0, 9.8, 1), 0); // 세워 듦 → 세로
    expect(tiltTurns(9.8, 0, 0), 1); // 왼쪽 옆면이 아래
    expect(tiltTurns(-9.8, 0, 0), 3);
    expect(tiltTurns(0.5, 0.5, 1), 1); // 책상에 눕혀 둠 → 그대로
  });
}
