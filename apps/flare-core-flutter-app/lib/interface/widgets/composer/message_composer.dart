import 'dart:async';

import 'package:flare_im/application/providers/chat_outbound_provider.dart';
import 'package:flare_im/application/providers/locale_provider.dart';
import 'package:flare_im/infrastructure/media/plain_text_markdown_detect.dart';
import 'package:flare_im/interface/widgets/composer/composer_emoji_span_builder.dart';
import 'package:flare_im/interface/widgets/composer/composer_models.dart';
import 'package:flare_im/interface/widgets/composer/composer_sheets.dart';
import 'package:flare_im/interface/widgets/composer/draft_idle_scheduler.dart';
import 'package:flare_im/shared/i18n/flare_messages.dart';
import 'package:flare_im_ui/flare_im_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

export 'composer_models.dart';

/// 文本输入：输入态（typing）、草稿变更回调（输入静默后调 SDK）。
/// 输入区由组件库 Composer 管理，宿主只连接 SDK 行为和权限。
/// 下行六格均分工具条（线框灰图标）；点「+」展开 4×2 宫格，展开时为「×」同风格收起。
/// 可选 [composeTargetName] → 占位「发送给 xxx」。
/// 发送（文本 / 点选表情立即发 / 贴纸意图）经 [chatOutboundProvider] 派发，由 [ChatScreen] 统一调 SDK。
/// IME「发送」键、[TextInputAction.send]、物理回车（Shift+回车换行）均走同一出站总线。
class MessageComposer extends ConsumerStatefulWidget {
  final String conversationId;
  final String? initialText;
  final void Function(bool isTyping)? onTypingChanged;
  final void Function(String text)? onDraftChanged;

  /// 引用回复条；为 null 时不展示。
  final ComposerReplyQuote? replyQuote;
  final VoidCallback? onClearReply;

  /// 「+」更多入口（附件等）；后续可扩展音视频通话等，未实现业务时可仅 SnackBar 占位。
  final void Function(ComposerPickMediaKind kind)? onPickMedia;

  final Future<bool> Function(String path, int durationMs)? onVoiceSend;
  final int? maxLength;
  final String placeholder;
  final bool disabled;

  /// 非空时输入框占位为「发送给 xxx」（与常见 IM 稿一致）；否则用 [placeholder]。
  final String? composeTargetName;

  const MessageComposer({
    super.key,
    required this.conversationId,
    this.initialText,
    this.onTypingChanged,
    this.onDraftChanged,
    this.replyQuote,
    this.onClearReply,
    this.onPickMedia,
    this.onVoiceSend,
    this.maxLength,
    this.placeholder = 'Type a message...',
    this.disabled = false,
    this.composeTargetName,
  });

  @override
  ConsumerState<MessageComposer> createState() => MessageComposerState();
}

class MessageComposerState extends ConsumerState<MessageComposer> {
  static const Duration _draftIdleDelay = Duration(seconds: 5);

  /// 一次性读取语言文案（回调/弹窗等非 build 响应式路径）；build 内用 watch 版。
  FlareComposerCopy get _c => ref.read(flareMessagesProvider).composer;

  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _typingIdleTimer;
  late final DraftIdleScheduler _draftScheduler;
  bool _typingActive = false;

  /// 富文本模式（Aa）；作为持久输入模式，发送后保留。
  final _kitKey = GlobalKey<FlareComposerState>();

  /// 圆形「+」下方的内联功能宫格（4×2）；与 [showComposerAttachSheet] 并存，「全部附件」进 Sheet。

  bool get _isStackLayout => _controller.text.contains('\n');

  String get _effectiveHint {
    final name = widget.composeTargetName?.trim();
    if (name != null && name.isNotEmpty) return _c.hint(name);
    return widget.placeholder;
  }

