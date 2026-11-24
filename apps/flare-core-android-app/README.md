# Flare Core Android Reference App

English · [中文](README.zh-CN.md)

## What This Demonstrates

An official Flare design consumer under active canonical UI migration.
Kotlin, Compose, Android Navigation and lifecycle-aware ViewModels.

## Architecture

`AppSession` owns the public `FlareImClient`; repositories and ViewModels
map SDK state into conversation, lifecycle, message and capability contracts.
Screens compose kit components and invoke SDK actions through their adapters.

## flare-im-design Package Used

`com.flare.im:im-ui-compose:2.0.0-rc.1`, substituted by the relative workspace composite build.

Public `IMAppKit`, `ConversationRow`, `ConversationHeader`, `MessageBubble`,
`Composer` and `ImagePreview` are integrated. The old hand-drawn chat header
is removed. Search sheets, conversation menus and other local composables
are still migration work, not already canonical.

## SDK Adapter

SDK authentication, persistence, event subscriptions, lifecycle transitions,
retry and media transfer stay in the SDK/application layer. Public kit data
contracts and intents form the visual boundary; do not import private renderers.

## Run

```bash
export ANDROID_HOME=/path/to/android/sdk
./gradlew :app:testDirectDebugUnitTest :app:lintDirectDebug :app:assembleDirectDebug
./gradlew :app:compileDirectDebugAndroidTestKotlin
```

## Demo Mode

The runnable app uses the real SDK. There is no automatic fake-data fallback.
Unit/widget fixtures are test inputs, not a supported product demo mode.

## Real SDK Mode

Enter a test user ID on the login screen. Where the SDK connects is not a login
setting: it comes from the build's access configuration (below). The SDK issues
and refreshes connect tokens itself (`auth: {}`) on the Core API of the access
point it is on; do not put signing keys in UI code.
Use isolated test accounts for destructive or send workflows.

## Endpoint configuration

Release builds take `baseUrl` and `websocketUrl` from `FLARE_CORE_ENDPOINTS_JSON`, with optional `quicUrl` and `mediaBaseUrl`. Debug builds default to the Android emulator host `10.0.2.2`. Override them with `FLARE_DEV_CORE_API_URL`, `FLARE_DEV_WS_URL`, `FLARE_DEV_QUIC_URL`, and `FLARE_DEV_MEDIA_URL`. Gradle properties take precedence over environment variables.

## Distribution flavors

The `distribution` dimension sets `app.distribution`, which the release manifest picks a package by.

| Flavor | For | Installs through |
|---|---|---|
| `direct` (default) | The website | A system install session. Only this flavor declares `REQUEST_INSTALL_PACKAGES`. |
| `play` | Google Play | Play In-App Updates. Only this flavor carries the Play dependency. |

Task names carry the flavor: `assembleDirectDebug`, `assemblePlayRelease`,
`compileDirectDebugKotlin`, `testDirectDebugUnitTest`. The update channel is
`stable` unless `-PFLARE_UPDATE_CHANNEL=beta` or the environment variable of
the same name says otherwise.

## Push Notifications

The app uses the platform push module `flare-core-android-push` (which the core
package brings) and, optionally, `flare-core-android-push-getui`:

- `FlareCoreApplication` installs the module (`core/push/AppPush.kt`): notification
  channels, FCM, notification taps and the permission report. Once sign-in or the
  session restore has finished, the module gets the host adapter (`CorePushHost`
  over the signed-in client); sign-out withdraws it and calls `FlarePush.signOut()`,
  which removes this app's notifications and forgets the reported tokens. Token
  registration carries the app's language (`FlarePush.setLocale`).
- `MainActivity` hands every launch intent to `FlarePush.handleLaunchIntent` and
  opens the conversation of each `FlarePush.routes` entry. A tap that starts the
  app is resolved once the session is restored, and only for the signed-in account.
- The permission state is the module's (`FlarePush.permission`); requests go
  through `FlarePushPermission.request`, which records that it asked. After
  sign-in, while notifications are off, the conversation list asks once with the
  kit `PermissionPrompt` soft-ask in a sheet: Turn on notifications while the
  system dialog can still show, Open Settings otherwise. Any choice is remembered
  per account. Settings shows the kit `NotificationDeliverySettings`: whether
  notifications are on and how the battery settings treat background work, with
  a guide to the system pages: battery usage, and auto-start on Huawei, Honor,
  Xiaomi, OPPO and vivo. Nothing is automated.
- A process the push started without any screen has no session: the notification
  is shown from the payload the server rendered.
- While the app is open, the engine decides each alert and hands in-app ones over
  as `notification.present` (surface `inApp`): `MessageAlerts` feeds them to the
  kit `InAppNotificationHost` at the root (tapping a banner opens the conversation
  like a notification tap) and the system notification sound plays when the engine
  asks. The chat screen reports the conversation on screen and `MainActivity` the
  foreground (`notification.setFocus`). Settings adds the kit
  `NotificationAlertSettings`: quiet hours, preview and the other-device behaviour,
  shared by the account's devices, saved through `notification.updateSettings`
  (shown at once, rolled back and read again when a save fails).
