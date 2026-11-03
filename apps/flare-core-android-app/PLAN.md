# flare-core-android-app 交付计划

## Goal
- Compose UI 落地 `FlareTheme` 设计系统（双主题 + token），六大界面：会话列表 / 聊天 / Composer / 搜索 / 设置 / SDK Lab。
- i18n（strings.xml en + zh-rCN）。
**Done** = `./gradlew :app:compileDebugKotlin` 通过 + `:app:testDebugUnitTest` 通过 + CAPABILITY-PARITY.md Android 列复核更新（≈97）。

## Constraints & decisions
- **核心发现：不需要改 core / SDK**。`flare-core-android-sdk` 已暴露完整 12 模块 API（MessagesApi 28 / ConversationsApi 18 / SessionApi 17 …），与 apple-sdk 1:1。本任务 100% 在 `examples/flare-core-android-app` 内写代码（flare-im-spec 层归属：product/UI → examples，干净满足）。
- **反应式契约（唯一 correctness 敏感点）**：`AppSession` 唯一持有 `FlareImClient`，**只订阅一次** `client.events.onViewUpdated` → 路由给 `ViewDataRepository.apply()` → 暴露 `StateFlow`；绝不轮询。乐观发送立即返回 optimistic message，靠 view-update 流对账；`onMessageSendFailed` 标记失败。
- **乐观/离线优先**：用户动作不等待网络（下一帧反映意图）。SDK 调用走 `Dispatchers.IO`/`viewModelScope`，UI 读 StateFlow。LazyColumn 虚拟化 + 稳定 key。
- **构建**：gradlew 已提交（wrapper 在）；JDK17；快速门禁 `./gradlew :app:compileDebugKotlin`。现有包根 `com.flare.im.app.*`；空 DDD 脚手架 `com.flare.im.{interface,application,...}` 暂留/复用。

- [x] **删除全部冗余文件夹**：旧 DDD 脚手架 `com/flare/im/{interface,application,domain,infrastructure,shared}`（15 个 .gitkeep）+ 空 `app/{application,infrastructure/repositories}`。现 `com/flare/im/` 仅 `app/`。
- [x] 共享 UI 原子 `features/shell/SharedComposables.kt`(internal) 跨包复用；test `SdkModelMapperTest` 同步迁 `core/domain/`。
- [x] 门禁：assembleDebug + testDebugUnitTest 全绿，parity 105/116 不变。

## 旧 Status: ✅ Phase 7 完成（/flare-im-engineer 审计修复 + 全部增强）— 105/116 全绿
完成全部剩余项：
- [x] **语音录制**：`core/platform/AudioRecorder.kt`(MediaRecorder→m4a/AAC) + RECORD_AUDIO 权限 + Composer 麦克风按钮(运行时权限请求 + 录/停切换) → `vm.sendAudio` → uploadFile(best-effort)+buildAudio。
- [x] **拆分剩余屏**：Login/Search/Settings → `features/{auth,search,settings}/*Screen.kt`；共享 UI 原子 → `features/shell/SharedComposables.kt`(internal)。**FlareApp.kt 543→323 行**（仅留 root/nav/ConversationList/Chat/Composer/StartDialog —— 经选择态耦合，合理同居）。
- [x] 门禁：assembleDebug + testDebugUnitTest 全绿，parity 105/116。
结构现状：每特性 ViewModel + Screen 独立文件（auth/messaging/search/settings/sdklab + shell）。仅 F6（发送后轻微冗余 re-fetch，本地 DB 读）有意保留。

