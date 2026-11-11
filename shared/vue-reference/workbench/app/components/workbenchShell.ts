export type WorkbenchShellMode = "conversations" | "chat" | "lab";

export function workbenchShellClass(mode: WorkbenchShellMode | string | undefined): string {
  if (mode === "chat") return "workbench-shell--chat";
  if (mode === "lab") return "workbench-shell--lab";
  return "workbench-shell--conversations";
}
