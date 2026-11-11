import type { MediaApi } from "@flare-im/sdk";

/**
 * 「下载位置」与本地媒体缓存（核心 SDK 的 `media.user_download_*` / `media.cache_*`）。
 *
 * 原生宿主（Tauri）通过 [configureDownloadDirectoryPicker] 提供系统的选文件夹对话框；web 端由 SDK 的
 * 浏览器实现自己弹选择器（File System Access API，Chromium 系才有），没有时只说明由浏览器决定。
 */
export type DownloadDirectoryPicker = (currentDirectory: string) => Promise<string | null>;

let hostPicker: DownloadDirectoryPicker | undefined;

export function configureDownloadDirectoryPicker(picker: DownloadDirectoryPicker | undefined): void {
  hostPicker = picker;
}

export interface DownloadLocation {
  /** 实际生效的位置；web 未选文件夹时为空（由浏览器决定）。 */
  directory: string;
  isCustom: boolean;
  /** 能不能在这里选文件夹。 */
  canPick: boolean;
  /** web 未选文件夹：文件交给浏览器的下载流程。 */
  managedByBrowser: boolean;
}

type WebMediaExtras = {
  pickUserDownloadDirectory?: () => Promise<unknown>;
  revokeDisplayUrl?: (url: string) => void;
};

export async function loadDownloadLocation(media: MediaApi): Promise<DownloadLocation> {
  const raw = (await media.getUserDownloadDirectory()) as Record<string, unknown>;
  const managedByBrowser = raw.managedByBrowser === true;
  return {
    directory: String(raw.directory ?? ""),
    isCustom: raw.isCustom === true,
    canPick: hostPicker !== undefined || raw.supportsPicker === true,
    managedByBrowser,
  };
}

/** 选一个文件夹作为下载位置；取消时返回 false。必须在点击里调用（浏览器要求手势）。 */
export async function pickDownloadLocation(media: MediaApi, current: string): Promise<boolean> {
  if (hostPicker) {
    const picked = await hostPicker(current);
    if (!picked) return false;
    await media.setUserDownloadDirectory({ directory: picked });
    return true;
  }
  const web = media as MediaApi & WebMediaExtras;
  if (typeof web.pickUserDownloadDirectory !== "function") return false;
  try {
    await web.pickUserDownloadDirectory();
    return true;
  } catch (error) {
    if ((error as { name?: string })?.name === "AbortError") return false;
    throw error;
  }
}

export async function resetDownloadLocation(media: MediaApi): Promise<void> {
  await media.setUserDownloadDirectory({ directory: null });
}

/** 本地媒体缓存占用（字节）：原生是核心的缓存目录，web 是 Cache Storage。 */
export async function mediaCacheBytes(media: MediaApi): Promise<number | null> {
  const stats = (await media.getMediaCacheStats()) as Record<string, unknown>;
  const total = stats.total_bytes ?? stats.totalBytes;
  return typeof total === "number" ? total : null;
}
