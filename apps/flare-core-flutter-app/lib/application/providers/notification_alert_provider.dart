import 'dart:async';

import 'package:flare_core_flutter_sdk/flare_core_flutter_sdk.dart' as core;
import 'package:flare_im/application/providers/sdk_provider.dart';
import 'package:flare_im/infrastructure/sdk/flare_core_sdk_wrapper.dart';
import 'package:flare_im_ui/flare_im_ui.dart'
    show
        FlareMultiDeviceAlert,
        FlareNotificationAlertPreferences,
        FlareNotificationPreview,
        FlareQuietHours;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 设置页上的通知提醒：勿扰时段、通知预览、其他设备活跃时。账号级设置，同一账号的所有设备共用一份，由核心的
/// notification 模块读写。
@immutable
final class NotificationAlertSettingsState {
  const NotificationAlertSettingsState({
    this.preferences = const FlareNotificationAlertPreferences(),
    this.loaded = false,
  });

  /// 显示的值：改动先显示再写。
  final FlareNotificationAlertPreferences preferences;

  /// 读到过一次；之前各行只显示、不接受操作。
  final bool loaded;
}

/// 设置页在的时候才有；每次打开设置页读一次。
final notificationAlertSettingsProvider =
    StateNotifierProvider.autoDispose<
      NotificationAlertSettingsNotifier,
      NotificationAlertSettingsState
    >((ref) {
      final notifier = NotificationAlertSettingsNotifier(
        ref.watch(sdkWrapperProvider),
      );
      unawaited(notifier.refresh());
      return notifier;
    });

class NotificationAlertSettingsNotifier
    extends StateNotifier<NotificationAlertSettingsState> {
  NotificationAlertSettingsNotifier(this._sdk)
    : super(const NotificationAlertSettingsState());

  final SdkWrapper _sdk;

  /// 核心存着的设置。它的版本随写入带回去：别的设备同时改过时整次写入被拒。
  core.UserNotificationSettings? _stored;
  bool _saving = false;

  /// 读一次（设置页出现时）；正在写的时候不读，写完自会带回存好的值。
  Future<void> refresh() async {
    if (_saving) return;
    try {
      _adopt(await _sdk.notificationSettings());
    } catch (error) {
      debugPrint('notification settings: ${error.runtimeType}');
    }
  }

  /// 一行改了：先显示，再把与核心存着的值的差别写进去；写的期间又改了就接着写最新的。写失败（别的设备同时改过也
  /// 在内）退回存着的值并重读一次，重读拿到的就是别处改过的新值；返回 false 让设置页说一声。
  Future<bool> change(FlareNotificationAlertPreferences next) async {
    final known = _stored;
    if (known == null) return false;
    _show(next);
    if (_saving) return true;
    var stored = known;
    _saving = true;
    try {
      while (true) {
        final target = state.preferences;
        final request = alertSettingsChanges(stored, target);
        if (request == null) break;
        try {
          stored = await _sdk.updateNotificationSettings(request);
        } catch (error) {
          debugPrint('notification settings: ${error.runtimeType}');
          _show(alertPreferencesOf(stored, state.preferences.quietHours));
          try {
            _adopt(await _sdk.notificationSettings());
          } catch (_) {
            // 读不到就留着退回的值，下次进设置页再读。
          }
          return false;
        }
        _stored = stored;
        // 写的期间没再改：换成核心存好的值；又改过就留着新值，下一轮接着写。
        if (state.preferences == target) {
          _show(alertPreferencesOf(stored, target.quietHours));
        }
      }
      return true;
    } finally {
      _saving = false;
    }
  }

  void _adopt(core.UserNotificationSettings settings) {
    if (!mounted) return;
    _stored = settings;
    state = NotificationAlertSettingsState(
      preferences: alertPreferencesOf(settings, state.preferences.quietHours),
      loaded: true,
    );
  }

  void _show(FlareNotificationAlertPreferences preferences) {
    if (!mounted) return;
    state = NotificationAlertSettingsState(
      preferences: preferences,
      loaded: state.loaded,
    );
  }
}

/// 核心存着的设置在 Kit 里的样子。没有勿扰时段时开关关着，时间沿用 [shown] 那一段：关了再打开还是原来的时间。
FlareNotificationAlertPreferences alertPreferencesOf(
  core.UserNotificationSettings settings,
  FlareQuietHours shown,
) {
  final stored = settings.quietHours;
  return FlareNotificationAlertPreferences(
    quietHours: stored == null
        ? shown.copyWith(enabled: false)
        : FlareQuietHours(
            enabled: true,
            startMinute: stored.startMinute,
            endMinute: stored.endMinute,
            weekdays: stored.weekdays,
            allowMentions: stored.allowMentions,
          ),
    preview: switch (settings.preview) {
      core.NotificationPreview.full => FlareNotificationPreview.full,
      core.NotificationPreview.senderOnly => FlareNotificationPreview.senderOnly,
      core.NotificationPreview.hidden => FlareNotificationPreview.hidden,
    },
    multiDevice: switch (settings.multiDevice) {
      core.MultiDeviceAlertPolicy.delay => FlareMultiDeviceAlert.delay,
      core.MultiDeviceAlertPolicy.immediate => FlareMultiDeviceAlert.immediate,
      core.MultiDeviceAlertPolicy.badgeOnly => FlareMultiDeviceAlert.badgeOnly,
    },
  );
}

/// 从核心存着的 [stored] 改成 [next] 要写的那几项，基于 [stored] 的版本；没有要写的时为 null。
core.UpdateUserNotificationSettingsRequest? alertSettingsChanges(
  core.UserNotificationSettings stored,
  FlareNotificationAlertPreferences next,
) {
  final current = alertPreferencesOf(stored, next.quietHours);
  final quietChanged = next.quietHours != current.quietHours;
  final quietHours = quietChanged && next.quietHours.enabled
      ? core.QuietHours(
          allowMentions: next.quietHours.allowMentions,
          endMinute: next.quietHours.endMinute,
          startMinute: next.quietHours.startMinute,
          weekdays: next.quietHours.weekdays,
        )
      : null;
  final clearQuietHours = quietChanged && !next.quietHours.enabled;
  final preview = next.preview == current.preview
      ? null
      : switch (next.preview) {
          FlareNotificationPreview.full => core.NotificationPreview.full,
          FlareNotificationPreview.senderOnly =>
            core.NotificationPreview.senderOnly,
          FlareNotificationPreview.hidden => core.NotificationPreview.hidden,
        };
  final multiDevice = next.multiDevice == current.multiDevice
      ? null
      : switch (next.multiDevice) {
          FlareMultiDeviceAlert.delay => core.MultiDeviceAlertPolicy.delay,
          FlareMultiDeviceAlert.immediate =>
            core.MultiDeviceAlertPolicy.immediate,
          FlareMultiDeviceAlert.badgeOnly =>
            core.MultiDeviceAlertPolicy.badgeOnly,
        };
  if (quietHours == null &&
      !clearQuietHours &&
      preview == null &&
      multiDevice == null) {
    return null;
  }
  return core.UpdateUserNotificationSettingsRequest(
    quietHours: quietHours,
    clearQuietHours: clearQuietHours,
    preview: preview,
    multiDevice: multiDevice,
    baseSettingsVersion: stored.settingsVersion,
  );
}
