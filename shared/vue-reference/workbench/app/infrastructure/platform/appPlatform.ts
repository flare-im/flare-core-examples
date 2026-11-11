import type { FlarePlatformOptions } from "@flare-im/vue-ui/composables";

let options: FlarePlatformOptions | undefined;

/** Installed once at bootstrap from the runtime; read by ReferenceApp for FlareUiProvider. */
export function configureAppPlatform(next?: FlarePlatformOptions): void {
  options = next;
}

/** The host's platform contract; undefined means the kit's web default. */
export function appPlatformOptions(): FlarePlatformOptions | undefined {
  return options;
}
