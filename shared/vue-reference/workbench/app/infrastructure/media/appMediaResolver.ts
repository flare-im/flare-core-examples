import type {
  FlareMediaResolveRequest,
  FlareMediaResolver,
} from "@flare-im/vue-ui/contracts";
import { mediaProxyFields as sdkMediaProxyFields, proxiedMediaUrl } from "@flare-im/vue-ui/utils";
import type { FlareSdkContext } from "../../sdk/flareSdkContext";

type LocalPathResolver = (path: string) => string;

const CORE_MEDIA_PATH_SEGMENT = "/flare-media/media/";
const UUID_FILE_ID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

let localPathResolver: LocalPathResolver | undefined;

export function configureAppMediaLocalPathResolver(resolver?: LocalPathResolver): void {
  localPathResolver = resolver;
}

export function resolveAppMediaLocalPath(path: string): string {
  const value = path.trim();
  if (!value) return "";
  return localPathResolver ? localPathResolver(value) : value;
}

function readString(source: unknown, key: string): string {
  if (!source || typeof source !== "object") return "";
  const value = (source as Record<string, unknown>)[key];
  return typeof value === "string" ? value.trim() : "";
}

function pickRemoteUrl(resolved: unknown): string {
  if (!resolved || typeof resolved !== "object") return "";
  const topLevel = readString(resolved, "url") || readString(resolved, "cdnUrl");
  if (topLevel) return topLevel;
  const remote = (resolved as Record<string, unknown>).remote;
  if (!remote || typeof remote !== "object") return "";
  return readString(remote, "url") || readString(remote, "cdnUrl");
}

function pickLocalPath(resolved: unknown): string {
  return readString(resolved, "localPath");
}

function coreMediaFileIdFromUrl(url: string | undefined): string {
  const raw = url?.trim();
  if (!raw) return "";
  try {
    const parsed = new URL(raw, "http://flare.local");
    let path = parsed.pathname;
    const proxyPrefix = sdkMediaProxyFields().storageProxyPrefix?.replace(/\/$/, "");
    if (proxyPrefix && path.startsWith(`${proxyPrefix}/`)) {
      path = path.slice(proxyPrefix.length);
    }
    if (!path.includes(CORE_MEDIA_PATH_SEGMENT)) return "";
    const filename = decodeURIComponent(path.split("/").pop() ?? "").trim();
    const dotIndex = filename.lastIndexOf(".");
    const fileId = dotIndex > 0 ? filename.slice(0, dotIndex) : filename;
    return UUID_FILE_ID_RE.test(fileId) ? fileId : "";
  } catch {
    return "";
  }
}

function cacheKey(request: FlareMediaResolveRequest, fileId: string): string {
  return [
    request.kind,
    fileId,
    request.url ?? "",
    request.localPath ?? "",
  ].join("|");
}

const PICTURE_KINDS = new Set(["image", "imageThumbnail", "imageGroupItem"]);

/** One `blob:` URL per cached picture for the session, so re-renders do not mint new ones. */
const webPictureUrls = new Map<string, string>();

async function webPictureUrl(
  media: { resolveDisplayUrl(request: Record<string, unknown>): Promise<string> },
  fileId: string,
  mediaUrl: string,
): Promise<string> {
  const known = webPictureUrls.get(fileId);
  if (known) return known;
  const url = await media.resolveDisplayUrl({ fileId, mediaUrl, autoCache: true });
  if (url.startsWith("blob:")) {
    webPictureUrls.set(fileId, url);
    return url;
  }
  return proxiedMediaUrl(url);
}

export function createAppMediaResolver(sdk: FlareSdkContext): FlareMediaResolver {
  // Coalesce concurrent requests only. The SDK owns signed URL lifetime and caching.
  const cache = new Map<string, Promise<string>>();
  const scope = () => `${sdk.currentUserId?.value ?? ''}|${sdk.loggedIn?.value ?? ''}`;

  return async (request) => {
    const directUrl = request.url?.trim();
    const localPath = request.localPath?.trim();
    if (localPath) {
      return localPathResolver ? localPathResolver(localPath) : localPath;
    }

    const fileId = request.fileId?.trim() || coreMediaFileIdFromUrl(directUrl);
    if (!fileId) return directUrl ? proxiedMediaUrl(directUrl) : "";

    const owner = scope();
    const key = `${owner}|${cacheKey(request, fileId)}`;
    const cached = cache.get(key);
    if (cached) return cached;

    // Pictures are cached by the SDK as they are shown (`autoCache`): a picture seen once is read
    // from this device afterwards — the local copy wins over the signed URL.
    const picture = PICTURE_KINDS.has(request.kind);
    const media = sdk.client.media as typeof sdk.client.media & { revokeDisplayUrl?: (url: string) => void };
    const task = (
      picture && !localPathResolver && typeof media.revokeDisplayUrl === "function"
        ? // Web: the SDK hands out its cached copy as a `blob:` URL, one per file for the session.
          webPictureUrl(media, fileId, directUrl ?? "")
        : media
            .resolveMediaAccess({ fileId, mediaUrl: directUrl ?? "", autoCache: picture })
            .then((resolved) => {
              const resolvedLocalPath = pickLocalPath(resolved);
              if (resolvedLocalPath && localPathResolver) return localPathResolver(resolvedLocalPath);
              const remoteUrl = pickRemoteUrl(resolved);
              return remoteUrl ? proxiedMediaUrl(remoteUrl) : "";
            })
    )
      .then((url) => {
        if (owner !== scope()) throw new Error('媒体会话已切换，请重新打开');
        return url;
      })
      .finally(() => {
        if (cache.get(key) === task) cache.delete(key);
      });
    cache.set(key, task);
    return task;
  };
}
