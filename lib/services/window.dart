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

  static String? _lastStatus;
  static String? _lastMenu;

  /// 메뉴 막대 글자와 메뉴를 바꿉니다. [text]가 null이면 메뉴 막대에서 뺍니다.
  /// 바뀐 것만 보냅니다.
  static Future<void> setStatus(
    String? text, [
    List<Map<String, Object>> menu = const [],
  ]) async {
    if (text != _lastStatus) {
      if (_lastStatus == null) _lastMenu = null; // 새로 만들면 메뉴도 다시
      _lastStatus = text;
      await _call('setStatus', text);
    }
    if (text == null) return;
    final key = menu.toString();
    if (key == _lastMenu) return;
    _lastMenu = key;
    await _call('setStatusMenu', menu);
  }

  /// 로그인할 때 자동 실행 (macOS 13 이상).
  static Future<bool> launchAtLogin() async =>
      (await _call('getLaunchAtLogin')) as bool? ?? false;

  static Future<void> setLaunchAtLogin(bool on) => _channel
      .invokeMethod('setLaunchAtLogin', on)
      .then((_) {}); // 실패하면 예외를 그대로 알려 줍니다.

  /// 지금 켜져 있는 앱 이름 목록.
  static Future<List<String>> runningApps() async =>
      ((await _call('runningApps')) as List?)?.cast<String>() ?? const [];

  /// 맨 앞 앱이 바뀔 때([onFrontApp])와 메뉴 막대 메뉴를 눌렀을 때([onMenu]) 부릅니다.
  static void listen({
    required void Function(String appName) onFrontApp,
    required void Function(String id) onMenu,
  }) {
    if (!isMac) return;
    _channel.setMethodCallHandler((call) async {
      final arg = call.arguments;
      if (arg is! String) return;
      if (call.method == 'frontAppChanged') onFrontApp(arg);
      if (call.method == 'menuAction') onMenu(arg);
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
