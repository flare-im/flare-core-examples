# Migrate flare-core-ios-app UI → FlareIMUI kit

Same pattern as the Android migration (see flare-core-android-app/MIGRATION-TO-KIT.md).
Verify = `swift build` + `swift test`.

## Done (verified)
- **Phase 1 · wire ✅**: `Package.swift` — `.package(path: "../../../flare-im-design/ios-im-ui")` +
  `.product(name: "FlareIMUI", package: "ios-im-ui")` (package identity = **dir name** `ios-im-ui`,
  not the declared `FlareIMUI`). `swift build` green.
- **Phase 2a · card family ✅**: `MessageBubbleViews.swift` dispatch — location/card/linkCard/
  system/notification/announcement/vote/task were shared `RichCardMessageView`/`StructuredWorkMessageView`
  placeholders (kit is richer) → delegated to `FlareIMUI.{LocationMessageView, ContactMessageView,
  LinkCardMessageView, SystemMessageView, VoteMessageView, TaskMessageView}`. Added `hasStandaloneKitCard`
  → these render bare (no app bubble; the kit card carries its own surface). Kit types qualified
  `FlareIMUI.*` (the app has same-named views). `swift build` + 43 tests green.
- **Phase 2b · plain text ✅**: `.text` is separate from `.richText` → made `.text` always bare;
  `EmojiAwareTextMessageView` gains `outgoing`, plain case → `FlareIMUI.TextMessageView(text:isSelf:)`
  (lone-pack asset / single-emoji cases kept). `swift build` + 43 tests green.

- **Phase 2c · media ✅**: 
  - **Image**: `MessageMediaViews.swift` — app keeps URL resolution (`resolveMediaDisplayURL`) +
    aspect-aware size (`imageDisplaySize`) + caption + preview; image render → `FlareIMUI.ImageMessageView(
    src: displayURL.absoluteString, width:height: computed size, onTap: preview)`. **No kit change** (the
    iOS kit already takes width/height + the app computes the size). `swift build` + 43 tests green.
  - **Audio → `FlareIMUI.VoiceMessageView`**: app keeps AVPlayer playback + observers + task; visual →
    kit shell (`seconds`/`playing`/`onPlay: togglePlayback`). `swift build` + 43 tests green.

**9 message types now render via FlareIMUI (card family 6 + text + image + audio).**

## App-specific boundaries (kept — like Android)
- **Video**: uses an inline AVKit `VideoPlayer` (plays in-bubble) — richer than the kit's poster
  thumbnail; delegating would downgrade or need app thumbnail-gen + a kit poster slot. Keep app.
- **Sticker/Emoji**: asset packs (`FlareAssetImageView`). **RichText**: richdoc. **Composer**: rich editing.

- **Phase 3 · conversation row ✅** (kit-enriched, no downgrade): `ConversationListView.swift`
  `ConversationCard` → `FlareIMUI.ConversationRowView(item: ConversationRowData(...))`. App maps its
  conversation → the kit row model (title/avatar/preview/time/unread/pinned/muted/mentioned/draft) and
  keeps only the ellipsis-actions button + pinned row background around it. **Kit enriched** (in
  `flare-im-design/ios-im-ui`): added `ConversationRowTag` + `FlareTagTone` + `tags:` on
  `ConversationRowData`, rendered in `ConversationRowView`'s title strip — so the app's Group/Bot/Official
  tags survive (the "补 kit 到与 app 对齐" philosophy). Dead app code removed (`ConversationTag`,
  `tagStrip`, `previewLine`, `avatarColor`, `rowBackground`). Note: the list's lone-emoji-pack *preview
  image* becomes text (minor list cosmetic; chat still renders the emoji). `swift build` + 43 tests green;
  kit builds standalone.

- **Phase 4 · avatar ✅** (kit richer, no downgrade): the app's `AvatarView` (`ConversationListView.swift`)
  was a solid-fill circle with white initials that **never rendered the remote image**. Rewrote it as a thin
  wrapper delegating to `FlareIMUI.AvatarView` (AsyncImage with initials fallback + identity-seeded pastel
  tint + optional presence dot). Kept the app's own call-site signature but swapped `tint:`/external `.frame`
  for a `size:` param (the kit self-frames, so callers must pass size). Updated **all 7 call sites** across
  `ConversationListView` (54/42/44/44), `ChatView` header (42), `MessageRowViews` (30/38). The decorative
  `tint` (orange/blue/brand) is intentionally dropped — the kit's deterministic identity pastel is the
  premium replacement (per the kit's `seedTint` note), and callers now gain real avatar images. **No kit
  change.** `swift build` + 43 tests green.
- **Phase 5 · date pill ✅** (kit parity, no downgrade): `ChatView.swift` `TimelineDatePill` (capsule + text +
  border + shadow) → delegates to `FlareIMUI.DatePillView(label:)` (byte-for-byte the same visual). App keeps
  only the vertical rhythm padding around it. `swift build` + 43 tests green.

## Remaining (app-specific — keep)
- **Chat header** (`ChatView.header`): app-richer than `FlareIMUI.ChatHeaderView`. The kit exposes 3 trailing
  actions (search / call / details); the app renders **5** (disabled phone + disabled video placeholders,
  search, a distinct analytics `chart.bar.xaxis` toggle, and ellipsis) plus a live runtime-status dot driven
  by `messaging.runtimeStatus`. Delegating would drop the video + analytics actions and the runtime dot →
  downgrade. Would need 2+ extra action slots on the kit header to reach parity; left app-side. **Kept.**
- **Message status line** (`MessageRowViews.MessageRow`): app renders combined text `Edited` / `Sending` /
  `Failed`. `FlareIMUI.MessageStatusView` is a pure icon delivery indicator (tick/exclamation) and carries no
  "Edited" semantics — swapping would lose information. **Kept** (different semantics, not a leaf swap).
- EmptyState: app's is already rich (icon + action) → not a clean win.
- Settings: `SettingsView` is a bespoke SDK-lab config panel (text fields / pickers / diagnostics), not a
  generic settings-row list → not a `SettingsListView` parity swap. **Kept.**
- Sticker/Emoji asset packs, richText, video inline player, composer — app-specific (documented above).
