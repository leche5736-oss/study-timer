import ActivityKit
import Foundation

/// 잠금화면·다이내믹 아일랜드 타이머에 보여줄 내용.
/// 앱(Runner)과 위젯(TimerWidget) 양쪽에 같은 파일이 들어갑니다.
@available(iOS 16.1, *)
struct TimerActivityAttributes: ActivityAttributes {
  struct ContentState: Codable, Hashable {
    var title: String  // 과목 이름 또는 "휴식"
    var rest: Bool
    var startedAt: Date  // 이 단계가 시작된 시각 (일시정지한 시간은 빼고 계산)
    var endsAt: Date?  // 끝나는 시각. 스톱워치면 nil
    var paused: Bool
    var shownSec: Int  // 일시정지 중 보여줄 시간
  }
}
