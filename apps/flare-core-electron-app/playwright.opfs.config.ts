import { defineConfig, devices } from "@playwright/test";

/**
 * 本 app 自己的 e2e 配置，只跑桌面存储（wa-sqlite + OPFS）的认证。
 *
 * 为什么不并进 `playwright.config.ts`：那份的 testDir 指向
 * `../flare-core-web-app/tests/e2e`，是**刻意复用** web app 的整套用例
 * （electron 与 web 共用同一个渲染层）。playwright 的 testDir 只能有一个，
 * 把本 app 的用例塞进去会破坏那份复用关系，所以单独开一份。
 *
 *   npm run test:e2e:opfs
 *
 * 前置：`npx playwright install chromium`。
 */
export default defineConfig({
  testDir: "tests/e2e",
  timeout: 90_000,
  expect: { timeout: 20_000 },
  fullyParallel: false,
  retries: process.env.CI ? 1 : 0,
  reporter: [["list"]],
  use: {
    baseURL: process.env.PLAYWRIGHT_BASE_URL ?? "http://127.0.0.1:1434",
    trace: "retain-on-failure",
  },
  webServer: {
    // 端口与 playwright.config.ts 的 1433 错开，两份配置可以同时跑。
    command: "npm run dev:web -- --port 1434 --strictPort",
    url: "http://127.0.0.1:1434",
    reuseExistingServer: true,
    timeout: 120_000,
  },
  projects: [{ name: "chromium", use: { ...devices["Desktop Chrome"] } }],
});
