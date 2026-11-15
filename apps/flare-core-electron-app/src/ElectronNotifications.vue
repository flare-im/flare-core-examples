<script setup lang="ts">
/**
 * Runs the engine's notifications for the Electron shell (./notifications.ts). It renders nothing. Mount it inside
 * `ReferenceApp`, which provides the SDK it reads.
 */
import { getFlareSdkSingleton } from "../../../shared/vue-reference/workbench/app";
import { useElectronNotifications } from "./notifications";

const sdk = getFlareSdkSingleton();
if (!sdk) throw new Error("ElectronNotifications reads the reference app's SDK: mount it inside ReferenceApp.");
useElectronNotifications(sdk);
</script>

<template></template>
