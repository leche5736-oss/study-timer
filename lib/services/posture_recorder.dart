import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models.dart';
import 'head_motion.dart';
import 'store.dart';

/// 기준 자세보다 이만큼(도) 더 숙이면 "고개 숙임"으로 셉니다 (임시 기준).
/// 사용자 측정(2026-10-28): 바른 책 읽기 -3~-5°, 구부정 -8° 이하.
const postureDownDeg = 4.0;

/// 블록 처음 이만큼(초)의 중앙값을 그 블록의 기준 자세로 씁니다.
const postureBaselineSec = 120;

/// 이보다 적게 읽혔으면(초) 기록하지 않습니다.
const postureMinSec = 60;

/// 1초에 한 번 모은 고개 각도(pitch, 숙이면 -)를 블록 하나의 요약으로 만듭니다.
/// [samples]는 (블록 시작 뒤 몇 초, 각도) 목록입니다.
///
/// 결과: {"v":1, "base": 기준 각도, "thr": 기준, "down": 숙인 초,
/// "secs": 읽은 초, "min": 분마다 중앙값 (못 읽은 분은 null)}
Map<String, dynamic>? summarizePosture(List<(int, double)> samples) {
  if (samples.length < postureMinSec) return null;
  double round1(double v) => (v * 10).roundToDouble() / 10;
  final base = _median([
    for (final (_, p) in samples.take(postureBaselineSec)) p,
  ]);
  final down = samples.where((s) => s.$2 < base - postureDownDeg).length;
  final lastMin = samples.last.$1 ~/ 60;
  final byMin = List.generate(lastMin + 1, (_) => <double>[]);
  for (final (t, p) in samples) {
    if (t >= 0) byMin[t ~/ 60].add(p);
  }
  return {
    'v': 1,
    'base': round1(base),
    'thr': postureDownDeg,
    'down': down,
    'secs': samples.length,
    'min': [for (final m in byMin) m.isEmpty ? null : round1(_median(m))],
  };
}

double _median(List<double> xs) {
  final s = [...xs]..sort();
  final n = s.length;
  return n.isOdd ? s[n ~/ 2] : (s[n ~/ 2 - 1] + s[n ~/ 2]) / 2;
}

/// 집중 중일 때만 에어팟 고개 각도를 모아, 블록이 끝나면 요약을 기록에 붙입니다.
/// 알림은 하지 않습니다 (자세 알림 2단계: 기록만).
class PostureRecorder {
  static const _kEnabled = 'posture_record';

  final AppStore store;
  final ValueNotifier<bool> enabled;

  PostureRecorder._(this.store, this.enabled);

  static PostureRecorder? instance;

  static void start(AppStore store) {
    final r = PostureRecorder._(
      store,
      ValueNotifier(store.prefs.getBool(_kEnabled) ?? true),
    );
    instance = r;
    store.postureFor = r._summaryFor;
    store.addListener(r._update);
    r.enabled.addListener(r._update);
    r._update();
  }

  void setEnabled(bool on) {
    enabled.value = on;
    store.prefs.setBool(_kEnabled, on);
  }

  StreamSubscription<HeadPose>? _sub;
  String? _sessionId;
  DateTime? _startedAt;
  final _samples = <(int, double)>[];
  int _lastSec = -1;
  final _done = <String, Map<String, dynamic>?>{};

  void _update() {
    final t = store.timer;
    final id = t.sessionId;
    if (id != null && id != _sessionId && t.phase == Phase.focus) {
      if (_sessionId != null) {
        _done[_sessionId!] = summarizePosture(_samples);
        if (_done.length > 20) _done.remove(_done.keys.first);
      }
      _sessionId = id;
      _startedAt = t.sessionStartedAt;
      _samples.clear();
      _lastSec = -1;
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
  }

  Map<String, dynamic>? _summaryFor(String sessionId) => sessionId == _sessionId
      ? summarizePosture(_samples)
      : _done.remove(sessionId);
}
