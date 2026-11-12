/**
 * The page's system notifications: the browser's `Notification` through the SDK presenter, and the permission built
 * on it. The notifier (MessageAlerts) shows through this presenter, and the soft-ask and the settings row share the
 * permission, so one answer updates both.
 */
import { browserNotificationPresenter } from "@flare-im/sdk/notifications";
import { createNotificationPermission } from "../../../../../flare-core-sdk/examples/shared/vue-reference/workbench/app";

export const notificationPresenter = browserNotificationPresenter();
export const notificationPermission = createNotificationPermission(notificationPresenter);
