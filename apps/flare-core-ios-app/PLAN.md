# flare-core-ios-app 优化计划

## Goal
在不破坏现有 MVVM 架构与示例行为的前提下，完成四项优化并保持 sim 可构建、测试通过：
1. **国际化**：引入 String Catalog（`Localizable.xcstrings`），清理全部中英文混写硬编码文案（en + zh-Hans 双基线）。
2. **平台服务收敛**：把散落在 12 个 Messaging 文件中的 `#if canImport(UIKit)/(AppKit)`（剪贴板/图片解码/录音/触感）抽到 `Core/Platform/`，视图层回到纯 SwiftUI 无条件编译。
3. **MessagingViewModel 瘦身**：抽出 `MessageBuilder`（payload 解析 + 消息构建）到 Core/Domain，VM 从 789 行降到 ~450。
4. **目录与设计系统**：Messaging 内部按子域分目录；`FlareDesign` 补 Spacing/Typography/Radius token。

"done" = 全部 4 项落地 + `xcodebuild ... build` 成功 + 现有测试（7/7）通过 + 无新增硬编码文案。

## Constraints & decisions
- 视图层**已经是 100% SwiftUI**，不要引入 UIViewRepresentable；`import UIKit/AppKit` 仅平台服务，目标是收敛而非消除。
- deploy target 当前 iOS 16 / macOS 13。**不抬高到 iOS 17**，因此保持 `ObservableObject`，不迁 `@Observable`（已评估，列为非目标）。
- 这些 example 是**生产级参考种子**（下游会照抄），所以文案规范、设计 token 完整性很重要。
- 架构骨架（App 组合根 / Core / Features MVVM）已重构完成，**保留不动**。
- `MessagingViewModel` 列表态与聊天态记忆中标注 interdependent——本轮**不强行拆 VM**，只抽领域逻辑（MessageBuilder）；VM 拆分留作后续可选项。
- 改动需保持跨平台（iOS + macOS）条件编译正确；`Core/Platform/` 是唯一允许出现 `#if canImport` 的地方。
- 构建依赖：JDK 无关；需先 `scripts/sync_ffi.sh` 再 `xcodegen generate`，sim 构建用 `xcodebuild -project FlareImApp.xcodeproj -scheme FlareImApp -destination 'platform=iOS Simulator,name=iPhone 17' build`。

## Status: ✅ ALL DONE (P0–P4)
Current focus: 全部完成。最终验证：swift build ✅ / 32 tests 4 skip ✅ / iOS sim BUILD SUCCEEDED ✅。

### P4 — 全面落地 MVVM  ✅ DONE
- [x] `Core/Session/AppLifecycle.swift`：`@MainActor protocol AppLifecycle: AnyObject { login/logout/dispose }`；`FlareAppStore` 实现；VM 经 `weak var lifecycle` + `bind(lifecycle:)`（init 后回填）破强引用环。
- [x] `AuthViewModel`：`validationMessage`@Published + `draftBinding(\.)` + visible/secondaryServerAddress 绑定 + `isBusy/lastError/canLogin` + `submit()`。LoginView 只依赖它（删除 store/environment/@State validationMessage）。
- [x] `SettingsViewModel`：themeChoice/draftBinding + currentUserId/connectionState/runtimeStatus + refreshDiagnostics/logout/dispose。SettingsView 只依赖它。
- [x] 现有 VM 暴露只读态 + 动作：`MessagingViewModel`(allConversations/currentUserId/runtimeStatus/lastError + logout)；`SdkLabViewModel`(eventLog/labResults/runtimeStatus/coverageRows【从 store 迁入】 + logout/dispose)。
- [x] 收口所有视图 store 直读：SdkLabView 去 10 个 store env-object；Messaging 五视图全去 store（searchViewModel 改注入 `@EnvironmentObject search`）；Shell 三子视图去 store。
- [x] 装配：FlareAppStore 新建 auth/settings VM；root 注入 auth/settings/search 三个 environmentObject。
- [x] Shell(RootWorkbenchView)：仅保留顶层路由 `store.isLoggedIn`（coordinator-level 合理例外，唯一残留）。
- [x] 校验：**6 处 `store.(login|logout|dispose)` 直接调用 → 0**；全仓视图 `store.*` 仅剩 1 处(isLoggedIn)；swift build + 32 tests + iOS sim 全绿。
注意：perl 替换中 `\(` 会丢反斜杠、`$var`/`$0` 会被当 perl 变量吞掉 —— 已修复 8 处。后续若再用 perl 改插值/绑定，务必 `\\(` 和 `\$`。
P0 验证结果：`swift build` ✅ + `swift test` 30 passed / 4 skipped(需 FFI dylib) ✅ + iOS sim `xcodebuild` BUILD SUCCEEDED ✅，catalog 编译进 `FlareImExampleApp.app/{en,zh-Hans}.lproj/`（含 stringsdict 复数）。

