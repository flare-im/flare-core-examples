import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum SdkRuntimePhase {
  idle,
  initializing,
  initialized,
  loggingIn,
  connecting,
  syncing,
  ready,
  failed,
  loggedOut,
}

@immutable
final class SdkRuntimeStatus extends Equatable {
  const SdkRuntimeStatus({
    required this.phase,
    required this.title,
    required this.detail,
    this.progress,
    this.error,
    this.updatedAt,
  });

  const SdkRuntimeStatus.idle()
    : phase = SdkRuntimePhase.idle,
      title = '等待初始化',
      detail = 'SDK 尚未启动',
      progress = null,
      error = null,
      updatedAt = null;

  final SdkRuntimePhase phase;
  final String title;
  final String detail;
  final int? progress;
  final String? error;
  final DateTime? updatedAt;

  bool get isBusy =>
      phase == SdkRuntimePhase.initializing ||
      phase == SdkRuntimePhase.loggingIn ||
      phase == SdkRuntimePhase.connecting ||
      phase == SdkRuntimePhase.syncing;

  bool get isFailure => phase == SdkRuntimePhase.failed;

  bool get shouldShowInline =>
      isBusy || isFailure || phase == SdkRuntimePhase.initialized;

  SdkRuntimeStatus copyWith({
    SdkRuntimePhase? phase,
    String? title,
    String? detail,
    int? progress,
    String? error,
    DateTime? updatedAt,
    bool clearProgress = false,
    bool clearError = false,
  }) {
    return SdkRuntimeStatus(
      phase: phase ?? this.phase,
      title: title ?? this.title,
      detail: detail ?? this.detail,
      progress: clearProgress ? null : progress ?? this.progress,
      error: clearError ? null : error ?? this.error,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [phase, title, detail, progress, error, updatedAt];
}

final sdkRuntimeStatusProvider =
    StateNotifierProvider<SdkRuntimeStatusNotifier, SdkRuntimeStatus>((ref) {
      return SdkRuntimeStatusNotifier();
    });

class SdkRuntimeStatusNotifier extends StateNotifier<SdkRuntimeStatus> {
  SdkRuntimeStatusNotifier() : super(const SdkRuntimeStatus.idle());

  void reset() {
    state = const SdkRuntimeStatus.idle();
  }

  void markConversationBootstrap() {
    state = SdkRuntimeStatus(
      phase: SdkRuntimePhase.syncing,
      title: '正在同步数据',
      detail: '正在拉取会话和最近消息',
      updatedAt: DateTime.now(),
    );
  }

  void markReady({int? conversationCount}) {
    state = SdkRuntimeStatus(
      phase: SdkRuntimePhase.ready,
      title: '同步完成',
      detail: conversationCount == null
          ? '本地数据已就绪'
          : conversationCount == 0
          ? '暂无会话，可以发起新会话'
          : '已加载 $conversationCount 个会话',
      updatedAt: DateTime.now(),
    );
  }

  void markFailure(String message) {
    state = SdkRuntimeStatus(
      phase: SdkRuntimePhase.failed,
      title: 'SDK 状态异常',
      detail: message,
      error: message,
      updatedAt: DateTime.now(),
    );
  }

  void applyLifecycle(Map<String, dynamic> payload) {
    final event = '${payload['event'] ?? ''}';
    final operation = '${payload['operation'] ?? ''}';
    final error = _errorMessage(payload['error']);
    state = switch (event) {
      'initializing' => SdkRuntimeStatus(
        phase: SdkRuntimePhase.initializing,
        title: '正在初始化 SDK',
        detail: '准备本地存储、事件通道和运行环境',
        updatedAt: DateTime.now(),
      ),
      'initialized' => SdkRuntimeStatus(
        phase: SdkRuntimePhase.initialized,
        title: 'SDK 初始化完成',
        detail: '运行环境已准备，正在等待登录',
        updatedAt: DateTime.now(),
      ),
      'loginSucceeded' => SdkRuntimeStatus(
        phase: SdkRuntimePhase.syncing,
        title: '登录成功，正在同步',
        detail: '正在同步会话、未读数和最近消息',
        updatedAt: DateTime.now(),
      ),
      'loginFailed' || 'initFailed' => SdkRuntimeStatus(
        phase: SdkRuntimePhase.failed,
        title: event == 'initFailed' ? '初始化失败' : '登录失败',
        detail: error ?? (operation.isEmpty ? 'SDK 返回失败状态' : operation),
        error: error,
        updatedAt: DateTime.now(),
      ),
      'loggedOut' => SdkRuntimeStatus(
        phase: SdkRuntimePhase.loggedOut,
        title: '已退出登录',
        detail: 'SDK 会话已断开',
        updatedAt: DateTime.now(),
      ),
      'disposed' => const SdkRuntimeStatus.idle(),
      _ => state,
    };
  }

  void applyConnection(Map<String, dynamic> payload) {
    final event = '${payload['event'] ?? ''}';
    final error = _errorMessage(payload['error']);
    state = switch (event) {
      'connecting' || 'reconnecting' => SdkRuntimeStatus(
        phase: SdkRuntimePhase.connecting,
        title: event == 'reconnecting' ? '正在重连服务器' : '正在连接服务器',
        detail: '连接建立后会继续同步离线数据',
        updatedAt: DateTime.now(),
      ),
      'connected' || 'ready' => SdkRuntimeStatus(
        phase: SdkRuntimePhase.syncing,
        title: '连接就绪，正在同步',
        detail: '正在拉取服务端会话和消息增量',
        updatedAt: DateTime.now(),
      ),
      'server_error' || 'reconnect_failed' => SdkRuntimeStatus(
        phase: SdkRuntimePhase.failed,
        title: '连接服务器失败',
        detail: error ?? '${payload['reason'] ?? '请检查服务地址和网络状态'}',
        error: error,
        updatedAt: DateTime.now(),
      ),
      'disconnected' => SdkRuntimeStatus(
        phase: SdkRuntimePhase.failed,
        title: '连接已断开',
        detail: '${payload['reason'] ?? '等待 SDK 自动恢复连接'}',
        updatedAt: DateTime.now(),
      ),
      'kicked_off' => const SdkRuntimeStatus(
        phase: SdkRuntimePhase.failed,
        title: '账号已在其他设备登录',
        detail: '当前设备会话已被下线',
      ),
      'token_expired' => const SdkRuntimeStatus(
        phase: SdkRuntimePhase.failed,
        title: '登录凭证已过期',
        detail: '请重新登录后继续使用',
      ),
      _ => state,
    };
  }

  void applySync(Map<String, dynamic> payload) {
    final event = '${payload['event'] ?? ''}';
    final phase = '${payload['phase'] ?? ''}'.trim();
    final task = '${payload['task'] ?? ''}'.trim();
    final label = task.isNotEmpty ? task : phase;
    final progress = (payload['progress'] as num?)?.toInt();
    final error = _errorMessage(payload['error']);

    state = switch (event) {
      'started' || 'state_changed' => SdkRuntimeStatus(
        phase: SdkRuntimePhase.syncing,
        title: '正在同步数据',
        detail: label.isEmpty ? '正在同步会话和消息' : '正在同步 $label',
        progress: progress,
        updatedAt: DateTime.now(),
      ),
      'progress' || 'task_completed' => SdkRuntimeStatus(
        phase: SdkRuntimePhase.syncing,
        title: '正在同步数据',
        detail: label.isEmpty ? '同步任务进行中' : '正在同步 $label',
        progress: progress,
        updatedAt: DateTime.now(),
      ),
      'finished' => SdkRuntimeStatus(
        phase: SdkRuntimePhase.ready,
        title: '同步完成',
        detail: '会话和消息数据已更新',
        updatedAt: DateTime.now(),
      ),
      'failed' => SdkRuntimeStatus(
        phase: SdkRuntimePhase.failed,
        title: '同步失败',
        detail: error ?? (label.isEmpty ? '服务端同步返回失败' : '$label 同步失败'),
        error: error,
        updatedAt: DateTime.now(),
      ),
      _ => state,
    };
  }
}

String? _errorMessage(Object? error) {
  if (error is Map) {
    final message = error['message']?.toString().trim();
    if (message != null && message.isNotEmpty) return message;
    final code = error['code']?.toString().trim();
    if (code != null && code.isNotEmpty) return code;
  }
  final text = error?.toString().trim();
  return text == null || text.isEmpty || text == 'null' ? null : text;
}
