import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models.dart';
import '../phone_flip.dart';
import 'notifications.dart';
import 'store.dart';

/// iPhone·iPad: 집중 중에 폰을 엎어 두면 화면이 꺼지지 않게 하고,
/// 들어 올리거나 다른 앱을 켜면 딴짓으로 셉니다.
class PhoneFlipWatcher with WidgetsBindingObserver {
  final AppStore store;
  PhoneFlipWatcher(this.store);

  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  final _detector = FlipDetector();
  StreamSubscription<AccelerometerEvent>? _sub;

  void start() {
    if (!supported) return;
    WidgetsBinding.instance.addObserver(this);
    store.addListener(_update);
    _update();
  }

  bool get _active =>
      store.settings.phoneFlip &&
      store.timer.phase == Phase.focus &&
      store.timer.isRunning;

  void _update() {
    if (_active) {
      if (_sub != null) return;
      // 엎어 둔 동안 화면이 자동으로 잠기면 센서가 멈추므로 켜 둡니다.
      WakelockPlus.enable().ignore();
      _sub = accelerometerEventStream(
        samplingPeriod: SensorInterval.normalInterval,
      ).listen((e) => _apply(_detector.sample(e.z, DateTime.now().toUtc())));
    } else {
      if (_sub == null) return;
      _sub?.cancel();
      _sub = null;
      _detector.reset();
      WakelockPlus.disable().ignore();
    }
  }

  void _apply(FlipEvent? e) {
    if (e == null) return;
    store.phoneFlipped(away: e.away, at: e.at);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_sub == null || state != AppLifecycleState.paused) return;
    final e = _detector.appHidden(DateTime.now().toUtc());
    if (e == null) return;
    _apply(e);
    Notifications.instance.nudge('다른 앱');
  }
}