### Phase 7 — 工程审计修复 + 剩余增强
审计发现：F1 消息只渲染 previewText（应按 contentType 渲染）；F2 emoji/sticker 资产空+无渲染/选择器；F3 无图片/语音发送；F4 FlareApp.kt 543 行单文件需拆；F5 StateFlow read-modify-write 非原子（应 `.update{}`）；F6 发送后双重 re-fetch 冗余；F7 非真乐观（消息等 ack 才显示，违反 spec optimistic-always）。
- [x] **F2** `core/domain/EmojiPresentation.kt` + `core/platform/FlareAssetImage.kt`（Compose 读 assets webp，按 path 缓存解码）→ 渲染 emoji-pack/sticker/单 emoji 消息 + Composer `EmojiStickerPanel` 选择面板（点选→buildAndSend CreateEmoji/CreateSticker）。
- [x] **F3** 图片发送：Android `PickVisualMedia` photo picker → `media.uploadImage`(best-effort) → buildImage（`vm.sendPickedImage`）。
- [x] **F4** 拆分：MessageRowView(185 行) + SdkLabScreen 抽出独立文件；FlareApp.kt **543→435 行**。
- [x] **F5** ViewDataRepository StateFlow 全部 `.update{}` 原子化（消除 read-modify-write 竞态）；**F7** `insertOptimistic` 乐观插入（optimistic-always）。
- [x] 门禁：`:app:assembleDebug` + `:app:testDebugUnitTest` **BUILD SUCCESSFUL**；parity 仍 105/116。
- 已知保留（可选）：**F6** 发送后 re-fetch 与 onViewUpdated 轻微冗余（本地 DB 读，可接受）；语音录制；Search/Settings/Login 继续拆文件。

完成：Core 数据流 + 5 特性 VM + FlareRootViewModel + 6 屏 Compose UI + FlareTheme + i18n。
验证全绿：`:app:compileDebugKotlin` ✅ / `:app:assembleDebug` **BUILD SUCCESSFUL(37s)** ✅ / `:app:testDebugUnitTest` ✅。
### 收尾完善（2026-06-27 第二轮）✅
- [x] **UX：让 VM 能力全部可达** —— 会话长按上下文菜单(pin/mute/archive/unread/clear/delete)、消息长按动作菜单(react/unreact/pin/mark/edit/recall/deleteSelf/copy/forward)、起会话对话框(peer/group)、Composer「+」构建菜单(11 种 build op)、发送状态指示(sending/failed+retry/reactions)、置顶标记。
- [x] **平台服务（部分）**：Copy 用 Compose `LocalClipboardManager`（无需平台抽象）。image/audio picker 留作可选 UX 增强。设计 token 已全屏使用。
- [x] **清理死代码**：删除旧簇 5 文件（FlareAndroidViewModel/FlareAndroidAppStore/Android{Conversation,Message}Repository/AppSendMessageResult）；`AndroidTransportConfigTest` 迁移到 `LoginDraft.transportConfig()`。
- [x] **恢复 listMessages/createTextMessage**（删除旧仓后掉的 2 op → SdkLab 探针补回）→ 仍 105/116。
- [x] 最终门禁：`:app:assembleDebug` + `:app:testDebugUnitTest` **BUILD SUCCESSFUL**。

原 Status:
**已建 Core API 可用**：`FlareAppStore(dataDir,scope)` → `.session`/`.repository`/`.environment`（均 StateFlow）+ `login/logout/dispose`。`MessageBuilder.build(client,cid,op,payload,selected)`。`AppSession.client` 取门面。
**未接线**：旧 `FlareAndroidViewModel`/`MainActivity`/`app/application/FlareAndroidAppStore` 仍是旧极简实现，Phase 2 起逐步替换（新 UI 用新 Core；最后切 MainActivity setContent → 新 Shell + FlareAppTheme）。

### 构建配方（已验证）
```
cd examples/flare-core-android-app
export JAVA_HOME=/opt/homebrew/Cellar/openjdk@17/17.0.19/libexec/openjdk.jdk/Contents/Home
export ANDROID_HOME=/Users/hg/Library/Android/sdk
./gradlew :app:compileDebugKotlin --console=plain
```
首跑 4m42s（含 gradle/依赖下载），增量更快。包根 `com.flare.im.app.*`（namespace 同名）；现有真实代码在 `com/flare/im/app/{domain,application,infrastructure}`，DDD 脚手架 `com/flare/im/{interface,...}` 为空。MainActivity 现用裸 `MaterialTheme{}`，**无 `res/values/strings.xml`**（硬编码中文如"聊天"）。

