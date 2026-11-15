# Flare Core iOS 参考应用

[English](README.md) · 简体中文

## 演示内容

Flare 设计库的官方使用方，正在迁移到规范 UI。
Swift 6、SwiftUI、SwiftPM 与 Apple SDK（iOS 16+；SwiftPM 也可在 macOS 上编译）。

## 架构

`AppSession` 持有 `FlareImClientProtocol`。`ViewDataRepository`、各特性的 ViewModel
与 SDK 映射负责会话与事件、分页、命令、媒体解析和能力判断。导航与弹出层用 SwiftUI 原生实现。

## 使用的 flare-im-design 包

工作区相对路径下的 `FlareIMUI`，版本 `2.0.0-rc.1`。

已接入公开的 `IMAppKitView`、`ConversationHeaderView`、`MessageBubbleView`、
`ComposerView` 与 `ImagePreviewView`。本地的聊天头部和操作浮层背景已移除，保留原生 sheet 呈现。
本地的消息操作内容、菜单与面板修饰符、输入区表单还需要接入规范组件库。

## SDK 适配

SDK 的认证、持久化、事件订阅、生命周期切换、重试和媒体传输留在 SDK 与应用层。
视觉边界是组件库公开的数据契约与意图，不要引入私有渲染器。

## 运行

```bash
bash scripts/sync_ffi.sh
swift build
swift test
xcodegen generate
xcodebuild -project FlareImApp.xcodeproj -scheme FlareImExampleApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

## 演示模式

可运行的应用用的是真实 SDK，没有自动切换到假数据的兜底。
单元测试与组件测试里的固定数据只是测试输入，不是受支持的演示模式。

## 真实 SDK 模式

在登录页输入测试用户 ID。连到哪里不是登录设置：构建把 `access` 配置（`AppAccess`）交给 SDK，
由 SDK 选择接入点与协议、负责重连，并自己上报网络与前后台变化。取值先读进程环境变量
（模拟器上是 `SIMCTL_CHILD_` 加变量名），再读 Info.plist（`project.yml` 里的构建设置）：

- 调试构建走开发模式。什么都不设时连本机栈：IM `ws://127.0.0.1:60051`，Core HTTP 与媒体
  `http://127.0.0.1:50050`。用 `FLARE_DEV_WS_URL`、`FLARE_DEV_QUIC_URL`（给了才走 QUIC；
  自签证书的服务端还要配 `FLARE_TLS_CA_CERT`）、`FLARE_DEV_CORE_API_URL` 与 `FLARE_DEV_MEDIA_URL`
  单项覆盖，例如 `xcodebuild ... FLARE_DEV_WS_URL=ws://192.168.1.20:60051`。
- `FLARE_ACCESS_JSON` 用一整段 `access` 对象替换上面所有项，例如为切线演练加第二个接入点：
  `{"trustMode":"development","developmentEndpoints":{"wsUrl":"ws://127.0.0.1:60051","coreApiUrl":"http://127.0.0.1:50050","mediaUrl":"http://127.0.0.1:50050","accessPoints":[{"id":"dev-b","wsUrl":"ws://127.0.0.1:61051","coreApiUrl":"http://127.0.0.1:51050","mediaUrl":"http://127.0.0.1:51050"}]}}`
  （第二项按实际端口填写）。
- 发布构建只读 `FLARE_ACCESS_JSON`（正式的 `bootstrapId`、`trustRoots`、`seed` 与
  `trustMode: production`），没有就在启动时停下，绝不退回开发模式。

连接令牌由 SDK 托管（每种构建都是 `"auth": {}`）：SDK 在它所用接入点的 Core API 上签发并续期，
开发模式下就是上面的 Core HTTP 入口。在设置里粘贴的令牌原样交给登录。不要把签名密钥放进界面代码。
会删除数据或发送消息的流程请用隔离的测试账号。

## 推送通知

APNs 推送经 `FlarePlatformPush`（`flare-core-apple-sdk` 的一个 product）到达，它的宿主是核心客户端
（`CorePushHost`）。提示、去重和角标由推送模块与核心负责；应用接的是：

- `FlareImAppDelegate`，运行器用 `@UIApplicationDelegateAdaptor` 装上：在启动返回之前开起推送模块
  （冷启动的那次点击才不会丢），并转交 APNs 令牌与静默推送的回调。它还在启动时、不等界面就恢复保存的会话，
  用的是进程里唯一的 `FlareAppStore`（`FlareAppStore.shared`，其中是唯一的客户端）：被后台刷新或静默推送冷启动
  起来的进程没有界面，本地库一开推送宿主就接上。界面之后用的是同一个组合根。会话还在恢复时到的静默推送先等它
  （最多 2 秒），核心才唤醒得了、同步得了。
