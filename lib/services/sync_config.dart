import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';

/// 동기화(Supabase) 연결 정보. 설정 화면에서 넣고 이 기기에 저장합니다.
/// config.dart에 값이 들어 있으면 그것을 먼저 씁니다.
class SyncConfig {
  static const _key = 'sync_config';

  final String url;
  final String publishableKey;
  const SyncConfig(this.url, this.publishableKey);

  /// 동기화가 준비됐으면(Supabase 초기화 완료) 연결 정보, 아니면 null.
  static final active = ValueNotifier<SyncConfig?>(null);

  static bool _initialized = false;
  static String? _initializedUrl;

  static SyncConfig? load(SharedPreferences prefs) {
    if (AppConfig.syncEnabled) {
      return const SyncConfig(
        AppConfig.supabaseUrl,
        AppConfig.supabasePublishableKey,
      );
    }
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    final j = jsonDecode(raw) as Map<String, dynamic>;
    return SyncConfig(j['url'] as String, j['key'] as String);
  }

  /// 저장된 연결 정보가 있으면 Supabase를 켭니다. 실패하면 동기화 없이 계속.
  static Future<void> startFromSaved(SharedPreferences prefs) async {
    final c = load(prefs);
    if (c == null) return;
    try {
      await _init(c);
    } catch (e) {
      debugPrint('동기화 시작 실패: $e');
    }
  }

  /// 새 연결 정보를 저장하고 바로 켭니다. 주소가 잘못되면 예외.
  static Future<void> connect(
    SharedPreferences prefs,
    String url,
    String key,
  ) async {
    final c = SyncConfig(url.trim(), key.trim());
    if (!c.url.startsWith('https://') || c.publishableKey.isEmpty) {
      throw const FormatException('Project URL(https://…)과 키를 모두 넣어 주세요.');
    }
    await prefs.setString(
      _key,
      jsonEncode({'url': c.url, 'key': c.publishableKey}),
    );
    // Supabase는 앱을 켠 동안 한 번만 초기화할 수 있어서, 이미 다른 주소로
    // 켜졌다면 다음 실행 때 새 주소를 씁니다.
    if (_initialized && _initializedUrl != c.url) {
      throw StateError('저장했어요. 앱을 껐다 켜면 새 주소로 연결돼요.');
    }
    await _init(c);
  }

  /// 동기화를 끕니다 (로그아웃하고 연결 정보 삭제). 이 기기 기록은 그대로 남습니다.
  static Future<void> disconnect(SharedPreferences prefs) async {
    await prefs.remove(_key);
    if (active.value != null) {
      try {
        await Supabase.instance.client.auth.signOut();
      } catch (_) {}
    }
    active.value = null;
  }

  static Future<void> _init(SyncConfig c) async {
    if (!_initialized) {
      await Supabase.initialize(url: c.url, publishableKey: c.publishableKey);
      _initialized = true;
      _initializedUrl = c.url;
    }
    active.value = c;
  }
}
