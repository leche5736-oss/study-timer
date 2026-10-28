import ActivityKit
import Flutter
import Foundation

/// Flutter(lib/services/live_activity.dart)에서 받은 타이머 상태로
/// 잠금화면·다이내믹 아일랜드 타이머를 켜고, 바꾸고, 끕니다.
enum LiveActivityController {
  static func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "study_timer/live", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard #available(iOS 16.2, *) else { return result(nil) }
      switch call.method {
      case "show":
        if let args = call.arguments as? [String: Any], let state = contentState(args) {
          Task { await show(state) }
        }
        result(nil)
      case "end":
        Task { await endAll() }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  @available(iOS 16.2, *)
  private static func contentState(_ a: [String: Any]) -> TimerActivityAttributes.ContentState? {
    guard let title = a["title"] as? String, let start = a["startedAt"] as? NSNumber else {
      return nil
    }
    let end = (a["endsAt"] as? NSNumber).map { date($0) }
    return .init(
      title: title,
      rest: a["rest"] as? Bool ?? false,
      startedAt: date(start),
      endsAt: end,
      paused: a["paused"] as? Bool ?? false,
      shownSec: (a["shownSec"] as? NSNumber)?.intValue ?? 0
    )
  }

  private static func date(_ ms: NSNumber) -> Date {
    Date(timeIntervalSince1970: ms.doubleValue / 1000)
  }

  @available(iOS 16.2, *)
  private static func show(_ state: TimerActivityAttributes.ContentState) async {
    // 끝나는 시각이 지나면 "오래된 정보"로 표시되게 합니다.
    let stale = state.paused ? nil : state.endsAt?.addingTimeInterval(60)
    let content = ActivityContent(state: state, staleDate: stale)
    let current = Activity<TimerActivityAttributes>.activities
    if let first = current.first {
      await first.update(content)
      for extra in current.dropFirst() { await extra.end(nil, dismissalPolicy: .immediate) }
      return
    }
    guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
    _ = try? Activity.request(attributes: TimerActivityAttributes(), content: content, pushType: nil)
  }

  @available(iOS 16.2, *)
  private static func endAll() async {
    for activity in Activity<TimerActivityAttributes>.activities {
      await activity.end(nil, dismissalPolicy: .immediate)
    }
  }
}
