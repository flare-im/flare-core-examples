import 'package:flare_im/application/providers/app_theme_mode_provider.dart';
import 'package:flare_im/application/providers/locale_provider.dart';
import 'package:flare_im/application/providers/media_storage_provider.dart';
import 'package:flare_im/application/providers/service_providers.dart';
import 'package:flare_im/domain/value_objects/media_storage.dart';
import 'package:flare_im/infrastructure/platform/download_location_host.dart';
import 'package:flare_im/interface/theme/flare_im_design.dart';
import 'package:flare_im/shared/i18n/flare_locale.dart';
import 'package:flare_im_ui/flare_im_ui.dart'
    show
        FlareBottomSheet,
        FlareButton,
        FlareButtonVariant,
        FlareControlSize,
        FlareDangerConfirm,
        FlareSettingKind,
        FlareSettingsItem,
        FlareSettingsList,
        FlareSettingsSection,
        FlareSizes,
        FlareToast,
        FlareToastVariant,
        formatBytes;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 设置屏：语言 + 外观 + 存储（下载位置、图片与文件缓存），飞书式 kit 列表
/// (单选行由 kit FlareSettingsList 承载)。
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final i18n = ref.watch(flareMessagesProvider);
    final settings = i18n.settings;
    final locale = ref.watch(flareLocaleProvider);
    final themeMode = ref.watch(appThemeModeProvider);
    final location = ref.watch(downloadLocationProvider).valueOrNull;
    final cacheBytes = ref.watch(mediaCacheBytesProvider);

    final sections = [
      FlareSettingsSection(
        title: settings.language,
        items: [
          FlareSettingsItem(
            key: 'lang_zh',
            label: i18n.conversation.languageZh,
            kind: FlareSettingKind.select,
            value: locale == FlareLocale.zhCn,
          ),
          FlareSettingsItem(
            key: 'lang_en',
            label: i18n.conversation.languageEn,
            kind: FlareSettingKind.select,
            value: locale == FlareLocale.enUs,
          ),
        ],
      ),
      FlareSettingsSection(
        title: settings.appearance,
        items: [
          FlareSettingsItem(
            key: 'theme_system',
            label: settings.themeSystem,
            kind: FlareSettingKind.select,
            value: themeMode == ThemeMode.system,
          ),
          FlareSettingsItem(
            key: 'theme_light',
            label: settings.themeLight,
            kind: FlareSettingKind.select,
            value: themeMode == ThemeMode.light,
          ),
          FlareSettingsItem(
            key: 'theme_dark',
            label: settings.themeDark,
            kind: FlareSettingKind.select,
            value: themeMode == ThemeMode.dark,
          ),
        ],
      ),
      FlareSettingsSection(
        title: settings.storage,
        items: [
          FlareSettingsItem(
            key: 'download_location',
            label: settings.downloadLocation,
            icon: 'folder',
            // 读到之前不写位置（SDK 还没就绪时也是）。
            detail: location == null
                ? null
                : shortDownloadLocation(location.directory),
          ),
          FlareSettingsItem(
            key: 'media_cache',
            label: settings.mediaCache,
            icon: 'storage',
            kind: FlareSettingKind.action,
            detail: cacheBytes.isLoading
                ? null
                : formatBytes(cacheBytes.valueOrNull) ?? settings.notMeasured,
          ),
        ],
      ),
    ];

    return Scaffold(
      backgroundColor: FlareImDesign.mobileCanvas,
      appBar: AppBar(
        title: Text(settings.title),
        backgroundColor: FlareImDesign.card,
        surfaceTintColor: Colors.transparent,
      ),
      body: FlareSettingsList(
        sections: sections,
        onSelect: (item) {
          switch (item.key) {
            case 'lang_zh':
              ref
                  .read(flareLocaleProvider.notifier)
                  .setLocale(FlareLocale.zhCn);
            case 'lang_en':
              ref
                  .read(flareLocaleProvider.notifier)
                  .setLocale(FlareLocale.enUs);
            case 'theme_system':
              ref.read(appThemeModeProvider.notifier).setMode(ThemeMode.system);
            case 'theme_light':
              ref.read(appThemeModeProvider.notifier).setMode(ThemeMode.light);
            case 'theme_dark':
              ref.read(appThemeModeProvider.notifier).setMode(ThemeMode.dark);
            case 'download_location':
              _showDownloadLocation(context, ref);
            case 'media_cache':
              _clearMediaCache(context, ref);
          }
        },
      ),
    );
  }

  /// 下载位置：保存的图片、视频、文件写进哪个文件夹（核心 SDK 的下载位置）。能挑文件夹的
  /// 平台（桌面、Android）可以换，自选过的可以恢复默认；iOS 在「文件」App 里。
  Future<void> _showDownloadLocation(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final settings = ref.read(flareMessagesProvider).settings;
    final DownloadLocation current;
    try {
      current = await ref.read(mediaStorageServiceProvider).downloadLocation();
    } catch (_) {
      if (context.mounted) {
        FlareToast.show(
          context,
          message: settings.downloadLocationUnavailable,
          variant: FlareToastVariant.error,
        );
      }
      return;
    }
    if (!context.mounted) return;
    ref.invalidate(downloadLocationProvider);
    // 短任务面:手机上是底部面板,宽屏交给居中模态框(auto)。面板里第一行就是
    // 「下载位置」分组标题,所以名称只给读屏,不再画一遍。
    await FlareBottomSheet.show<void>(
      context,
      title: settings.downloadLocation,
      titleHidden: true,
      builder: (sheet) => Padding(
        padding: const EdgeInsets.fromLTRB(
          FlareSizes.spacingLg,
          0,
          FlareSizes.spacingLg,
          FlareSizes.spacingLg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FlareSettingsList(
              // 放在面板的 Column 里：列表按内容收高，否则高度无界、面板画不出来。
              shrinkWrap: true,
              sections: [
                FlareSettingsSection(
                  title: settings.downloadLocation,
                  items: [
                    FlareSettingsItem(
                      key: 'current',
                      label: current.directory,
                      icon: 'folder',
                      kind: FlareSettingKind.value,
                      detail: DownloadLocationHost.inFilesApp
                          ? settings.downloadLocationFilesApp
                          : null,
                    ),
                  ],
                ),
              ],
            ),
            if (DownloadLocationHost.canPick) ...[
              const SizedBox(height: FlareSizes.spacingMd),
              FlareButton(
                label: settings.downloadLocationChange,
                size: FlareControlSize.lg,
                block: true,
                onPressed: () async {
                  if (sheet.mounted) Navigator.of(sheet).pop();
                  final picked = await DownloadLocationHost.pickDirectory(
                    initialDirectory: current.directory,
                  );
                  if (picked == null || !context.mounted) return;
                  await _setDownloadLocation(context, ref, picked);
                },
              ),
            ],
            if (current.isCustom) ...[
              const SizedBox(height: FlareSizes.spacingSm),
              FlareButton(
                label: settings.downloadLocationReset,
                size: FlareControlSize.lg,
                variant: FlareButtonVariant.secondary,
                block: true,
                onPressed: () async {
                  if (sheet.mounted) Navigator.of(sheet).pop();
                  await _setDownloadLocation(context, ref, null);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _setDownloadLocation(
    BuildContext context,
    WidgetRef ref,
    String? directory,
  ) async {
    final settings = ref.read(flareMessagesProvider).settings;
    try {
      final updated = await ref
          .read(mediaStorageServiceProvider)
          .setDownloadLocation(directory);
      if (directory == null) await DownloadLocationHost.forgetDirectory();
      if (!context.mounted) return;
      ref.invalidate(downloadLocationProvider);
      FlareToast.show(
        context,
        message: shortDownloadLocation(updated.directory),
        variant: FlareToastVariant.success,
      );
    } catch (_) {
      if (!context.mounted) return;
      FlareToast.show(
        context,
        message: settings.downloadLocationUnwritable,
        variant: FlareToastVariant.error,
      );
    }
  }

  /// 清图片与文件缓存：先问（组件库的危险确认，清的时候它自己显示忙、失败留在框里可重试）。
  Future<void> _clearMediaCache(BuildContext context, WidgetRef ref) async {
    final settings = ref.read(flareMessagesProvider).settings;
    final service = ref.read(mediaStorageServiceProvider);
    final cleared = await FlareDangerConfirm.show(
      context,
      title: settings.clearCache,
      description: settings.clearCacheConfirm,
      target: settings.mediaCache,
      confirmText: settings.clearCache,
      action: () async {
        try {
          await service.clearMediaCache();
        } catch (_) {
          throw _ReadableFailure(settings.clearCacheFailed);
        }
      },
    );
    if (!cleared || !context.mounted) return;
    ref
      ..invalidate(mediaCacheBytesProvider)
      // 时间线上记着的本机副本已经没了：重新解析（核心会再缓存看到的图）。
      ..invalidate(pictureAccessProvider);
    FlareToast.show(
      context,
      message: settings.cacheCleared,
      variant: FlareToastVariant.success,
    );
  }
}

/// 危险确认框把失败原样显示出来：给它一句人话，而不是异常类型名。
class _ReadableFailure implements Exception {
  const _ReadableFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
