/* tslint:disable */
/* eslint-disable */
export function createWasmRuntime(): FlareImWasmRuntime;
export function wasm_start(): void;
/**
 * Full client config contract (transport policy, race order, URLs).
 */
export function flareClientConfigContractJson(): string;
/**
 * Example init JSON for Web hosts (same shape as C/Tauri `sdk_config`).
 */
export function flareClientInitExampleJson(): string;
/**
 * Contract version string for L2/L3 SDK parity checks.
 */
export function flareBindingContractVersion(): string;
export class FlareImWasmRuntime {
  free(): void;
  [Symbol.dispose](): void;
  /**
   * Register JS IndexedDB persistence host callbacks before `sdk.login`.
   */
  setStorageHost(load_snapshot: Function, save_message: Function, save_conversation: Function, save_cursor: Function, save_pending_send: Function, delete_message: Function, delete_conversation: Function, delete_pending_send: Function): void;
  clearStorageHost(): void;
  setEventCallback(callback?: Function | null): void;
  storageHostConfigured(): boolean;
  constructor();
  /**
   * Sync export returning a JS Promise — avoids nested `block_on` inside wasm-bindgen `async fn`.
   */
  invoke(operation: string, request_json: string): Promise<any>;
  dispose(): void;
}

export type InitInput = RequestInfo | URL | Response | BufferSource | WebAssembly.Module;

export interface InitOutput {
  readonly memory: WebAssembly.Memory;
  readonly __wbg_flareimwasmruntime_free: (a: number, b: number) => void;
  readonly createWasmRuntime: () => number;
  readonly flareimwasmruntime_clearStorageHost: (a: number) => void;
  readonly flareimwasmruntime_dispose: (a: number) => void;
  readonly flareimwasmruntime_invoke: (a: number, b: number, c: number, d: number, e: number) => number;
  readonly flareimwasmruntime_setEventCallback: (a: number, b: number) => void;
  readonly flareimwasmruntime_setStorageHost: (a: number, b: number, c: number, d: number, e: number, f: number, g: number, h: number, i: number) => void;
  readonly flareimwasmruntime_storageHostConfigured: (a: number) => number;
  readonly flareimwasmruntime_new: () => number;
  readonly flareClientConfigContractJson: (a: number) => void;
  readonly flareClientInitExampleJson: (a: number) => void;
  readonly wasm_start: () => void;
  readonly flareBindingContractVersion: (a: number) => void;
  readonly __wasm_bindgen_func_elem_4465: (a: number, b: number, c: number) => void;
  readonly __wasm_bindgen_func_elem_2202: (a: number, b: number) => void;
  readonly __wasm_bindgen_func_elem_4467: (a: number, b: number) => void;
  readonly __wasm_bindgen_func_elem_5676: (a: number, b: number, c: number) => void;
  readonly __wasm_bindgen_func_elem_5675: (a: number, b: number) => void;
  readonly __wasm_bindgen_func_elem_6619: (a: number, b: number, c: number, d: number) => void;
  readonly __wbindgen_export: (a: number, b: number) => number;
  readonly __wbindgen_export2: (a: number, b: number, c: number, d: number) => number;
  readonly __wbindgen_export3: (a: number) => void;
  readonly __wbindgen_export4: (a: number, b: number, c: number) => void;
  readonly __wbindgen_add_to_stack_pointer: (a: number) => number;
  readonly __wbindgen_start: () => void;
}

export type SyncInitInput = BufferSource | WebAssembly.Module;
/**
* Instantiates the given `module`, which can either be bytes or
* a precompiled `WebAssembly.Module`.
*
* @param {{ module: SyncInitInput }} module - Passing `SyncInitInput` directly is deprecated.
*
* @returns {InitOutput}
*/
export function initSync(module: { module: SyncInitInput } | SyncInitInput): InitOutput;

/**
* If `module_or_path` is {RequestInfo} or {URL}, makes a request and
* for everything else, calls `WebAssembly.instantiate` directly.
*
* @param {{ module_or_path: InitInput | Promise<InitInput> }} module_or_path - Passing `InitInput` directly is deprecated.
*
* @returns {Promise<InitOutput>}
*/
export default function __wbg_init (module_or_path?: { module_or_path: InitInput | Promise<InitInput> } | InitInput | Promise<InitInput>): Promise<InitOutput>;
