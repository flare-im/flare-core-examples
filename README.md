# Flare Core Examples

This repository hosts local cross-platform integration. See [demos/README.md](demos/README.md) for standalone exports and [Core demo downloads](https://github.com/flare-im/flare-core-sdk/tree/dev/examples) for the public entry points.

English · [Simplified Chinese](README.zh-CN.md)

Reference applications for Web, Tauri, Flutter, iOS, and Android, plus Electron, React Native, uni-app, ArkTS and Cangjie scaffolds. Complete apps live only in this repository.

## Setup

Clone `flare-core-sdk`, `flare-core-sdk-engine`, and `flare-im-design` alongside this repository. Follow the [Core server quickstart](https://github.com/flare-im/flare-core-server/blob/main/docs/QUICKSTART.md) for the local messaging endpoint.

| Platform | App |
| --- | --- |
| web | [`apps/flare-core-web-app`](apps/flare-core-web-app) |
| tauri | [`apps/flare-core-tauri-app`](apps/flare-core-tauri-app) |
| flutter | [`apps/flare-core-flutter-app`](apps/flare-core-flutter-app) |
| ios | [`apps/flare-core-ios-app`](apps/flare-core-ios-app) |
| android | [`apps/flare-core-android-app`](apps/flare-core-android-app) |

Follow each app’s README for platform tooling, local configuration, and build commands. Shared behavior lives in the sibling SDK and UI repositories.

## Additional platform scaffolds

| Platform | App |
| --- | --- |
| Electron | [`apps/flare-core-electron-app`](apps/flare-core-electron-app) |
| React Native | [`apps/flare-core-rn-app`](apps/flare-core-rn-app) |
| uni-app | [`apps/flare-core-uni-app`](apps/flare-core-uni-app) |
| HarmonyOS ArkTS | [`apps/flare-core-arkts-app`](apps/flare-core-arkts-app) |
| HarmonyOS Cangjie | [`apps/flare-core-cangjie-app`](apps/flare-core-cangjie-app) |

These retain their platform-specific scaffolding maturity; moving them does not
make them equivalent to the five reference applications. Vue application
composition lives in `shared/vue-reference`; reusable UI comes from
`flare-im-design`, and SDK runtime behavior stays in `flare-core-sdk` and its engine.
See [structure](docs/STRUCTURE.md) and [capability coverage](docs/CAPABILITY-PARITY.md).
The scaffold generator is `scripts/scaffold_platform_apps.sh`.
