/** The site's Service Worker, the same script for every build: see `@flare-im/sdk/update/service-worker`. */
import { handleFlareNotificationClick } from "@flare-im/sdk/notifications";
import { installFlareServiceWorker } from "@flare-im/sdk/update/service-worker";

// "index.html" resolves against this script: beside it, whatever the deploy base is.
installFlareServiceWorker({
  navigationFallback: "index.html",
  bypass: [/^\/api\//, /^\/flare-media\//, /^\/ws/, /^\/quic/],
});

// The page shows its notifications through this worker; their clicks arrive here and go back to the page.
self.addEventListener("notificationclick", (event) => handleFlareNotificationClick(event));
