import 'dart:async' show unawaited;

import 'package:flare_core_flutter_push/flare_core_flutter_push.dart'
    show FlarePushBackgroundDelivery, FlarePushPermissionStatus;
import 'package:flare_core_flutter_update_ui/flare_core_flutter_update_ui.dart'
    show FlareUpdateScope;
import 'package:flare_im/application/providers/app_theme_mode_provider.dart';
import 'package:flare_im/application/providers/locale_provider.dart';
import 'package:flare_im/application/providers/media_storage_provider.dart';
import 'package:flare_im/application/providers/notification_alert_provider.dart';
import 'package:flare_im/application/providers/push_provider.dart';
import 'package:flare_im/application/providers/service_providers.dart';
import 'package:flare_im/domain/value_objects/media_storage.dart';
import 'package:flare_im/infrastructure/platform/download_location_host.dart';
import 'package:flare_im/interface/theme/flare_im_design.dart';
import 'package:flare_im/shared/i18n/flare_locale.dart';
import 'package:flare_im_ui/flare_im_ui.dart'
    show
        FlareBackgroundDelivery,
        FlareBottomSheet,
        FlareButton,
        FlareButtonVariant,
        FlareControlSize,
        FlareDangerConfirm,
        FlareNotificationAlertPreferences,
        FlareNotificationAlertSettings,
        FlareNotificationDeliverySettings,
        FlareNotificationGuideAction,
        FlareNotificationStatus,
        FlareSettingKind,
        FlareSettingsItem,
        FlareSettingsList,
        FlareSettingsSection,
        FlareSizes,
        FlareStrings,
        FlareToast,
        FlareToastVariant,
        formatBytes;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// 设置屏：语言 + 外观 + 通知（Android、iOS）+ 勿扰与通知内容 + 网络与线路 + 版本信息 + 存储（下载位置、图片与