## Steps

### Phase 0 — 基线 + 设计系统 + i18n 骨架
- [x] **构建基线**：`:app:compileDebugKotlin` **BUILD SUCCESSFUL**（4m42s 首跑）。android-sdk + app 均编译；仅 WireCodec unchecked-cast 警告（pre-existing）。
- [x] `core/designsystem/FlareTheme.kt`：`FlareColors`(light+dark，dynamic-color off)、`FlareTokens`(Spacing 2/4/8/12/16/20/24、Radius 6/8/12/16/pill)、`FlareType`(largeTitle..captionStrong+eyebrow)、`FlareTone`、`FlareAppTheme(dark:)`、`FlareTheme.{colors,tokens,type}` 访问器。包根定为 `com.flare.im.app.core.*` / `features.*`。
- [x] i18n：`res/values/strings.xml`(en) + `res/values-zh-rCN/strings.xml`(zh)，shell/nav/filter/common/conversation/chat/auth/settings/lab 起始集（按屏逐步扩充）。
- [x] 门禁：`:app:compileDebugKotlin` **BUILD SUCCESSFUL in 6s**（增量）。
- 包结构：随各 feature 文件落地自然形成（`core/{session,data,domain,platform,designsystem}` + `features/*`）。

- [x] 领域模型镜像：`core/domain/AppModels.kt`（AppSection/ConversationFilter/ThemeChoice/StartConversationKind/RuntimeStatus(sealed)/LoginTransportMode/LoginDraft(+transportConfig)/LabResult/EventLogEntry）。复用现有 `app/domain/{AppConversation,AppMessage,...}` 薄包装。
- [x] `core/session/AppSession.kt`（唯一 client 持有 + start/logout/dispose + 订阅 onViewUpdated/connect*/disconnect/login 事件 + StateFlow(currentUserId/isLoggedIn/connectionState/eventLog) + onViewUpdate/onMessageSendFailed 钩子）。
- [x] `core/data/ViewDataRepository.kt`（StateFlow conversations/messagesByConversation/hasMore + openConversationList/openTimeline/loadOlder/apply + reset/clearMessages/removeConversation）。**决策**：re-fetch-on-signal（Kotlin SDK 无 snapshot/delta 解码器；onViewUpdated→重拉 typed 快照，core 拥序、client 只投影；local-first 存储含乐观消息故一致）。
- [x] `core/data/AppEnvironment.kt`（selected/filter/section/theme/isBusy/runtimeStatus/lastError/labResults/loginDraft StateFlow + run()）。
- [x] 门禁：compileDebugKotlin **SUCCESSFUL**（SDK request/event 构造签名全部验证正确）。
- [x] `core/domain/MessageBuilder.kt`（payload reader + `MessageBuildOp` 枚举 + build* 覆盖 20 类）。坑：`ForwardSourceMessage`∈`model.content`、`MediaSourceInfo`∈`model.media`（非 model.entity）；`MessageContent(MessageContentType, Map)`；Kotlin `BuildVoteMessageRequest` 无 participantUserIds。
- [x] `core/session/AppLifecycle.kt` 接口 + `core/FlareAppStore.kt` 组合根（装配 session/repo/env + login/logout/dispose 编排 + `session.onViewUpdate`→scope.launch{repo.apply} 反应式接线）。5 VM 在 Phase 2+ 装配。
- [x] 门禁：compileDebugKotlin **SUCCESSFUL**。Phase 1 完成（8 文件全编译）。

