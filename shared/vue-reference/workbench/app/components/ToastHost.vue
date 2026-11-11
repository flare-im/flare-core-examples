<script setup lang="ts">
import { FlareToast } from "@flare-im/vue-ui/components";
import { useToast } from "../ui/toast";

// Renders the workbench toast stack with the kit's Toast. The app owns *when* to
// report; the kit owns how a toast looks.
const toast = useToast();
</script>

<template>
  <div v-if="toast.items.value.length" class="reference-toast-host" role="status" aria-live="polite">
    <FlareToast
      v-for="item in toast.items.value"
      :key="item.id"
      :message="item.message"
      :variant="item.variant"
      @close="toast.dismiss(item.id)"
    />
  </div>
</template>

<style scoped>
.reference-toast-host {
  position: fixed;
  top: calc(16px + env(safe-area-inset-top, 0px));
  left: 50%;
  z-index: 4000;
  display: flex;
  flex-direction: column;
  gap: 8px;
  align-items: center;
  width: max-content;
  max-width: min(520px, calc(100vw - 32px));
  transform: translateX(-50%);
  pointer-events: none;
}
.reference-toast-host > * {
  pointer-events: auto;
}
</style>
