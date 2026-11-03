import Foundation

/// 跨切面的会话生命周期编排（由组合根 `FlareAppStore` 实现）。
///
/// 登录/登出/释放天然跨多个特性（session + 诊断 + 时间线引导），属于协调器职责。
/// 特性 ViewModel 通过这个窄协议触发它们，从而**不直接依赖组合根**，也避免视图越过
/// VM 去调 `store.login()/logout()/dispose()`。
@MainActor
protocol AppLifecycle: AnyObject {
    func login() async
    func logout() async
    func dispose() async
}
