# Migrate flare-core-android-app UI → flare-im-design compose kit

## Goal
把 flare-core-android-app 的自建 UI 迁到 `com.flare.im.ui`（flare-im-design/android-im-ui, module `:flare-im-ui-compose`），kit 缺的组件就补到 kit。保 app 的 SDK 接线不变。验证 = `:app:compileDebugKotlin` + `:app:testDebugUnitTest` 绿（JDK17）。Android 是 3 原生端迁移的**先行样板**。

## 现状（已查清）
- app 0 处 import kit；自建 UI 在 `features/messaging/**`（message rows / conversationlist / composer / chat）+ `features/{auth,search,settings,sdklab,shell}`。50 app-kt vs 41 kit-kt → kit 缺组件，需补齐。
- app 数据模型：`core/domain/App{Message,Conversation,...}`；leaf 视图吃 AppMessage。kit 组件吃纯 props。→ 迁移 = leaf 视图内部改调 kit（映射 App模型→kit props）。
- kit module `:flare-im-ui-compose` @ `../../../flare-im-design/android-im-ui`，namespace `com.flare.im.ui`，compose-bom 2024.12（与 app 同）、coil 2.7。
- 无 committed gradlew（复用 flutter app wrapper + local.properties + JDK17）。非 git 仓库。

## Steps
- [x] **Phase 1 接线 ✅（verified）**：源码模块方式冲突（kit build.gradle 自带 plugin version，与 app 根 classpath 撞 "already on classpath with unknown version"）→ 改走**真实消费路径 mavenLocal**：kit `publishToMavenLocal`（`com.flare.im:im-ui-compose:0.1.0`），app settings 加 `mavenLocal()`，`implementation("com.flare.im:im-ui-compose:0.1.0")`。**`:app:compileDebugKotlin` BUILD SUCCESSFUL** —— app 现可用 `com.flare.im.ui.*`。（迭代改 kit 需重跑 publishToMavenLocal。）

## Phase 2 关键发现（架构错配 → 需按组件补 kit）
迁移不是"叶子换组件",因为**原生 app 是 kit 的设计来源,app 视图比 kit 富**:
- **气泡粒度**:app = `MessageRow` 的气泡 chrome 与 `MessageContentView` 内容**分离**(内容只是内容);kit 消息体是**自带气泡**的自包含组件。→ 接缝 = `MessageRow.standalone` 标志(standalone 时 app 不画气泡),自包含 kit 体应走 standalone。
- **每类型都更富**:`SystemMessageView`=图标+文本卡 vs kit `SystemMessage`=居中 pill;`ImageMessageView`=本地直链→vm.resolveMediaUrl 远端签名 URL + FlareLocalImage(maxPx 降采样) + 全屏预览 vs kit `ImageMessage`=固定 132×92 Coil 缩略;`TextMessageView`=RichDoc v2 + 表情包 key 大图 + 单 emoji 大字 vs kit `TextMessage`=纯文本+链接。
- **媒体解析**:image/video/audio 靠 `vm.resolveMediaUrl(message)`(SDK 异步),kit 体吃已解析 URL。
- **kit 待补(faithful parity)**:ImageMessage 弹性尺寸(maxW/maxH 保比)+ 可注入 loader、StickerMessage 资源图(非 emoji 字形)、RichDoc 渲染(或 slot)、SystemMessage 图标+文本变体、媒体 URL prop。

