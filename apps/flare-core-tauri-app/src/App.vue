<script setup lang="ts">
import { useFlareI18nProvider } from "@flare-im/vue-ui/i18n";
import ReferenceApp from "../../../shared/vue-reference/ReferenceApp.vue";
import MessageAlerts from "./notifications/MessageAlerts.vue";
import { notificationPermission } from "./notifications/permission";

// The app's language, set once here: the reference app's kit provider inherits it, and so do the alerts inside it
// (banner, permission soft-ask), which follow a switch.
useFlareI18nProvider();
</script>

<template>
  <!-- The alerts render inside the reference app's providers; the settings sheet shows the same permission. -->
  <ReferenceApp :notification-permission="notificationPermission">
    <MessageAlerts />
  </ReferenceApp>
</template>
