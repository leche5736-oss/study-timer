import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_timer/models.dart';
import 'package:study_timer/services/sync_config.dart';
import 'package:study_timer/stats.dart';

void main() {
  test('메뉴 막대 글자', () {
    final start = DateTime.utc(2026, 10, 5, 9);
    final focus = TimerState(
      phase: Phase.focus,
      durationSec: 1500,
      runningSince: start,
      updatedAt: start,
    );
    expect(
      menuBarText(focus, start.add(const Duration(seconds: 2))),
      '집중 24:58',
    );
    final paused = TimerState(
      phase: Phase.focus,
      durationSec: 1500,
      accumulatedSec: 60,
      updatedAt: start,
    );
    expect(menuBarText(paused, start), '일시정지 24:00');
    final rest = TimerState(
      phase: Phase.rest,
      durationSec: 300,
      runningSince: start,
      updatedAt: start,
    );
    expect(menuBarText(rest, start), '휴식 05:00');
    expect(menuBarText(TimerState.initial(), start), isNull);
  });

  test('메뉴 막대 설정은 저장된다', () {
    final s = Settings.fromJson(
      const Settings().copyWith(menuBar: false).toJson(),
    );
    expect(s.menuBar, isFalse);
    expect(Settings.fromJson({}).menuBar, isTrue);
  });

  test('동기화 주소가 잘못되면 저장하지 않는다', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    expect(SyncConfig.load(prefs), isNull);
    await expectLater(
      SyncConfig.connect(prefs, 'xxxx.supabase.co', 'key'),
      throwsFormatException,
    );
    expect(SyncConfig.load(prefs), isNull);
  });

  test('저장된 동기화 정보를 읽는다', () async {
    SharedPreferences.setMockInitialValues({
      'sync_config': '{"url":"https://a.supabase.co","key":"k"}',
    });
    final c = SyncConfig.load(await SharedPreferences.getInstance())!;
    expect(c.url, 'https://a.supabase.co');
    expect(c.publishableKey, 'k');
  });
}