## i18n 关键决策（盘点后新增，影响实现方式）
- **现状是三套并存**：(1) `AppModels.PreviewCopy` 手搓 `isChinese ? 中:英` 运行时判断（绕过系统本地化，15 标签）；(2) `AppModels` 枚举 + `FlareFormatters` 纯中文硬编码（Core 层返回 String）；(3) 视图层中英混写硬编码。三套都要统一到 String Catalog。
- **SPM 约束**：视图在 library target `FlareImApp`，SwiftUI `Text("k")` 默认查 `Bundle.main`，**找不到 library catalog**。必须：(a) `Package.swift` 加 `defaultLocalization: "en"`；(b) `Localizable.xcstrings` 作为 target resource；(c) 所有本地化点显式走 `.module` bundle。
- **Key 策略**：采用 **Apple 默认的"英文字面量即 key"**（开发语言=en），zh-Hans 译文放 catalog。理由：抽取最省、风险最低、对生产种子最惯用。
- **方案修正（更优）**：把 `Localizable.xcstrings` 放进 **app runner target**（`Sources/FlareImAppRunner/`）→ 编译进 `Bundle.main`。这样 SwiftUI `Text("...")` 与 `String(localized:)` **默认就查 Bundle.main，自动解析，无需 `.module`、无需 helper**。代码改动塌缩为"仅替换中文硬编码点"。
  - Package.swift：加 `defaultLocalization: "en"` + executableTarget 加 `resources: [.process("Localizable.xcstrings")]`（避免 `swift build` 报 unknown resource）。
  - 英文字面量调用点：**零改动**（字面量已是 key）。
  - 中文视图字面量：替换为英文 key 文案。
  - 模型层中文 `return "中文"`：改 `String(localized: "English key")`。
- **删除** `PreviewCopy.isChinese` 整套三元，替换为 `String(localized:)`。
- 测试/`swift build` 下 Bundle.main 无 catalog → 回退显示英文 key，可接受。
- **范围确认（用户拍板：务实范围）**：实际中文字面量约 200 处（远超首次 35 处估计）。覆盖深度 = **仅用户可见 UI 文案**：Text/Button/Label/Picker/DatePicker label/navigationTitle/空状态/状态文字/表单字段名/校验与错误提示/指令型 placeholder（"请输入X"/"输入X"）。**保留不动**：示例值 placeholder（"例如：…"、"video-id"、坐标、url）、消息 payload 内容默认值（markdown 脚手架 "## 标题"、"回复 \(text)"、"语音消息" description、"转发消息" 等）。
- **String vs LocalizedStringKey**：所有自定义 helper（EmptyStateView/inputField/MessageQuickAction/ActionRow/MobileSectionContainer/ComposerTool 等）的 title/message 都是 `String` 类型 → `Text(stringVar)` 不本地化 → 这些调用点必须包 `String(localized:)`，不能仅换字面量。SwiftUI 原生控件（Text/Button/Label/TextField/Picker/DatePicker 的 label 参数）取 LocalizedStringKey → 直接换字面量即可。
- **EmojiLabels.label(for:locale:)** 已是 locale 感知的 zh/en 数据查表（非 UI chrome）→ 有意保留不改。

## Steps

