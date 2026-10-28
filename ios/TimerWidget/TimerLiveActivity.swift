import ActivityKit
import SwiftUI
import WidgetKit

private let night = Color(red: 0.06, green: 0.09, blue: 0.15)
private let accent = Color(red: 0.49, green: 0.60, blue: 0.77)

struct TimerLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: TimerActivityAttributes.self) { context in
      LockScreenView(state: context.state)
        .activityBackgroundTint(night)
        .activitySystemActionForegroundColor(.white)
    } dynamicIsland: { context in
      let s = context.state
      return DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Label(s.title, systemImage: icon(s))
            .font(.headline)
            .lineLimit(1)
            .padding(.leading, 4)
        }
        DynamicIslandExpandedRegion(.trailing) {
          TimerText(state: s)
            .font(.title2.monospacedDigit().weight(.medium))
            .multilineTextAlignment(.trailing)
            .frame(maxWidth: 110)
            .padding(.trailing, 4)
        }
      } compactLeading: {
        Image(systemName: icon(s)).foregroundColor(accent)
      } compactTrailing: {
        TimerText(state: s)
          .monospacedDigit()
          .multilineTextAlignment(.trailing)
          .frame(width: 52)
      } minimal: {
        Image(systemName: icon(s)).foregroundColor(accent)
      }
    }
  }
}

private func icon(_ s: TimerActivityAttributes.ContentState) -> String {
  s.rest ? "cup.and.saucer.fill" : "book.fill"
}

private struct LockScreenView: View {
  let state: TimerActivityAttributes.ContentState

  var body: some View {
    HStack(alignment: .center) {
      VStack(alignment: .leading, spacing: 4) {
        Text(state.rest ? "휴식" : (state.paused ? "일시정지" : "집중"))
          .font(.caption)
          .foregroundColor(.white.opacity(0.6))
        Text(state.title)
          .font(.headline)
          .foregroundColor(.white)
          .lineLimit(1)
      }
      Spacer()
      TimerText(state: state)
        .font(.system(size: 40, weight: .light).monospacedDigit())
        .foregroundColor(.white)
        .multilineTextAlignment(.trailing)
        .frame(maxWidth: 170, alignment: .trailing)
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 16)
  }
}

/// 앱이 꺼져 있어도 iOS가 알아서 1초마다 바꿔 그리는 시간 글자.
private struct TimerText: View {
  let state: TimerActivityAttributes.ContentState

  var body: some View {
    if state.paused {
      Text(clock(state.shownSec))
    } else if let end = state.endsAt, end > state.startedAt {
      Text(timerInterval: state.startedAt...end, countsDown: true)
    } else {
      Text(state.startedAt, style: .timer)
    }
  }
}

private func clock(_ sec: Int) -> String {
  let s = max(0, sec)
  let h = s / 3600, m = (s % 3600) / 60, r = s % 60
  return h > 0
    ? String(format: "%d:%02d:%02d", h, m, r)
    : String(format: "%d:%02d", m, r)
}
