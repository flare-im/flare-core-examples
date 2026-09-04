# flare-core-tauri-app

`flare-im-core-sdk/bindings/tauri` 的 **Tauri** 桌面应用模板。Tauri 侧拥有自己的 `src/App.vue`、`src/router.ts`、平台媒体选择、桌面通知和 native transport 配置；IM 工作台页面与业务函数复用 `packages/@flare-im/vue-ui/app`。

## SDK

- Package: `@flare-im/sdk/tauri`（前端 L3/L2 SDK + Tauri L1 adapter）
- Shared types: `@flare-im/sdk`
- Rust L1: `flare-im-core-sdk/bindings/tauri`

## 目录结构

```text
src/
├── App.vue                 # Tauri 宿主 workbench 根组件
├── router.ts               # Tauri 路由表、route guard 和页面注册
├── views/                  # Tauri 本地 route views，组装共享 workbench 组件
├── main.ts                 # Vue mount + Tauri SDK/媒体/传输配置
└── desktopNotifications.ts # Electron/Tauri 分开的桌面通知桥
src-tauri/            # Tauri Rust shell（注册 im_invoke_handler）
tests/                # Tauri renderer/platform smoke tests
```

完整规范见 [`examples/STRUCTURE.md`](../STRUCTURE.md)。

## 开发

客户端不持有签名密钥：只输用户 ID 时，SDK 向 API 网关 `{httpUrl}/api/v1/auth/tokens` 签发接入 token
并在到期前自动刷新（本地联调把网关起成 `FLARE_API_GATEWAY_AUTH_DEV_ISSUE=true`）；也可以在登录页高级区
粘贴业务后端签好的 token（见 `flare-im-core/docs/AUTH-TOKEN-ISSUANCE.zh-CN.md`）。

```bash
cd examples/flare-core-tauri-app
yarn install
yarn typecheck
yarn tauri dev
```

参考实现：`examples/flare-core-flutter-app`、`examples/flare-core-web-app`。
