import 'package:extended_text_field/extended_text_field.dart';
import 'package:flare_im/application/providers/locale_provider.dart';
import 'package:flare_im/infrastructure/media/composer_pack_assets.dart';
import 'package:flare_im/infrastructure/media/composer_recent_emoji_store.dart';
import 'package:flare_im/infrastructure/media/composer_static_asset_image.dart';
import 'package:flare_im/infrastructure/media/plain_text_markdown_detect.dart';
import 'package:flare_im/interface/widgets/composer/composer_emoji_pack_thumb.dart';
import 'package:flare_im/interface/widgets/composer/composer_emoji_span_builder.dart';
import 'package:flare_im/interface/widgets/composer/composer_inline_text_field.dart';
import 'package:flare_im/interface/widgets/composer/composer_models.dart';
import 'package:flare_im/shared/i18n/flare_messages.dart';
import 'package:flare_im_ui/flare_im_ui.dart' as kit_sizes show FlareSizes;
import 'package:flare_im_ui/flare_im_ui.dart' as kit_theme show FlareColors;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 表情来自 `assets/emoji/*.webp`，贴纸来自 `assets/stickers/**`。
/// 选择器内资源用 [ComposerStaticAssetImage] 仅显示首帧（静态）；会话内仍可用动图展示。
/// 点表情：无 [onPanelSend] 时插入 `[key]` 并关闭；若仅提供 [onEmojiPackTapSend] 则立即回调。
/// 若同时提供 [onPanelSend] 与 [onEmojiPackTapSend]，点表情仍写入面板输入框（可与文字组合），由用户点「发送」提交。
/// 点贴纸立即走 [onPickSticker]（发送由上层处理，并关闭面板）。
///
/// 若提供 [onPanelSend]，会显示草稿输入框；点选表情写入草稿（不关闭），点「发送」传入当前草稿全文后**不关闭**面板以便继续选表情/输入。
///
/// 若传入 [panelDraftController]，则与主栏**共用**同一 [TextEditingController]（内容与选区一致）。
/// **不要**共用 [FocusNode]：面板顶栏使用内部焦点，避免与主栏两个 [TextField] 抢同一节点导致无法聚焦。
/// 未传入 [panelDraftController] 时使用面板内独立草稿框。
Future<void> showComposerEmojiStickerSheet(
  BuildContext context, {
  required void Function(String insert) onInsertBracket,
  void Function(String packKey)? onEmojiPackTapSend,
  void Function(ComposerStickerPick pick)? onPickSticker,
  void Function(String sheetDraft)? onPanelSend,

  /// 与主栏共用时可传入，使面板顶栏与主输入内容、选区一致。
  TextEditingController? panelDraftController,
  int? panelMaxLength,
  bool panelDraftEnabled = true,
  String? panelHintText,
  ValueChanged<String>? onPanelDraftChanged,

  /// 与 [MessageComposer] 主栏一致：行数、样式、展开、键盘发送。
  int panelMinLines = 1,
  int panelMaxLines = 5,
  SpecialTextSpanBuilder? panelSpecialTextSpanBuilder,
  VoidCallback? onPanelExpandPressed,
  ValueChanged<String>? onPanelSubmitted,
  int initialBottomTab = 0,
}) async {
  final h = MediaQuery.sizeOf(context).height;
  final sheetHeight = (h * 0.54).clamp(340.0, 540.0);

  await showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    backgroundColor: Colors.transparent,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: Column(
        children: [
          Expanded(
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (_) {
                final nav = Navigator.of(ctx, rootNavigator: true);
                if (nav.canPop()) nav.pop();
              },
              child: const SizedBox.expand(),
            ),
          ),
          Container(
            height: sheetHeight,
            color: kit_theme.FlareColors.of(ctx).bgSecondary,
            child: _ComposerEmojiStickerPanel(
              initialBottomTab: initialBottomTab,
              panelDraftController: panelDraftController,
              panelMaxLength: panelMaxLength,
              panelDraftEnabled: panelDraftEnabled,
              panelHintText: panelHintText,
              onPanelDraftChanged: onPanelDraftChanged,
              panelMinLines: panelMinLines,
              panelMaxLines: panelMaxLines,
              panelSpecialTextSpanBuilder: panelSpecialTextSpanBuilder,
              onPanelExpandPressed: onPanelExpandPressed,
              onPanelSubmitted: onPanelSubmitted,
              onInsertBracket: (s) {
                final nav = Navigator.of(ctx, rootNavigator: true);
                if (nav.canPop()) nav.pop();
                onInsertBracket(s);
              },
              onEmojiPackTapSend: onEmojiPackTapSend == null
                  ? null
                  : (key) {
                      final nav = Navigator.of(ctx, rootNavigator: true);
                      if (nav.canPop()) nav.pop();
                      onEmojiPackTapSend(key);
                    },
              onPickSticker: onPickSticker == null
                  ? null
                  : (pick) {
                      final nav = Navigator.of(ctx, rootNavigator: true);
                      if (nav.canPop()) nav.pop();
                      onPickSticker(pick);
                    },
              onPanelSend: onPanelSend == null
                  ? null
                  : (String sheetDraft) {
                      onPanelSend(sheetDraft);
                    },
            ),
          ),
        ],
      ),
    ),
  );
}

