/// <reference types="vite/client" />

interface ImportMetaEnv {
  /** Required Core HTTP base for a production build. */
  readonly VITE_FLARE_CORE_API_URL?: string;
  readonly VITE_FLARE_WEBSOCKET_URL?: string;
  readonly VITE_FLARE_QUIC_URL?: string;
  readonly VITE_FLARE_MEDIA_BASE_URL?: string;
  /** The tenant (platform app id); "0" when unset. */
  readonly VITE_FLARE_TENANT_ID?: string;
  /** Integer build number reported on CONNECT (`app.build`), injected by the Flare Vite config. */
  readonly VITE_FLARE_APP_BUILD?: string;
  /** Update channel (`app.channel`, stable or beta), injected by the Flare Vite config; the core defaults to stable. */
  readonly VITE_FLARE_APP_CHANNEL?: string;
  /** The web build's id; without it a production build makes one from the day. */
  readonly VITE_FLARE_WEB_BUILD_ID?: string;
}