  @override
  void initState() {
    super.initState();
    final d = widget.initialText;
    if (d != null && d.isNotEmpty) {
      _controller.text = d;
    }
    _draftScheduler = DraftIdleScheduler(
      delay: _draftIdleDelay,
      onSave: (text) => widget.onDraftChanged?.call(text),
    );
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant MessageComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.conversationId != widget.conversationId) {
      _typingIdleTimer?.cancel();
      _cancelPendingDraftSave();
      _setTyping(false);
      final d = widget.initialText;
      _controller.text = d ?? '';
    } else if (oldWidget.initialText != widget.initialText &&
        _controller.text.trim().isEmpty) {
      final d = widget.initialText;
      if (d != null && d.isNotEmpty) {
        _controller.text = d;
      }
    }
  }

  void _onFocusChange() {
    _typingIdleTimer?.cancel();
    if (_focusNode.hasFocus) {
      _setTyping(true);
    } else {
      _setTyping(false);
    }
  }

  @override
  void dispose() {
    _typingIdleTimer?.cancel();
    flushDraftNow();
    _draftScheduler.dispose();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _setTyping(bool v) {
    if (_typingActive == v) return;
    _typingActive = v;
    widget.onTypingChanged?.call(v);
  }

  void _onTextChanged(String t) {
    setState(() {});

    _scheduleDraftSave(t);

    if (widget.onTypingChanged == null) return;

    if (_focusNode.hasFocus) {
      _setTyping(true);
      return;
    }

    if (t.trim().isEmpty) return;

    _setTyping(true);
    _typingIdleTimer?.cancel();
    _typingIdleTimer = Timer(const Duration(milliseconds: 3500), () {
      _setTyping(false);
    });
  }

  void _cancelPendingDraftSave() {
    _draftScheduler.cancel();
  }

  /// 退出聊天页或切换会话前，把当前仍在静默窗口内的非空输入立即保存为草稿。
  void flushDraftNow() {
    _draftScheduler.flush();
  }

  void _scheduleDraftSave(String text) {
    if (widget.onDraftChanged == null) return;
    _draftScheduler.schedule(text);
  }

  void _restartDraftIdleWindow() {
    _scheduleDraftSave(_controller.text);
  }

  void _insertAtCursor(String insert) {
    _closeMoreGrid();
    if (widget.disabled) return;
    final v = _controller.value;
    final s = v.selection;
    final t = v.text;
    final start = s.start >= 0 ? s.start : t.length;
    final end = s.end >= 0 ? s.end : t.length;
    var newText = t.replaceRange(start, end, insert);
    if (widget.maxLength != null && newText.length > widget.maxLength!) {
      newText = newText.substring(0, widget.maxLength!);
    }
    final newOffset = (start + insert.length).clamp(0, newText.length);
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newOffset),
    );
    _onTextChanged(newText);
  }

  void _closeMoreGrid() {
    _kitKey.currentState?.dismissPanel();
  }

  /// 收起「+」内联宫格（例如点击消息区时通过 [GlobalKey<MessageComposerState>] 调用）。
  void dismissMoreFeatureGrid() => _kitKey.currentState?.dismissPanel();

  void _pickMedia(ComposerPickMediaKind kind) {
    if (widget.onPickMedia != null) {
      widget.onPickMedia!(kind);
    } else {
      final label = switch (kind) {
        ComposerPickMediaKind.imageOrVideo => _c.albumImageVideo,
        ComposerPickMediaKind.image => _c.image,
        ComposerPickMediaKind.video => _c.video,
        ComposerPickMediaKind.audio => _c.voice,
        ComposerPickMediaKind.file => _c.localFile,
        ComposerPickMediaKind.folder => _c.localFolder,
      };
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_c.placeholderLabel(label))));
    }
  }

  /// 与主栏 [ComposerInlineTextField] 共用 [TextEditingController]，顶栏单独 [FocusNode]，避免双输入框抢焦点无法打字。
  Future<void> _showEmojiStickerSheet(BuildContext sheetContext) async {
    final cid = widget.conversationId;
    final locale = Localizations.maybeLocaleOf(sheetContext)?.toLanguageTag();
    await showComposerEmojiStickerSheet(
      sheetContext,
      panelDraftController: _controller,
      panelMinLines: 1,
      panelMaxLines: _isStackLayout ? 8 : 5,
      panelMaxLength: widget.maxLength,
      panelDraftEnabled: !widget.disabled,
      panelHintText: _effectiveHint,
      onPanelDraftChanged: _onTextChanged,
      panelSpecialTextSpanBuilder:
          PlainTextMarkdownDetect.isMarkdown(_controller.text)
          ? null
          : ComposerEmojiSpanBuilder(inlineSize: 15 * 1.72, localeTag: locale),

      onPanelSubmitted: _submit,
      onInsertBracket: (s) {
        _insertAtCursor(s);
        _focusNode.requestFocus();
      },
      onEmojiPackTapSend: (packKey) {
        _restartDraftIdleWindow();
        ref
            .read(chatOutboundProvider(cid).notifier)
            .dispatch(ChatOutboundSendEmojiPackKey(packKey));
      },
      onPickSticker: (pick) {
        _restartDraftIdleWindow();
        ref
            .read(chatOutboundProvider(cid).notifier)
            .dispatch(ChatOutboundSendSticker(pick));
      },
      onPanelSend: (sheetDraft) => _submit(sheetDraft),
    );
  }

  Future<void> _openEmojiStickerPanel() async {
    _closeMoreGrid();
    await _showEmojiStickerSheet(context);
  }

  bool _submit(String text) {
    final value = text.trim();
    if (value.isEmpty || widget.disabled) return false;
    _cancelPendingDraftSave();
    _setTyping(false);
    ref
        .read(chatOutboundProvider(widget.conversationId).notifier)
        .dispatch(
          PlainTextMarkdownDetect.isMarkdown(value)
              ? ChatOutboundSendRichDoc(
                  format: ChatRichDocInputFormat.markdown,
                  source: value,
                )
              : ChatOutboundSendText(value),
        );
    return true;
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(flareMessagesProvider);
    return FlareComposer(
      key: _kitKey,
      conversationKey: widget.conversationId,
      controller: _controller,
      focusNode: _focusNode,
      specialTextSpanBuilder: ComposerEmojiSpanBuilder(
        inlineSize: 22,
        localeTag: Localizations.maybeLocaleOf(context)?.toLanguageTag(),
      ),
      placeholder: _effectiveHint,
      disabled: widget.disabled,
      maxLength: widget.maxLength,
      enableVoice: widget.onVoiceSend != null,
      onVoiceSend: widget.onVoiceSend,
      replyTo: widget.replyQuote == null
          ? null
          : FlareReplyTarget(
              senderName: widget.replyQuote!.senderName,
              summary: widget.replyQuote!.preview,
            ),
      onCancelReply: widget.onClearReply,
      onTyping: _onTextChanged,
      onSend: _submit,
      onSendRich: (source) {
        _cancelPendingDraftSave();
        _setTyping(false);
        ref
            .read(chatOutboundProvider(widget.conversationId).notifier)
            .dispatch(
              ChatOutboundSendRichDoc(
                format: ChatRichDocInputFormat.markdown,
                source: source,
              ),
            );
      },
      onEmoji: () => unawaited(_openEmojiStickerPanel()),
      onImage: () => _pickMedia(ComposerPickMediaKind.image),
      actions: [
        FlareComposerAction(id: 'file', label: _c.file, icon: 'file'),
        FlareComposerAction(id: 'video', label: _c.video, icon: 'video'),
        FlareComposerAction(
          id: 'location',
          label: _c.location,
          icon: 'location',
        ),
        FlareComposerAction(id: 'contactCard', label: _c.contact, icon: 'card'),
        FlareComposerAction(
          id: 'schedule',
          label: _c.schedule,
          icon: 'calendar',
        ),
        FlareComposerAction(id: 'task', label: _c.task, icon: 'check'),
      ],
      onAction: (action) {
        if (action.id == 'file') {
          _pickMedia(ComposerPickMediaKind.file);
          return;
        }
        if (action.id == 'video') {
          _pickMedia(ComposerPickMediaKind.video);
          return;
        }
        final kind = ChatBusinessMessageKind.values.byName(action.id);
        ref
            .read(chatOutboundProvider(widget.conversationId).notifier)
            .dispatch(ChatOutboundRequestBusinessMessage(kind));
      },
    );
  }
}
