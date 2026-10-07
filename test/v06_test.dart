import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_timer/models.dart';
import 'package:study_timer/config.dart';
import 'package:study_timer/services/sync_config.dart';

void main() {
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
    // 처음에는 앱에 들어 있는 기본 연결을 씁니다.
    expect(SyncConfig.load(prefs)!.url, AppConfig.supabaseUrl);
    await expectLater(
      SyncConfig.connect(prefs, 'xxxx.supabase.co', 'key'),
      throwsFormatException,
    );
    expect(SyncConfig.load(prefs)!.url, AppConfig.supabaseUrl);
  });

  test('동기화를 끄면 기본 연결도 쓰지 않는다', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await SyncConfig.disconnect(prefs);
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
