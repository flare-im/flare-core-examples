import { expect, test } from "@playwright/test";

const variants = [
  { width: 320, height: 720, locale: "zh-CN", theme: "light" },
  { width: 390, height: 844, locale: "zh-CN", theme: "light" },
  { width: 390, height: 420, locale: "en-US", theme: "light" },
  { width: 768, height: 900, locale: "zh-CN", theme: "light" },
  { width: 1024, height: 768, locale: "zh-CN", theme: "light" },
  { width: 1440, height: 900, locale: "zh-CN", theme: "light" },
  { width: 1920, height: 1080, locale: "en-US", theme: "light" },
  { width: 1440, height: 900, locale: "en-US", theme: "dark" },
  { width: 390, height: 844, locale: "zh-CN", theme: "dark" },
];

for (const variant of variants) {
  test(`shared login ${variant.width}x${variant.height} ${variant.locale} ${variant.theme}`, async ({ page }, testInfo) => {
    await page.setViewportSize(variant);
    await page.emulateMedia({ reducedMotion: "reduce" });
    await page.addInitScript(({ locale, theme }) => {
      localStorage.setItem("flare-web-locale", locale);
      localStorage.setItem("flare-web-theme-mode", theme);
    }, variant);
    await page.goto("/#/login");
    const input = page.locator(".auth-user-input input");
    const submit = page.getByRole("button", { name: /立即登录|Sign in/i });
    const settings = page.getByRole("button", { name: /连接设置|Connection settings/i });
    await expect(input).toBeVisible();
    await expect(submit).toBeDisabled();
    await expect(page.locator("html")).toHaveAttribute("data-flare-brand", "violet");
    const visual = page.locator(".auth-brand__visual");
    await expect(page.locator(".auth-screen .message-bubble")).toHaveCount(0);
    if (variant.width >= 900) {
      await expect(visual).toBeVisible();
      await expect.poll(() => visual.locator("img").evaluate((image: HTMLImageElement) => image.complete && image.naturalWidth > 0)).toBe(true);
      const artwork = (await visual.boundingBox())!;
      expect(artwork.width / artwork.height).toBeCloseTo(1.5, 1);
      const brand = (await page.locator(".auth-brand").boundingBox())!;
      const panel = (await page.locator(".auth-panel").boundingBox())!;
      expect(brand.width).toBeCloseTo(variant.width / 2, 0);
      expect(brand.x + brand.width).toBeLessThanOrEqual(panel.x + 1);
    } else {
      await expect(visual).toBeHidden();
    }

    await page.keyboard.press("Tab");
    await expect(input).toBeFocused();
    await input.fill("login-preview-user");
    await expect(submit).toBeEnabled();
    await expect(submit).toHaveAttribute("type", "submit");
    await expect(submit).toHaveCSS("color", "rgb(255, 255, 255)");
    expect(await page.locator(".auth-screen").evaluate(node => getComputedStyle(node).fontFamily)).toContain("sans-serif");
    await page.keyboard.press("Tab");
    await expect(submit).toBeFocused();
    await page.screenshot({ path: testInfo.outputPath("login-ready.png"), fullPage: true });

    await page.keyboard.press("Tab");
    await expect(settings).toBeFocused();
    await page.keyboard.press("Space");
    await expect(settings).toHaveAttribute("aria-expanded", "true");
    await expect(page.locator(".auth-server-fields input")).toHaveCount(2);
    await page.keyboard.press("Tab");
    const ws = page.getByLabel(/WebSocket 网关地址|WebSocket gateway URL/);
    await expect(ws).toBeFocused();
    await ws.fill(`wss://gateway.example/${"long-path/".repeat(12)}ws`);
    await page.screenshot({ path: testInfo.outputPath("login-settings.png"), fullPage: true });

    await expect.poll(() => page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
    const layout = await page.locator(".auth-panel__scroll").evaluate(node => {
      const panel = node.getBoundingClientRect();
      const controls = [...node.querySelectorAll(".n-input, button, .auth-footnote")].map(el => {
        const rect = el.getBoundingClientRect();
        return { x: rect.x, right: rect.right, height: rect.height };
      });
      return { width: panel.width, controls };
    });
    expect(layout.width).toBeLessThanOrEqual(400);
    for (const control of layout.controls) {
      expect(control.x).toBeGreaterThanOrEqual(0);
      expect(control.right).toBeLessThanOrEqual(variant.width);
    }
    expect((await submit.boundingBox())!.height).toBeGreaterThanOrEqual(44);
    expect((await settings.boundingBox())!.height).toBeGreaterThanOrEqual(44);

    await settings.click();
    await expect(settings).toHaveAttribute("aria-expanded", "false");
    await settings.click();
    await expect(ws).toHaveValue(`wss://gateway.example/${"long-path/".repeat(12)}ws`);
  });
}
