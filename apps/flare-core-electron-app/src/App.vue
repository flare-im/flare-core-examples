<script setup lang="ts">
import ReferenceApp from "../../../shared/vue-reference/ReferenceApp.vue";
import ElectronNotifications from "./ElectronNotifications.vue";
</script>

<template>
  <!-- The engine's notifications start inside the reference app's providers, where its SDK exists. -->
  <ReferenceApp>
    <ElectronNotifications />
  </ReferenceApp>
</template>
