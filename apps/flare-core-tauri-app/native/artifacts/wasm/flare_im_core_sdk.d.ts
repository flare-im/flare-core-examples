/* tslint:disable */
/* eslint-disable */
export function createWasmRuntime(): FlareImWasmRuntime;
export function flareSetEncryptionKey(key: string): void;
export function flareNowRfc3339(): string;
export function flareWallClockMs(): bigint;
export function flareHasEncryptionKey(): boolean;
export function flareEncryptionKeyLen(): number;
export function flareRuntimeId(): string;
export function flareClearEncryptionKey(): void;
export function flareSetEncryptionKeyHex(hex: string): void;
export function flareBindingContractJson(): string;
export function wasm_start(): void;
/**
 * Full client config contract (transport policy, race order, URLs).
 */
export function flareClientConfigContractJson(): string;
/**
 * Example init JSON for Web hosts (same shape as C/Tauri `sdkConfig`).
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
  readonly flareBindingContractJson: (a: number) => void;
  readonly flareBindingContractVersion: (a: number) => void;
  readonly flareClearEncryptionKey: () => void;
  readonly flareClientConfigContractJson: (a: number) => void;
  readonly flareClientInitExampleJson: (a: number) => void;
  readonly flareEncryptionKeyLen: () => number;
  readonly flareHasEncryptionKey: () => number;
  readonly flareNowRfc3339: (a: number) => void;
  readonly flareRuntimeId: (a: number) => void;
  readonly flareSetEncryptionKey: (a: number, b: number, c: number) => void;
  readonly flareSetEncryptionKeyHex: (a: number, b: number, c: number) => void;
  readonly flareimwasmruntime_clearStorageHost: (a: number) => void;
  readonly flareimwasmruntime_dispose: (a: number) => void;
  readonly flareimwasmruntime_invoke: (a: number, b: number, c: number, d: number, e: number) => number;
  readonly flareimwasmruntime_setEventCallback: (a: number, b: number) => void;
  readonly flareimwasmruntime_setStorageHost: (a: number, b: number, c: number, d: number, e: number, f: number, g: number, h: number, i: number) => void;
  readonly flareimwasmruntime_storageHostConfigured: (a: number) => number;
  readonly wasm_start: () => void;
  readonly flareimwasmruntime_new: () => number;
  readonly flareWallClockMs: () => bigint;
  readonly __wasm_bindgen_func_elem_10737: (a: number, b: number, c: number) => void;
  readonly __wasm_bindgen_func_elem_10062: (a: number, b: number) => void;
  readonly __wasm_bindgen_func_elem_11669: (a: number, b: number, c: number) => void;
  readonly __wasm_bindgen_func_elem_11654: (a: number, b: number) => void;
  readonly __wasm_bindgen_func_elem_11751: (a: number, b: number) => void;
  readonly __wasm_bindgen_func_elem_11718: (a: number, b: number) => void;
  readonly __wasm_bindgen_func_elem_11962: (a: number, b: number, c: number, d: number) => void;
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