class _ComposerEmojiStickerPanel extends ConsumerStatefulWidget {
  const _ComposerEmojiStickerPanel({
    required this.initialBottomTab,
    required this.onInsertBracket,
    this.onEmojiPackTapSend,
    this.onPickSticker,
    this.onPanelSend,
    this.panelDraftController,
    this.panelMaxLength,
    this.panelDraftEnabled = true,
    this.panelHintText,
    this.onPanelDraftChanged,
    this.panelMinLines = 1,
    this.panelMaxLines = 5,
    this.panelSpecialTextSpanBuilder,
    this.onPanelExpandPressed,
    this.onPanelSubmitted,
  });

  final int initialBottomTab;
  final void Function(String insert) onInsertBracket;
  final void Function(String packKey)? onEmojiPackTapSend;
  final void Function(ComposerStickerPick pick)? onPickSticker;
  final void Function(String sheetDraft)? onPanelSend;
  final TextEditingController? panelDraftController;
  final int? panelMaxLength;
  final bool panelDraftEnabled;
  final String? panelHintText;
  final ValueChanged<String>? onPanelDraftChanged;
  final int panelMinLines;
  final int panelMaxLines;
  final SpecialTextSpanBuilder? panelSpecialTextSpanBuilder;
  final VoidCallback? onPanelExpandPressed;
  final ValueChanged<String>? onPanelSubmitted;

  @override
  ConsumerState<_ComposerEmojiStickerPanel> createState() =>
      _ComposerEmojiStickerPanelState();
}

