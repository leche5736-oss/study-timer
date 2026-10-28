import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 에어팟이 알려 주는 머리 자세 한 번. 각도는 도 단위입니다.
class HeadPose {
  /// 앞뒤 기울기. 값이 어느 쪽으로 커지는지는 테스트 화면에서 확인합니다.
  final double pitch;

  /// 좌우로 갸웃한 정도.
  final double roll;

  /// 좌우로 돌린 정도. 기준이 수시로 바뀌어 자세 판단에는 쓰지 않습니다.
  final double yaw;

  /// 중력 방향 (x, y, z). pitch가 이상하면 이 값으로 다시 계산합니다.
  final List<double> gravity;

  /// 값을 보낸 쪽 에어팟: left, right 또는 빈 문자열.
  final String bud;

  const HeadPose({
    required this.pitch,
    required this.roll,
    required this.yaw,
    required this.gravity,
    required this.bud,
  });

  static HeadPose? fromMap(Object? m) {
    if (m is! Map) return null;
    double d(String k) => (m[k] as num?)?.toDouble() ?? 0;
    return HeadPose(
      pitch: d('pitch'),
      roll: d('roll'),
      yaw: d('yaw'),
      gravity: [d('gx'), d('gy'), d('gz')],
      bud: m['bud'] as String? ?? '',
    );
  }
}

/// 에어팟 머리 움직임 (macos/Runner/MainFlutterWindow.swift의 HeadTracker).
/// 지금은 Mac(macOS 14 이상)에서만 됩니다.
class HeadMotion {
  static const _channel = MethodChannel('study_timer/head');

  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

  static final _poses = StreamController<HeadPose>.broadcast();
  static final _status = StreamController<String>.broadcast();
  static bool _listening = false;

  /// 1초에 10번까지 들어오는 자세.
  static Stream<HeadPose> get poses => _poses.stream;

  /// connected, disconnected 또는 "error: ..." 같은 연결 상태.
  static Stream<String> get status => _status.stream;

  /// 읽기를 시작합니다. started, denied, unavailable, unsupported 중 하나를
  /// 돌려줍니다.
  static Future<String> start() async {
    if (!supported) return 'unsupported';
    if (!_listening) {
      _listening = true;
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'pose') {
          final p = HeadPose.fromMap(call.arguments);
          if (p != null) _poses.add(p);
        } else if (call.method == 'status' && call.arguments is String) {
          _status.add(call.arguments as String);
        }
      });
    }
    try {
      return (await _channel.invokeMethod<String>('start')) ?? 'unsupported';
    } catch (e) {
      debugPrint('에어팟 자세 시작 실패: $e');
      return 'unsupported';
    }
  }

  static Future<void> stop() async {
    if (!supported) return;
    try {
      await _channel.invokeMethod('stop');
    } catch (e) {
      debugPrint('에어팟 자세 멈춤 실패: $e');
    }
  }
}
