import 'package:flare_im/application/providers/locale_provider.dart';
import 'package:flare_im/interface/widgets/composer/sdk_message_build_catalog.dart';
import 'package:flare_im_ui/flare_im_ui.dart' as kit_sizes show FlareSizes;
import 'package:flare_im_ui/flare_im_ui.dart' as kit_theme show FlareColors;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SdkMessageBuildDraft {
  final SdkMessageBuildKind kind;
  final Map<String, String> values;

  const SdkMessageBuildDraft({required this.kind, required this.values});
}

Future<SdkMessageBuildDraft?> showSdkMessageBuildSheet(BuildContext context) {
  return showModalBottomSheet<SdkMessageBuildDraft>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const _SdkMessageBuildSheet(),
  );
}

class _SdkMessageBuildSheet extends ConsumerStatefulWidget {
  const _SdkMessageBuildSheet();

  @override
  ConsumerState<_SdkMessageBuildSheet> createState() =>
      _SdkMessageBuildSheetState();
}

class _SdkMessageBuildSheetState extends ConsumerState<_SdkMessageBuildSheet> {
  late SdkMessageBuildCatalogEntry _entry;
  Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _setEntry(
      sdkMessageBuildCatalog(ref.read(flareMessagesProvider).composer).first,
    );
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _setEntry(SdkMessageBuildCatalogEntry next) {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _entry = next;
    final values = initialSdkMessageBuildValues(next);
    _controllers = {
      for (final field in next.fields)
        field.key: TextEditingController(text: values[field.key] ?? ''),
    };
  }

  void _onEntryChanged(SdkMessageBuildCatalogEntry? next) {
    if (next == null || next.kind == _entry.kind) return;
    setState(() => _setEntry(next));
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(flareMessagesProvider).composer;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(left: 12, right: 12, bottom: bottom + 12),
      child: Material(
        color: kit_theme.FlareColors.of(context).bgPrimary,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.88,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 12, 10),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: kit_theme.FlareColors.of(
                          context,
                        ).primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(
                        Icons.hub_outlined,
                        color: kit_theme.FlareColors.of(context).primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.sdkMessageType,
                            style: TextStyle(
                              fontSize: kit_sizes.FlareSizes.fontSize4xl,
                              height: 1.2,
                              fontWeight: FontWeight.w800,
                              color: kit_theme.FlareColors.of(
                                context,
                              ).textPrimary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            c.sdkMessageDesc,
                            style: TextStyle(
                              fontSize: kit_sizes.FlareSizes.fontSizeSm,
                              height: 1.25,
                              color: kit_theme.FlareColors.of(
                                context,
                              ).textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: c.close,
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<SdkMessageBuildCatalogEntry>(
                        key: ValueKey(_entry.kind),
                        initialValue: _entry,
                        isExpanded: true,
                        items: [
                          for (final entry in sdkMessageBuildCatalog(c))
                            DropdownMenuItem(
                              value: entry,
                              child: Text('${entry.group} · ${entry.label}'),
                            ),
                        ],
                        onChanged: _onEntryChanged,
                        decoration: _fieldDecoration(
                          c.messageType,
                          Icons.category_outlined,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _entry.protoHint,
                        style: TextStyle(
                          fontSize: kit_sizes.FlareSizes.fontSizeSm,
                          height: 1.35,
                          color: kit_theme.FlareColors.of(
                            context,
                          ).textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      for (final field in _entry.fields)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: TextField(
                            controller: _controllers[field.key],
                            minLines:
                                field.type == SdkMessageBuildFieldType.textarea
                                ? 3
                                : 1,
                            maxLines:
                                field.type == SdkMessageBuildFieldType.textarea
                                ? 8
                                : 1,
                            textInputAction:
                                field.type == SdkMessageBuildFieldType.textarea
                                ? TextInputAction.newline
                                : TextInputAction.next,
                            decoration: _fieldDecoration(
                              field.label,
                              Icons.edit_note_outlined,
                            ).copyWith(hintText: field.placeholder),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: kit_theme.FlareColors.of(
                            context,
                          ).primary,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: Text(c.cancel),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: kit_theme.FlareColors.of(
                            context,
                          ).primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(
                            context,
                            SdkMessageBuildDraft(
                              kind: _entry.kind,
                              values: {
                                for (final e in _controllers.entries)
                                  e.key: e.value.text,
                              },
                            ),
                          );
                        },
                        icon: const Icon(Icons.send_rounded, size: 18),
                        label: Text(c.createAndSend),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(
        icon,
        size: 19,
        color: kit_theme.FlareColors.of(context).textSecondary,
      ),
      filled: true,
      fillColor: kit_theme.FlareColors.of(context).bgSecondary,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      labelStyle: TextStyle(
        fontSize: kit_sizes.FlareSizes.fontSizeSm,
        fontWeight: FontWeight.w600,
        color: kit_theme.FlareColors.of(context).textSecondary,
      ),
      hintStyle: TextStyle(
        fontSize: kit_sizes.FlareSizes.fontSizeLg,
        color: kit_theme.FlareColors.of(
          context,
        ).textSecondary.withValues(alpha: 0.72),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: kit_theme.FlareColors.of(context).borderSecondary,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: kit_theme.FlareColors.of(context).borderSecondary,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: kit_theme.FlareColors.of(context).primary,
          width: 1.4,
        ),
      ),
    );
  }
}
