import 'package:flare_im/application/providers/locale_provider.dart';
import 'package:flare_im/application/providers/sdk_provider.dart';
import 'package:flare_im/application/services/auth_service.dart';
import 'package:flare_im/application/services/conversation_service.dart';
import 'package:flare_im/application/services/media_storage_service.dart';
import 'package:flare_im/application/services/message_service.dart';
import 'package:flare_im/domain/repositories/i_auth_repository.dart';
import 'package:flare_im/domain/repositories/i_conversation_repository.dart';
import 'package:flare_im/domain/repositories/i_media_repository.dart';
import 'package:flare_im/domain/repositories/i_message_repository.dart';
import 'package:flare_im/infrastructure/paths/sdk_data_url.dart';
import 'package:flare_im/infrastructure/repositories/auth_repository_impl.dart';
import 'package:flare_im/infrastructure/repositories/conversation_repository_impl.dart';
import 'package:flare_im/infrastructure/repositories/media_repository_impl.dart';
import 'package:flare_im/infrastructure/repositories/message_repository_impl.dart';
import 'package:flare_im/shared/config/app_config_loader.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 认证仓库 Provider
final authRepositoryProvider = Provider<IAuthRepository>((ref) {
  final sdkWrapper = ref.watch(sdkWrapperProvider);
  return AuthRepositoryImpl(
    sdkWrapper,
    locale: () => ref.read(flareLocaleProvider).code,
  );
});

/// 会话仓库 Provider
final conversationRepositoryProvider = Provider<IConversationRepository>((ref) {
  final sdkWrapper = ref.watch(sdkWrapperProvider);
  return ConversationRepositoryImpl(sdkWrapper);
});

/// 消息仓库 Provider
final messageRepositoryProvider = Provider<IMessageRepository>((ref) {
  final sdkWrapper = ref.watch(sdkWrapperProvider);
  return MessageRepositoryImpl(sdkWrapper);
});

/// 认证服务 Provider
final authServiceProvider = Provider<AuthService>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  return AuthService(authRepository);
});

/// Initializes the SDK with what the sign-in uses, so signing in later is no
/// second init. `access.*` and `update.*` need the core, not a session: a
/// recovery link or a refused build comes before anyone signs in.
final sdkReadyProvider = Provider<Future<void> Function()>((ref) {
  final sdk = ref.watch(sdkWrapperProvider);
  return () async {
    if (sdk.isInitialized) return;
    final defaults = await AppConfigLoader.load();
    await ref
        .read(authServiceProvider)
        .initSdk(
          tenantId: defaults.tenantId,
          tlsCaCertPath: defaults.defaultTlsCaCertPath,
          tlsCaCert: defaults.defaultTlsCaCert,
          dataUrl: await resolveSdkDataUrl(),
        );
  };
});

/// 会话服务 Provider
final conversationServiceProvider = Provider<ConversationService>((ref) {
  final conversationRepository = ref.watch(conversationRepositoryProvider);
  return ConversationService(conversationRepository);
});

/// 消息服务 Provider
final messageServiceProvider = Provider<MessageService>((ref) {
  final messageRepository = ref.watch(messageRepositoryProvider);
  return MessageService(messageRepository);
});

/// 本机媒体仓库 Provider（下载位置 / 保存到本机 / 本地媒体缓存）
final mediaRepositoryProvider = Provider<IMediaRepository>((ref) {
  final sdkWrapper = ref.watch(sdkWrapperProvider);
  return MediaRepositoryImpl(sdkWrapper);
});

/// 本机媒体服务 Provider
final mediaStorageServiceProvider = Provider<MediaStorageService>((ref) {
  final mediaRepository = ref.watch(mediaRepositoryProvider);
  return MediaStorageService(mediaRepository);
});
