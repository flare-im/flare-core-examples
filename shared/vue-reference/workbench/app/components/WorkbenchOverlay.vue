<script setup lang="ts">
import { computed, onBeforeUnmount, ref, watch } from "vue";
import { FlareIcon } from "@flare-im/vue-ui/components";

/**
 * Workbench overlay — the product shell's own sheet / side panel / centered card.
 * Shell chrome, not kit API: the kit's BottomSheet and FormSheet cover the phone
 * sheet and the confirm-shaped form, while the workbench also needs a titled
 * desktop side panel and a plain preview card.
 *
 * Owns what an overlay owes the user: a scrim that closes, Escape, a labelled
 * dialog, focus moved in and returned on close, and no background scroll.
 */
const props = withDefaults(
  defineProps<{
    title?: string;
    /** right = desktop side panel, bottom = phone sheet, center = card. */
    placement?: "right" | "bottom" | "center";
    /** Side-panel width (px). */
    width?: number;
    /** Bottom-sheet height (any CSS length). */
    height?: string;
    closeLabel?: string;
  }>(),
  { title: "", placement: "bottom", closeLabel: "Close" },
);
const open = defineModel<boolean>("open", { default: false });

const panel = ref<HTMLElement | null>(null);
let restoreFocus: HTMLElement | null = null;

const style = computed(() => ({
  ...(props.placement === "right" && props.width ? { width: `${props.width}px` } : {}),
  ...(props.placement === "bottom" && props.height ? { height: props.height } : {}),
}));

function close(): void {
  open.value = false;
}
function onKeydown(event: KeyboardEvent): void {
  if (event.key !== "Escape") return;
  event.stopPropagation();
  close();
}
watch(open, (visible) => {
  if (typeof document === "undefined") return;
  if (visible) {
    restoreFocus = document.activeElement as HTMLElement | null;
    document.body.style.overflow = "hidden";
    void Promise.resolve().then(() => panel.value?.focus());
    return;
  }
  document.body.style.overflow = "";
  restoreFocus?.focus?.();
  restoreFocus = null;
}, { immediate: true });
onBeforeUnmount(() => {
  if (typeof document !== "undefined") document.body.style.overflow = "";
});
</script>

<template>
  <Teleport to="body">
    <Transition name="workbench-overlay">
      <div v-if="open" class="workbench-overlay" :class="`workbench-overlay--${placement}`" @click.self="close">
        <section
          ref="panel"
          class="workbench-overlay__panel"
          role="dialog"
          aria-modal="true"
          :aria-label="title || undefined"
          tabindex="-1"
          :style="style"
          @keydown="onKeydown"
        >
          <header v-if="title" class="workbench-overlay__head">
            <h2>{{ title }}</h2>
            <button type="button" class="workbench-overlay__close" :aria-label="closeLabel" :title="closeLabel" @click="close">
              <FlareIcon name="close" :size="18" />
            </button>
          </header>
          <div class="workbench-overlay__body"><slot /></div>
        </section>
      </div>
    </Transition>
  </Teleport>
</template>

<style scoped>
.workbench-overlay {
  position: fixed;
  inset: 0;
  z-index: 3000;
  display: flex;
  background: color-mix(in srgb, #000 42%, transparent);
}
.workbench-overlay--right { justify-content: flex-end; }
.workbench-overlay--bottom { align-items: flex-end; }
.workbench-overlay--center { align-items: center; justify-content: center; padding: 24px; }

.workbench-overlay__panel {
  display: flex;
  flex-direction: column;
  min-width: 0;
  max-width: 100%;
  overflow: hidden;
  color: var(--flare-color-text-primary);
  background: var(--flare-color-bg-primary);
  box-shadow: var(--flare-shadow-lg);
}
.workbench-overlay--right .workbench-overlay__panel { width: min(440px, 100%); height: 100%; }
.workbench-overlay--bottom .workbench-overlay__panel {
  width: 100%;
  max-height: 88vh;
  border-start-start-radius: var(--flare-size-radius-xl, 18px);
  border-start-end-radius: var(--flare-size-radius-xl, 18px);
  padding-bottom: env(safe-area-inset-bottom, 0px);
}
.workbench-overlay--center .workbench-overlay__panel {
  width: min(720px, 100%);
  max-height: 84vh;
  border-radius: var(--flare-size-radius-lg);
}

.workbench-overlay__head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: var(--flare-size-spacing-md);
  padding: var(--flare-size-spacing-md) var(--flare-size-spacing-lg);
  border-bottom: 1px solid var(--flare-color-border-primary);
}
.workbench-overlay__head h2 {
  margin: 0;
  font-size: var(--flare-size-font-size-lg);
  font-weight: 600;
}
.workbench-overlay__close {
  display: grid;
  place-items: center;
  width: var(--flare-size-layout-touch-target, 48px);
  height: var(--flare-size-layout-touch-target, 48px);
  margin: -8px -8px -8px 0;
  border: 0;
  border-radius: var(--flare-size-radius-sm);
  color: var(--flare-color-text-tertiary);
  background: transparent;
  cursor: pointer;
}
.workbench-overlay__close:hover { color: var(--flare-color-text-primary); background: var(--flare-color-bg-hover); }
.workbench-overlay__close:focus-visible { outline: 2px solid var(--flare-color-focus-ring); outline-offset: -2px; }
.workbench-overlay__panel:focus-visible { outline: none; }

.workbench-overlay__body {
  flex: 1;
  min-height: 0;
  overflow: auto;
  padding: var(--flare-size-spacing-lg);
}

.workbench-overlay-enter-active,
.workbench-overlay-leave-active { transition: opacity var(--flare-transition-fast) ease; }
.workbench-overlay-enter-from,
.workbench-overlay-leave-to { opacity: 0; }
@media (prefers-reduced-motion: reduce) {
  .workbench-overlay-enter-active,
  .workbench-overlay-leave-active { transition: none; }
}
</style>
