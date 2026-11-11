/**
 * Minimal ambient types for the optional `wa-sqlite` dependency so the SQLite/OPFS
 * storage host typechecks without the package installed. The real types ship with
 * `wa-sqlite`; install it (and configure Vite worker/WASM assets) to activate the
 * desktop SQLite backend.
 */
declare module "wa-sqlite/dist/wa-sqlite.mjs" {
  const factory: () => Promise<unknown>;
  export default factory;
}

declare module "wa-sqlite" {
  export type SQLiteCompatibleType = number | string | bigint | Uint8Array | null;
  export const SQLITE_ROW: number;
  export const SQLITE_DONE: number;
  export interface SQLiteAPI {
    vfs_register(vfs: unknown, makeDefault?: boolean): number;
    open_v2(filename: string, flags?: number, vfs?: string): Promise<number>;
    close(db: number): Promise<number>;
    exec(db: number, sql: string, callback?: (row: unknown[], columns: string[]) => void): Promise<number>;
    statements(db: number, sql: string): AsyncIterable<number>;
    bind_collection(
      stmt: number,
      bindings: SQLiteCompatibleType[] | Record<string, SQLiteCompatibleType>,
    ): number;
    step(stmt: number): Promise<number>;
    reset(stmt: number): Promise<number>;
    column(stmt: number, index: number): SQLiteCompatibleType;
    column_names(stmt: number): string[];
    row(stmt: number): SQLiteCompatibleType[];
  }
  export function Factory(module: unknown): SQLiteAPI;
}

declare module "wa-sqlite/src/examples/OPFSCoopSyncVFS.js" {
  export class OPFSCoopSyncVFS {
    static create(name: string, module: unknown): Promise<unknown>;
  }
}
