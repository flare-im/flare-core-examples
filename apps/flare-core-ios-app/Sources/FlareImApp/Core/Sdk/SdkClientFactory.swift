import FlareCoreAppleSDK

/// DI 缝:SDK 客户端的创建被抽到协议背后,而非 god-object 内部 `FlareCoreSdk.createClient` 硬造。
///
/// - 生产:`DefaultSdkClientFactory` 包装 `FlareCoreSdk`(经 FFI 造真客户端)。
/// - 测试:注入一个返回 mock `FlareImClientProtocol` 的 fake,即可无 FFI/无后端地驱动 ViewModel。
///
/// 这是把"app 结构映射 SDK 协议门面"的第一步:app 依赖 `any FlareImClientProtocol`(SDK 已给的端口),
/// 不再依赖具体的 `FlareCoreSdk` 工厂。
protocol SdkClientFactory: Sendable {
    /// 创建一个未初始化的客户端。`libraryPath` 为空表示用默认(iOS 静态链 / 同步进 FFI 的 dylib)。
    func makeClient(libraryPath: String?) throws -> any FlareImClientProtocol
}

struct DefaultSdkClientFactory: SdkClientFactory {
    func makeClient(libraryPath: String?) throws -> any FlareImClientProtocol {
        let trimmed = libraryPath?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolved = (trimmed?.isEmpty == false) ? trimmed : nil
        return try FlareCoreSdk.createClient(libraryPath: resolved)
    }
}
