import { afterEach, describe, expect, it, vi } from "vitest";
import type { MediaApi } from "@flare-im/sdk";

import {
  configureDownloadDirectoryPicker,
  loadDownloadLocation,
  mediaCacheBytes,
  pickDownloadLocation,
  resetDownloadLocation,
} from "./downloadLocation";
import { configureAppMediaLocalPathResolver, createAppMediaResolver } from "./appMediaResolver";

function nativeMedia(overrides: Partial<Record<string, unknown>> = {}) {
  return {
    getUserDownloadDirectory: vi.fn(async () => ({ directory: "/Users/me/Downloads/flare", isCustom: false })),
    setUserDownloadDirectory: vi.fn(async () => ({})),
    getMediaCacheStats: vi.fn(async () => ({ total_bytes: 2048 })),
    resolveMediaAccess: vi.fn(async () => ({ source: "remote", remote: { url: "https://cdn/x.png?sig=1" } })),
    ...overrides,
  } as unknown as MediaApi & Record<string, ReturnType<typeof vi.fn>>;
}

afterEach(() => {
  configureDownloadDirectoryPicker(undefined);
  configureAppMediaLocalPathResolver();
});

describe("download location", () => {
  it("uses the host's folder picker (Tauri) and sets what it returns", async () => {
    const media = nativeMedia();
    configureDownloadDirectoryPicker(async (current) => (current ? "/Volumes/Work/收件" : null));
    expect((await loadDownloadLocation(media)).canPick).toBe(true);
    await expect(pickDownloadLocation(media, "/Users/me/Downloads/flare")).resolves.toBe(true);
    expect(media.setUserDownloadDirectory).toHaveBeenCalledWith({ directory: "/Volumes/Work/收件" });
    await expect(pickDownloadLocation(media, "")).resolves.toBe(false);
    await resetDownloadLocation(media);
    expect(media.setUserDownloadDirectory).toHaveBeenLastCalledWith({ directory: null });
  });

  it("on the web lets the SDK pick, and says when the browser decides", async () => {
    const pick = vi.fn(async () => ({}));
    const media = nativeMedia({
      getUserDownloadDirectory: vi.fn(async () => ({ directory: "", isCustom: false, managedByBrowser: true, supportsPicker: false })),
      pickUserDownloadDirectory: pick,
    });
    const location = await loadDownloadLocation(media);
    expect(location).toMatchObject({ canPick: false, managedByBrowser: true });
    await expect(pickDownloadLocation(media, "")).resolves.toBe(true);
    expect(pick).toHaveBeenCalled();
    pick.mockRejectedValueOnce(Object.assign(new Error("cancelled"), { name: "AbortError" }));
    await expect(pickDownloadLocation(media, "")).resolves.toBe(false);
  });

  it("reads the cache size from the native core or the browser cache", async () => {
    await expect(mediaCacheBytes(nativeMedia())).resolves.toBe(2048);
    await expect(
      mediaCacheBytes(nativeMedia({ getMediaCacheStats: vi.fn(async () => ({ totalBytes: 10 })) })),
    ).resolves.toBe(10);
  });
});

describe("app media resolver", () => {
  const sdk = (media: unknown) => ({ client: { media }, currentUserId: { value: "u1" }, loggedIn: { value: true } }) as never;

  it("asks the SDK to cache pictures and prefers the local copy", async () => {
    configureAppMediaLocalPathResolver((path: string) => `asset://localhost${path}`);
    const media = nativeMedia({
      resolveMediaAccess: vi.fn(async () => ({ source: "local", localPath: "/cache/a.png", remote: { url: "https://cdn/a.png?sig=1" } })),
    });
    const resolve = createAppMediaResolver(sdk(media));
    await expect(resolve({ kind: "image", fileId: "11111111-2222-3333-4444-555555555555" })).resolves.toBe(
      "asset://localhost/cache/a.png",
    );
    expect(media.resolveMediaAccess).toHaveBeenCalledWith(expect.objectContaining({ autoCache: true }));
    await resolve({ kind: "video", fileId: "11111111-2222-3333-4444-555555555556" });
    expect(media.resolveMediaAccess).toHaveBeenLastCalledWith(expect.objectContaining({ autoCache: false }));
  });

  it("on the web hands out the SDK's cached blob once per picture", async () => {
    const display = vi.fn(async () => "blob:http://localhost/1");
    const media = nativeMedia({ resolveDisplayUrl: display, revokeDisplayUrl: vi.fn() });
    const resolve = createAppMediaResolver(sdk(media));
    const request = { kind: "image", fileId: "11111111-2222-3333-4444-555555555557" };
    await expect(resolve(request)).resolves.toBe("blob:http://localhost/1");
    await expect(resolve(request)).resolves.toBe("blob:http://localhost/1");
    expect(display).toHaveBeenCalledTimes(1);
    expect(display).toHaveBeenCalledWith(expect.objectContaining({ autoCache: true }));
  });
});
