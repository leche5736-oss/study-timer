import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Mac에서 앱 창을 맨 앞으로 가져옵니다 (macos/Runner/MainFlutterWindow.swift).
class AppWindow {
  static const _channel = MethodChannel('study_timer/window');

  static Future<void> bringToFront() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.macOS) return;
    try {
      await _channel.invokeMethod('bringToFront');
    } catch (e) {
      debugPrint('창 앞으로 가져오기 실패: $e');
    }
  }
}
