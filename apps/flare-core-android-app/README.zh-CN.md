# Flare Core Android Reference App

[English](README.md) · 中文

## 演示内容

Flare 官方设计体系的使用方，正在向规范 UI 迁移。
Kotlin、Compose、Android Navigation 与感知生命周期的 ViewModel。

## 架构

`AppSession` 持有公开的 `FlareImClient`；仓库与 ViewModel 把 SDK 状态映射成会话、
生命周期、消息与能力契约。各屏组合 kit 组件，经各自的适配层调用 SDK 动作。

## 使用的 flare-im-design 包

`com.flare.im:im-ui-compose:2.0.0-rc.1`，工作区内由相对路径的组合构建替换。

公开的 `IMAppKit`、`ConversationRow`、`ConversationHeader`、`MessageBubble`、
`Composer` 与 `ImagePreview` 已接入。旧的手绘聊天头已移除。搜索面板、会话菜单
和其他本地 composable 仍在迁移中，还不是规范实现。

## SDK 适配层

SDK 的认证、持久化、事件订阅、生命周期切换、重试与媒体传输留在 SDK／应用层。
公开的 kit 数据契约与意图构成视觉边界；不要引入私有渲染器。

## 运行

```bash
export ANDROID_HOME=/path/to/android/sdk
./gradlew :app:testDirectDebugUnitTest :app:lintDirectDebug :app:assembleDirectDebug
./gradlew :app:compileDirectDebugAndroidTestKotlin
```

## 演示模式

可运行的应用使用真实 SDK，没有自动回落的假数据。单元／组件测试里的夹具是测试输入，
不是受支持的产品演示模式。

## 真实 SDK 模式

在登录页输入测试用户 ID。连哪里不是登录设置：它来自构建的接入配置（见下）。SDK 在当前
接入点的 Core API 上自己签发并刷新连接 token（`auth: {}`）；不要把签名密钥放进 UI 代码。
破坏性操作或发送流程用隔离的测试账号。

## 接入配置

应用把 `sdkConfig.access`（`AppAccess.kt`）和 `auth: {}`（SDK 托管的连接 token，在 Core API 上
签发：开发模式是 `developmentEndpoints.coreApiUrl`，正式环境是接入点的 Core API）交给核心 SDK。
每项先读 Gradle 属性，再读同名环境变量；空串算没给。

| 设置 | 含义 |
|---|---|
| `FLARE_ACCESS_JSON` | 整段 `access`：正式配置（`bootstrapId`、`trustRoots`、`seed`、`trustMode: production`），或完整的开发配置。release 构建必须给。 |
| `FLARE_DEV_WS_URL` | 开发模式 IM 入口，默认 `ws://10.0.2.2:60051`（模拟器访问宿主机 `access-gateway.toml` 的端口）。 |
| `FLARE_DEV_QUIC_URL` | 开发模式 QUIC 入口，给了才提供 QUIC（例如 `quic://10.0.2.2:60052`）。 |
| `FLARE_DEV_CORE_API_URL` | 开发模式 Core HTTP 入口，默认 `http://10.0.2.2:50050`（`api-gateway.toml`）。 |
| `FLARE_DEV_MEDIA_URL` | 开发模式媒体入口，缺省同 Core HTTP 入口。 |

调试构建没给 `FLARE_ACCESS_JSON` 时按 `FLARE_DEV_*` 组装开发模式，连接横幅随之带开发模式角标。
本地栈上的两个接入点（故障切换演练）直接给整段：

```bash
FLARE_ACCESS_JSON='{"trustMode":"development","developmentEndpoints":{"wsUrl":"ws://10.0.2.2:60051","coreApiUrl":"http://10.0.2.2:50050","accessPoints":[{"id":"dev-b","wsUrl":"ws://10.0.2.2:61051","coreApiUrl":"http://10.0.2.2:51050"}]}}' \
  ./gradlew :app:assembleDirectDebug
```

