import FlareIMUI
import SwiftUI

public struct FlareImRootView: View {
    @StateObject private var store = FlareAppStore()
    /// Toasts and confirmations for the whole app (kit `FlareFeedback`): saving media, clearing the cache.
    @StateObject private var feedback = FlareFeedback()
    // Layer 5：宿主适配器装在根上，能力里的断点跟随实际宽度（iPad 分屏会变）。
    @State private var width: CGFloat = .infinity

    public init() {}

    public var body: some View {
        RootWorkbenchView()
            .environmentObject(store)
            .environmentObject(store.environment)
            .environmentObject(store.messagingViewModel)
            .environmentObject(store.sdkLabViewModel)
            .environmentObject(store.searchViewModel)
            .environmentObject(store.authViewModel)
            .environmentObject(store.settingsViewModel)
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