→ 忠实迁移 = **逐组件把 app 的富behavior补进 kit**(把富度从 app 迁入通用 kit),再 app 走 standalone 委派。是真活,非浅换。已把接缝(standalone)与缺口清单钉死。
- [x] **Phase 2a 卡片族(7 类)✅（compile+unittest verified）**：**关键发现——app 的 File/Location/Card/LinkCard/Vote/Task/System 只是 `CardRow(icon,title)` 占位,kit 反而更富**,所以是干净升级(非补 kit)。`CardMessageViews.kt` 改调 kit `com.flare.im.ui.{FileMessage,LocationMessage,ContactMessage,LinkCardMessage,VoteMessage,TaskMessage,SystemMessage}`(app content→props);`isStandaloneAsset` 把这 7 类标 standalone(kit 卡自带 surface,app 不再包气泡)。MiniProgram/Schedule kit 无对应→留 CardRow(kit 待补)。`:app:compileDebugKotlin` + `:app:testDebugUnitTest` **BUILD SUCCESSFUL**。→ 证明"kit 更富→委派"方向。
- [x] **Phase 2b-Image ✅（补 kit + 委派，compile+unittest verified）**：kit `ImageMessage` 加**弹性尺寸**(`maxWidth`/`maxHeight` → `sizeIn`+`ContentScale.Fit`,保留固定缩略默认)——通用完善,republish mavenLocal。app `ImageMessageView` 改调 kit `ImageMessage(src=已解析path, maxWidth=220,maxHeight=280, onTap=预览)`,**URL 解析仍归 app(vm.resolveMediaUrl)**,组件只吃已解析 src(Coil 加载本地/远端皆可);IMAGE/IMAGE_GROUP 标 standalone。→ 证明"app 更富→补 kit→委派"方向。**8 类消息现经 kit 渲染。**
- [x] **Phase 2b 消息体全迁 ✅（compile+unittest verified）**：
  - **Audio → kit VoiceMessage**：kit shell(波形+▶/⏸+时长),app 保 MediaPlayer 播放,喂 playing/onPlay。无需改 kit。
  - **Video → kit VideoMessage**：kit 加 **posterContent slot**(app 传 MediaMetadataRetriever 首帧 bitmap)+ matchParentSize 浮层自适应;app 保缩略提取 + 内联播放器 dialog。republish。
  - **Text(plain) → kit TextMessage**(self=outgoing);isStandaloneAsset(TEXT)=docJson==null(plain/emoji standalone 走 kit 气泡,richdoc 保 app 气泡);TextMessageView 加 outgoing 参、MessageContentView 传入。
  - IMAGE/VIDEO/AUDIO/TEXT(plain) 全标 standalone。
  - **Sticker/Emoji 保 app**：是真资源包图(FlareAssetImage,asset:// 路径),非占位;kit 通用 unicode 版路由无收益 → app 专属资源系统保留(kit 的 glyph 版给无资源系统的宿主)。
  - **11 类消息现经 flare-im-design kit 渲染,`:app:compileDebugKotlin`+`:app:testDebugUnitTest` 全绿。** 两套模式(kit 更富→委派 / app 更富→补 kit slot→委派)都验证。
- [x] **Phase 3a 会话行 ✅（compile+unittest verified）**：app 私有 `ConversationRow` 改调 kit `com.flare.im.ui.ConversationRow(item=ConversationRowData(...), onSelect, onLongPress)`（映射 AppConversation→ConversationRowData：id/title/preview/unreadCount/pinned/muted/mentioned），app 保长按 DropdownMenu 菜单包在外。**修了 kit 真 bug**：`ConversationRow.onLongPress` 是死参（只接了 `.clickable`）→ 改 `combinedClickable` 接 onClick+onLongClick（+@OptIn）。republish。→ 升级(kit 行更富：presence/mute 图标/draft/时间)。
- **Composer 保 app（合理边界）**：`ComposerBar` 是富编辑 infra——6 槽工具栏 + 富文本格式条 + emoji 面板 + 语音录制 + `vm.buildAndSend` SDK 消息构建。kit 的 composer parts(SendButton/ActionPanel/ReplyStrip)是给"从零搭 composer"的宿主用；app 有整套富 composer → 保留(同 Sticker/Emoji 边界)。
- [x] **Phase 3b 共享基元 EmptyState ✅（compile+unittest verified）**：app shell `EmptyState(title,message)` 内部改调 kit `com.flare.im.ui.EmptyState(title,description)`（保全屏居中包装）→ **涟漪到所有空态**（会话列表/聊天空等）。
- [ ] **剩余屏（app 专属，低收益）**：auth/search/settings/sdklab——SDK 接线的表单/实验屏,保 app;可选把 Avatar/StatusDot 再挑共享。

## 状态：Android 核心消息 UI 已上 kit（verified）
- **消息体 11 类** + **会话行** + **空态** 经 flare-im-design kit 渲染。
- **app 专属 infra 正确保留**：composer 富编辑、媒体播放(VideoView/MediaPlayer)、asset sticker/emoji、richdoc、URL 解析、SDK 消息构建。
- **kit 三处通用完善**（回馈 flare-im-design，已推送）：ImageMessage 弹性尺寸(1791ac3)、VideoMessage posterContent(6889cff)、ConversationRow onLongPress 修死参(8bfb49b)。
- 全程 `:app:compileDebugKotlin` + `:app:testDebugUnitTest` 绿。
- **可复用迁移模式已成型**，供 iOS/Flutter 照搬。
- [ ] **Phase 3 会话列表 + 输入**：`conversationlist/ConversationListView` → kit ConversationRow；`composer/ComposerView` → kit composer parts。compile。
- [ ] **Phase 4 补 kit 缺口**：迁移中发现 kit 缺的组件（按需）补到 android-im-ui，回跑 kit 自身 compile+unittest。
- [ ] **验证**：`:app:compileDebugKotlin` + `:app:testDebugUnitTest` 绿；kit `:compileDebugKotlin`+`:testDebugUnitTest` 绿。
- [ ] 记录迁移模式，供 iOS/Flutter 复用。

## Notes
- 验证态度（用户定）：编译/单测为主，不假设整套后端+模拟器在跑。
- 迁移原则：保 app SDK/ViewModel 接线；只换 UI 叶子渲染层。kit 组件是 props-in/events-out（standalone 已验证）。
