# Flare Core 示例

[English](README.md) · 简体中文

本仓包含 Web、Tauri、Flutter、iOS 和 Android 参考应用。[迁移记录](migration-sources.json)列出了原仓与导入的提交。

## 本地运行

将本仓与 `flare-core-sdk`、`flare-core-sdk-engine` 和 `flare-im-design` 并列检出。按照 [Core 快速开始](https://github.com/flare-im/flare-core-server/blob/main/docs/QUICKSTART.zh-CN.md) 启动本地消息服务。

| 平台 | 应用 |
| --- | --- |
| web | [`apps/flare-core-web-app`](apps/flare-core-web-app) |
| tauri | [`apps/flare-core-tauri-app`](apps/flare-core-tauri-app) |
| flutter | [`apps/flare-core-flutter-app`](apps/flare-core-flutter-app) |
| ios | [`apps/flare-core-ios-app`](apps/flare-core-ios-app) |
| android | [`apps/flare-core-android-app`](apps/flare-core-android-app) |

各端的工具链、配置和构建命令见对应应用的 README。共享行为在同级 SDK 和 UI 仓库维护。
