import { defaultWindowIcon, show as showApp } from "@tauri-apps/api/app";
import { Menu } from "@tauri-apps/api/menu";
import { TrayIcon } from "@tauri-apps/api/tray";
import { getCurrentWindow, UserAttentionType } from "@tauri-apps/api/window";
import {
  isPermissionGranted,
  requestPermission,
  sendNotification,
} from "@tauri-apps/plugin-notification";
import type { NotificationPresenter } from "@flare-im/sdk/notifications";
import { translateFlare } from "@flare-im/vue-ui/i18n";
import { playDesktopNotificationSound } from "../../../../flare-core-sdk/examples/shared/vue-reference/workbench/app";

let trayTask: Promise<TrayIcon | null> | undefined;
let trayUnavailable = false;
let currentBadgeCount = 0;
const trayId = "flare-core-tauri-tray";

export function configureTauriDesktopNotifications(): void {
  void ensureTrayIcon();
}

/**
 * The engine's system notifications on the desktop, through the Tauri notification plugin. The engine decided each
 * one (and rendered its text); this only puts it on screen: one notification per conversation (its collapse id as the
 * notification id, its thread as the group), the app's message sound and a dock / taskbar bounce when the engine asks
 * for a sound, urgent ones bouncing until the window is brought forward. The desktop plugin reports no clicks and
 * cannot take a shown notification down, so a click only brings the app to the front through the system and the
 * notification centre tidies itself.
 */
export function tauriNotificationPresenter(): NotificationPresenter {
  let denied = false;
  return {
    async permission() {
      if (await isPermissionGranted()) return "granted";
      return denied ? "denied" : "prompt";
    },
    async requestPermission() {
      const answer = await requestPermission();
      denied = answer === "denied";
      if (answer === "granted") return "granted";
      return denied ? "denied" : "prompt";
    },
    async show(notification) {
      if (!(await isPermissionGranted())) return;
      sendNotification({
        id: notificationId(notification.collapseId),
        ...(notification.threadId ? { group: notification.threadId } : {}),
        title: notification.title || notification.body,
        body: notification.title ? notification.body : "",
      });
      if (!notification.sound) return;
      await playDesktopNotificationSound("message");
      await getCurrentWindow().requestUserAttention(
        notification.channel === "urgent" ? UserAttentionType.Critical : UserAttentionType.Informational,
      );
    },
    close() {},
    closeAll() {},
    focus: revealMainWindow,
  };
}

/** The dock / taskbar badge and the tray title: the engine's unread total (`notification.badge`). */
export async function setDesktopBadgeCount(count: number): Promise<void> {
  const normalized = Math.max(0, Math.trunc(count));
  currentBadgeCount = normalized;
  await getCurrentWindow().setBadgeCount(normalized > 0 ? normalized : undefined);
  await updateTrayBadgeCount(normalized);
}

function ensureTrayIcon(): Promise<TrayIcon | null> {
  if (trayUnavailable) return Promise.resolve(null);
  trayTask ??= (async () => {
    const existing = await TrayIcon.getById(trayId);
    if (existing) {
      await updateTrayBadgeCount(currentBadgeCount, existing);
      return existing;
    }
    const icon = await defaultWindowIcon();
    const menu = await Menu.new({
      items: [
        {
          id: "show",
          text: translateFlare("notifications.openApp"),
          action: () => {
            void revealMainWindow();
          },
        },
      ],
    });
    const tray = await TrayIcon.new({
      id: trayId,
      icon: icon ?? undefined,
      iconAsTemplate: false,
      menu,
      showMenuOnLeftClick: false,
      tooltip: "Flare Core Tauri",
      title: badgeLabel(currentBadgeCount),
      action: (event) => {
        if (event.type === "Click" && event.button === "Left" && event.buttonState === "Up") {
          void revealMainWindow();
        }
      },
    });
    await updateTrayBadgeCount(currentBadgeCount, tray);
    return tray;
  })().catch((error) => {
    trayTask = undefined;
    trayUnavailable = true;
    console.warn("[flare-tauri] tray_init_failed", error);
    return null;
  });
  return trayTask;
}

async function revealMainWindow(): Promise<void> {
  await showApp();
  const window = getCurrentWindow();
  await window.unminimize();
  await window.show();
  await window.setFocus();
}

async function updateTrayBadgeCount(count: number, trayOverride?: TrayIcon | null): Promise<void> {
  const tray = trayOverride ?? await ensureTrayIcon();
  if (!tray) return;
  const label = badgeLabel(count);
  await tray.setTitle(label || null);
  await tray.setTooltip(
    label
      ? `Flare Core Tauri - ${translateFlare("notifications.trayUnread", { label })}`
      : "Flare Core Tauri",
  );
}

/** The collapse id as a 32-bit notification id: a later notification for the conversation reuses it. */
function notificationId(collapseId: string): number {
  let hash = 0;
  for (let index = 0; index < collapseId.length; index += 1) {
    hash = (Math.imul(hash, 31) + collapseId.charCodeAt(index)) | 0;
  }
  return hash;
}

function badgeLabel(count: number): string {
  if (count <= 0) return "";
  return count > 99 ? "99+" : String(count);
}