### Phase 2 — Messaging 特性（核心 IM 界面）
- 注：动作 op 名已大量出现在 VM（recall/edit/deleteSelf/deleteEveryone/react/unreact/pin/unpin/mark/unmark/setTyping/setConversationPinned/Muted/Archived/markConversationUnread/clearLocalChatHistory/deleteConversation/getOneConversation/getGroupConversationByUserIds/updateConversationDraft）→ parity 计数已推进。
- [ ] ConversationList 屏（Compose）：header(eyebrow+title+live subtitle+presence dot)、filter tabs、会话卡片、空状态、context menu(pin/mute/archive/unread/clear)、起会话 sheet、more sheet。
- [ ] Chat 屏：时间线 LazyColumn(虚拟化+稳定key)、加载更早、连接状态条、消息行（incoming/outgoing 气泡 + 媒体 + 富卡片 + 反应 pill + 投递状态 + 长按动作菜单 + quick actions）、chat 搜索 sheet。
- [ ] Composer：文本/富文本输入、工具栏(emoji/语音/图片/富文本/更多)、扩展面板(11 种 builder 表单)、录音、贴纸/表情面板。
- [ ] 门禁：compileDebugKotlin。

### Phase 3 — Auth + Settings + Shell + 其余 VM
- [ ] `AuthViewModel` + Login 屏（loginDraft 绑定 + 校验 + transport 选择 + submit→lifecycle.login）。
- [ ] `SettingsViewModel` + Settings 屏（theme/loginDraft/会话态 + refreshDiagnostics/logout/dispose）。
- [ ] Shell：`WindowSizeClass` 自适应（phone NavigationBar + 全屏 chat / expanded 双栏）+ 顶层登录路由。
- [ ] 门禁：compileDebugKotlin。

### Phase 4 — Search + SDK Lab（达成长尾 op 覆盖）
- [x] `features/sdklab/SdkLabViewModel.kt` **完成**（~50 长尾 op 全覆盖：diagnostics×4 / lifecycle+connection×14 / conversation 探针×4 / message 探针×5 / builder normalize×4+catalog / media×19 / capabilities×6 / presence×3 / sync×3 / events×3）。门禁通过。坑：`Normalize*Request`/`SetHeartbeat*Request`/`NetworkChangeRequest`∈`model.command`；`HeartbeatAppState`∈`model.entity`。
- [ ] `SearchViewModel`（searchMessages/ByQuery/InConversation + draft）。
- [ ] Search 屏 + SDK Lab 屏 Compose。

### Phase 5 — 平台服务 + 收尾
- [ ] `core/platform/`：Clipboard、ImageDecoder/load、AudioRecorder（Android MediaRecorder）。
- [ ] 设计 token 全屏推广（魔法数字 → FlareTokens）。
- [ ] 门禁：compileDebugKotlin + testDebugUnitTest。

### Phase 6 — Parity 复核 + 文档
- [ ] 按 CAPABILITY-PARITY.md 方法学（word-boundary grep 各 op 名 over `flare-core-android-app/app/src/main`）重算 Android 列。
- [ ] 更新 CAPABILITY-PARITY.md：Android 21 → ~97，矩阵 Android 列、总览、补齐清单、日期。
- [ ] 更新 memory（[[flare-im-example-parity]]、[[android-app-build-setup]]）。

## Notes / open questions
- Android SDK 关键类型：`FlareImClient`(facade, extends SessionApi)、`client.{messages,conversations,media,messageBuilder,views,events,presence,sync,connection,capabilities,diagnostics}`、`EventsApi.onViewUpdated(ViewUpdate)`、`ViewsApi.{openTimeline,openConversationList,loadOlderTimeline,close}`。
- FlareTheme 色值（光/暗）见本会话设计输出（brand #7D3BED / #9D6BFF …）。
- 构建命令：`cd examples/flare-core-android-app && ./gradlew :app:compileDebugKotlin`（首跑可能需下载 gradle/依赖，耗时）。
- 规模预警：~76 op + 完整 Compose UI，多执行周期。每 Phase 收尾必跑门禁 + 回填本文件。
- 踩坑预防：Kotlin `*Request` 构造参数顺序逐一核对（不臆断）。
