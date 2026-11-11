import { ref, type Ref } from "vue";
import type { FlareToastVariant } from "@flare-im/vue-ui/contracts";

/**
 * Transient feedback of the reference workbench. One module-level stack so any
 * module can report without wiring a provider — a missing provider is exactly
 * how the previous `useMessage()` wiring crashed the workspace on mount.
 *
 * The stack is app state; the visuals belong to the kit (`FlareToast`, rendered
 * by `ToastHost.vue`).
 */
export interface ReferenceToast {
  id: number;
  message: string;
  variant: FlareToastVariant;
}

const MAX_VISIBLE = 4;
const DISMISS_MS: Record<FlareToastVariant, number> = {
  info: 3200,
  success: 3200,
  warning: 4200,
  error: 5200,
  loading: 0,
};

const items = ref<ReferenceToast[]>([]);
const timers = new Map<number, ReturnType<typeof setTimeout>>();
let nextId = 0;

function dismiss(id: number): void {
  const timer = timers.get(id);
  if (timer !== undefined) clearTimeout(timer);
  timers.delete(id);
  items.value = items.value.filter((item) => item.id !== id);
}

function push(variant: FlareToastVariant, message: string): number {
  const text = message?.trim();
  if (!text) return -1;
  const id = ++nextId;
  items.value = [...items.value, { id, message: text, variant }].slice(-MAX_VISIBLE);
  // Anything trimmed by the cap must not leave a timer behind.
  for (const [timerId, timer] of timers) {
    if (!items.value.some((item) => item.id === timerId)) {
      clearTimeout(timer);
      timers.delete(timerId);
    }
  }
  const ms = DISMISS_MS[variant];
  if (ms > 0) timers.set(id, setTimeout(() => dismiss(id), ms));
  return id;
}

export interface ReferenceToastApi {
  info(message: string): number;
  success(message: string): number;
  warning(message: string): number;
  error(message: string): number;
  loading(message: string): number;
  dismiss(id: number): void;
  readonly items: Ref<ReferenceToast[]>;
}

const api: ReferenceToastApi = {
  info: (message) => push("info", message),
  success: (message) => push("success", message),
  warning: (message) => push("warning", message),
  error: (message) => push("error", message),
  loading: (message) => push("loading", message),
  dismiss,
  items,
};

export function useToast(): ReferenceToastApi {
  return api;
}

/** Test helper: drop every pending toast and timer. */
export function resetToasts(): void {
  for (const timer of timers.values()) clearTimeout(timer);
  timers.clear();
  items.value = [];
}
