import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models.dart';

/// 집중/휴식이 끝나는 시각에 알림을 예약합니다.
/// 앱이 뒤에 있어도 운영체제가 알림을 띄워 줍니다.
class Notifications {
  static const _id = 1;
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> init() async {
    try {
      tzdata.initializeTimeZones();
      const darwin = DarwinInitializationSettings();
      await _plugin.initialize(
        settings: const InitializationSettings(iOS: darwin, macOS: darwin),
      );
      _ready = true;
    } catch (e) {
      debugPrint('알림 초기화 실패: $e');
    }
  }

  /// 타이머 상태가 바뀔 때마다 호출: 이전 예약을 지우고 새로 예약합니다.
  Future<void> sync(TimerState s) async {
    if (!_ready) return;
    try {
      await _plugin.cancel(id: _id);
      final end = s.endsAt();
      if (end == null || !end.isAfter(DateTime.now())) return;
      final (title, body) = switch (s.phase) {
        Phase.focus => ('집중 끝!', '방금 배운 것을 3줄로 떠올려 적어 보세요.'),
        Phase.rest => ('휴식 끝', '다음 집중 블록을 시작할 준비가 됐어요.'),
        _ => (null, null),
      };
      if (title == null) return;
      await _plugin.zonedSchedule(
        id: _id,
        scheduledDate: tz.TZDateTime.from(end, tz.UTC),
        notificationDetails: const NotificationDetails(
          iOS: DarwinNotificationDetails(),
          macOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: title,
        body: body,
      );
    } catch (e) {
      debugPrint('알림 예약 실패: $e');
    }
  }
}
