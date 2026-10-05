import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Mac 전용 창 기능 (macos/Runner/MainFlutterWindow.swift).
/// 다른 기기에서는 아무 일도 하지 않습니다.
class AppWindow {
  static const _channel = MethodChannel('study_timer/window');

  static bool get isMac =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

  /// 앱 창을 맨 앞으로 가져옵니다.
  static Future<void> bringToFront() => _call('bringToFront');

  /// 작은 창으로 줄여 다른 창 위에 띄웁니다 (false면 원래대로).
  static Future<void> setMini(bool on) => _call('setMini', on);

  /// 지금 켜져 있는 앱 이름 목록.
  static Future<List<String>> runningApps() async =>
      ((await _call('runningApps')) as List?)?.cast<String>() ?? const [];

  /// 맨 앞 앱이 바뀔 때마다 [onChange]를 부릅니다.
  static void listenFrontApp(void Function(String appName) onChange) {
    if (!isMac) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'frontAppChanged' && call.arguments is String) {
        onChange(call.arguments as String);
      }
    });
  }

  static Future<Object?> _call(String method, [Object? args]) async {
    if (!isMac) return null;
    try {
      return await _channel.invokeMethod(method, args);
    } catch (e) {
      debugPrint('창 기능 $method 실패: $e');
      return null;
    }
  }
}
