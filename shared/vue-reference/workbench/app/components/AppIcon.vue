<script setup lang="ts">
import type { Component } from "vue";

// Renders a host-provided glyph component at a given size. The kit's FlareIcon
// takes *semantic* kit icon names; the workbench console and SDK lab also draw
// operational glyphs that are not part of that set, and this is the single place
// the app renders one. Decorative by default — pass `label` when the glyph is
// the only thing naming a control.
withDefaults(defineProps<{ icon: Component; size?: number; label?: string }>(), { size: 18 });
</script>

<template>
  <span
    class="app-icon"
    :style="{ width: `${size}px`, height: `${size}px`, fontSize: `${size}px` }"
    :role="label ? 'img' : undefined"
    :aria-label="label"
    :aria-hidden="label ? undefined : 'true'"
  >
    <component :is="icon" />
  </span>
</template>

<style scoped>
.app-icon {
  display: inline-grid;
  flex: none;
  place-items: center;
  line-height: 1;
}
/* The glyph is rendered by `<component :is>`, so its root element carries this
   component's scope id too — no `:deep` piercing needed, and `> svg` only reaches
   the glyph root rather than every nested svg inside it. */
.app-icon > svg {
  width: 1em;
  height: 1em;
}
</style>
