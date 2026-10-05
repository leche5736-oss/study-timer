import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  // 창을 닫아도 앱은 메뉴 막대에 남아 있습니다. 완전히 끄려면 ⌘Q 또는 메뉴 막대의 "종료".
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  // Dock 아이콘을 누르면 닫았던 창을 다시 보여 줍니다.
  override func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    if !flag {
      for window in sender.windows where window is MainFlutterWindow {
        window.makeKeyAndOrderFront(nil)
      }
    }
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