### P0 — 国际化（优先，独立、低风险、价值最高）
- [x] **盘点全部 UI 文案** — 完成。三套并存（见上方"i18n 关键决策"），清单见下方 Notes。
- [x] **基础设施** — `Package.swift` 加 `defaultLocalization: "en"` + executableTarget `resources:`；catalog 落 `Sources/FlareImAppRunner/Localizable.xcstrings`（→ Bundle.main，免 helper）。
- [x] 模型层改造：`AppModels` 枚举标签 + 传输地址 label + `FlareFormatters` 错误 + 删除 `PreviewCopy.isChinese` → 全部 `String(localized:)`。
- [x] 视图层改造：13 个文件全部完成（LoginView/RootWorkbenchView/ComposerForms/ComposerControls/ComposerView/ChatSearchSheet/MediaPreviewSheet/MessageMediaViews/MessageRichViews/ComposerAudioRecorder/ChatView/MessageBubbleViews/ConversationListView/MessageRowViews）。
- [x] 复数/插值文案：`%lld reactions`、`%lld chats · %lld pinned · %@`、`%lld messages failed...` → catalog stringsdict。
- [x] catalog 232 key，全部 zh-Hans 译文填好；JSON 校验通过。
- [x] 校验：剩余中文仅 = 占位示例 + payload 内容 + emoji 数据（务实范围内有意保留）；测试断言已同步更新（中文→英文 key 4 处）。
- [ ] （可选）sim 真机运行 + 切 zh 截图，肉眼确认双语渲染。

### P1 — 平台服务收敛到 Core/Platform/  ✅ DONE
- [x] 新建 3 个 Platform 文件：`PlatformImage.swift`（`Image(localFileURL:)` + `platformImageSize`）、`PlatformClipboard.swift`、`PlatformAudioSession.swift`（activate/deactivate/requestMicrophonePermission，macOS no-op）。
- [x] 替换内联条件编译：`MessageBubbleViews`/`MessageMediaViews`/`EmojiPresentation` 图片加载 → `Image(localFileURL:)`；`MessagingMediaUtilities` 图片尺寸 → 移入 Platform；`MessageRowViews` 剪贴板 enum → 移入 Platform。
- [x] `ComposerAudioRecorder` 4 处 `#if os(iOS)` AVAudioSession → `PlatformAudioSession` 调用，文件内无条件编译。
- [x] 清理 12 个 Messaging 文件顶部死 import 样板（UTType 全仓未用 / UIKit·AppKit 已无符号引用 / PhotosUI 仅 ComposerView 用）。
- [x] 结果：全仓 `#if canImport` 仅剩 ComposerView 的 PhotosUI 门控（6 处，按设计保留）+ Core/Platform/ 3 文件。从 ~50 行散落条件编译塌缩到中心化。校验：swift build ✅ / 31 tests 4 skip ✅ / iOS sim ✅。

### P1 — MessagingViewModel 瘦身（抽 MessageBuilder）  ✅ DONE
- [x] 新建 `Core/Domain/MessageBuilder.swift`（state-free `enum`）：迁移 `buildCoreMessage`(→`build`)、`make{Image,Video,Audio}BuildRequest`、`mediaSourceInfo`、`sendableMap`、`richDocJson` + 全部 `payload*` 取值器。`selectedMessages`(forward/quote 默认值)改为显式入参；`unavailable()` → 直接 `throw AppStoreError`。
- [x] `MessagingViewModel` 调用 `MessageBuilder.build(...)`，删除迁出代码：**789 → 417 行**（-372）。
- [x] 测试 3 处 `MessagingViewModel.make*BuildRequest` → `MessageBuilder.make*`。
- [x] 校验：swift build ✅ / 31 tests 4 skip ✅（image/video/audio build 测试直接覆盖迁出方法）/ iOS sim ✅。
- 注意：`BuildRichDocMessageRequest` 无 `markdown:` 参数；真实顺序 `…contentSchema, plainText, inputFormat, inputFormatVersion, sourcePayload, title, searchText`，`markdown` 局部变量喂给 `sourcePayload:["markdown": markdown]`（重建值，richDoc 无单测覆盖）。