/// 文件缓存），飞书式 kit 列表(单选行由 kit FlareSettingsList 承载，通知是 kit 的通知分组与通知提醒分组)。
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
    final push = ref.watch(pushNotificationsProvider);

    // 整页一张 Kit 列表；通知分组（Kit 组件给出的一节）排在外观之后，没有系统推送的平台没有这一节；紧接着是通知
    // 提醒的三节（勿扰时段、通知预览、多设备），每个平台都有。
    List<FlareSettingsSection> sections(
      FlareSettingsSection? notifications,
      List<FlareSettingsSection> alerts,
    ) => [
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
      ?notifications,
      ...alerts,
      FlareSettingsSection(
        items: [
          FlareSettingsItem(
            key: 'network',
            label: FlareStrings.of(context).accessDiagnosticsTitle,
            icon: 'link',
          ),
          FlareSettingsItem(
            key: 'about',
            label: FlareStrings.of(context).versionPanelTitle,
            icon: 'info',
            badge: FlareUpdateScope.badgeOf(context),
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

    void select(FlareSettingsItem item) {
      switch (item.key) {
        case 'lang_zh':
          ref.read(flareLocaleProvider.notifier).setLocale(FlareLocale.zhCn);
        case 'lang_en':
          ref.read(flareLocaleProvider.notifier).setLocale(FlareLocale.enUs);
        case 'theme_system':
          ref.read(appThemeModeProvider.notifier).setMode(ThemeMode.system);
        case 'theme_light':
          ref.read(appThemeModeProvider.notifier).setMode(ThemeMode.light);
        case 'theme_dark':
          ref.read(appThemeModeProvider.notifier).setMode(ThemeMode.dark);
        case 'network':
          context.push('/network');
        case 'about':
          context.push('/about');
        case 'download_location':
          _showDownloadLocation(context, ref);
        case 'media_cache':
          _clearMediaCache(context, ref);
      }
    }

    return Scaffold(
      backgroundColor: FlareImDesign.mobileCanvas,
      appBar: AppBar(
        title: Text(settings.title),
        backgroundColor: FlareImDesign.card,
        surfaceTintColor: Colors.transparent,
      ),
      // 系统推送只在 Android、iOS 上有：通知分组的两行由 Kit 组件处理；通知提醒各行也由 Kit 组件处理；其余的行
      // 归设置页。
      body: _AlertSettings(
        builder: (_, alerts, selectAlert, toggleAlert) {
          FlareSettingsList list(
            FlareSettingsSection? notifications,
            bool Function(FlareSettingsItem item) selectNotification,
          ) => FlareSettingsList(
            sections: sections(notifications, alerts),
            onSelect: (item) {
              if (!selectNotification(item) && !selectAlert(item)) {
                select(item);
              }
            },
            onToggle: (item, on) => toggleAlert(item, on),
          );
          return push.isSupported
              ? _NotificationSettings(
                  builder: (_, notifications, selectNotification) =>
                      list(notifications, selectNotification),
                )
              : list(null, (_) => false);
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

/// 通知（Kit 通知分组，自带标题），作为一节交给 [builder] 排进设置页的列表：「新消息通知」显示系统权限，系统
/// 授权框还会弹时点它申请，弹不出来了去系统设置里改。Android 另有「后台接收消息」：电池设置的那一档，点开是 Kit
/// 的说明面板，里面是电池使用，以及有自启动管理页的厂商的入口（文案用 Kit 的）。只读状态、打开系统自己的页面，
/// 不做任何自动化。
class _NotificationSettings extends ConsumerWidget {
  const _NotificationSettings({required this.builder});

  final Widget Function(
    BuildContext context,
    FlareSettingsSection notifications,
    bool Function(FlareSettingsItem item) select,
  )
  builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final push = ref.watch(pushNotificationsProvider);
    final status = ref.watch(pushPermissionProvider).valueOrNull;
    final background = ref.watch(pushBackgroundProvider).valueOrNull;
    return FlareNotificationDeliverySettings(
      status: status == null ? null : _notificationStatus(status),
      background: background == null
          ? null
          : _backgroundDelivery(background.delivery),
      vendorActions: [
        if (background?.hasAutoStartSettings ?? false)
          FlareNotificationGuideAction(
            onSelect: () => unawaited(_attempt(push.openAutoStartSettings())),
          ),
      ],
      onStatusAction: () => unawaited(_attempt(push.changeFromSettings())),
      onOpenBatterySettings: () =>
          unawaited(_attempt(push.openBatterySettings())),
      sectionBuilder: builder,
    );
  }
}

/// 通知提醒（Kit 的三节：勿扰时段、通知预览、其他设备活跃时），交给 [builder] 排进设置页的列表。账号级设置，同一
/// 账号的所有设备共用一份：改了先显示再写进核心，没写成就退回存着的值并说一声；读到之前只显示、不接受操作。
class _AlertSettings extends ConsumerWidget {
  const _AlertSettings({required this.builder});

  final Widget Function(
    BuildContext context,
    List<FlareSettingsSection> sections,
    bool Function(FlareSettingsItem item) select,
    bool Function(FlareSettingsItem item, bool on) toggle,
  )
  builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alerts = ref.watch(notificationAlertSettingsProvider);
    return FlareNotificationAlertSettings(
      value: alerts.preferences,
      disabled: !alerts.loaded,
      onChange: (next) => unawaited(_change(context, ref, next)),
      sectionsBuilder: builder,
    );
  }

  Future<void> _change(
    BuildContext context,
    WidgetRef ref,
    FlareNotificationAlertPreferences next,
  ) async {
    final message = ref
        .read(flareMessagesProvider)
        .settings
        .notificationAlertsNotSaved;
    final saved = await ref
        .read(notificationAlertSettingsProvider.notifier)
        .change(next);
    if (saved || !context.mounted) return;
    FlareToast.show(
      context,
      message: message,
      variant: FlareToastVariant.error,
    );
  }
}

/// 模块的三态权限在设置行上的说法。
FlareNotificationStatus _notificationStatus(FlarePushPermissionStatus status) =>
    switch (status) {
      FlarePushPermissionStatus.granted => FlareNotificationStatus.on,
      FlarePushPermissionStatus.denied => FlareNotificationStatus.off,
      FlarePushPermissionStatus.notDetermined =>
        FlareNotificationStatus.notTurnedOn,
    };

/// 插件读出的电池设置那一档，换成 Kit 的同名三档。
FlareBackgroundDelivery _backgroundDelivery(
  FlarePushBackgroundDelivery delivery,
) => switch (delivery) {
  FlarePushBackgroundDelivery.unrestricted =>
    FlareBackgroundDelivery.unrestricted,
  FlarePushBackgroundDelivery.optimized => FlareBackgroundDelivery.optimized,
  FlarePushBackgroundDelivery.restricted => FlareBackgroundDelivery.restricted,
};

/// 打开系统页面尽力而为：失败只记类型，不打断设置页。
Future<void> _attempt(Future<void> work) async {
  try {
    await work;
  } catch (error) {
    debugPrint('push settings: ${error.runtimeType}');
  }
}

/// 危险确认框把失败原样显示出来：给它一句人话，而不是异常类型名。
class _ReadableFailure implements Exception {
  const _ReadableFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
