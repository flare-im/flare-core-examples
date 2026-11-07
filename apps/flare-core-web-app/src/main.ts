import { createApp } from "vue";
import App from "./App.vue";
import { router } from "./router";
import { referenceRuntime, registerWebBundleWorker } from "./integration/referenceRuntime";
import { configureReferenceApp } from "../../../../flare-core-sdk/examples/shared/vue-reference/bootstrap";

configureReferenceApp(referenceRuntime);
createApp(App).use(router).mount("#app");
registerWebBundleWorker();
