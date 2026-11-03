import { defineConfig, devices } from "@playwright/test";

// 忠实验证「前台恢复自愈」专用配置：直接打 PLAYWRIGHT_BASE_URL 指向的已部署 web app
//（真实 WASM 产物），不起本地 dev server。用 routeWebSocket 造半开死连，再触发 visibility→visible。
// 目标地址必须显式给出，这套用例从不默认指向任何线上环境。
const baseURL = process.env.PLAYWRIGHT_BASE_URL;
if (!baseURL) {
  throw new Error(
    "PLAYWRIGHT_BASE_URL is required for the selfheal suite, e.g. PLAYWRIGHT_BASE_URL=http://localhost:1430",
  );
}

export default defineConfig({
  testDir: "./tests/e2e-selfheal",
  timeout: 180_000,
  expect: { timeout: 30_000 },
  fullyParallel: false,
  retries: 0,
  reporter: [["list"]],
  use: {
    baseURL,
    trace: "retain-on-failure",
  },
  projects: [{ name: "chromium", use: { ...devices["Desktop Chrome"] } }],
});
