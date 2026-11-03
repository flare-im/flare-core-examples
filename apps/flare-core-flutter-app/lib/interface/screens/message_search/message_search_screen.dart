import 'dart:async';

import 'package:flare_core_flutter_sdk/flare_core_flutter_sdk.dart' as core;
import 'package:flare_im/application/outbound/im_outbound_facade.dart';
import 'package:flare_im/application/providers/im_outbound_provider.dart';
import 'package:flare_im/application/providers/locale_provider.dart';
import 'package:flare_im/domain/entities/message.dart';
import 'package:flare_im/interface/theme/flare_im_design.dart';
import 'package:flare_im/interface/widgets/message/plain_text_emoji_rich.dart';
import 'package:flare_im/shared/i18n/flare_messages.dart';
import 'package:flare_im/shared/layout/workbench_layout.dart';
import 'package:flare_im_ui/flare_im_ui.dart' as kit_sizes show FlareSizes;
import 'package:flare_im_ui/flare_im_ui.dart' show FlareInput;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 消息搜索（会话内或全局）。
class MessageSearchScreen extends ConsumerStatefulWidget {
  const MessageSearchScreen({super.key, this.conversationId});

  final String? conversationId;

  @override
  ConsumerState<MessageSearchScreen> createState() =>
      _MessageSearchScreenState();
}

class _MessageSearchScreenState extends ConsumerState<MessageSearchScreen> {
  final _keywordController = TextEditingController();
  List<Message> _results = const [];
  bool _loading = false;
  String? _lastKeyword;
  core.MessageSearchKind _kind = core.MessageSearchKind.message;

  late final ImOutboundFacade _outbound;

  String? get _cid {
    final t = widget.conversationId?.trim() ?? '';
    return t.isEmpty ? null : t;
  }

  @override
  void initState() {
    super.initState();
    _outbound = ref.read(imOutboundProvider);
  }

  @override
  void dispose() {
    _keywordController.dispose();
    super.dispose();
  }

  Future<void> _runSearch() async {
    final kw = _keywordController.text.trim();
    if (kw.isEmpty) return;
    setState(() {
      _loading = true;
      _lastKeyword = kw;
    });
    try {
      final kinds = <core.MessageSearchKind>[_kind];
      final list = _cid == null
          ? await _outbound.searchMessagesGlobal(kw, kinds: kinds)
          : await _outbound.chatSearchInServer(_cid!, kw, kinds: kinds);
      if (!mounted) return;
      setState(() => _results = list);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openMessage(Message message) {
    final cid = message.conversationId.trim();
    if (cid.isEmpty) return;
    navigateToChat(context, cid);
  }

  List<DropdownMenuItem<core.MessageSearchKind>> _kindItems(
    FlareSearchCopy search,
  ) {
    return [
      DropdownMenuItem(
        value: core.MessageSearchKind.message,
        child: Text(search.filterAll),
      ),
      DropdownMenuItem(
        value: core.MessageSearchKind.text,
        child: Text(search.filterText),
      ),
      DropdownMenuItem(
        value: core.MessageSearchKind.media,
        child: Text(search.filterMedia),
      ),
      DropdownMenuItem(
        value: core.MessageSearchKind.image,
        child: Text(search.filterImage),
      ),
      DropdownMenuItem(
        value: core.MessageSearchKind.video,
        child: Text(search.filterVideo),
      ),
      DropdownMenuItem(
        value: core.MessageSearchKind.audio,
        child: Text(search.filterAudio),
      ),
      DropdownMenuItem(
        value: core.MessageSearchKind.file,
        child: Text(search.filterFile),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final i18n = ref.watch(flareMessagesProvider);
    final search = i18n.search;
    final scopeLabel = _cid == null ? search.global : search.inConversation;

    return Scaffold(
      backgroundColor: FlareImDesign.mobileCanvas,
      appBar: AppBar(
        title: Text(search.title),
        backgroundColor: FlareImDesign.card,
        surfaceTintColor: Colors.transparent,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              scopeLabel,
              style: const TextStyle(
                fontSize: kit_sizes.FlareSizes.fontSizeSm,
                fontWeight: FontWeight.w600,
                color: FlareImDesign.mutedForeground,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: FlareInput(
                    controller: _keywordController,
                    autofocus: true,
                    placeholder: search.keywordHint,
                    prefix: const Icon(Icons.search_rounded, size: 22),
                    onSubmitted: (_) => unawaited(_runSearch()),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: _loading ? null : () => unawaited(_runSearch()),
                  style: FilledButton.styleFrom(
                    backgroundColor: FlareImDesign.brandPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(search.searchButton),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: DropdownButtonFormField<core.MessageSearchKind>(
              initialValue: _kind,
              items: _kindItems(search),
              onChanged: _loading
                  ? null
                  : (value) {
                      if (value == null) return;
                      setState(() => _kind = value);
                    },
              decoration: InputDecoration(
                labelText: search.filterLabel,
                prefixIcon: const Icon(Icons.tune_rounded, size: 20),
                filled: true,
                fillColor: FlareImDesign.listHeaderIconCircleBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          if (_lastKeyword != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                _results.isEmpty
                    ? search.noResults
                    : search.resultCount(_results.length),
                style: const TextStyle(
                  fontSize: kit_sizes.FlareSizes.fontSizeMd,
                  color: FlareImDesign.mutedForeground,
                ),
              ),
            ),
          Expanded(
            child: _results.isEmpty
                ? Center(
                    child: Text(
                      _lastKeyword == null
                          ? search.keywordHint
                          : search.noResults,
                      style: const TextStyle(
                        color: FlareImDesign.mutedForeground,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                    itemCount: _results.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final m = _results[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        title: PlainTextEmojiRich(
                          text: m.content.previewText,
                          style: const TextStyle(
                            fontSize: kit_sizes.FlareSizes.fontSizeXl,
                            height: 1.35,
                          ),
                        ),
                        subtitle: Text(
                          'seq ${m.seq} · ${m.senderDisplayName.isNotEmpty ? m.senderDisplayName : m.senderId}',
                          style: const TextStyle(
                            fontSize: kit_sizes.FlareSizes.fontSizeSm,
                          ),
                        ),
                        trailing: _cid == null
                            ? TextButton(
                                onPressed: () => _openMessage(m),
                                child: Text(search.openInChat),
                              )
                            : null,
                        onTap: _cid == null ? () => _openMessage(m) : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