release 构建没有 `FLARE_ACCESS_JSON`、或给的是开发配置，会在 `preDirectReleaseBuild`（play 渠道是
`prePlayReleaseBuild`）停下，运行时应用也拒绝开发配置。
选哪条线路、协议竞速、重连、网络变化与前后台都归 SDK：`FlareCoreSdk.createClient(context)` 在 `init`
之后装上平台生命周期，连接横幅是由 `connection://status` 驱动的 kit `ConnectionNotice`。

## 分发渠道

维度 `distribution` 决定 `app.distribution`，发布清单按它选安装包。

| 渠道 | 用于 | 安装方式 |
|---|---|---|
| `direct`（默认） | 官网 | 系统安装会话。只有这个渠道声明 `REQUEST_INSTALL_PACKAGES`。 |
| `play` | Google Play | Play In-App Updates。只有这个渠道带 Play 依赖。 |

任务名都带渠道：`assembleDirectDebug`、`assemblePlayRelease`、`compileDirectDebugKotlin`、
`testDirectDebugUnitTest`。更新渠道默认 `stable`，用 `-PFLARE_UPDATE_CHANNEL=beta` 或同名环境变量改。

## 推送通知

应用使用平台推送模块 `flare-core-android-push`（由核心包带进来），以及可选的
`flare-core-android-push-getui`：

- `FlareCoreApplication` 装上模块（`core/push/AppPush.kt`）：通知渠道、FCM、通知点击与权限上报。
  登录或会话恢复完成后，模块拿到宿主适配器（包在已登录客户端上的 `CorePushHost`）；退出登录时撤下它并调
  `FlarePush.signOut()`：移除本应用发出的通知，忘掉报过的令牌。令牌登记带应用界面的语言（`FlarePush.setLocale`）。
- `MainActivity` 把每个启动意图交给 `FlarePush.handleLaunchIntent`，按 `FlarePush.routes` 的每一项打开会话。
  点通知拉起应用时，这次点击等会话恢复后才解析，而且只对当前登录的账号生效。
- 权限状态来自模块（`FlarePush.permission`），申请经 `FlarePushPermission.request`，问没问过由模块记。登录后来到
  会话列表、通知还没开时，用 kit `PermissionPrompt` 软询问在底部面板里问一次：系统授权框还会弹时「开启通知」，
  弹不出来了「前往设置」。选了哪个都按账号记住。设置里是 kit `NotificationDeliverySettings`：通知开没开、电池设置
  怎么对待后台运行，并引导到系统自己的页面：电池使用，以及华为、荣耀、小米、OPPO、vivo 的自启动。不做任何自动化。
- 推送在没有界面的情况下拉起的进程里没有会话：通知按服务端渲染好的载荷展示。
- 应用开着时，提不提醒由引擎决定，应用内的那种经 `notification.present`（surface 为 `inApp`）交来：`MessageAlerts`
  交给根上的 kit `InAppNotificationHost`（点横幅与点通知一样打开会话），引擎要响时放系统的通知提示音。聊天页报屏幕上
  的会话、`MainActivity` 报前后台（`notification.setFocus`）。设置里另有 kit `NotificationAlertSettings`：勿扰时段、
  通知预览、其他设备活跃时，同一账号的设备共用一份，经 `notification.updateSettings` 保存（改了先显示，没存成就退回
  并重读）。
- 客户端是进程级的：唯一的 `FlareRootViewModel`（连同它的 `FlareAppStore`）放在 `FlareCoreApplication` 自己的
  ViewModelStore 里，关掉界面也不释放，退到后台后链路照常在线。`AppPush` 启动时就要上模块的后台展示器；模块在通知
  已允许、会话就绪时才告诉引擎接上，撤销权限时断开。接上期间，引擎在后台决定的提示由模块发成系统通知。
- 常驻连接模式（`flare-core-android-keepalive`，`core/push/AppKeepAlive.kt`）只在没有推送通道的构建里出现在设置中
  （没有 `google-services.json`，也没有个推应用标识）。打开时启动前台服务、关掉推送绑定（对每个通道 `clearPushToken`）、
  后台展示器接着；开机或更新后服务自启，在没有界面的情况下恢复会话。关掉时反过来。开着且电池优化没关时，kit 再给
  一行，点了打开电池优化的设置页。

### Firebase（FCM）