class _ComposerEmojiStickerPanelState
    extends ConsumerState<_ComposerEmojiStickerPanel> {
  FlareComposerCopy get _c => ref.read(flareMessagesProvider).composer;

  late int _bottomTab;
  List<String> _recentKeys = [];
  TextEditingController? _ownedDraftController;
  FocusNode? _ownedDraftFocus;
  bool _sharedDraftRefreshScheduled = false;

  int get _packageCount => widget.onPickSticker == null
      ? 0
      : ComposerPackAssets.stickerPackageIdsInOrder.length;

  int get _maxTab => _packageCount;

  List<String> get _packageIds => ComposerPackAssets.stickerPackageIdsInOrder;

  bool get _showDraftField => widget.onPanelSend != null;

  bool get _usesSharedDraft => widget.panelDraftController != null;

  TextEditingController get _draft =>
      widget.panelDraftController ?? _ownedDraftController!;

  void _onSharedDraftControllerChanged() {
    if (!mounted || _sharedDraftRefreshScheduled) return;
    _sharedDraftRefreshScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sharedDraftRefreshScheduled = false;
      if (mounted) setState(() {});
    });
  }

  @override
  void initState() {
    super.initState();
    _bottomTab = widget.initialBottomTab.clamp(0, _maxTab);
    if (_showDraftField) {
      _ownedDraftFocus = FocusNode();
      if (!_usesSharedDraft) {
        _ownedDraftController = TextEditingController();
      } else {
        widget.panelDraftController!.addListener(
          _onSharedDraftControllerChanged,
        );
      }
    }
    _loadRecent();
  }

  @override
  void dispose() {
    if (_usesSharedDraft && _showDraftField) {
      widget.panelDraftController?.removeListener(
        _onSharedDraftControllerChanged,
      );
    }
    _ownedDraftController?.dispose();
    _ownedDraftFocus?.dispose();
    super.dispose();
  }

  Future<void> _loadRecent() async {
    final raw = await ComposerRecentEmojiStore.load();
    if (!mounted) return;
    setState(() => _recentKeys = raw);
  }

  Future<void> _onEmojiKey(String key) async {
    await ComposerRecentEmojiStore.record(key);
    if (!mounted) return;
    if (_showDraftField && !widget.panelDraftEnabled) return;
    if (_showDraftField) {
      _insertIntoDraft('[$key]');
      return;
    }
    if (widget.onEmojiPackTapSend != null) {
      widget.onEmojiPackTapSend!(key);
      return;
    }
    widget.onInsertBracket('[$key]');
  }

  void _insertIntoDraft(String insert) {
    final v = _draft.value;
    final t = v.text;
    final s = v.selection;
    final start = s.start >= 0 ? s.start : t.length;
    final end = s.end >= 0 ? s.end : t.length;
    var newText = t.replaceRange(start, end, insert);
    if (widget.panelMaxLength != null &&
        newText.length > widget.panelMaxLength!) {
      newText = newText.substring(0, widget.panelMaxLength!);
    }
    final newOffset = (start + insert.length).clamp(0, newText.length);
    _draft.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newOffset),
    );
    widget.onPanelDraftChanged?.call(newText);
    setState(() {});
  }

  String? get _locale => Localizations.maybeLocaleOf(context)?.toLanguageTag();

  /// 与 [MessageComposer._buildInputRow] 使用同一套 [ComposerInlineTextField] 参数（独立 [FocusNode]）。
  Widget _buildDraftTextField() {
    assert(_ownedDraftFocus != null, 'draft focus only when _showDraftField');
    final span =
        widget.panelSpecialTextSpanBuilder ??
        ComposerEmojiSpanBuilder(inlineSize: 15 * 1.72, localeTag: _locale);
    final field = ComposerInlineTextField(
      controller: _draft,
      focusNode: _ownedDraftFocus!,
      hintText: widget.panelHintText ?? _c.emojiSearchHint,
      minLines: widget.panelMinLines,
      maxLines: widget.panelMaxLines,
      enabled: widget.panelDraftEnabled,
      maxLength: widget.panelMaxLength,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.send,
      specialTextSpanBuilder: span,
      onChanged: widget.onPanelDraftChanged,
      onSubmitted: widget.onPanelSubmitted,
      onExpandPressed: widget.onPanelExpandPressed,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
    );
    if (widget.onPanelSubmitted == null) return field;
    return Focus(
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey != LogicalKeyboardKey.enter &&
            event.logicalKey != LogicalKeyboardKey.numpadEnter) {
          return KeyEventResult.ignored;
        }
        if (HardwareKeyboard.instance.isShiftPressed) {
          return KeyEventResult.ignored;
        }
        widget.onPanelSubmitted!(_draft.text);
        return KeyEventResult.handled;
      },
      child: field,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 2, bottom: 2),
            decoration: BoxDecoration(
              color: kit_theme.FlareColors.of(context).borderPrimary,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
        if (_showDraftField)
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 0, 6, 4),
            child: _buildDraftTextField(),
          ),
        Expanded(
          child: ColoredBox(
            color: kit_theme.FlareColors.of(context).bgSecondary,
            child: _bottomTab == 0
                ? _buildEmojiPage()
                : _buildStickerPage(_packageIds[_bottomTab - 1]),
          ),
        ),
        _buildBottomBar(context),
      ],
    );
  }

  Widget _buildEmojiPage() {
    final allKeys = ComposerPackAssets.sortedEmojiKeys;
    final recent = _recentKeys.where(allKeys.contains).take(21).toList();

    if (allKeys.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _c.emojiAssetsMissing,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: kit_theme.FlareColors.of(context).textSecondary,
              fontSize: kit_sizes.FlareSizes.fontSizeLg,
              height: 1.4,
            ),
          ),
        ),
      );
    }

    return CustomScrollView(
      slivers: [
        if (recent.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
              child: Text(
                _c.frequentlyUsed,
                style: TextStyle(
                  fontSize: kit_sizes.FlareSizes.fontSizeSm,
                  fontWeight: FontWeight.w600,
                  color: kit_theme.FlareColors.of(
                    context,
                  ).textSecondary.withValues(alpha: 0.95),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 52,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                scrollDirection: Axis.horizontal,
                itemCount: recent.length,
                separatorBuilder: (context, _) => const SizedBox(width: 6),
                itemBuilder: (context, i) {
                  final key = recent[i];
                  return ComposerEmojiPackThumb(
                    emojiKey: key,
                    locale: _locale,
                    onTap: () => _onEmojiKey(key),
                  );
                },
              ),
            ),
          ),
        ],
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(8, recent.isEmpty ? 6 : 10, 8, 6),
            child: Text(
              _c.defaultEmoji,
              style: TextStyle(
                fontSize: kit_sizes.FlareSizes.fontSizeSm,
                fontWeight: FontWeight.w600,
                color: kit_theme.FlareColors.of(
                  context,
                ).textSecondary.withValues(alpha: 0.95),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              childAspectRatio: 1,
            ),
            delegate: SliverChildBuilderDelegate((context, i) {
              final key = allKeys[i];
              return ComposerEmojiPackThumb(
                emojiKey: key,
                locale: _locale,
                onTap: () => _onEmojiKey(key),
              );
            }, childCount: allKeys.length),
          ),
        ),
      ],
    );
  }

  Widget _buildStickerPage(String packageId) {
    if (widget.onPickSticker == null) {
      return const SizedBox.shrink();
    }
    final items = ComposerPackAssets.stickersForPackage(packageId);
    if (items.isEmpty) {
      return Center(
        child: Text(
          _c.noWebpInPack,
          style: TextStyle(
            color: kit_theme.FlareColors.of(context).textSecondary,
          ),
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final it = items[i];
        return Tooltip(
          message: it.alt,
          child: Material(
            color: kit_theme.FlareColors.of(context).bgPrimary,
            borderRadius: BorderRadius.circular(10),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => widget.onPickSticker!(
                ComposerStickerPick(
                  stickerId: it.stickerId,
                  packageId: it.packageId,
                  assetPath: it.assetPath,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: ComposerStaticAssetImage(
                  assetPath: it.assetPath,
                  fit: BoxFit.contain,
                  decodeSize: 128,
                  error: Icon(
                    Icons.broken_image_outlined,
                    color: kit_theme.FlareColors.of(context).textSecondary,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    final sendEnabled = widget.onPanelSend != null && widget.panelDraftEnabled;
    return Material(
      color: kit_theme.FlareColors.of(context).bgPrimary,
      elevation: 0,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 3, 8, 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              IconButton(
                tooltip: _c.moreEmojiPacks,
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                padding: EdgeInsets.zero,
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(_c.customEmojiPackPlaceholder)),
                  );
                },
                icon: Icon(
                  Icons.add_circle_outline,
                  color: kit_theme.FlareColors.of(context).textSecondary,
                ),
              ),
              _BottomPackChip(
                selected: _bottomTab == 0,
                onTap: () => setState(() => _bottomTab = 0),
                child: Icon(
                  Icons.emoji_emotions_outlined,
                  size: 20,
                  color: _bottomTab == 0
                      ? kit_theme.FlareColors.of(context).primary
                      : kit_theme.FlareColors.of(context).textSecondary,
                ),
              ),
              if (widget.onPickSticker != null)
                for (var i = 0; i < _packageIds.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: _BottomPackChip(
                      selected: _bottomTab == i + 1,
                      onTap: () => setState(() => _bottomTab = i + 1),
                      child: _StickerPackTabIcon(packageId: _packageIds[i]),
                    ),
                  ),
              const Spacer(),
              FilledButton(
                onPressed: sendEnabled
                    ? () {
                        final draft = _draft.text;
                        widget.onPanelSend!(draft);
                        if (!_usesSharedDraft) {
                          _draft.clear();
                        }
                        setState(() {});
                      }
                    : null,
                style: FilledButton.styleFrom(
                  backgroundColor: kit_theme.FlareColors.of(context).primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  _c.send,
                  style: const TextStyle(
                    fontSize: kit_sizes.FlareSizes.fontSizeMd,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomPackChip extends StatelessWidget {
  const _BottomPackChip({
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? kit_theme.FlareColors.of(context).bgSelected
          : kit_theme.FlareColors.of(context).bgTertiary,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(width: 36, height: 36, child: Center(child: child)),
      ),
    );
  }
}

class _StickerPackTabIcon extends StatelessWidget {
  const _StickerPackTabIcon({required this.packageId});

  final String packageId;

  @override
  Widget build(BuildContext context) {
    final first = ComposerPackAssets.firstStickerInPackage(packageId);
    if (first == null) {
      return Icon(
        Icons.collections_outlined,
        size: 20,
        color: kit_theme.FlareColors.of(context).textSecondary,
      );
    }
    return ClipOval(
      child: SizedBox(
        width: 28,
        height: 28,
        child: ComposerStaticAssetImage(
          assetPath: first.assetPath,
          fit: BoxFit.cover,
          decodeSize: 64,
        ),
      ),
    );
  }
}

/// 「+」更多面板：图片 / 视频 / 文件 / 文件夹等；可选「表情与贴纸」；后续可扩音视频通话等入口。
Future<void> showComposerAttachSheet(
  BuildContext context, {
  required void Function(ComposerPickMediaKind kind) onPick,
  required FlareComposerCopy i18n,
  VoidCallback? onOpenEmojiSticker,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    isDismissible: true,
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 8, bottom: 12),
                  decoration: BoxDecoration(
                    color: kit_theme.FlareColors.of(context).borderPrimary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  i18n.more,
                  style: TextStyle(
                    fontSize: kit_sizes.FlareSizes.fontSize2xl,
                    fontWeight: FontWeight.w600,
                    color: kit_theme.FlareColors.of(context).textPrimary,
                  ),
                ),
              ),
              if (onOpenEmojiSticker != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: kit_theme.FlareColors.of(
                          context,
                        ).borderSecondary,
                      ),
                    ),
                    leading: Icon(
                      Icons.emoji_emotions_outlined,
                      color: kit_theme.FlareColors.of(context).textSecondary,
                    ),
                    title: Text(i18n.emojiSticker),
                    subtitle: Text(
                      i18n.emojiStickerDesc,
                      style: TextStyle(
                        fontSize: kit_sizes.FlareSizes.fontSizeSm,
                        color: kit_theme.FlareColors.of(
                          context,
                        ).textSecondary.withValues(alpha: 0.9),
                      ),
                    ),
                    onTap: () {
                      final nav = Navigator.of(ctx, rootNavigator: true);
                      if (nav.canPop()) nav.pop();
                      onOpenEmojiSticker();
                    },
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _AttachTile(
                            icon: Icons.image_outlined,
                            label: i18n.image,
                            onTap: () {
                              final nav = Navigator.of(
                                ctx,
                                rootNavigator: true,
                              );
                              if (nav.canPop()) nav.pop();
                              onPick(ComposerPickMediaKind.image);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _AttachTile(
                            icon: Icons.videocam_outlined,
                            label: i18n.video,
                            onTap: () {
                              final nav = Navigator.of(
                                ctx,
                                rootNavigator: true,
                              );
                              if (nav.canPop()) nav.pop();
                              onPick(ComposerPickMediaKind.video);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _AttachTile(
                            icon: Icons.insert_drive_file_outlined,
                            label: i18n.file,
                            onTap: () {
                              final nav = Navigator.of(
                                ctx,
                                rootNavigator: true,
                              );
                              if (nav.canPop()) nav.pop();
                              onPick(ComposerPickMediaKind.file);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _AttachTile(
                            icon: Icons.photo_library_outlined,
                            label: i18n.album,
                            subtitle: i18n.imageAndVideo,
                            onTap: () {
                              final nav = Navigator.of(
                                ctx,
                                rootNavigator: true,
                              );
                              if (nav.canPop()) nav.pop();
                              onPick(ComposerPickMediaKind.imageOrVideo);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _AttachTile(
                            icon: Icons.folder_open_outlined,
                            label: i18n.folder,
                            onTap: () {
                              final nav = Navigator.of(
                                ctx,
                                rootNavigator: true,
                              );
                              if (nav.canPop()) nav.pop();
                              onPick(ComposerPickMediaKind.folder);
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _AttachTile extends StatelessWidget {
  const _AttachTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kit_theme.FlareColors.of(context).bgTertiary,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 28,
                color: kit_theme.FlareColors.of(context).textSecondary,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: kit_sizes.FlareSizes.fontSizeMd,
                  fontWeight: FontWeight.w500,
                  color: kit_theme.FlareColors.of(context).textPrimary,
                ),
              ),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    subtitle!,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: kit_sizes.FlareSizes.fontSizeXs,
                      color: kit_theme.FlareColors.of(
                        context,
                      ).textSecondary.withValues(alpha: 0.95),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 展开大输入区（与主输入共用 [controller] / [focusNode]）。
/// 使用 [ComposerInlineTextField] 与主栏/表情草稿同款白底无描边样式；底部浅灰工具条。
/// 收起：点击 Sheet 上方空白（与表情面板一致）或系统遮罩。
Future<void> showComposerExpandedEditor(
  BuildContext context, {
  required TextEditingController controller,
  required FocusNode focusNode,
  required String placeholder,
  required int? maxLength,
  required bool disabled,
  required ValueChanged<String> onChanged,
  required VoidCallback onSend,
  required FlareComposerCopy i18n,
  Future<void> Function()? onEmojiSticker,
  void Function(ComposerPickMediaKind kind)? onPickMedia,
  void Function(String insert)? onInsertAtCursor,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    backgroundColor: Colors.transparent,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    builder: (ctx) {
      final keyboardBottom = MediaQuery.viewInsetsOf(ctx).bottom;
      final hintText = placeholder.trim().isNotEmpty
          ? placeholder.trim()
          : i18n.sendMessage;
      final bottomBreathing = keyboardBottom > 0 ? 0.0 : 18.0;
      final localeTag = Localizations.maybeLocaleOf(ctx)?.toLanguageTag();
      final screenH = MediaQuery.sizeOf(ctx).height;
      final panelH = (screenH * 0.58).clamp(280.0, screenH * 0.92);

      Future<void> emoji() async {
        if (onEmojiSticker != null) {
          await onEmojiSticker();
        } else if (ctx.mounted) {
          ScaffoldMessenger.of(
            ctx,
          ).showSnackBar(SnackBar(content: Text(i18n.emojiNotWired)));
        }
      }

      void pick(ComposerPickMediaKind k) {
        if (onPickMedia != null) {
          onPickMedia(k);
        } else if (ctx.mounted) {
          ScaffoldMessenger.of(
            ctx,
          ).showSnackBar(SnackBar(content: Text(i18n.attachNotWired)));
        }
      }

      void insert(String s) {
        if (onInsertAtCursor != null) {
          onInsertAtCursor(s);
        } else if (ctx.mounted) {
          ScaffoldMessenger.of(
            ctx,
          ).showSnackBar(SnackBar(content: Text(i18n.insertNotWired)));
        }
      }

      void comingSoon(String name) {
        if (ctx.mounted) {
          ScaffoldMessenger.of(
            ctx,
          ).showSnackBar(SnackBar(content: Text(i18n.inDev(name))));
        }
      }

      Widget tbIcon(IconData icon, String tip, VoidCallback? onTap) {
        final c = disabled
            ? kit_theme.FlareColors.of(
                context,
              ).textSecondary.withValues(alpha: 0.38)
            : kit_theme.FlareColors.of(context).textSecondary;
        return IconButton(
          tooltip: tip,
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          onPressed: disabled || onTap == null ? null : onTap,
          icon: Icon(icon, size: 22, color: c),
        );
      }

      return Padding(
        padding: EdgeInsets.only(bottom: keyboardBottom + bottomBreathing),
        child: Column(
          children: [
            Expanded(
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (_) {
                  final nav = Navigator.of(ctx, rootNavigator: true);
                  if (nav.canPop()) nav.pop();
                },
                child: const SizedBox.expand(),
              ),
            ),
            SizedBox(
              height: panelH,
              child: Material(
                color: kit_theme.FlareColors.of(context).bgSecondary,
                child: StatefulBuilder(
                  builder: (modalCtx, setModalState) {
                    void finishSendLive() {
                      if (controller.text.trim().isEmpty || disabled) return;
                      onSend();
                      if (ctx.mounted) {
                        final nav = Navigator.of(ctx, rootNavigator: true);
                        if (nav.canPop()) nav.pop();
                      }
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                            child: ComposerInlineTextField(
                              expands: true,
                              controller: controller,
                              focusNode: focusNode,
                              hintText: hintText,
                              enabled: !disabled,
                              maxLength: maxLength,
                              style: TextStyle(
                                fontSize: kit_sizes.FlareSizes.fontSize2xl,
                                height: 1.45,
                                color: kit_theme.FlareColors.of(
                                  context,
                                ).textPrimary,
                              ),
                              hintFontSize: 16,
                              specialTextSpanBuilder:
                                  PlainTextMarkdownDetect.isMarkdown(
                                    controller.text,
                                  )
                                  ? null
                                  : ComposerEmojiSpanBuilder(
                                      inlineSize: 16 * 1.72,
                                      localeTag: localeTag,
                                    ),
                              textInputAction: TextInputAction.send,
                              contentPadding: const EdgeInsets.all(14),
                              borderRadius: 6,
                              onChanged: (s) {
                                onChanged(s);
                                setModalState(() {});
                              },
                              onSubmitted: (_) => finishSendLive(),
                            ),
                          ),
                        ),
                        ListenableBuilder(
                          listenable: controller,
                          builder: (context, _) {
                            final canSubmitNow =
                                controller.text.trim().isNotEmpty && !disabled;
                            return Container(
                              width: double.infinity,
                              padding: EdgeInsets.fromLTRB(
                                4,
                                2,
                                6,
                                keyboardBottom > 0 ? 4 : 10,
                              ),
                              decoration: BoxDecoration(
                                color: kit_theme.FlareColors.of(
                                  context,
                                ).bgSecondary,
                                border: Border(
                                  top: BorderSide(
                                    color: kit_theme.FlareColors.of(
                                      context,
                                    ).borderSecondary.withValues(alpha: 0.95),
                                    width: 0.5,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceEvenly,
                                      children: [
                                        tbIcon(
                                          Icons.emoji_emotions_outlined,
                                          i18n.emojiSticker,
                                          () => emoji(),
                                        ),
                                        tbIcon(
                                          Icons.alternate_email,
                                          i18n.mention,
                                          () => insert('@'),
                                        ),
                                        tbIcon(
                                          Icons.image_outlined,
                                          i18n.image,
                                          () =>
                                              pick(ComposerPickMediaKind.image),
                                        ),
                                        tbIcon(
                                          Icons.text_fields_rounded,
                                          i18n.richText,
                                          () => comingSoon(i18n.richText),
                                        ),
                                        tbIcon(
                                          Icons.format_indent_increase,
                                          i18n.increaseIndent,
                                          () => comingSoon(i18n.indent),
                                        ),
                                        tbIcon(
                                          Icons.format_indent_decrease,
                                          i18n.decreaseIndent,
                                          () => comingSoon(i18n.indent),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: i18n.send,
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.all(8),
                                    constraints: const BoxConstraints(
                                      minWidth: 44,
                                      minHeight: 44,
                                    ),
                                    onPressed: canSubmitNow
                                        ? finishSendLive
                                        : null,
                                    icon: Icon(
                                      Icons.send_rounded,
                                      size: 22,
                                      color: canSubmitNow
                                          ? kit_theme.FlareColors.of(
                                              context,
                                            ).primary
                                          : kit_theme.FlareColors.of(
                                              context,
                                            ).textDisabled,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
