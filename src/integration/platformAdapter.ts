import { open } from "@tauri-apps/plugin-dialog";
import {
  normalizePlatformError,
  platformErr,
  platformOk,
  type FlarePickedFile,
  type FlarePickFilesOptions,
  type FlarePickImagesOptions,
  type FlarePlatformAdapter,
  type FlarePlatformResult,
} from "@flare-im/vue-ui/contracts";

const IMAGE_EXTENSIONS = ["png", "jpg", "jpeg", "gif", "webp", "heic", "heif", "bmp", "avif"];
const VIDEO_EXTENSIONS = ["mp4", "mov", "m4v", "webm", "mkv", "avi"];
const AUDIO_EXTENSIONS = ["mp3", "m4a", "aac", "wav", "ogg", "flac", "opus"];

type DialogFilter = { name: string; extensions: string[] };

/** Translate the contract's accept list (MIME wildcards or extensions) into dialog filters; empty = any file. */
export function dialogFiltersFor(accept: readonly string[] | undefined): DialogFilter[] | undefined {
  if (!accept?.length) return undefined;
  const extensions = new Set<string>();
  for (const entry of accept) {
    const value = entry.trim().toLowerCase();
    if (value === "image/*") IMAGE_EXTENSIONS.forEach((ext) => extensions.add(ext));
    else if (value === "video/*") VIDEO_EXTENSIONS.forEach((ext) => extensions.add(ext));
    else if (value === "audio/*") AUDIO_EXTENSIONS.forEach((ext) => extensions.add(ext));
    else if (value.startsWith(".")) extensions.add(value.slice(1));
    else if (value === "*/*" || value === "*") return undefined;
  }
  return extensions.size ? [{ name: "Files", extensions: [...extensions] }] : undefined;
}

function toPicked(path: string): FlarePickedFile {
  const name = path.split(/[\\/]/).pop() || path;
  return { name, path };
}

async function pick(multiple: boolean, filters: DialogFilter[] | undefined): Promise<FlarePlatformResult<FlarePickedFile[]>> {
  try {
    const selected = await open({ multiple, fileAccessMode: "scoped", filters });
    if (!selected) return platformErr("CANCELLED", "dialog dismissed");
    const paths = (Array.isArray(selected) ? selected : [selected]).map((path) => String(path).trim()).filter(Boolean);
    return paths.length ? platformOk(paths.map(toPicked)) : platformErr("CANCELLED", "no file selected");
  } catch (error) {
    return { ok: false, error: normalizePlatformError(error) };
  }
}

/**
 * The Tauri host's implementation of the kit's platform contract: pickers
 * through the dialog plugin (a dismissed dialog is CANCELLED), no share surface.
 */
export function createTauriPlatformAdapter(): FlarePlatformAdapter {
  return {
    pickFiles(options: FlarePickFilesOptions = {}) {
      return pick(Boolean(options.multiple), dialogFiltersFor(options.accept));
    },
    pickImages(options: FlarePickImagesOptions = {}) {
      return pick(Boolean(options.multiple), dialogFiltersFor(options.video ? ["image/*", "video/*"] : ["image/*"]));
    },
  };
}
