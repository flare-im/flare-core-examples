/// <reference types="vite/client" />

interface ImportMetaEnv {
  /**
   * The core SDK's access configuration `access` as JSON: a signed seed, or development endpoints
   * (`{"trustMode":"development","developmentEndpoints":{...}}`). The dev server falls back to the local stack
   * without it; a production build without it offers no sign-in.
   */
  readonly VITE_FLARE_ACCESS_JSON?: string;
  /** The tenant (platform app id); "0" when unset. */
  readonly VITE_FLARE_TENANT_ID?: string;
  /** Integer build number reported on CONNECT (`app.build`), injected by the Flare Vite config. */
  readonly VITE_FLARE_APP_BUILD?: string;
  /** Update channel (`app.channel`, stable or beta), injected by the Flare Vite config; the core defaults to stable. */
  readonly VITE_FLARE_APP_CHANNEL?: string;
  /** The web build's id; without it a production build makes one from the day. */
  readonly VITE_FLARE_WEB_BUILD_ID?: string;
}
