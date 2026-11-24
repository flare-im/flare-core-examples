/// <reference types="vite/client" />

interface ImportMetaEnv {
  /** Required Core HTTP base for a production build. */
  readonly VITE_FLARE_CORE_API_URL?: string;
  readonly VITE_FLARE_WEBSOCKET_URL?: string;
  readonly VITE_FLARE_QUIC_URL?: string;
  readonly VITE_FLARE_MEDIA_BASE_URL?: string;
  /** The tenant (platform app id); "0" when unset. */
  readonly VITE_FLARE_TENANT_ID?: string;
  /** The private CA for TLS endpoints given in the access configuration (a local gateway's self-signed QUIC). */
  readonly VITE_FLARE_TLS_CA_CERT_PATH?: string;
  /** Integer build number (`app.build`), injected by the Flare Vite config: without it the core checks for no update. */
  readonly VITE_FLARE_APP_BUILD?: string;
  /** Update channel (`app.channel`, stable or beta), injected by the Flare Vite config; the core defaults to stable. */
  readonly VITE_FLARE_APP_CHANNEL?: string;
  /** Distribution of a store build (`app.distribution`, say `appstore`); the Tauri binding reports `tauri` without it. A store build has no updater. */
  readonly VITE_FLARE_DISTRIBUTION?: string;
  /** `1` on a build with an updater, set by the SDK package's scripts/tauri-build-with-updater.mjs. */
  readonly VITE_FLARE_UPDATER_ENABLED?: string;
}
