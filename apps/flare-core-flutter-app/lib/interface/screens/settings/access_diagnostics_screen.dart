import 'dart:async';

import 'package:flare_im/application/providers/access_diagnostics_provider.dart';
import 'package:flare_im/application/providers/locale_provider.dart';
import 'package:flare_im_ui/flare_im_ui.dart'
    show
        FlareAccessDiagnostics,
        FlareScreen,
        FlareStrings,
        FlareToast,
        FlareToastVariant;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// 网络与线路：设置里的一行、连接横幅的「诊断」和恢复链接都打开这一页。
/// 正文是 kit 的 [FlareAccessDiagnostics]；读写都在 [AccessDiagnosticsController]。
class AccessDiagnosticsScreen extends ConsumerStatefulWidget {
  const AccessDiagnosticsScreen({super.key});

  @override
  ConsumerState<AccessDiagnosticsScreen> createState() =>
      _AccessDiagnosticsScreenState();
}

class _AccessDiagnosticsScreenState
    extends ConsumerState<AccessDiagnosticsScreen> {
  late final AccessDiagnosticsController _controller = ref.read(
    accessDiagnosticsProvider,
  );

  @override
  void initState() {
    super.initState();
    _controller.follow();
  }

  @override
  void dispose() {
    _controller.stop();
    super.dispose();
  }

  Future<void> _pin(String accessPointId) async {
    final pinned = await _controller.pin(accessPointId);
    if (pinned || !mounted) return;
    FlareToast.show(
      context,
      message: ref.read(flareMessagesProvider).settings.accessPinFailed,
      variant: FlareToastVariant.error,
    );
  }

  /// 恢复链接打开时这一页就是栈底：退回首页，由首页决定去会话还是去登录。
  void _leave() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(accessDiagnosticsProvider);
    return Scaffold(
      body: FlareScreen(
        title: FlareStrings.of(context).accessDiagnosticsTitle,
        padded: true,
        onBack: _leave,
        child: FlareAccessDiagnostics(
          status: controller.status,
          accessPoints: controller.accessPoints,
          refreshing: controller.refreshing,
          refreshOutcome: controller.refreshOutcome,
          importing: controller.importing,
          importOutcome: controller.importOutcome,
          importCode: controller.importCode,
          exporting: controller.exporting,
          exportOutcome: controller.exportOutcome,
          onPin: (id) => unawaited(_pin(id)),
          onUnpin: () => unawaited(controller.unpin()),
          onRefresh: () => unawaited(controller.refresh()),
          onImportRecovery: (link) =>
              unawaited(controller.importRecovery(link)),
          onExportDiagnostics: () => unawaited(controller.exportDiagnostics()),
        ),
      ),
    );
  }
}
