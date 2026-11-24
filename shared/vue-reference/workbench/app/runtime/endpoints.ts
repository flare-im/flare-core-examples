import type { CoreEndpoints } from "@flare-im/sdk";

export function resolveCoreEndpoints(env: Record<string, unknown>): CoreEndpoints {
  const value = (key: string) => typeof env[key] === "string" ? (env[key] as string).trim() : "";
  const development = env.DEV === true;
  const baseUrl = value("VITE_FLARE_CORE_API_URL") || (development ? "http://127.0.0.1:50050" : "");
  const websocketUrl = value("VITE_FLARE_WEBSOCKET_URL") || (development ? "ws://127.0.0.1:60051" : "");
  if (!baseUrl || !websocketUrl) throw new Error("Configure VITE_FLARE_CORE_API_URL and VITE_FLARE_WEBSOCKET_URL");
  const quicUrl = value("VITE_FLARE_QUIC_URL");
  const mediaBaseUrl = value("VITE_FLARE_MEDIA_BASE_URL");
  return { baseUrl, websocketUrl, ...(quicUrl ? { quicUrl } : {}), ...(mediaBaseUrl ? { mediaBaseUrl } : {}) };
}
