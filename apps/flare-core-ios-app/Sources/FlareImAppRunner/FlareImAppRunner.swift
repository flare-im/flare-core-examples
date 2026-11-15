import FlareImApp
import SwiftUI

@main
struct FlareImAppRunner: App {
    #if os(iOS)
    // 推送的系统回调只到应用代理；它在启动返回之前把推送接上。
    @UIApplicationDelegateAdaptor(FlareImAppDelegate.self) private var appDelegate
    #endif

    var body: some Scene {
        WindowGroup {
            FlareImRootView()
        }
    }
}
