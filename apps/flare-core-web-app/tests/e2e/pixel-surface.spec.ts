import { expect, test, type Browser, type Page, type TestInfo } from "@playwright/test";

test.skip(process.env.FLARE_REAL_SERVICE !== "1", "Requires the explicitly selected development service");

async function login(browser: Browser, id: string) {
  const context = await browser.newContext({ viewport: { width: 1440, height: 900 }, reducedMotion: "reduce" });
  const page = await context.newPage();
  await page.goto("/#/login");
  await page.getByRole("button", { name: /连接设置|Connection settings/i }).click();
  if (process.env.FLARE_TEST_WS_URL) {
    await page.getByLabel(/WebSocket 网关地址|WebSocket gateway URL/i).fill(process.env.FLARE_TEST_WS_URL);
  }
  if (process.env.FLARE_TEST_HTTP_URL) {
    await page.getByLabel(/HTTP 网关地址|HTTP gateway URL/i).fill(process.env.FLARE_TEST_HTTP_URL);
  }
  await page.getByPlaceholder(/请输入用户 ID|Enter user ID/i).fill(id);
  await page.getByRole("button", { name: /立即登录|Log in|Sign in/i }).click();
  await expect(page).toHaveURL(/#\/conversations/, { timeout: 60_000 });
  return { context, page };
}

async function send(page: Page, text: string) {
  await page.locator(".composer-input textarea").fill(text);
  await page.getByRole("button", { name: /^(发送|Send)$/ }).click();
  await expect(page.locator(".composer-input textarea")).toHaveValue("");
  await expect(page.locator(".message-row--self").filter({ hasText: text }).locator(".message-status--sent, .message-status--delivered, .message-status--read")).toBeVisible({ timeout: 45_000 });
}

async function expectStableLayout(page: Page, testInfo: TestInfo, state: string) {
  const samples = await page.evaluate(async () => {
    const rows: number[][] = [];
    for (let index = 0; index < 180; index += 1) {
      await new Promise<void>(resolve => requestAnimationFrame(() => resolve()));
      const composer = document.querySelector('.composer-studio')!.getBoundingClientRect();
      const list = document.querySelector('.message-list')!;
      const last = document.querySelector('.message-row:last-of-type .message-bubble')!.getBoundingClientRect();
      rows.push([composer.y, composer.height, list.clientHeight, list.scrollTop, list.scrollHeight, last.y, last.height]);
    }
    return rows;
  });
  await testInfo.attach(`${state}-layout-samples`, { body: JSON.stringify(samples), contentType: "application/json" });
  // Expansion and new-message entrance can move once; settled frames must stay still.
  const settled = samples.slice(90);
  for (let column = 0; column < settled[0].length; column += 1) {
    const values = settled.map(row => row[column]);
    expect(Math.max(...values) - Math.min(...values), `${state} layout column ${column}`).toBeLessThan(0.1);
  }
}

test("real SDK conversation uses the shared composer across desktop and H5", async ({ browser }, testInfo) => {
  test.setTimeout(180_000);
  const stamp = Date.now();
  const alice = await login(browser, `pw-pixel-a-${stamp}`);
  const bob = await login(browser, `pw-pixel-b-${stamp}`);
  try {
    const page = alice.page;
    await page.getByRole("button", { name: /新建会话|New conversation/i }).first().click();
    const dialog = page.getByRole("dialog").last();
    await dialog.getByRole("textbox").first().fill(`pw-pixel-b-${stamp}`);
    await dialog.getByRole("button", { name: /^(打开|Open)$/ }).click();
    await expect(page).toHaveURL(/#\/chat/, { timeout: 60_000 });

    const outgoing = `Surface verification ${stamp}`;
    const incoming = `Received and reviewed ${stamp}`;
    await send(page, outgoing);
    await expect(bob.page.getByText(outgoing).first()).toBeVisible({ timeout: 45_000 });
    await bob.page.getByText(outgoing).first().click();
    await expect(bob.page).toHaveURL(/#\/chat/);
    await send(bob.page, incoming);
    await expect(page.getByText(incoming).last()).toBeVisible({ timeout: 45_000 });
    await expect(page.locator('.message-row--self .message-status--read').first()).toBeVisible();

    for (const width of [1920, 1440, 1024, 768, 390]) {
      await page.setViewportSize({ width, height: width === 390 ? 844 : 900 });
      const field = page.locator('[data-flare-surface-owner="composer"]');
      await expect(field).toBeVisible();
      await expect.poll(() => page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
      const geometry = await field.evaluate((node) => {
        const rect = node.getBoundingClientRect();
        const toolbar = node.querySelector(".composer-toolbar")!.getBoundingClientRect();
        return {
          height: rect.height,
          inside: toolbar.left >= rect.left && toolbar.right <= rect.right + 1 && toolbar.bottom <= rect.bottom + 1,
          fits: rect.left >= 0 && rect.right <= innerWidth && rect.bottom <= innerHeight,
        };
      });
      expect(geometry.inside).toBe(true);
      expect(geometry.fits).toBe(true);
      expect(geometry.height).toBeLessThan(140);
      const messageEdges = await page.locator(".message-list").evaluate(list => {
        const rect = list.getBoundingClientRect();
        const content = list.querySelector(".message-list-content")!.getBoundingClientRect();
        const outgoing = list.querySelector(".message-row--self .message-bubble")!.getBoundingClientRect();
        return {
          contentWidth: content.width,
          viewportWidth: list.clientWidth,
          rightGap: rect.left + list.clientLeft + list.clientWidth - outgoing.right,
          overflow: list.scrollWidth - list.clientWidth,
        };
      });
      expect(messageEdges.contentWidth).toBeCloseTo(messageEdges.viewportWidth, 0);
      expect(messageEdges.rightGap).toBeGreaterThanOrEqual(7);
      expect(messageEdges.rightGap).toBeLessThanOrEqual(24);
      expect(messageEdges.overflow).toBeLessThanOrEqual(1);
      await page.screenshot({ path: testInfo.outputPath(`web-app-${width}.png`), animations: "disabled" });
    }

    await page.setViewportSize({ width: 390, height: 420 });
    await page.locator('.composer-input textarea').focus();
    const keyboardField = await page.locator('[data-flare-surface-owner="composer"]').boundingBox();
    expect(keyboardField!.y + keyboardField!.height).toBeLessThanOrEqual(420);
    await page.screenshot({ path: testInfo.outputPath('web-app-keyboard-viewport.png'), animations: 'disabled' });

    await page.setViewportSize({ width: 1440, height: 900 });
    await page.locator('.flare-conversation-header').getByRole('button', { name: '搜索消息', exact: true }).click();
    const search = page.locator('.chat-search-panel');
    await search.getByRole('searchbox').fill('Surface verification');
    await search.getByRole('searchbox').press('Enter');
    await expect(search.getByText(outgoing, { exact: true })).toBeVisible();
    await search.getByText(outgoing, { exact: true }).click();
    await expect(search).toBeHidden();

    const textarea = page.locator(".composer-input textarea");
    await textarea.fill(Array.from({ length: 14 }, (_, index) => `Draft line ${index + 1}`).join("\n"));
    await expect.poll(() => textarea.evaluate(node => node.scrollHeight > node.clientHeight)).toBe(true);
    expect((await textarea.boundingBox())!.height).toBeLessThanOrEqual(145);
    await page.screenshot({ path: testInfo.outputPath("web-app-multiline.png") });
    await textarea.fill("");

    await page.getByRole("button", { name: /^富文本$|^Rich text$/i }).click();
    const heading = page.locator(".composer-heading-select");
    await expect(heading).toBeVisible();
    await expect(heading.locator('option')).toHaveText(['P', 'H1', 'H2', 'H3', 'H4', 'H5', 'H6']);
    await heading.selectOption("2");
    await page.screenshot({ path: testInfo.outputPath("web-app-rich-text.png") });
    await page.getByRole("button", { name: /^富文本$|^Rich text$/i }).click();

    const transfer = await page.evaluateHandle(() => {
      const data = new DataTransfer();
      data.items.add(new File(["Surface verification attachment"], "surface-review.txt", { type: "text/plain" }));
      return data;
    });
    await page.locator(".composer-studio").dispatchEvent("drop", { dataTransfer: transfer });
    const preview = page.locator(".media-composer-preview");
    await expect(preview).toBeVisible();
    await expect(preview.getByText("surface-review.txt")).toBeVisible();
    await page.screenshot({ path: testInfo.outputPath("web-app-attachment-preview.png") });
    await preview.getByRole("button", { name: /^(取消|Cancel)$/ }).click();
    await expect(preview).toBeHidden();
    await transfer.dispose();

    await page.emulateMedia({ reducedMotion: "no-preference" });
    for (let index = 0; index < 5; index += 1) {
      await send(page, `Layout stability ${index}: ${"A long conversation keeps its scroll position while composing. ".repeat(12)}`);
    }
    await page.getByRole("button", { name: "展开输入", exact: true }).click();
    await expectStableLayout(page, testInfo, "expanded");
    await page.screenshot({ path: testInfo.outputPath("web-app-expanded-stability.png") });
    const list = page.locator(".message-list");
    expect(await list.evaluate(node => node.scrollHeight - node.clientHeight - node.scrollTop)).toBeLessThan(2);
    await page.getByRole("button", { name: "收起输入", exact: true }).click();
    await expectStableLayout(page, testInfo, "collapsed");
    expect(await list.evaluate(node => node.scrollHeight - node.clientHeight - node.scrollTop)).toBeLessThan(2);

    const lastBubble = page.locator(".message-row:last-of-type .message-bubble");
    const beforeHover = (await lastBubble.boundingBox())!;
    await lastBubble.hover();
    await expectStableLayout(page, testInfo, "hovered");
    expect((await lastBubble.boundingBox())!.y).toBeCloseTo(beforeHover.y, 1);

    await list.hover();
    await page.mouse.wheel(0, -360);
    await expect.poll(() => list.evaluate(node => node.scrollHeight - node.clientHeight - node.scrollTop)).toBeGreaterThan(300);
    await expectStableLayout(page, testInfo, "reading-history");
    const historyScroll = await list.evaluate(node => node.scrollTop);
    await page.getByRole("button", { name: "展开输入", exact: true }).click();
    await expectStableLayout(page, testInfo, "history-expanded");
    expect(await list.evaluate(node => node.scrollTop)).toBeCloseTo(historyScroll, 1);
    await page.setViewportSize({ width: 1030, height: 964 });
    await expectStableLayout(page, testInfo, "header-breakpoint");
    await page.screenshot({ path: testInfo.outputPath("web-app-header-breakpoint.png") });
  } finally {
    await alice.context.close();
    await bob.context.close();
  }
});