把你的 Firebase 项目的客户端配置放在 `app/google-services.json`（已加入 gitignore：每个部署自带）。
只有这个文件存在时才套用 Google 服务插件。没有它应用照样构建运行，FCM 不启用，推送的其余部分照常。
Firebase 里的 Android 应用按 `applicationId`（`com.flare.im.app`）登记，服务端的 FCM 凭据必须属于同一个
Firebase 项目。

### 个推（可选，面向中国大陆设备）

构建没给个推 app id 时个推不启用。用 Gradle 属性或同名环境变量给出：

```bash
./gradlew :app:assembleDirectRelease -PFLARE_GETUI_APP_ID=<个推 app id>
```

它填个推 SDK 清单里的 `GETUI_APPID` 占位符和 `BuildConfig.FLARE_GETUI_APP_ID`。给了之后应用在登录后才启动个推，
用户登录前不初始化任何推送 SDK；不给时个推照样编进来，但从不初始化。面向国内应用商店的构建还要在登录前让用户
同意隐私政策。个推的制品来自它自己的 Maven 仓库，`settings.gradle.kts` 只让 `com.getui` 下的坐标走那里。

应用被杀后靠手机厂商自己的通道到达，由个推的厂商插件提供。按个推 Android 接入文档（以
`flare-core-android-push-getui` 固定的 SDK 版本为准）加上插件和各厂商的应用标识与密钥（华为、荣耀还要把厂商的
配置文件放进 `app/`）。厂商问应用在哪个通知渠道上展示消息时，用模块创建的渠道：`flare.messages`、
`flare.mentions`、`flare.urgent`、`flare.quiet`。

### 即时通讯类目（运营方）

在中国大陆上线前，运营方要在各手机厂商的开发者后台申请即时通讯类目：华为（消息自分类）、荣耀（通知重要级别）、
小米（单聊、群聊的私信 channel 与模板）、OPPO（通讯与服务通道与私信模板）、vivo（消息分类，另要备案应用的通知渠道）。
没有获批的类目时，厂商通知按运营消息处理：每日限额、被折叠或静音，应用代码绕不过去。审批周期不可控，尽早提交；
获批后把结果写进服务端该应用的个推凭据，`getui.android_vendor` 下：

- `huawei_category`、`honor_importance`、`vivo_category`；
- 小米：`xiaomi_channel_id` 与 `xiaomi_template_id`（两者要一起填），群聊可另填 `xiaomi_group_channel_id`、
  `xiaomi_group_template_id`（各自不填时用单聊的值）；
- OPPO：`oppo_private_template_id`，可选的 `oppo_notify_level`（1、2 或 16），账号仍有旧私信通道时才填 `oppo_channel_id`。

模板用 `title`、`content` 两个变量，由服务端填入它渲染好的标题与正文。vivo 按渠道 id 与中文名称备案：聊天消息
（`flare.messages`）、聊天中@我的消息（`flare.mentions`）、紧急聊天消息（`flare.urgent`）、聊天消息静默更新
（`flare.quiet`）。要申请什么、模板示例与怎样确认生效，见 Flare 知识库的
[厂商即时通讯类目申请手册](https://github.com/flare-im/flare-knowledge-base/blob/main/docs/operations/push-vendor-im-category.md)。

## 支持的功能

会话／消息流程是 Core 的范围：会话初始化、列表、打开会话、时间线、输入区、发送／重试、消息操作、搜索、
媒体与 SDK 诊断。各平台的接入程度和规范渲染器覆盖面不同。组件归属见
[UI 复用规则](https://github.com/flare-im/flare-im-design/blob/main/docs/ui-component-reuse-policy.md)。
通讯录、群目录与关系导航需要 Social 适配层。群会话是消息目标，不是群管理。

## 平台集成

Activity 生命周期、系统返回、输入法、导航、权限（包括通知权限）、文件／相机选择与 JNI 加载由宿主负责。
构建好对应的原生 SDK 产物后用 `scripts/sync_ffi.sh` 同步。

## 文案与组件库接入

组件库文案必须跟随应用语言；Swift 自定义文案使用配置闭包。迁移、资源生成及六个原生示例的接入约定见 [原生文案接入](../../docs/native-localization.md)。
