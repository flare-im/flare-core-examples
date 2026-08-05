import { defaultWindowIcon, show as showApp } from "@tauri-apps/api/app";
import { Menu } from "@tauri-apps/api/menu";
import { TrayIcon } from "@tauri-apps/api/tray";
import { getCurrentWindow, UserAttentionType } from "@tauri-apps/api/window";
import {
  isPermissionGranted,
  requestPermission,
  sendNotification,
} from "@tauri-apps/plugin-notification";
import {
  configureDesktopNotifications,
  playDesktopNotificationSound,
  type DesktopNotificationPayload,
} from "@flare-im/vue-ui/app";

let permissionTask: Promise<boolean> | undefined;
let trayTask: Promise<TrayIcon | null> | undefined;
let trayUnavailable = false;
let currentUnreadCount = 0;
const trayId = "flare-core-tauri-tray";

export function configureTauriDesktopNotifications(): void {
  void ensureTrayIcon();
  configureDesktopNotifications({
    async notify(payload) {
      if (payload.playSound !== false) {
        await playDesktopNotificationSound(payload.kind);
      }
      if (await ensureNotificationPermission()) {
        sendNotification({
          title: notificationText(payload.title, "Flare IM"),
          body: notificationText(payload.body, "收到新的提醒"),
        });
      }
      if (payload.requireAttention !== false) {
        await requestAttention(payload);
      }
    },
    async setUnreadCount(count) {
      const normalized = Math.max(0, Math.trunc(count));
      currentUnreadCount = normalized;
      await getCurrentWindow().setBadgeCount(normalized > 0 ? normalized : undefined);
      await updateTrayUnreadCount(normalized);
    },
  });
}

function ensureTrayIcon(): Promise<TrayIcon | null> {
  if (trayUnavailable) return Promise.resolve(null);
  trayTask ??= (async () => {
    const existing = await TrayIcon.getById(trayId);
    if (existing) {
      await updateTrayUnreadCount(currentUnreadCount, existing);
      return existing;
    }
    const icon = await defaultWindowIcon();
    const menu = await Menu.new({
      items: [
        {
          id: "show",
          text: "打开 Flare Core",
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
      title: badgeLabel(currentUnreadCount),
      action: (event) => {
        if (event.type === "Click" && event.button === "Left" && event.buttonState === "Up") {
          void revealMainWindow();
        }
      },
    });
    await updateTrayUnreadCount(currentUnreadCount, tray);
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

async function updateTrayUnreadCount(count: number, trayOverride?: TrayIcon | null): Promise<void> {
  const tray = trayOverride ?? await ensureTrayIcon();
  if (!tray) return;
  const label = badgeLabel(count);
  await tray.setTitle(label || null);
  await tray.setTooltip(label ? `Flare Core Tauri - ${label} 条未读` : "Flare Core Tauri");
}

function ensureNotificationPermission(): Promise<boolean> {
  permissionTask ??= (async () => {
    if (await isPermissionGranted()) return true;
    const permission = await requestPermission();
    return permission === "granted";
  })().catch((error) => {
    permissionTask = undefined;
    console.warn("[flare-tauri] notification_permission_failed", error);
    return false;
  });
  return permissionTask;
}

async function requestAttention(payload: DesktopNotificationPayload): Promise<void> {
  const requestType = payload.kind === "call"
    ? UserAttentionType.Critical
    : UserAttentionType.Informational;
  await getCurrentWindow().requestUserAttention(requestType);
}

function notificationText(value: string, fallback: string): string {
  const trimmed = value.trim();
  return (trimmed || fallback).slice(0, 180);
}

function badgeLabel(count: number): string {
  if (count <= 0) return "";
  return count > 99 ? "99+" : String(count);
}
