export type DesktopNotificationKind = "message" | "call";

export type DesktopNotificationPayload = {
  kind: DesktopNotificationKind;
  title: string;
  body: string;
  conversationId?: string;
  messageId?: string;
  senderId?: string;
  unreadCount?: number;
  requireAttention?: boolean;
  playSound?: boolean;
  dedupeKey?: string;
};

export type DesktopNotificationAdapter = {
  notify(payload: DesktopNotificationPayload): void | Promise<void>;
  setUnreadCount?(count: number): void | Promise<void>;
};

const dedupeTtlMs = 4_000;
const recentNotificationKeys = new Map<string, number>();

let desktopNotificationAdapter: DesktopNotificationAdapter | null = null;
let audioContext: AudioContext | undefined;

export function configureDesktopNotifications(adapter: DesktopNotificationAdapter | null | undefined): void {
  desktopNotificationAdapter = adapter ?? null;
}

export function emitDesktopNotification(payload: DesktopNotificationPayload): void {
  const adapter = desktopNotificationAdapter;
  if (!adapter) return;
  if (payload.dedupeKey && isDuplicateNotification(payload.dedupeKey)) return;
  void Promise.resolve(adapter.notify(payload)).catch((error) => {
    console.warn("[flare-desktop] notification_failed", error);
  });
}

export function setDesktopUnreadCount(count: number): void {
  const adapter = desktopNotificationAdapter;
  if (!adapter?.setUnreadCount) return;
  void Promise.resolve(adapter.setUnreadCount(Math.max(0, count))).catch((error) => {
    console.warn("[flare-desktop] unread_badge_failed", error);
  });
}

export async function playDesktopNotificationSound(kind: DesktopNotificationKind): Promise<void> {
  if (typeof window === "undefined") return;
  const audioWindow = window as Window & typeof globalThis & {
    webkitAudioContext?: typeof AudioContext;
  };
  const AudioContextCtor = audioWindow.AudioContext ?? audioWindow.webkitAudioContext;
  if (!AudioContextCtor) return;
  audioContext ??= new AudioContextCtor();
  const context = audioContext;
  if (context.state === "suspended") {
    await context.resume();
  }

  const pattern = kind === "call"
    ? [
      { start: 0, frequency: 740, duration: 0.16 },
      { start: 0.22, frequency: 980, duration: 0.18 },
      { start: 0.48, frequency: 740, duration: 0.16 },
    ]
    : [
      { start: 0, frequency: 660, duration: 0.09 },
      { start: 0.12, frequency: 880, duration: 0.1 },
    ];
  const base = context.currentTime;
  for (const tone of pattern) {
    playTone(context, base + tone.start, tone.frequency, tone.duration);
  }
}

function isDuplicateNotification(key: string): boolean {
  const now = Date.now();
  for (const [candidate, seenAt] of recentNotificationKeys) {
    if (now - seenAt > dedupeTtlMs) recentNotificationKeys.delete(candidate);
  }
  const previous = recentNotificationKeys.get(key);
  recentNotificationKeys.set(key, now);
  return previous !== undefined && now - previous < dedupeTtlMs;
}

function playTone(context: AudioContext, start: number, frequency: number, duration: number): void {
  const oscillator = context.createOscillator();
  const gain = context.createGain();
  oscillator.type = "sine";
  oscillator.frequency.setValueAtTime(frequency, start);
  gain.gain.setValueAtTime(0.0001, start);
  gain.gain.exponentialRampToValueAtTime(0.16, start + 0.012);
  gain.gain.exponentialRampToValueAtTime(0.0001, start + duration);
  oscillator.connect(gain);
  gain.connect(context.destination);
  oscillator.start(start);
  oscillator.stop(start + duration + 0.03);
}
