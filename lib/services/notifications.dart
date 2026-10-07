import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models.dart';

/// 집중/휴식이 끝나는 시각에 알림을 예약합니다.
/// Mac/iOS 앱에서는 앱이 뒤에 있어도 운영체제가 알림을 띄워 줍니다.
/// 웹에서는 예약 알림이 안 되므로, 페이지가 열려 있는 동안 시간이 다 되는 순간 알림을 띄웁니다.
class Notifications {
  Notifications._();
  static final instance = Notifications._();

  static const _id = 1;
  static const _nudgeId = 2;
  static const _restWarnId = 3;

  /// 휴식이 끝나기 이만큼 전에 미리 알려 줍니다 (휴식 중 다른 앱을 쓰니까).
  static const restWarnBefore = Duration(minutes: 1);

  /// 알림 소리. 설정 화면에서 바꿉니다.
  bool sound = true;
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> init() async {
    try {
      tzdata.initializeTimeZones();
      const darwin = DarwinInitializationSettings();
      await _plugin.initialize(
        settings: const InitializationSettings(
          iOS: darwin,
          macOS: darwin,
          web: WebInitializationSettings(),
        ),
      );
      _ready = true;
    } catch (e) {
      debugPrint('알림 초기화 실패: $e');
    }
  }

  /// 웹 브라우저는 사용자가 버튼을 누를 때만 알림 권한을 물을 수 있어서,
  /// 집중 시작 버튼을 누를 때 호출합니다.
  Future<void> requestWebPermission() async {
    if (!kIsWeb || !_ready) return;
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<
            WebFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    } catch (e) {
      debugPrint('알림 권한 요청 실패: $e');
    }
  }

  /// 타이머 상태가 바뀔 때마다 호출: 이전 예약을 지우고 새로 예약합니다.
  Future<void> sync(TimerState previous, TimerState s) async {
    if (!_ready) return;
    if (kIsWeb) return _showIfTimeUp(previous, s);
    try {
      await _plugin.cancel(id: _id);
      await _plugin.cancel(id: _restWarnId);
      final end = s.endsAt();
      if (end == null || !end.isAfter(DateTime.now())) return;
      final (title, body) = _message(s.phase);
      if (title == null) return;
      await _schedule(_id, end, title, body);
      final warnAt = restWarnAt(s);
      if (warnAt != null && warnAt.isAfter(DateTime.now())) {
        await _schedule(
          _restWarnId,
          warnAt,
          '휴식 1분 남았어요',
          '하던 것을 정리하고 공부로 돌아올 준비를 해요.',
        );
      }
    } catch (e) {
      debugPrint('알림 예약 실패: $e');
    }
  }

  /// 휴식이 [restWarnBefore] 넘게 남아 있으면 미리 알릴 시각, 아니면 null.
  static DateTime? restWarnAt(TimerState s) {
    final end = s.endsAt();
    if (s.phase != Phase.rest || end == null) return null;
    if (s.durationSec <= restWarnBefore.inSeconds) return null;
    return end.subtract(restWarnBefore);
  }

  Future<void> _schedule(int id, DateTime at, String title, String? body) =>
      _plugin.zonedSchedule(
        id: id,
        scheduledDate: tz.TZDateTime.from(at, tz.UTC),
        notificationDetails: NotificationDetails(
          iOS: DarwinNotificationDetails(presentSound: sound),
          macOS: DarwinNotificationDetails(presentSound: sound),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: title,
        body: body,
      );

  /// 딴짓 앱으로 넘어갔을 때 바로 띄우는 알림.
  Future<void> nudge(String appName) async {
    if (!_ready) return;
    try {
      await _plugin.show(
        id: _nudgeId,
        title: '지금은 집중 시간이에요',
        body: '$appName 대신 공부로 돌아갈까요?',
        notificationDetails: NotificationDetails(
          iOS: DarwinNotificationDetails(presentSound: sound),
          macOS: DarwinNotificationDetails(presentSound: sound),
        ),
      );
    } catch (e) {
      debugPrint('알림 표시 실패: $e');
    }
  }

  /// 시간이 다 돼서 단계가 넘어갔는지 (사용자가 버튼을 눌러 넘긴 게 아니라).
  static bool isTimeUp(TimerState previous, TimerState next) {
    final end = previous.endsAt();
    return end != null &&
        !DateTime.now().toUtc().isBefore(end) &&
        previous.phase != next.phase;
  }

  /// 웹: 시간이 다 돼서 단계가 넘어간 경우에만 바로 알림을 띄웁니다.
  Future<void> _showIfTimeUp(TimerState previous, TimerState s) async {
    if (!isTimeUp(previous, s)) return;
    final (title, body) = _message(previous.phase);
    if (title == null) return;
    try {
      await _plugin.show(id: _id, title: title, body: body);
    } catch (e) {
      debugPrint('알림 표시 실패: $e');
    }
  }

  static (String?, String?) _message(Phase endingPhase) =>
      switch (endingPhase) {
        Phase.focus => ('집중 끝!', '책을 덮고 방금 배운 것을 떠올려 적어 보세요.'),
        Phase.rest => ('휴식 끝', '다음 집중 블록을 시작할 준비가 됐어요.'),
        _ => (null, null),
      };
}
