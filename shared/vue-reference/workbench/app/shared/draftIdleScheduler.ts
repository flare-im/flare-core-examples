export type DraftSnapshot = {
  conversationId: string;
  draft: string;
};

export type DraftIdleSave = (
  conversationId: string,
  draft: string,
) => void | Promise<void>;

export class DraftIdleScheduler {
  private timer: ReturnType<typeof setTimeout> | undefined;
  private pending: DraftSnapshot | null = null;

  constructor(
    private readonly delayMs: number,
    private readonly save: DraftIdleSave,
  ) {}

  schedule(snapshot: DraftSnapshot): void {
    this.cancel();
    if (!snapshot.conversationId || !snapshot.draft.trim()) return;
    this.pending = snapshot;
    this.timer = setTimeout(() => {
      void this.flush();
    }, this.delayMs);
  }

  cancel(): void {
    if (this.timer) clearTimeout(this.timer);
    this.timer = undefined;
    this.pending = null;
  }

  async flush(snapshot?: DraftSnapshot): Promise<void> {
    if (this.timer) clearTimeout(this.timer);
    this.timer = undefined;
    const next = snapshot ?? this.pending;
    this.pending = null;
    if (!next?.conversationId || !next.draft.trim()) return;
    await this.save(next.conversationId, next.draft);
  }

  dispose(): void {
    this.cancel();
  }
}
