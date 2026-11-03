# Flutter 示例应用 — UI 与业务对齐说明

本示例与 `flare-core-web-app`、`packages/@flare-im/vue-ui` 共享同一套 **产品交互契约**（见 `.agents/skills/sdk-example-app-development`）。

## 分层

| 层 | 职责 |
|----|------|
| `application/` | Riverpod 状态、SDK 事件桥、`ImOutboundFacade` 编排 |
| `domain/` | 会话/消息实体、`ConversationFilter` 等业务值对象 |
| `infrastructure/` | `flare_core_flutter_sdk` 适配、`listConversationsByQuery` |
| `interface/` | 页面、Composer、气泡、筛选条 |
| `shared/i18n/` | 中英双语（键与 Vue `flareMessages` 对齐） |

## 会话工作台

- **筛选**：全部 / 未读 / @我 / 置顶 / 免打扰 / 归档 / 草稿；归档走 `listConversationsIncludingArchived`，其余走 `ConversationListQuery`。
- **搜索**：列表内本地关键词过滤（与 Web 服务端 debounce 搜索可后续对齐）。
- **状态条**：`SdkRuntimeStatus` + 连接事件，展示同步/重连/失败。
- **空态**：区分无会话、搜索无结果、同步中、失败。

## 聊天页

- 消息时间线 + `MessageComposer`（文本/表情/贴纸/媒体/位置/业务消息构建器）。
- 连接条仅在非 `connected` 时展示（与 Tauri 一致）。
- 多选、引用回复、长按菜单、送达/已读态。

## 国际化

- `flareLocaleProvider` + `flareMessagesProvider`，持久化到 `SharedPreferences`。
- 入口：会话列表「更多」→ 切换 简体中文 / English。

## SDK 包边界

`flare_core_flutter_sdk` 仅做 **契约化 FFI 适配**，不含 IM 业务 UI。示例应用的 IM 界面全部在 `examples/flare-core-flutter-app/lib/interface/`。

## 消息搜索

- 全局：`/search`（更多菜单 → 搜索消息）
- 会话内：`/chat/:id/search`（聊天页更多 → 搜索消息）
- SDK：`searchMessagesByQuery` / `searchMessagesInConversation`

## 会话详情

- 手机：聊天页更多 → 会话详情（底部 Sheet）
- 宽屏：`WorkbenchShell` 第三栏（`workbenchDetailsOpenProvider`）
- 操作：同步、已读/未读、置顶、免打扰、归档、清空本地、删除

## 设置

- 路由：`/settings`
- 语言（zh-CN / en-US）、主题（跟随系统 / 浅色 / 深色）

## 平板分栏

- 断点：`900px`（`kWorkbenchWideBreakpoint`）
- `ShellRoute` + `WorkbenchShell`：列表 360px + 聊天区 + 可选详情 320px
- 窄屏仍为单页 push 栈

## 验证清单

1. 登录 → 会话列表 → 打开单聊 → 发送文本/图片。
2. 切换各会话筛选 chip，确认列表与 SDK 查询一致。
3. 切换语言，确认标题/空态/筛选文案更新。
4. `/search` 与聊天内搜索返回结果并可跳转会话。
5. 会话详情各项操作后列表/聊天状态正确。
6. `/settings` 切换主题与语言。
7. 宽屏（≥900px）验证三栏布局；窄屏验证 push 导航。
8. `/sdk-lab` 查看 diagnostics / 能力 / 媒体 / 事件。
