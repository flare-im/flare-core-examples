import FlareIMUI
import FlarePlatformUpdate
import SwiftUI

public struct FlareImRootView: View {
    /// 进程级的组合根：应用代理在启动时已经取了它（恢复会话、接上推送），这里只用，不另建。
    @ObservedObject private var store = FlareAppStore.shared
    /// Toasts and confirmations for the whole app (kit `FlareFeedback`): saving media, clearing the cache.
    @StateObject private var feedback = FlareFeedback()
    // Layer 5：宿主适配器装在根上，能力里的断点跟随实际宽度（iPad 分屏会变）。
    @State private var width: CGFloat = .infinity

    public init() {}

    public var body: some View {
        // 应用内新消息横幅盖在所有页面之上；点开去那个会话，与点系统通知走同一条路。这个应用的时间线不支持
        // 定位到某条消息，只打开会话。
        InAppNotificationHost(notifications: store.alerts.banners, onOpen: { conversationId, _ in
            store.notifications.open(conversationId: conversationId)
        }) {
            RootWorkbenchView()
        }
        .environmentObject(store)
        .environmentObject(store.updateCenter)
        .environmentObject(store.environment)
        .environmentObject(store.messagingViewModel)
        .environmentObject(store.sdkLabViewModel)
        .environmentObject(store.searchViewModel)
        .environmentObject(store.authViewModel)
        .environmentObject(store.settingsViewModel)
        .environmentObject(store.notifications)
        .environmentObject(store.alerts)
        .background(
            GeometryReader { proxy in
                Color.clear.preference(key: RootWidthKey.self, value: proxy.size.width)
            }
        )
        .onPreferenceChange(RootWidthKey.self) { width = $0 }
        .flarePlatform(IosPlatformAdapter(width: width))
        .flareFeedbackHost(feedback)
        .flareStrings(KitStrings.current)
    }
}

private struct RootWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = .infinity
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}
