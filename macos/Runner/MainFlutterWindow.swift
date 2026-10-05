import Cocoa
import FlutterMacOS
import ServiceManagement

class MainFlutterWindow: NSWindow {
  private var channel: FlutterMethodChannel?
  private var frameBeforeMini: NSRect?
  private var statusItem: NSStatusItem?

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
      case "setStatus":
        self.setStatus(call.arguments as? String)
        result(nil)
      case "setStatusMenu":
        self.setStatusMenu(call.arguments as? [[String: Any]] ?? [])
        result(nil)
      case "getLaunchAtLogin":
        if #available(macOS 13.0, *) {
          result(SMAppService.mainApp.status == .enabled)
        } else {
          result(false)
        }
      case "setLaunchAtLogin":
        if #available(macOS 13.0, *) {
          do {
            if (call.arguments as? Bool) == true {
              try SMAppService.mainApp.register()
            } else {
              try SMAppService.mainApp.unregister()
            }
            result(nil)
          } catch {
            result(FlutterError(code: "login", message: error.localizedDescription, details: nil))
          }
        } else {
          result(FlutterError(code: "login", message: "macOS 13 이상에서만 돼요", details: nil))
        }
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

  /// 메뉴 막대에 남은 시간을 보여 줍니다. nil이면 메뉴 막대에서 뺍니다.
  private func setStatus(_ text: String?) {
    guard let text = text else {
      if let item = statusItem { NSStatusBar.system.removeStatusItem(item) }
      statusItem = nil
      return
    }
    if statusItem == nil {
      let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
      item.button?.target = self
      item.button?.action = #selector(statusClicked)
      item.button?.font = NSFont.monospacedDigitSystemFont(
        ofSize: NSFont.systemFontSize, weight: .regular)
      statusItem = item
    }
    statusItem?.button?.title = text
  }

  @objc private func statusClicked() {
    NSApp.activate(ignoringOtherApps: true)
    self.makeKeyAndOrderFront(nil)
  }

  /// 메뉴 막대를 눌렀을 때 나오는 메뉴. 항목마다 id를 Flutter에 돌려줍니다.
  /// 항목: {"id": String, "title": String, "enabled": Bool} 또는 {"separator": true}
  private func setStatusMenu(_ items: [[String: Any]]) {
    guard let item = statusItem else { return }
    let menu = NSMenu()
    menu.autoenablesItems = false
    for spec in items {
      if spec["separator"] as? Bool == true {
        menu.addItem(NSMenuItem.separator())
        continue
      }
      let mi = NSMenuItem(
        title: spec["title"] as? String ?? "", action: #selector(menuClicked(_:)),
        keyEquivalent: "")
      mi.target = self
      mi.representedObject = spec["id"] as? String
      mi.isEnabled = spec["enabled"] as? Bool ?? true
      menu.addItem(mi)
    }
    menu.addItem(NSMenuItem.separator())
    menu.addItem(
      NSMenuItem(title: "종료", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    item.menu = menu
  }

  @objc private func menuClicked(_ sender: NSMenuItem) {
    guard let id = sender.representedObject as? String else { return }
    if id == "open" {
      statusClicked()
      return
    }
    channel?.invokeMethod("menuAction", arguments: id)
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
