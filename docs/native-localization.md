# 原生示例文案接入

Core 和 Social 都通过组件库的公开语言 API 接入文案。先在 Web 验证产品措辞，再同步原生生成资源；不要在页面中复制整个 Kit 语言表。

## 接入位置

| 端 | 入口 | 规则 |
| --- | --- | --- |
| iOS | `Sources/FlareImApp/Core/DesignSystem/KitStrings.swift` | 跟随 Bundle 的实际语言；英文继承 `.english`，只覆盖产品措辞 |
| Compose | `core/designsystem/KitStrings.kt` | 从 `flare_kit_language` 资源读取语言，`remember(language)` 缓存配置 |
| Flutter | `lib/application/providers/locale_provider.dart` | `kitStringsFor` 与 `materialLocaleFor` 使用同一个 `FlareLocale` |

## Swift：配置闭包替代旧的命名参数初始化

`FlareStrings()` 的中文默认值、`FlareStrings.english`、属性赋值及复制后修改仍然可用。
自定义中文文案使用新闭包，不能再使用 `FlareStrings(send: "发送")` 这样的旧写法：

```swift
let custom = FlareStrings { copy in
    copy.send = "发送"
    copy.packetFromSender = { "来自 \($0) 的红包" }
}
ContentView().flareStrings(custom)
```

英文应从生成的完整语言表开始，避免只改几个英文按钮、其余组件仍显示中文：

```swift
var english = FlareStrings.english
english.send = "Send"
ContentView().flareStrings(english)
```

配置闭包的参数是 `inout FlareStringsTable`。表由 Kit 创建，不直接初始化它；不要手工补一个上千参数的兼容构造器。
`FlareStrings` 保持值语义，修改某份文案不能影响缓存的预设。详见 [Kit 2.0 迁移说明](../../flare-im-design/docs/release/migration/2.0-rc-to-2.0.md)。

## Compose 和 Flutter

Compose 使用 `FlareStrings(flareStringsEnglish()) { send = "Send" }`，并在根部提供 `LocalFlareStrings`。
Flutter 使用 `flareStringsEnglish.copyWith(send: 'Send')`，在根部通过 `FlareStringsScope` 提供；中文使用 `const FlareStrings()`。
这两端保持各自公开的构造 / 复制 API，不照搬 Swift 的参数类型。业务文案和 Kit 文案必须使用同一个应用语言源。

## 生成与验证

在 `flare-im-design` 运行 `node strings/build.mjs`、`node strings/build.mjs --check`，同步组件库各端语言资源。
在 `flare-social-examples` 运行 `node apps/scripts/generate-app-strings.mjs`、`node apps/scripts/generate-app-strings.mjs --check` 和 `node apps/scripts/check-app-strings.mjs`，同步 Social 应用资源。
修改源 JSON / 生成器，不能只修改生成的 Swift、Kotlin 或 Dart 文件。

Core 应用自身的文案目前分别由 String Catalog、Android resources 和 Flutter `FlareMessages` 维护；它们不是 Social 的 `AppStrings` 生成产物。组件内部的通用文案统一从 Kit 生成语言表继承。

逐项运行各应用 README 的构建与测试命令。Swift Package 主机测试不能代替 iOS Simulator 应用构建；Android 需要 `ANDROID_HOME` 指向已安装 SDK。
iOS 构建前准备 `FFI/ios/aarch64-apple-ios-sim/libflare_im_core_sdk_ffi.a`；macOS Flutter 使用 SDK 的 `native/artifacts/host` 动态库（参见 [SDK 原生边界](../../flare-core-sdk/native/README.md)），不从示例应用调用工作区 xtask。
原生 Debug 构建不需要发布签名，远端服务用例需要其指定的测试环境变量。未配置而跳过的用例应单独记录。

切换中文、英文后检查：消息操作、语音录制 / 重试、红包金额及姓名格式、无障碍标签；新增的组件字段应自动继承 Kit 预设。保留 Web 类型检查和生产构建作为接入回归。
