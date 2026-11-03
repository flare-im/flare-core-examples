import { expect, test } from "@playwright/test";

test("dev app keeps the real login and SDK workbench entry flow", async ({ page }) => {
  await page.setViewportSize({ width: 1440, height: 900 });
  await page.goto("/#/chats");

  await expect(page).toHaveURL(/#\/login$/);
  await expect(page.locator(".auth-screen")).toBeVisible();
  await expect(page.getByRole("heading", { name: /欢迎回来|Welcome back/i })).toBeVisible();
  await expect(page.locator(".auth-user-input input")).toBeVisible();
  const connectionSettings = page.getByRole("button", { name: /连接设置|Connection settings/i });
  await expect(connectionSettings).toBeVisible();
  await expect(connectionSettings).toHaveAttribute("aria-expanded", "false");
  await expect(page.getByRole("button", { name: /立即登录|Sign in/i })).toBeVisible();
  await expect(page.getByText("Demo mode", { exact: false })).toHaveCount(0);

  await connectionSettings.click();
  await expect(connectionSettings).toHaveAttribute("aria-expanded", "true");
  await expect(page.locator(".auth-server-fields")).toBeVisible();
  await expect(page.locator(".auth-server-fields input")).toHaveCount(2);
  await expect(page.getByLabel(/WebSocket 网关地址|WebSocket gateway URL/i)).toBeVisible();
  await expect(page.getByLabel(/HTTP 网关地址|HTTP gateway URL/i)).toBeVisible();
  await expect(page.locator("html")).toHaveAttribute("data-flare-brand", "violet");
  await expect.poll(() => page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(true);
});

for (const route of ["conversations", "chat", "sdk-lab"]) {
  test(`${route} remains protected by the real session guard`, async ({ page }) => {
    await page.goto(`/#/${route}`);
    await expect(page).toHaveURL(/#\/login$/);
  });
}

for (const viewport of [
  { width: 375, height: 667 },
  { width: 390, height: 844 },
  { width: 430, height: 932 },
  { width: 768, height: 900 },
  { width: 1024, height: 768 },
  { width: 1280, height: 800 },
  { width: 1440, height: 900 },
  { width: 1920, height: 1080 },
]) {
  test(`login remains usable at ${viewport.width}px`, async ({ page }, testInfo) => {
    await page.setViewportSize(viewport);
    await page.goto("/#/login");

    await expect(page.locator(".auth-screen")).toBeVisible();
    await expect(page.locator(".auth-user-input input")).toBeVisible();
    await expect(page.getByRole("button", { name: /立即登录|Sign in/i })).toBeVisible();
    await page.getByRole("button", { name: /连接设置|Connection settings/i }).click();
    await expect(page.locator(".auth-server-fields input")).toHaveCount(2);
    await expect.poll(() => page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(true);
    await testInfo.attach("login-viewport", { body: await page.screenshot({ fullPage: true }), contentType: "image/png" });
  });
}
