import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    FlareFilesChannel.register(with: flutterViewController.engine.binaryMessenger)

    super.awakeFromNib()
  }
}

/// 「下载位置」的宿主一半（`flare.im/files`）。app 在沙盒里：挑到的文件夹只在这次运行里可写，
/// 所以留一枚安全书签，下次启动凭书签拿回写权限；另外在访达里显示保存好的文件。
/// 写文件本身由核心 SDK 做（`media.download_to_user_directory`）。
enum FlareFilesChannel {
  private static let bookmarkKey = "flare.downloadDirectoryBookmark"
  /// 正持有访问权的文件夹（同一时间只有一个）。
  private static var accessed: URL?

  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "flare.im/files", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "pickDirectory":
        let initial = (call.arguments as? [String: Any])?["initialDirectory"] as? String
        pickDirectory(initialDirectory: initial, result)
      case "restoreDirectoryAccess":
        result(restoreAccess()?.path)
      case "forgetDirectory":
        forget()
        result(nil)
      case "reveal":
        guard let path = (call.arguments as? [String: Any])?["path"] as? String, !path.isEmpty else {
          result(false)
          return
        }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
        result(true)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static func pickDirectory(initialDirectory: String?, _ result: @escaping FlutterResult) {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.canCreateDirectories = true
    panel.allowsMultipleSelection = false
    if let initialDirectory, !initialDirectory.isEmpty {
      panel.directoryURL = URL(fileURLWithPath: initialDirectory, isDirectory: true)
    }
    panel.begin { response in
      guard response == .OK, let url = panel.url else {
        result(nil)
        return
      }
      if let data = try? url.bookmarkData(
        options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
      {
        UserDefaults.standard.set(data, forKey: bookmarkKey)
      }
      startAccessing(url)
      result(url.path)
    }
  }

  private static func restoreAccess() -> URL? {
    guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else { return nil }
    var stale = false
    guard
      let url = try? URL(
        resolvingBookmarkData: data, options: .withSecurityScope, relativeTo: nil,
        bookmarkDataIsStale: &stale)
    else { return nil }
    if stale,
      let fresh = try? url.bookmarkData(
        options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
    {
      UserDefaults.standard.set(fresh, forKey: bookmarkKey)
    }
    startAccessing(url)
    return url
  }

  private static func startAccessing(_ url: URL) {
    accessed?.stopAccessingSecurityScopedResource()
    accessed = url.startAccessingSecurityScopedResource() ? url : nil
  }

  private static func forget() {
    accessed?.stopAccessingSecurityScopedResource()
    accessed = nil
    UserDefaults.standard.removeObject(forKey: bookmarkKey)
  }
}
