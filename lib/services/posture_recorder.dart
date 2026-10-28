import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models.dart';
import 'head_motion.dart';
import 'store.dart';

/// 바른 자세보다 이만큼(도) 더 숙이면 "고개 숙임"으로 셉니다.
/// 사용자 측정(2026-10-28): 바른 책 읽기 -3~-5°, 구부정 -8° 이하. 사용자가 5°로 정함.
const postureDownDeg = 5.0;

/// 바른 자세를 저장하지 않았을 때, 블록 처음 이만큼(초)의 중앙값을 기준으로 씁니다.
const postureBaselineSec = 120;

/// 이보다 적게 읽혔으면(초) 기록하지 않습니다.
const postureMinSec = 60;

/// 한 번 알린 뒤 이만큼(초)은 다시 알리지 않습니다.
const postureAlertGapSec = 300;

/// 1초에 한 번 모은 고개 각도(pitch, 숙이면 -)를 블록 하나의 요약으로 만듭니다.
/// [samples]는 (블록 시작 뒤 몇 초, 각도) 목록, [base]는 저장한 바른 자세입니다.
///
/// 결과: {"v":1, "base": 기준 각도, "fixed": 저장한 기준인지, "thr": 기준,
/// "down": 숙인 초, "secs": 읽은 초, "alerts": 알린 횟수,
/// "min": 분마다 중앙값 (못 읽은 분은 null)}
Map<String, dynamic>? summarizePosture(
  List<(int, double)> samples, {
  double? base,
  int alerts = 0,
}) {
  if (samples.length < postureMinSec) return null;
  double round1(double v) => (v * 10).roundToDouble() / 10;
  final b = base ?? autoBase(samples)!;
  final down = samples.where((s) => s.$2 < b - postureDownDeg).length;
  final lastMin = samples.last.$1 ~/ 60;
  final byMin = List.generate(lastMin + 1, (_) => <double>[]);
  for (final (t, p) in samples) {
    if (t >= 0) byMin[t ~/ 60].add(p);
  }
  return {
    'v': 1,
    'base': round1(b),
    'fixed': base != null,
    'thr': postureDownDeg,
    'down': down,
    'secs': samples.length,
    'alerts': alerts,
    'min': [for (final m in byMin) m.isEmpty ? null : round1(_median(m))],
  };
}

/// 바른 자세를 저장하지 않았을 때의 기준: 처음 2분의 중앙값 (1분도 안 모였으면 null).
double? autoBase(List<(int, double)> samples) => samples.length < postureMinSec
    ? null
    : _median([for (final (_, p) in samples.take(postureBaselineSec)) p]);

double _median(List<double> xs) {
  final s = [...xs]..sort();
  final n = s.length;
  return n.isOdd ? s[n ~/ 2] : (s[n ~/ 2 - 1] + s[n ~/ 2]) / 2;
}

/// 숙인 상태가 [alertSec]초 이어지면 한 번 알립니다. 고개를 들면 다시 셉니다.
class PostureAlarm {
  int? _downSince;
  bool _alerted = false;
  int? _lastAlert;

  /// 1초에 한 번 부릅니다. 지금 알려야 하면 true.
  bool feed(int sec, double pitch, double base, int alertSec) {
    if (pitch >= base - postureDownDeg) {
      _downSince = null;
      _alerted = false;
      return false;
    }
    final since = _downSince ??= sec;
    if (_alerted || sec - since < alertSec) return false;
    if (_lastAlert != null && sec - _lastAlert! < postureAlertGapSec) {
      return false;
    }
    _alerted = true;
    _lastAlert = sec;
    return true;
  }
}

/// 집중 중일 때만 에어팟 고개 각도를 모아, 오래 숙이면 소리로 알리고
/// 블록이 끝나면 요약을 기록에 붙입니다.
class PostureRecorder {
  static const _kEnabled = 'posture_record';
  static const _kAlert = 'posture_alert';
  static const _kAlertMin = 'posture_alert_min';
  static const _kBase = 'posture_base';

  final AppStore store;

  /// 기록 켜짐.
  final ValueNotifier<bool> enabled;

  /// 오래 숙이면 소리 알림.
  final ValueNotifier<bool> alert;

  /// 몇 분 숙이면 알릴지.
  final ValueNotifier<int> alertMin;

  /// 저장한 바른 자세 각도 (없으면 블록 처음 2분으로 잡음).
  final ValueNotifier<double?> base;

  PostureRecorder._(this.store)
    : enabled = ValueNotifier(store.prefs.getBool(_kEnabled) ?? true),
      alert = ValueNotifier(store.prefs.getBool(_kAlert) ?? true),
      alertMin = ValueNotifier(store.prefs.getInt(_kAlertMin) ?? 3),
      base = ValueNotifier(store.prefs.getDouble(_kBase));

  static PostureRecorder? instance;

  static void start(AppStore store) {
    final r = PostureRecorder._(store);
    instance = r;
    store.postureFor = r._summaryFor;
    store.addListener(r._update);
    r.enabled.addListener(r._update);
    r._update();
  }

  Listenable get settings => Listenable.merge([enabled, alert, alertMin, base]);

  void setEnabled(bool on) {
    enabled.value = on;
    store.prefs.setBool(_kEnabled, on);
  }

  void setAlert(bool on) {
    alert.value = on;
    store.prefs.setBool(_kAlert, on);
  }

  void setAlertMin(int m) {
    alertMin.value = m;
    store.prefs.setInt(_kAlertMin, m);
  }

  void saveBase(double pitch) {
    base.value = pitch;
    store.prefs.setDouble(_kBase, pitch);
  }

  StreamSubscription<HeadPose>? _sub;
  String? _sessionId;
  DateTime? _startedAt;
  final _samples = <(int, double)>[];
  int _lastSec = -1;
  int _alerts = 0;
  var _alarm = PostureAlarm();
  final _done = <String, Map<String, dynamic>?>{};

  void _update() {
    final t = store.timer;
    final id = t.sessionId;
    if (id != null && id != _sessionId && t.phase == Phase.focus) {
      if (_sessionId != null) {
        _done[_sessionId!] = _summary();
        if (_done.length > 20) _done.remove(_done.keys.first);
      }
      _sessionId = id;
      _startedAt = t.sessionStartedAt;
      _samples.clear();
      _lastSec = -1;
      _alerts = 0;
      _alarm = PostureAlarm();
    }
    final run =
        enabled.value &&
        HeadMotion.supported &&
        t.phase == Phase.focus &&
        t.isRunning;
    if (run && _sub == null) {
      _sub = HeadMotion.poses.listen(_onPose);
      HeadMotion.start();
    } else if (!run && _sub != null) {
      _sub!.cancel();
      _sub = null;
      HeadMotion.stop();
    }
  }

  void _onPose(HeadPose p) {
    final start = _startedAt;
    if (start == null) return;
    final sec = DateTime.now().difference(start).inSeconds;
    if (sec <= _lastSec) return; // 1초에 한 번만
    _lastSec = sec;
    _samples.add((sec, p.pitch));
    final b = base.value ?? autoBase(_samples);
    if (alert.value &&
        b != null &&
        _alarm.feed(sec, p.pitch, b, alertMin.value * 60)) {
      _alerts++;
      HeadMotion.ding();
    }
  }

  Map<String, dynamic>? _summary() =>
      summarizePosture(_samples, base: base.value, alerts: _alerts);

  Map<String, dynamic>? _summaryFor(String sessionId) =>
      sessionId == _sessionId ? _summary() : _done.remove(sessionId);
}