- The client is process-level: `FlareCoreApplication` owns the one
  `FlareRootViewModel` (and its `FlareAppStore`) in its own view model store, so
  closing the screen does not release it and the link stays up in the background.
  `AppPush` attaches the module's background presenter at start; the module tells
  the engine once notifications are allowed and a session is ready, and detaches
  when the permission is revoked. While it is attached, alerts the engine decides
  in the background are posted by the module as system notifications.
- Resident connection mode (`flare-core-android-keepalive`, `core/push/AppKeepAlive.kt`)
  is offered in settings only when the build has no push provider (no
  `google-services.json`, no Getui app id). Turning it on starts the foreground
  service, turns push bindings off (`clearPushToken` for every provider) and keeps
  the presenter attached; after a reboot or an update the service restarts and
  restores the session without a screen. Turning it off reverses it. While it is
  on and battery optimization is not off, the kit adds a row that opens the battery
  optimization settings.

### Firebase (FCM)

Put the Firebase client configuration of your Firebase project at
`app/google-services.json` (git-ignored: each deployment brings its own). The
Google services plugin is applied only when that file exists. Without it the app
builds and runs, FCM stays off and the rest of push works. The Firebase Android app
is registered with the `applicationId` (`com.flare.im.app`), and the server's FCM
credentials must belong to the same Firebase project.

### Getui (optional, devices in mainland China)

Getui is off unless the build has a Getui app id, given as a Gradle property or the
environment variable of the same name:

```bash
./gradlew :app:assembleDirectRelease -PFLARE_GETUI_APP_ID=<Getui app id>
```

The id fills the Getui SDK's `GETUI_APPID` manifest placeholder and
`BuildConfig.FLARE_GETUI_APP_ID`. With it the app starts Getui after sign-in, so no
push SDK starts before someone signed in; without it Getui is compiled in but never
initialised. A build for Chinese app stores also needs the privacy policy accepted
before sign-in. Getui's artifacts come from its own Maven repository, which
`settings.gradle.kts` uses for `com.getui` coordinates only.

A killed app is reached through the phone makers' own channels, which Getui's vendor
plugins provide. Add the plugins and each maker's app ids and keys as Getui's
Android integration guide describes for the SDK version pinned in
`flare-core-android-push-getui` (Huawei and Honor also need the maker's
configuration file in `app/`). Where a maker asks which notification channel the app
shows messages on, use the module's channel ids: `flare.messages`,
`flare.mentions`, `flare.urgent`, `flare.quiet`.

### Instant messaging category (operator)

Before releasing in mainland China, the operator applies for the instant messaging
category with each phone maker in the maker's developer console: Huawei (message
self-classification), Honor (notification importance), Xiaomi (private message
channels and templates for direct and group chats), OPPO (the communication and
service channel and a private message template) and vivo (message classification,
plus registering the app's notification channels). Without an approved category,
maker notifications count as marketing: daily limits, folded or silent, and no app
code works around it. Approval takes time outside your control, so apply early,
then put the granted values in the Getui credentials of the application on the
server, under `getui.android_vendor`:

- `huawei_category`, `honor_importance`, `vivo_category`;
- Xiaomi: `xiaomi_channel_id` with `xiaomi_template_id` (one needs the other), and
  optionally `xiaomi_group_channel_id` and `xiaomi_group_template_id` for group
  chats (each falls back to the direct-chat value);
- OPPO: `oppo_private_template_id`, optionally `oppo_notify_level` (1, 2 or 16),
  and `oppo_channel_id` only while the account still has the old private channel.

The templates use the variables `title` and `content`, which the server fills with
the title and body it renders. vivo registers the channels by id and Chinese name:
聊天消息 (`flare.messages`), 聊天中@我的消息 (`flare.mentions`), 紧急聊天消息
(`flare.urgent`), 聊天消息静默更新 (`flare.quiet`). What to apply for, example
templates and how to check the result are in the
[vendor instant messaging category handbook](https://github.com/flare-im/flare-knowledge-base/blob/main/docs/operations/push-vendor-im-category.md)
of the Flare knowledge base.

## Supported Features

Conversation/message flows are the Core scope: session initialization, list,
opening a conversation, timeline, composer, send/retry, message actions, search,
media and SDK diagnostics. Integration and canonical-renderer coverage differ by
platform. See the [UI reuse policy](https://github.com/flare-im/flare-im-design/blob/main/docs/ui-component-reuse-policy.md) for component ownership.
Contact-directory, group-directory and relationship navigation require a Social
adapter. Group conversations are messaging targets, not group administration.

## Platform-Specific Integration

Activity lifecycle, system back, IME, navigation, permissions (the notification
permission included), file/camera selection and JNI loading are host responsibilities. Use `scripts/sync_ffi.sh`
after building the matching native SDK artifacts.

## Localization integration

Kit strings follow the app language. Swift custom strings use the configuration closure. See [native localization integration](../../docs/native-localization.md) for the migration, generated resources, and platform adapters.
