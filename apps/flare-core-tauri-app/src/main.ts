import { createApp } from "vue";
import App from "./App.vue";
import { router } from "./router";
import { configureTauriDesktopNotifications } from "./desktopNotifications";
import { referenceRuntime, configureNativeReferenceBridges } from "./integration/referenceRuntime";
import { configureReferenceApp } from "../../../../flare-core-sdk/examples/shared/vue-reference/bootstrap";

configureReferenceApp(referenceRuntime);
configureNativeReferenceBridges();
configureTauriDesktopNotifications();
createApp(App).use(router).mount("#app");
