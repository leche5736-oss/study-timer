import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models.dart';

/// 아이폰 잠금화면·다이내믹 아일랜드 타이머 (ios/Runner/LiveActivityController.swift).
/// 다른 기기에서는 아무 일도 하지 않습니다.
class LiveActivity {
  static const _channel = MethodChannel('study_timer/live');
  static String? _last;

  static bool get isIOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// 타이머 상태가 바뀔 때마다 부릅니다. 보여줄 내용이 같으면 보내지 않습니다.
  static void sync(TimerState t, String? subjectName) {
    if (!isIOS) return;
    final state = liveActivityState(t, subjectName);
    final key = state?.toString() ?? 'end';
    if (key == _last) return;
    _last = key;
    _channel
        .invokeMethod(state == null ? 'end' : 'show', state)
        .catchError((Object e) => debugPrint('잠금화면 타이머: $e'));
  }
}

/// 잠금화면에 보낼 내용. 집중·휴식 중이 아니면 null (잠금화면 타이머를 끔).
///
/// 시각은 "이 단계를 일시정지 없이 이어 왔다면 시작했을 시각"으로 보내서,
/// iOS가 앱 없이도 1초마다 남은 시간을 그릴 수 있게 합니다.
Map<String, Object?>? liveActivityState(TimerState t, String? subjectName) {
  final focus = t.phase == Phase.focus;
  if (!focus && t.phase != Phase.rest) return null;
  final title = focus ? (subjectName ?? '집중') : (t.longRest ? '긴 휴식' : '휴식');
  final countUp = focus && t.stopwatch;
  final since = t.runningSince;
  if (since == null) {
    // 일시정지: 멈춘 시간을 그대로 보여 줍니다.
    return {
      'title': title,
      'rest': !focus,
      'startedAt': 0,
      'endsAt': null,
      'paused': true,
      'shownSec': countUp ? t.accumulatedSec : t.durationSec - t.accumulatedSec,
    };
  }
  final start = since.subtract(Duration(seconds: t.accumulatedSec));
  return {
    'title': title,
    'rest': !focus,
    'startedAt': start.millisecondsSinceEpoch,
    'endsAt': countUp
        ? null
        : start.add(Duration(seconds: t.durationSec)).millisecondsSinceEpoch,
    'paused': false,
    'shownSec': 0,
  };
}
