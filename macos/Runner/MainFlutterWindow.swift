import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var channel: FlutterMethodChannel?
  private var frameBeforeMini: NSRect?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // 창 제어와 맨 앞 앱 알림 (lib/services/window.dart)
    let channel = FlutterMethodChannel(
      name: "study_timer/window",
      binaryMessenger: flutterViewController.engine.binaryMessenger)
    self.channel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return result(nil) }
      switch call.method {
      case "bringToFront":
        NSApp.activate(ignoringOtherApps: true)
        self.makeKeyAndOrderFront(nil)
        result(nil)
      case "runningApps":
        result(self.runningAppNames())
      case "frontApp":
        result(NSWorkspace.shared.frontmostApplication?.localizedName)
      case "setMini":
        self.setMini((call.arguments as? Bool) ?? false)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    // 맨 앞 앱이 바뀔 때마다 Flutter에 알려 줍니다 (딴짓 앱 감지).
    NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.didActivateApplicationNotification,
      object: nil, queue: .main
    ) { [weak self] note in
      let app =
        note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
      guard let name = app?.localizedName else { return }
      self?.channel?.invokeMethod("frontAppChanged", arguments: name)
    }

    super.awakeFromNib()
  }

  /// 지금 켜져 있는 일반 앱 이름 (이 앱 제외).
  private func runningAppNames() -> [String] {
    let me = Bundle.main.bundleIdentifier
    let names = NSWorkspace.shared.runningApplications
      .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != me }
      .compactMap { $0.localizedName }
    return Array(Set(names)).sorted()
  }

  /// 작은 창으로 줄여 다른 창들 위에 띄우거나, 원래대로 돌립니다.
  private func setMini(_ on: Bool) {
    if on {
      if frameBeforeMini == nil { frameBeforeMini = self.frame }
      self.level = .floating
      self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
      self.minSize = NSSize(width: 200, height: 120)
      let size = NSSize(width: 280, height: 180)
      let screen = (self.screen ?? NSScreen.main)?.visibleFrame ?? .zero
      let origin = NSPoint(
        x: screen.maxX - size.width - 20, y: screen.maxY - size.height - 20)
      self.setFrame(NSRect(origin: origin, size: size), display: true, animate: true)
    } else {
      self.level = .normal
      self.collectionBehavior = []
      if let f = frameBeforeMini {
        self.setFrame(f, display: true, animate: true)
      }
      frameBeforeMini = nil
    }
  }
}
