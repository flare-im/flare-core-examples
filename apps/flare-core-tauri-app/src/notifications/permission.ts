/**
 * The app's system notifications: the Tauri notification plugin through the app's presenter, and the permission built
 * on it. The notifier (MessageAlerts) shows through this presenter, and the soft-ask and the settings row share the
 * permission, so one answer updates both (the plugin reports a refusal only to the presenter that asked).
 */
import { createNotificationPermission } from "../../../../../flare-core-sdk/examples/shared/vue-reference/workbench/app";
import { tauriNotificationPresenter } from "../desktopNotifications";

export const notificationPresenter = tauriNotificationPresenter();
export const notificationPermission = createNotificationPermission(notificationPresenter);
