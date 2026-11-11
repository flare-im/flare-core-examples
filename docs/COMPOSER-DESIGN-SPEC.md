# 消息输入框（Composer）跨平台设计规范

**基准平台：Flutter**（`flare-core-flutter-app/lib/interface/widgets/composer/`）。
其他平台（iOS / Android / Vue web+tauri）的消息输入框移动端**布局与排版**以本规范为准对齐。
本规范只约束 composer 栏的视觉结构/排版/token，不改变各平台已有的行为（表情面板、媒体选择、录音、构建菜单等照旧映射到现有 handler）。

## 设计 token（来自 Flutter `FlareThemeTokens`）

| 语义 | Light | Dark | 用途 |
|---|---|---|---|
| primary（强调/选中） | `#7C3AED` | `#9D6BFF` | 选中态图标、品牌色 |
| bgPrimary（输入框底） | `#FFFFFF` | `#1A1D23` | 文本输入框背景 |
| bgSecondary（栏底） | `#F5F6F8` | `#111318` | 整个 composer 栏背景 |
| textPrimary | `#111318` | `#FFFFFF` | 输入文本 |
| textSecondary | `#6B7280` | `#A6A6A6` | 占位符、工具栏图标 |
| borderSecondary | `#EEF0F4` | `#2F3440` | 顶边框、工具栏分隔线 |
| composerToolbarIcon | `#6B7280` | — | 工具栏图标默认色（= textSecondary） |

各平台已有等价 token（直接复用，不要新增魔法值）：
- Android `FlareTheme`: brand≈primary、surface=bgPrimary、background≈bgSecondary、textPrimary、textSecondary≈toolbarIcon、hairline≈borderSecondary、radiusSmall(6dp)、type.body(15sp/21)。
- iOS `FlareDesign`: 对应 surface / surfaceAlt / textPrimary / textSecondary / Radius / Spacing。
- Vue: CSS 变量 token（scoped）。

## 布局结构（移动端，两行）

```
┌───────────────────────────────────────────────┐  ← 栏：bgSecondary，顶部圆角 16，
│  [回复条 ComposerReplyStrip]（仅回复时）          │     顶部 1px borderSecondary，elevation/阴影 8/0.06，
│                                                 │     SafeArea(bottom)，padding LTRB(8, 10[回复时8], 8, 4)
│  ┌─────────────────────────────────────────┐    │
│  │ 输入框（bgPrimary 白底，圆角 6，无描边）       │    │  ← 第 1 行：文本输入
│  │ 文本 15/行高1.45 textPrimary；             │    │     contentPadding H8 V7，minLines1 maxLines5
│  │ 占位 textSecondary@0.75；                  │    │     发送 = IME 发送键 / 回车（无独立发送按钮）
│  │ 可选右侧「展开」suffix（open_in_full 18）      │    │
│  └─────────────────────────────────────────┘    │
│  [富文本格式条]（仅富文本开启时）                    │
│  (间距 8)                                        │
│  ┌─────────────────────────────────────────┐    │  ← 第 2 行：工具栏
│  │  😀    @     🎙     🖼     A     ＋        │    │     顶部 0.5px borderSecondary@0.95，padding-top 4
│  └─────────────────────────────────────────┘    │     6 个均分(weight 1/Expanded)图标，命中区 44×44，
│  [更多功能宫格]（仅展开时）                          │     图标 24，色 composerToolbarIcon（选中→primary，禁用→@0.38）
└───────────────────────────────────────────────┘
```

### 工具栏图标（Flutter 基准顺序与图标）
1. 表情/贴纸 — `emoji_emotions_outlined`
2. @提及 — `alternate_email`（向光标插入 `@`）
3. 语音 — `mic_none_outlined`（录音中→停止图标，色 danger）
4. 图片 — `image_outlined`
5. 富文本 — `text_fields_rounded`（开关，选中→primary）
6. 更多 — `add_outlined`（展开时→`close_outlined`）

各平台按**自身已有能力**填充这 6 槽；缺失的能力（如 Android 暂无富文本）保留布局位或替换为该平台已有动作，**保持两行结构与均分图标工具栏的视觉一致**，不强行造无效图标。

## 排版要点
- 输入文本：15 / 行高 1.45（Android body 15sp/21 已对齐；iOS `.body`；Vue `font-size:15px;line-height:1.45`）。
- 占位符：textSecondary，0.75 不透明度。
- 工具栏图标：单色描边 24，色 composerToolbarIcon；选中 primary；禁用 0.38。
- 圆角：输入框 6，栏顶 16。
- 间距：栏内 padding 8；输入与工具栏之间 8；4pt 网格。

## 不做的事
- 不引入与 Flutter 不一致的内联圆形发送按钮（移动端发送走 IME 发送键/回车）。
- 不用彩色 emoji 字形替代单色矢量图标（应使用各平台矢量图标库）。
- 不改变各按钮原有行为/handler，只重排版式。