- `PushNotifications`：登录或恢复会话成功后接上客户端，登出或释放时交给模块的 `signOut()`（摘下宿主，
  清掉本 SDK 的通知和角标）。令牌登记带应用界面的语言（`setLocale`）。
- 权限：状态来自模块的 `permissionChanges()`。已登录的账号来到会话列表、通知还没开时，组件库的
  `flarePermissionPrompt` 软询问在底部面板里说明原因：系统还没问过时「开启通知」弹系统授权框，关着时
  「前往设置」。选了哪个都对这个账号记住，不再出现。设置里的 `NotificationDeliverySettingsView` 显示系统权限状态：
  系统还没问过时点它会请求，其余情况打开系统设置里本应用的通知页。
- 点通知打开对应会话，包括在会话恢复之前就把应用冷启动起来的那次点击。
- 应用开着时，提不提醒由引擎决定，应用内的那种经 `notification.present`（surface 为 `inApp`）交来：`MessageAlerts`
  交给根上的 kit `InAppNotificationHost`（点横幅与点通知一样打开会话），引擎要响时放系统的新消息提示音。聊天页把
  屏幕上的会话报给引擎（`notification.setFocus`，退到后台时清空）。设置里另有 kit `NotificationAlertSettingsView`：
  勿扰时段、通知预览、其他设备活跃时，同一账号的设备共用一份，经 `notification.updateSettings` 保存（改了先显示，
  没存成就退回并重读）。
- `NotificationService`：应用扩展，继承 `FlareNotificationServiceBase`（product `FlareNotificationService`），按引擎写在
  App Group `group.com.flare.im.example.app` 里的通知快照重渲染提示的标题与发送者名字、套用本地的预览设置，并记下
  到达回执。`PushNotifications.configuration` 把同一个 App Group 交给推送模块、声明带了扩展（令牌登记随之带
  `serviceExtension`，服务端给提示推送加 `mutable-content`），并给出后台刷新任务 `com.flare.im.example.app.refresh`：
  登录期间最多每 15 分钟预取一次新消息。

要收到推送：

1. 在平台控制台里，应用的 APNs 凭据（Team ID、Key ID 与 `.p8` 认证密钥）的 topics 要列出本应用的
   包名 `com.flare.im.example.app`。没有控制台的部署把同样的记录写进推送 worker 的
   `flare.mobile-push-applications/v2` 文件（见 `flare-core-server` 的 `docs/offline-push-delivery.md`）。
   一个密钥同时适用于 APNs 的两个环境，每台设备登记自己的环境。
2. 用 App ID 已开通 Push Notifications 的团队签名，描述文件要包含这项能力。
   `Resources/FlareImApp.entitlements`（由 `project.yml` 生成）带 `aps-environment: development`，
   自动签名会把这项能力加到 App ID 上。推送模块在运行时从内嵌的描述文件读出环境：开发签名的构建登记为
   `sandbox`，App Store 与 TestFlight 的构建登记为 `production`。改了 `PRODUCT_BUNDLE_IDENTIFIER`
   也要把新包名加进凭据的 topics。
3. 在真机上运行，或在 Apple 芯片 Mac 的模拟器上运行；模拟器构建总是登记为 `sandbox`。
4. 通知扩展（`com.flare.im.example.app.NotificationService`）用同一个团队签名，两个 App ID 都要开 App Groups 能力并
   选中 `group.com.flare.im.example.app`（自动签名会注册它；手动签名要把这个组加进两个描述文件）。换包名时 App Group、
   后台刷新标识与扩展的包名一起改：`project.yml`、`PushNotifications.configuration` 与
   `NotificationService/NotificationService.swift`。没有 App Group 时推送照样到达，只是显示服务端文案、没有到达回执。

## 支持的功能

会话与消息流程是 Core 的范围：会话初始化、列表、打开会话、时间线、输入区、发送与重试、消息操作、
搜索、媒体与 SDK 诊断。各平台的接入程度与规范渲染器覆盖面不同。组件归属见
[UI 复用规则](https://github.com/flare-im/flare-im-design/blob/main/docs/ui-component-reuse-policy.md)。
通讯录、群目录与好友关系导航需要 Social 适配层。群会话在这里只是消息目标，不含群管理。

## 平台相关接入

NavigationStack、sheet/fullScreenCover、文件与照片选择器、麦克风权限、分享以及 FFI 产物加载都保持原生。
Xcode 按 SDK 与架构选择静态库：arm64 真机用 `aarch64-apple-ios`，arm64 模拟器用 `aarch64-apple-ios-sim`，
Intel 模拟器用 `x86_64-apple-ios`。通用 iOS 构建需要同步好的全部三个切片。
