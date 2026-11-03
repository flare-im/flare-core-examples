# Migrate flare-core-flutter-app UI → flare_im_ui kit

Same pattern as Android/iOS (see those apps' MIGRATION-TO-KIT.md). Verify =
`flutter analyze` + `flutter test`.

## Done (verified)
- **Phase 1 · wire ✅**: `pubspec.yaml` — `flare_im_ui: { path: ../../../flare-im-design/flutter-im-ui }`.
  `flutter pub get` resolves `flare_im_ui 0.1.0`; **`flutter analyze` clean**. The kit is now
  available to the app (`package:flare_im_ui/...`).

## Key finding — Flutter differs from Android/iOS
This app is the **design source** the kit was aligned *from* (memory: "flutter-im-ui 对齐
flare-core-flutter-app"), so its per-type views (`lib/interface/widgets/message/views/*`) are
**uniformly richer** than the kit's bodies — not placeholders. Examples:
- `FileView`: white card + icon + filename + size + **messageStatus + footerTimeText** (delivery footer).
- `AnnouncementView`: cream bg + headline + divider + body + publisher/time footer.
- Media views: aspect-aware sizing, caption, preview.

And the **delivery footer (time·status) is entangled** across both the views and `message_bubble`
(`messageStatus:` passed into `ContentView`, plus `_imageBubbleFooterClock` / `_selfStatusCaption`
in the bubble).

**Implication**: unlike Android/iOS (app had `CardRow`/`RichCardMessageView` placeholders that the
kit *upgraded*), delegating Flutter's rich views to the kit's simpler bodies would **downgrade** or
requires disentangling the footer first. The kit's Flutter bodies (`FlareFileMessage`, etc.) ARE
faithful to this app's design **minus the footer** (they were extracted from it), so a faithful
delegation = (a) render the kit body as content + (b) keep the app's footer/status around it.

## Investigated — body/primitive delegation is net-negative here (evidence)
Walked `content_view.dart` (the type dispatcher) against `flare_message_bodies.dart`. Every candidate
delegation is a **downgrade or a visual change**, because the app is the richer source:
- **NotificationView** (98 LOC) branches on `call_signal` → `CallNoticeTile` (duration/video/voice
  notices). Kit `FlareSystemMessage` is a single grey pill → delegating **loses call-signal notices**.
- **TaskView** (343 LOC) renders taskId/detail/**participantUserIds**/metadata-driven state. Kit
  `FlareTaskMessage` is title + meta + a checkbox → delegating **loses participants/detail**.
- **LocationView** (381 LOC): lat/lng/zoom/snapshot resolution + tap-to-map. Kit `FlareLocationMessage`
  is a static 264px card → downgrade.
- **UnreadBadge**: app is a riverpod `ConsumerWidget` watching `unreadProvider`, colored
  `FlareImDesign.destructive` (**red**, WeChat/Feishu convention). Kit `FlareUnreadBadge` is presentational
  and **brand-purple** (`colors.primary`) → delegating **silently recolors every unread badge red→purple**.

**Conclusion**: unlike Android/iOS (which had `CardRow`/`RichCardMessageView` *placeholders* the kit
upgraded), Flutter has no bespoke "kit to replace" — its widgets ARE the design the kit was extracted
*from*. Forcing per-widget delegation trades working richness/established visuals for parity with a
simpler extraction. So Flutter consumes flare-im-design at the **wiring + shared model/token layer**
(Phase 1, done): the kit is a dependency, its `MessageData`/`ConversationSummary` models + tokens are
available, and new shared components (shell/composer/call) can adopt it — but the rich per-type message
bodies stay in the app by design, not by omission. Revisit only if a body genuinely diverges from the kit
(then fix the kit and delegate), or when extracting a NEW screen that has no app-side incumbent.

## Pass 2 — leaf-primitive delegation (presentational primitives only)
Re-swept the app's presentational leaves (`lib/interface/widgets/**`, `lib/shared/**`, and the
inline `_`-widgets in the screens) against the kit's primitives/leaves. The bar for delegating in
this **design-source** app is strict: the app leaf must be a **byte-for-byte visual match** with no
i18n copy, no app-token divergence, and no richer state. Under that bar there was exactly **one**
clean win; everything else is kept (richer / diverged), which is the expected outcome for the source app.

### Delegated (safe, at-parity 1:1)
- **Account presence dot** (`conversation_list_screen.dart`, `_AccountSheetHeader`): a 13px green
  circle with a 2px white ring — structurally identical to **`FlarePresenceDot`**. Now
  `FlarePresenceDot(color: presenceOnline, size: 13, ringColor: Colors.white, ringWidth: 2)`.
  Pixel-identical; the kit primitive exists precisely for this.

### Kept deliberately (richer / diverged / app-specific — long by design)
- **`_PresencePill`** (chat header): dot **+ Chinese label** ("在线"/"离线"), and its dot is
  **ringless** (7px, no border). `FlarePresenceDot` always paints a border → delegating would add a
  hairline and drop the label. Keep.
- **`_ChatTimeDivider`** (`chat_message_list_item.dart`): flat chip **radius 4**, `EDEEF0`/`bgTertiary`
  fill, **Feishu-style** date formatting (`HH:mm` / `昨天` / `M月d日` / cross-year). Kit `FlareDatePill`
  is a **radius-999 pill with border+shadow** taking a pre-formatted English-agnostic label →
  different visual. Keep.
- **`_ConversationEmptyState`** (`conversation_list_screen.dart`): **stateful** icon that switches on
  searching / failed / preparing, i18n title+hint, and a brand-purple **CTA button**. Kit
  `FlareEmptyState` is a static icon+title+desc+optional outlined action → downgrade. Keep.
- **`UnreadBadge`** (nav, riverpod `ConsumerWidget`): **red** (`destructive`) per WeChat/Feishu
  convention; `FlareUnreadBadge` is brand-purple → recolor. Keep (also noted in Pass 1).
- **`ConversationItem`** avatar + inline unread badge: SDK-wired (`CachedNetworkImage` + network-image
  policy + error fallback + pinned overlay + slidable + semantics); the row badge uses the app's own
  `conversationListUnreadBadgeBg` token embedded in a rich row. Not a clean leaf. Keep.
- **Avatars** generally (`_avatarFallback`, `message_bubble`, `card_view` `CircleAvatar`s): the app's
  `avatarPastelForKey` seed + brand-purple account tint differ from `FlareAvatar._seedTint`, and are
  wrapped in caching/policy. Delegating would change the fallback palette. Keep.
- **Typing text** (chat header): plain Chinese inline string ("对方正在输入…" / "N人正在输入…"); kit
  `FlareTypingIndicator` is an animated English dots-bubble/inline widget → different form + copy. Keep.
- All **per-type message views** (`message/views/*`) and the **composer** — see Pass 1 (richer source /
  entangled delivery footer). Keep.

### Kit changes
- **None.** No kit enrichment was needed or made (the delicate design-source app is kept authoritative).

## Verified
- `flutter analyze` — **No issues found** (Pass 2, after the `FlarePresenceDot` delegation).