### P2 — 目录整理（纯移动，零行为变更）  ✅ DONE
- [x] Messaging 内部按子域建目录：`ConversationList/` `Chat/` `MessageRow/`(4 文件) `Composer/`(4) `Media/`(3 含 EmojiPresentation)，`MessagingViewModel.swift` 留根。
- [x] SwiftPM 递归 glob 无需改路径；xcodegen 重新生成。校验：swift build ✅ / iOS sim ✅。

### P3 — 设计系统补全  ✅ DONE
- [x] `FlareDesign` 增补 `Radius`(small/medium/large/pill)、`Spacing`(xxs..xxl, 4pt 基准)、`Typography`(largeTitle..captionStrong) token 组；`radius` 保留为 `Radius.medium` 别名（向后兼容）。
- [x] 等值示范替换（零视觉变更）：`FlarePanel` → `Radius.medium`；会话列表标题 → `Typography.largeTitle`。
- [x] **全面推广 token 到 15 个视图**（Python 脚本，按上下文消歧，仅替换数值完全一致项 → 零视觉变更）：147 处替换 = Spacing 134 + Radius 10 + Typography 7。
- [x] 校验：swift build ✅ / 32 tests ✅ / iOS sim ✅。
- [x] **重定标 / snap-to-scale（已获用户批准的视觉微调）**：归并 ad-hoc 取值。Radius 4 档 `small6/medium8/large12/xl16`（旧 large16→xl，snap 7→small、9/10→medium、14→large）；Spacing 7 档 4pt 网格 `xxs2/xs4/sm8/md12/lg16/xl20/xxl24`（xl 22→20、xxl 32→24，off-scale 按就近 round-half-up 归并）。193 处替换 / 17 文件，确定性映射（脚本）。
- 最终：**cornerRadius 100% token 化（33 处，0 raw 字面量）**；Spacing 303 处 token；仅留 `spacing: 0`(18×，惯用) + 4 个 bespoke 大布局值(28/30/42/66) 为字面量（有意）。属±1–2px 视觉微调（用户已批准）。校验 32 tests ✅ / iOS sim ✅。

## Notes / open questions
- 已确认现状（2026-06-27 分析）：
  - i18n 基础设施 = 0（无 NSLocalizedString / String(localized) / .xcstrings / .strings）。
  - `Text("...")` 字面量 35 处 + navigationTitle/Button/Label 若干；中英文混写（如 `"Appearance"` 与 `"ID 由管理员分配，可在邀请邮件中查看"`、`"\(count) 个回应"` 并存）。
  - UIKit/AppKit 仅 12 个 Messaging 文件，用途：`UIPasteboard`/`NSPasteboard`、`UIImage`/`NSImage`、`AVAudioSession`/`AVAudioRecorder`。
  - 大文件：`ConversationListView` 791、`MessagingViewModel` 789、`ComposerView` 537、`SdkLabView` 425。
- **文案清单（盘点结果）**：
  - 视图层 `Text` 字面量 35 处；`Button/Label/TextField/Toggle` ~70 处；遍布 Auth/Settings/SdkLab/Search/Shell/Messaging。
  - 中文硬编码视图：LoginView、ChatSearchSheet、ComposerControls/Forms/View、MessageBubble/RowViews、MediaPreviewSheet、ConversationListView 大部分。
  - 英文硬编码视图：SettingsView、SdkLabView（按钮/TextField）、SearchView、ConversationListView 部分(`Sync`/`Mark unread`/`Clear local`/`FLARE CORE`)。
  - Core 层中文：`AppModels.swift`(TabKind L15-18、ConversationFilter L127-133、ChatType L146-147、transport hints L220-247、emoji labels L813-814、`PreviewCopy` L823-847)、`FlareFormatters.swift` L32 错误文案。
  - `PreviewCopy.isChinese`（L824）是要删除的手搓本地化反模式。
- 构建/测试命令记录（首次跑通后回填确切 destination 名称与耗时）。
- 每完成一步：勾选 + 回填结果，并更新 Status / Current focus。
