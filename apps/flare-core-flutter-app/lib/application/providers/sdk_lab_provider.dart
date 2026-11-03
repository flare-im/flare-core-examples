import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flare_core_flutter_sdk/flare_core_flutter_sdk.dart' as core;
import 'package:flare_im/application/providers/auth_state_provider.dart';
import 'package:flare_im/application/providers/sdk_provider.dart';
import 'package:flare_im/infrastructure/mappers/sdk_model_mapper.dart';
import 'package:flare_im/infrastructure/sdk/flare_core_sdk_wrapper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final sdkLabProvider = StateNotifierProvider<SdkLabNotifier, SdkLabSnapshot>((
  ref,
) {
  return SdkLabNotifier(ref);
});

final class SdkLabSnapshot {
  const SdkLabSnapshot({
    this.loading = false,
    this.runningOperation,
    this.diagnostics = const <String, Object?>{},
    this.capabilities = const <String, Object?>{},
    this.userCapabilities = const <String, Object?>{},
    this.mediaCache = const <String, Object?>{},
    this.presence = const <String, Object?>{},
    this.builderOperations = const <Map<String, Object?>>[],
    this.events = const <SdkLabEventEntry>[],
    this.failures = const <SdkLabFailureEntry>[],
    this.lastResult,
    this.error,
  });

  final bool loading;
  final String? runningOperation;
  final Map<String, Object?> diagnostics;
  final Map<String, Object?> capabilities;
  final Map<String, Object?> userCapabilities;
  final Map<String, Object?> mediaCache;
  final Map<String, Object?> presence;
  final List<Map<String, Object?>> builderOperations;
  final List<SdkLabEventEntry> events;
  final List<SdkLabFailureEntry> failures;
  final SdkLabOperationResult? lastResult;
  final String? error;

  bool get busy => loading || runningOperation != null;

  SdkLabSnapshot copyWith({
    bool? loading,
    String? runningOperation,
    bool clearRunningOperation = false,
    Map<String, Object?>? diagnostics,
    Map<String, Object?>? capabilities,
    Map<String, Object?>? userCapabilities,
    Map<String, Object?>? mediaCache,
    Map<String, Object?>? presence,
    List<Map<String, Object?>>? builderOperations,
    List<SdkLabEventEntry>? events,
    List<SdkLabFailureEntry>? failures,
    SdkLabOperationResult? lastResult,
    String? error,
    bool clearError = false,
  }) {
    return SdkLabSnapshot(
      loading: loading ?? this.loading,
      runningOperation: clearRunningOperation
          ? null
          : runningOperation ?? this.runningOperation,
      diagnostics: diagnostics ?? this.diagnostics,
      capabilities: capabilities ?? this.capabilities,
      userCapabilities: userCapabilities ?? this.userCapabilities,
      mediaCache: mediaCache ?? this.mediaCache,
      presence: presence ?? this.presence,
      builderOperations: builderOperations ?? this.builderOperations,
      events: events ?? this.events,
      failures: failures ?? this.failures,
      lastResult: lastResult ?? this.lastResult,
      error: clearError ? null : error ?? this.error,
    );
  }
}

final class SdkLabOperationResult {
  const SdkLabOperationResult({
    required this.operation,
    required this.timestamp,
    required this.value,
  });

  final String operation;
  final DateTime timestamp;
  final Object? value;

  Map<String, Object?> toJson() => {
    'operation': operation,
    'timestamp': timestamp.toIso8601String(),
    'value': _jsonSafe(value),
  };
}

final class SdkLabEventEntry {
  const SdkLabEventEntry({
    required this.domain,
    required this.name,
    required this.timestamp,
    required this.payload,
  });

  final String domain;
  final String name;
  final DateTime timestamp;
  final Map<String, Object?> payload;

  Map<String, Object?> toJson() => {
    'domain': domain,
    'name': name,
    'timestamp': timestamp.toIso8601String(),
    'payload': payload,
  };
}

final class SdkLabFailureEntry {
  const SdkLabFailureEntry({
    required this.operation,
    required this.code,
    required this.message,
    required this.timestamp,
    this.retryable,
    this.details = const <String, Object?>{},
    this.cause,
  });

  final String operation;
  final String code;
  final String message;
  final bool? retryable;
  final Map<String, Object?> details;
  final String? cause;
  final DateTime timestamp;

  Map<String, Object?> toJson() => {
    'operation': operation,
    'code': code,
    'message': message,
    'retryable': retryable,
    'details': details,
    'cause': cause,
    'timestamp': timestamp.toIso8601String(),
  };
}

final class SdkLabOperationTemplate {
  const SdkLabOperationTemplate({
    required this.id,
    required this.family,
    required this.title,
    required this.description,
    required this.defaultPayload,
  });

  final String id;
  final String family;
  final String title;
  final String description;
  final Map<String, Object?> defaultPayload;

  String get defaultJson {
    return const JsonEncoder.withIndent('  ').convert(defaultPayload);
  }
}

const sdkLabOperationTemplates = <SdkLabOperationTemplate>[
  SdkLabOperationTemplate(
    id: 'conversation.bootstrap_home',
    family: 'Conversation',
    title: 'Bootstrap Home Timeline',
    description:
        'Core-owned home snapshot for conversation list bootstrapping.',
    defaultPayload: {'conversationLimit': 50},
  ),
  SdkLabOperationTemplate(
    id: 'conversation.open_timeline',
    family: 'Conversation',
    title: 'Open Conversation Timeline',
    description: 'Core-owned first page when entering a conversation.',
    defaultPayload: {'conversationId': '', 'messageLimit': 30},
  ),
  SdkLabOperationTemplate(
    id: 'conversation.get_group_by_user_ids',
    family: 'Conversation',
    title: 'Get Group By User Ids',
    description: 'Create or hydrate a group conversation from participant ids.',
    defaultPayload: {
      'userIds': ['{{currentUserId}}'],
      'displayName': 'SDK Lab Group',
    },
  ),
  SdkLabOperationTemplate(
    id: 'conversation.get_multiple',
    family: 'Conversation',
    title: 'Get Multiple Conversations',
    description: 'Bulk hydrate known conversation ids.',
    defaultPayload: {'conversationIds': <String>[]},
  ),
  SdkLabOperationTemplate(
    id: 'message.build_raw',
    family: 'Message',
    title: 'Build Typed Message',
    description:
        'Exercise typed messageBuilder operations with editable payload.',
    defaultPayload: {
      'op': 'create_text',
      'conversationId': '',
      'text': 'Hello from Flutter SDK Lab',
    },
  ),
  SdkLabOperationTemplate(
    id: 'message.send_no_oss',
    family: 'Message',
    title: 'Send Message No OSS',
    description: 'Build a message then send through messages.sendMessageNoOss.',
    defaultPayload: {
      'op': 'create_text',
      'conversationId': '',
      'text': 'No OSS path from Flutter SDK Lab',
    },
  ),
  SdkLabOperationTemplate(
    id: 'message.get',
    family: 'Message',
    title: 'Get Message',
    description: 'Fetch and decode one message through messages.getMessage.',
    defaultPayload: {'messageId': ''},
  ),
  SdkLabOperationTemplate(
    id: 'message.get_raw',
    family: 'Message',
    title: 'Get Raw Message',
    description: 'Fetch one message without app-side entity mapping.',
    defaultPayload: {'messageId': ''},
  ),
  SdkLabOperationTemplate(
    id: 'message.mark_read_and_burn',
    family: 'Message',
    title: 'Mark Read And Burn',
    description: 'Typed read-and-burn mutation for ephemeral messages.',
    defaultPayload: {'messageId': ''},
  ),
  SdkLabOperationTemplate(
    id: 'message.edit_rich_doc_by_message_id',
    family: 'Message',
    title: 'Edit Rich Doc By Message Id',
    description: 'Apply a RichDoc v2 payload to an existing rich-doc message.',
    defaultPayload: {'messageId': '', 'docJson': '{"type":"doc","content":[]}'},
  ),
  SdkLabOperationTemplate(
    id: 'message.pin',
    family: 'Message',
    title: 'Pin Message Object',
    description: 'Typed object-based pin path; paste a message payload.',
    defaultPayload: {'message': <String, Object?>{}},
  ),
  SdkLabOperationTemplate(
    id: 'message.unpin',
    family: 'Message',
    title: 'Unpin Message Object',
    description: 'Typed object-based unpin path; paste a message payload.',
    defaultPayload: {'message': <String, Object?>{}},
  ),
  SdkLabOperationTemplate(
    id: 'message.mark_with_color',
    family: 'Message',
    title: 'Mark Message With Color',
    description: 'Typed colored mark command.',
    defaultPayload: {'messageId': '', 'color': 'yellow'},
  ),
  SdkLabOperationTemplate(
    id: 'message.unmark_by_message_id',
    family: 'Message',
    title: 'Unmark Message By Id',
    description: 'Typed unmark command by message id.',
    defaultPayload: {'messageId': ''},
  ),
  SdkLabOperationTemplate(
    id: 'rich_doc.normalize_markdown',
    family: 'Message Builder',
    title: 'Normalize RichDoc Markdown',
    description: 'Core RichDoc v2 normalization from Markdown.',
    defaultPayload: {'markdown': '# Flare\\n\\nHello from SDK Lab.'},
  ),
  SdkLabOperationTemplate(
    id: 'rich_doc.normalize_html',
    family: 'Message Builder',
    title: 'Normalize RichDoc HTML',
    description: 'Core RichDoc v2 normalization from HTML.',
    defaultPayload: {'html': '<h1>Flare</h1><p>Hello from SDK Lab.</p>'},
  ),
  SdkLabOperationTemplate(
    id: 'rich_doc.normalize_doc_json',
    family: 'Message Builder',
    title: 'Normalize RichDoc JSON',
    description: 'Core RichDoc v2 validation from editor JSON.',
    defaultPayload: {'docJson': '{"type":"doc","content":[]}'},
  ),
  SdkLabOperationTemplate(
    id: 'media.get_url',
    family: 'Media',
    title: 'Get Media URL',
    description: 'Resolve a stable media access URL.',
    defaultPayload: {'mediaId': '', 'expiresIn': 3600},
  ),
  SdkLabOperationTemplate(
    id: 'media.temp_download_url',
    family: 'Media',
    title: 'Get Temp Download URL',
    description: 'Resolve a temporary download URL for a file id.',
    defaultPayload: {'fileId': '', 'expiresIn': 3600},
  ),
  SdkLabOperationTemplate(
    id: 'media.resolve_access',
    family: 'Media',
    title: 'Resolve Media Access',
    description: 'Resolve download/access metadata for a file id.',
    defaultPayload: {'fileId': '', 'expiresIn': 3600},
  ),
  SdkLabOperationTemplate(
    id: 'media.cache_remote',
    family: 'Media',
    title: 'Cache Remote Media',
    description: 'Ask core media cache to cache a remote file.',
    defaultPayload: {'fileId': '', 'expiresIn': 3600},
  ),
  SdkLabOperationTemplate(
    id: 'media.user_download_get_saved_path',
    family: 'Media',
    title: 'Get User Download Saved Path',
    description: 'Lookup a saved download path by download key.',
    defaultPayload: {'downloadKey': ''},
  ),
  SdkLabOperationTemplate(
    id: 'media.user_download_delete_record',
    family: 'Media',
    title: 'Delete User Download Record',
    description: 'Delete one local user-download record.',
    defaultPayload: {'downloadKey': ''},
  ),
  SdkLabOperationTemplate(
    id: 'media.cancel_user_file_download',
    family: 'Media',
    title: 'Cancel User File Download',
    description: 'Cancel an in-flight user download by key.',
    defaultPayload: {'downloadKey': ''},
  ),
  SdkLabOperationTemplate(
    id: 'media.download_file_to_downloads',
    family: 'Media',
    title: 'Download File To Downloads',
    description: 'Download or copy a source into the user downloads area.',
    defaultPayload: {
      'downloadKey': 'sdk-lab-download',
      'displayFileName': 'flare-sdk-lab.bin',
      'sourcePath': null,
      'sourceUrl': null,
      'remoteFileId': null,
      'expiresIn': 3600,
    },
  ),
  SdkLabOperationTemplate(
    id: 'presence.batch_get',
    family: 'Presence',
    title: 'Batch Get Presence',
    description: 'Batch presence query with editable user ids.',
    defaultPayload: {
      'userIds': ['{{currentUserId}}'],
    },
  ),
  SdkLabOperationTemplate(
    id: 'capability.dispatch',
    family: 'Capability',
    title: 'Dispatch Capability',
    description: 'Generic optional capability dispatch.',
    defaultPayload: {
      'capability': 'call',
      'op': 'probe',
      'userId': '{{currentUserId}}',
    },
  ),
  SdkLabOperationTemplate(
    id: 'connection.notify_network_change',
    family: 'Connection',
    title: 'Notify Network Change',
    description: 'Trigger SDK reconnect handling from a platform network hint.',
    defaultPayload: {
      'available': true,
      'interface': 'wifi',
      'expensive': false,
      'metered': false,
      'reason': 'flutter-sdk-lab',
    },
  ),
  SdkLabOperationTemplate(
    id: 'diagnostics.runtime_health',
    family: 'Diagnostics',
    title: 'Runtime Health',
    description:
        'Read runtime metrics, state, and bounded event drop counters.',
    defaultPayload: <String, Object?>{},
  ),
  SdkLabOperationTemplate(
    id: 'sdk.heartbeat_effective_interval',
    family: 'Session',
    title: 'Heartbeat Effective Interval',
    description: 'Read the currently effective adaptive heartbeat interval.',
    defaultPayload: <String, Object?>{},
  ),
  SdkLabOperationTemplate(
    id: 'sdk.set_heartbeat_app_state',
    family: 'Session',
    title: 'Set Heartbeat App State',
    description:
        'Update foreground/background state used by heartbeat scheduling.',
    defaultPayload: {'appState': 'foreground'},
  ),
  SdkLabOperationTemplate(
    id: 'sdk.set_heartbeat_nat_timeout',
    family: 'Session',
    title: 'Set Heartbeat NAT Timeout',
    description: 'Provide or clear the observed NAT idle timeout hint.',
    defaultPayload: {'natTimeoutSecs': 60},
  ),
  SdkLabOperationTemplate(
    id: 'sdk.current_user_id',
    family: 'Session',
    title: 'Current User Id',
    description: 'Read the active SDK user identity.',
    defaultPayload: <String, Object?>{},
  ),
  SdkLabOperationTemplate(
    id: 'sdk.session_active',
    family: 'Session',
    title: 'Session Active',
    description: 'Read session and connection booleans through diagnostics.',
    defaultPayload: <String, Object?>{},
  ),
];

String sdkLabDefaultBuilderPayloadJson(Map<String, Object?> entry) {
  return const JsonEncoder.withIndent(
    '  ',
  ).convert(sdkLabDefaultBuilderPayload(entry));
}

Map<String, Object?> sdkLabDefaultBuilderPayload(Map<String, Object?> entry) {
  final contentType = '${entry['contentType'] ?? ''}';
  final op = _wireBuildOp('${entry['op'] ?? ''}');
  final payload = <String, Object?>{'op': op, 'conversationId': ''};
  switch (contentType) {
    case 'text':
      payload['text'] = 'Hello from Flutter SDK Lab';
    case 'image':
      payload['imageId'] = '';
    case 'imageGroup':
      payload['imageIds'] = <String>[];
    case 'video':
      payload['videoId'] = '';
    case 'audio':
      payload
        ..['audioId'] = ''
        ..['durationMs'] = 0;
    case 'file':
      payload
        ..['fileId'] = ''
        ..['name'] = 'flare-sdk-lab.bin'
        ..['size'] = 0;
    case 'location':
      payload
        ..['latitude'] = 0
        ..['longitude'] = 0
        ..['name'] = 'SDK Lab'
        ..['address'] = '';
    case 'card':
      payload['card'] = <String, Object?>{
        'title': 'SDK Lab Card',
        'subtitle': '',
        'url': '',
      };
    case 'sticker':
      payload['stickerId'] = '';
    case 'emoji':
      payload['emoji'] = '👍';
    case 'quote':
      payload
        ..['text'] = 'Quoted reply from SDK Lab'
        ..['quotedMessageId'] = '';
    case 'linkCard':
      payload
        ..['url'] = 'https://flare.im'
        ..['title'] = 'Flare IM'
        ..['description'] = '';
    case 'forward':
      payload['messageIds'] = <String>[];
    case 'thread':
      payload
        ..['rootMessageId'] = ''
        ..['text'] = 'Thread reply from SDK Lab';
    case 'miniProgram':
      payload['miniProgram'] = <String, Object?>{
        'appId': '',
        'path': '',
        'title': 'SDK Lab Mini Program',
      };
    case 'richText':
      payload['docJson'] = '{"type":"doc","content":[]}';
    case 'system':
    case 'notification':
    case 'announcement':
      payload['text'] = 'System notice from SDK Lab';
    case 'vote':
      payload
        ..['title'] = 'SDK Lab Vote'
        ..['options'] = ['A', 'B'];
    case 'task':
      payload
        ..['title'] = 'SDK Lab Task'
        ..['assigneeIds'] = <String>[];
    case 'schedule':
      payload
        ..['title'] = 'SDK Lab Schedule'
        ..['startAt'] = 0;
    case 'custom':
      payload
        ..['contentType'] = 'custom'
        ..['data'] = <String, Object?>{'source': 'flutter_sdk_lab'};
    case 'placeholder':
      payload['reason'] = 'SDK Lab placeholder';
    default:
      payload['data'] = <String, Object?>{'source': 'flutter_sdk_lab'};
  }
  return payload;
}

String _wireBuildOp(String opName) {
  if (opName.isEmpty) return 'create_text';
  final buffer = StringBuffer();
  for (var i = 0; i < opName.length; i += 1) {
    final char = opName[i];
    final lower = char.toLowerCase();
    if (i > 0 && char != lower) buffer.write('_');
    buffer.write(lower);
  }
  return buffer.toString();
}

class SdkLabNotifier extends StateNotifier<SdkLabSnapshot> {
  SdkLabNotifier(this._ref) : super(const SdkLabSnapshot()) {
    final sdk = _ref.read(sdkWrapperProvider);
    _subscription = sdk.addEventListener(_SdkLabEventListener(_appendEvent));
    _ref.onDispose(() {
      _subscription?.unsubscribe();
      _subscription = null;
    });
  }

  static const _maxEvents = 80;
  static const _maxFailures = 40;

  final Ref _ref;
  core.EventSubscription? _subscription;

  Future<void> refresh() async {
    state = state.copyWith(loading: true, clearError: true);
    final sdk = _ref.read(sdkWrapperProvider);
    final userId = _currentUserId();
    final failures = [...state.failures];

    Future<T> capture<T>(
      String operation,
      T fallback,
      Future<T> Function() action,
    ) async {
      try {
        return await action();
      } catch (error) {
        failures.insert(0, _failureFromError(operation, error));
        return fallback;
      }
    }

    final diagnostics = await capture(
      'diagnostics.snapshot',
      <String, Object?>{},
      sdk.diagnosticsSnapshot,
    );
    final capabilities = await capture(
      'capabilities.list',
      <String, Object?>{},
      sdk.listCapabilities,
    );
    final userCapabilities = userId.isEmpty
        ? <String, Object?>{}
        : await capture(
            'capabilities.list_user',
            <String, Object?>{},
            () => sdk.listUserCapabilities(userId),
          );
    final mediaCache = await capture(
      'media.cache_stats',
      <String, Object?>{},
      sdk.mediaCacheStats,
    );
    final builderOperations = await capture(
      'message_builder.catalog',
      const <Map<String, Object?>>[],
      sdk.listMessageBuildOperations,
    );
    final presence = userId.isEmpty
        ? <String, Object?>{}
        : await capture(
            'presence.get',
            <String, Object?>{},
            () => sdk.getUserPresence(userId),
          );

    state = state.copyWith(
      loading: false,
      diagnostics: diagnostics,
      capabilities: capabilities,
      userCapabilities: userCapabilities,
      mediaCache: mediaCache,
      builderOperations: builderOperations,
      presence: presence,
      failures: _trimFailures(failures),
    );
  }

  Future<void> clearMediaCache() {
    return runOperation('media.clear_cache', (sdk) async {
      await sdk.clearMediaCache();
      return sdk.mediaCacheStats();
    });
  }

  Future<void> setMediaCacheMaxBytes() {
    return runOperation('media.set_cache_max_bytes', (sdk) async {
      await sdk.setMediaCacheMaxBytes(256 * 1024 * 1024);
      return sdk.mediaCacheStats();
    });
  }

  Future<void> setUserDownloadSubfolder() {
    return runOperation('media.set_user_download_subfolder', (sdk) async {
      await sdk.setUserDownloadSubfolder('flare-sdk-lab');
      final folder = await sdk.getUserDownloadSubfolder();
      return {'subfolder': folder};
    });
  }

  Future<void> getUserDownloadSubfolder() {
    return runOperation('media.get_user_download_subfolder', (sdk) async {
      final folder = await sdk.getUserDownloadSubfolder();
      return {'subfolder': folder};
    });
  }

  Future<void> uploadMediaPath(String path, {required String kind}) {
    return runOperation('media.upload_$kind', (sdk) async {
      final trimmed = path.trim();
      if (trimmed.isEmpty) {
        throw ArgumentError.value(path, 'path', 'must not be empty');
      }
      return switch (kind) {
        'image' => sdk.uploadImage(trimmed),
        'video' => sdk.uploadVideo(trimmed),
        _ => sdk.uploadFile(trimmed),
      };
    });
  }

  Future<void> uploadBytesSample() {
    return runOperation('media.upload_bytes', (sdk) {
      final bytes = utf8.encode(
        'Flare Flutter SDK Lab bytes ${DateTime.now().toIso8601String()}',
      );
      return sdk.uploadBytes(
        bytes: Uint8List.fromList(bytes),
        fileName: 'flare-sdk-lab.txt',
        mimeType: 'text/plain',
      );
    });
  }

  Future<void> getMediaUrl(String mediaId) {
    return runOperation('media.get_url', (sdk) {
      return sdk.getMediaUrl(_requiredText(mediaId, 'mediaId'));
    });
  }

  Future<void> getTempDownloadUrl(String fileId) {
    return runOperation('media.temp_download_url', (sdk) {
      return sdk.getTempDownloadUrl(_requiredText(fileId, 'fileId'));
    });
  }

  Future<void> resolveMediaAccess(String fileId) {
    return runOperation('media.resolve_access', (sdk) {
      return sdk.resolveMediaAccess(_requiredText(fileId, 'fileId'));
    });
  }

  Future<void> cacheRemoteMedia(String fileId) {
    return runOperation('media.cache_remote', (sdk) {
      return sdk.cacheRemoteMedia(_requiredText(fileId, 'fileId'));
    });
  }

  Future<void> downloadFileToDownloads({
    required String downloadKey,
    required String displayFileName,
    String? sourcePath,
    String? sourceUrl,
    String? remoteFileId,
  }) {
    return runOperation('media.download_file_to_downloads', (sdk) async {
      final normalizedSourcePath = _optionalText(sourcePath);
      final normalizedSourceUrl = _optionalText(sourceUrl);
      final normalizedRemoteFileId = _optionalText(remoteFileId);
      if (normalizedSourcePath == null &&
          normalizedSourceUrl == null &&
          normalizedRemoteFileId == null) {
        throw ArgumentError(
          'sourcePath, sourceUrl, or remoteFileId must be provided',
        );
      }
      final path = await sdk.downloadFileToDownloads(
        downloadKey: _requiredText(downloadKey, 'downloadKey'),
        displayFileName: _requiredText(displayFileName, 'displayFileName'),
        sourcePath: normalizedSourcePath,
        sourceUrl: normalizedSourceUrl,
        remoteFileId: normalizedRemoteFileId,
      );
      return {'path': path};
    });
  }

  Future<void> getUserDownloadSavedPath(String downloadKey) {
    return runOperation('media.user_download_get_saved_path', (sdk) async {
      final path = await sdk.getUserDownloadSavedPath(
        _requiredText(downloadKey, 'downloadKey'),
      );
      return {'path': path};
    });
  }

  Future<void> deleteUserDownloadRecord(String downloadKey) {
    return runOperation('media.user_download_delete_record', (sdk) async {
      await sdk.deleteUserDownloadRecord(
        _requiredText(downloadKey, 'downloadKey'),
      );
      return {'deleted': true};
    });
  }

  Future<void> cancelUserFileDownload(String downloadKey) {
    return runOperation('media.cancel_user_file_download', (sdk) async {
      final cancelled = await sdk.cancelUserFileDownload(
        _requiredText(downloadKey, 'downloadKey'),
      );
      return {'cancelled': cancelled};
    });
  }

  Future<void> getCurrentUserPresence() {
    return runOperation('presence.get', (sdk) async {
      final userId = _requireCurrentUserId();
      return sdk.getUserPresence(userId);
    });
  }

  Future<void> batchGetCurrentUserPresence() {
    return runOperation('presence.batch_get', (sdk) async {
      final userId = _requireCurrentUserId();
      return sdk.batchGetUserPresence([userId]);
    });
  }

  Future<void> subscribeCurrentUserPresence() {
    return runOperation('presence.subscribe', (sdk) async {
      final userId = _requireCurrentUserId();
      await sdk.subscribeUserPresence([userId]);
      return {
        'subscribedUserIds': [userId],
      };
    });
  }

  Future<void> syncConversationSummaries() {
    return runOperation('sync.conversation_summaries', (sdk) async {
      await sdk.syncConversationSummaries();
      return {'queued': true};
    });
  }

  Future<void> renewAccessToken({int ttlSecs = 3600}) {
    return runOperation('auth.update_access_token', (sdk) async {
      // 客户端不再签发：SDK 托管 token 由核心到期前自动刷新；应用托管形态请在登录页粘贴 token。
      final userId = _requireCurrentUserId();
      throw StateError(
        'access token for $userId is issued and refreshed by the SDK via the gateway (ttl hint $ttlSecs ignored); '
        'paste a backend-issued token on the login screen to apply one manually',
      );
    });
  }

  Future<void> listRawConversations() {
    return runOperation('conversation.list_raw', (sdk) async {
      final items = await sdk.getRawConversations();
      return {
        'count': items.length,
        'items': items
            .map(SdkModelMapper.conversationJsonFromCore)
            .toList(growable: false),
      };
    });
  }

  Future<void> listConversationsPaginated() {
    return runOperation('conversation.list_paginated', (sdk) async {
      final items = await sdk.getConversationsPaginated(limit: 20);
      return {
        'count': items.length,
        'items': items
            .map(SdkModelMapper.conversationJsonFromCore)
            .toList(growable: false),
      };
    });
  }

  Future<void> runBuilderOperation(String op, String payloadJson) {
    return runOperation('message_builder.$op', (sdk) async {
      final payload = _resolveTemplatePayload(
        _decodePayloadJson(payloadJson),
        currentUserId: _currentUserId(),
      );
      return sdk.messageBuildJson(payload);
    });
  }

  Future<void> runTemplateOperation(String templateId, String payloadJson) {
    return runOperation(templateId, (sdk) async {
      final payload = _resolveTemplatePayload(
        _decodePayloadJson(payloadJson),
        currentUserId: _currentUserId(),
      );
      switch (templateId) {
        case 'conversation.bootstrap_home':
          final snapshot = await sdk.bootstrapHomeTimeline(
            conversationLimit: _payloadInt(payload, 'conversationLimit', 50),
          );
          return {
            'conversations': snapshot.conversations
                .map(SdkModelMapper.conversationJsonFromCore)
                .toList(growable: false),
            'totalUnread': snapshot.totalUnread,
            'syncState': snapshot.syncState.name,
          };
        case 'conversation.open_timeline':
          final snapshot = await sdk.openConversationTimeline(
            conversationId: _requiredPayloadString(payload, 'conversationId'),
            messageLimit: _payloadInt(payload, 'messageLimit', 30),
          );
          return {
            'conversation': snapshot.conversation == null
                ? null
                : SdkModelMapper.conversationJsonFromCore(
                    snapshot.conversation!,
                  ),
            'messages': snapshot.messages
                .map(SdkModelMapper.messageJsonFromCore)
                .toList(growable: false),
            'hasMore': snapshot.hasMore,
          };
        case 'conversation.get_group_by_user_ids':
          final conversation = await sdk.getGroupConversationByUserIds(
            _payloadStringList(payload, 'userIds'),
            displayName: _payloadOptionalString(payload, 'displayName'),
          );
          return SdkModelMapper.conversationJsonFromCore(conversation);
        case 'conversation.get_multiple':
          final items = await sdk.getMultipleConversations(
            _payloadStringList(payload, 'conversationIds'),
          );
          return {
            'count': items.length,
            'items': items
                .map(SdkModelMapper.conversationJsonFromCore)
                .toList(growable: false),
          };
        case 'message.build_raw':
          return sdk.messageBuildJson(payload);
        case 'message.send_no_oss':
          return sdk.sendMessageNoOss(payload);
        case 'message.get':
          return sdk.getMessageJson(payload);
        case 'message.get_raw':
          return sdk.getRawMessageJson(payload);
        case 'message.mark_read_and_burn':
        case 'message.edit_rich_doc_by_message_id':
        case 'message.pin':
        case 'message.unpin':
        case 'message.mark_with_color':
        case 'message.unmark_by_message_id':
          return sdk.messageCommandJson(
            templateId.substring('message.'.length),
            payload,
          );
        case 'rich_doc.normalize_markdown':
          return sdk.normalizeRichDocFromMarkdown(
            _payloadString(payload, 'markdown'),
          );
        case 'rich_doc.normalize_html':
          return sdk.normalizeRichDocFromHtml(_payloadString(payload, 'html'));
        case 'rich_doc.normalize_doc_json':
          return sdk.normalizeRichDocFromDocJson(
            _payloadString(payload, 'docJson'),
          );
        case 'media.get_url':
          return sdk.getMediaUrl(
            _requiredPayloadString(payload, 'mediaId'),
            expiresIn: _payloadInt(payload, 'expiresIn', 3600),
          );
        case 'media.temp_download_url':
          return sdk.getTempDownloadUrl(
            _requiredPayloadString(payload, 'fileId'),
            expiresIn: _payloadInt(payload, 'expiresIn', 3600),
          );
        case 'media.resolve_access':
          return sdk.resolveMediaAccess(
            _requiredPayloadString(payload, 'fileId'),
            expiresIn: _payloadInt(payload, 'expiresIn', 3600),
          );
        case 'media.cache_remote':
          return sdk.cacheRemoteMedia(
            _requiredPayloadString(payload, 'fileId'),
            expiresIn: _payloadInt(payload, 'expiresIn', 3600),
          );
        case 'media.user_download_get_saved_path':
          final path = await sdk.getUserDownloadSavedPath(
            _requiredPayloadString(payload, 'downloadKey'),
          );
          return {'path': path};
        case 'media.user_download_delete_record':
          await sdk.deleteUserDownloadRecord(
            _requiredPayloadString(payload, 'downloadKey'),
          );
          return {'deleted': true};
        case 'media.cancel_user_file_download':
          final cancelled = await sdk.cancelUserFileDownload(
            _requiredPayloadString(payload, 'downloadKey'),
          );
          return {'cancelled': cancelled};
        case 'media.download_file_to_downloads':
          final path = await sdk.downloadFileToDownloads(
            downloadKey: _requiredPayloadString(payload, 'downloadKey'),
            displayFileName: _requiredPayloadString(payload, 'displayFileName'),
            sourcePath: _payloadOptionalString(payload, 'sourcePath'),
            sourceUrl: _payloadOptionalString(payload, 'sourceUrl'),
            remoteFileId: _payloadOptionalString(payload, 'remoteFileId'),
            expiresIn: _payloadInt(payload, 'expiresIn', 3600),
          );
          return {'path': path};
        case 'presence.batch_get':
          return sdk.batchGetUserPresence(
            _payloadStringList(payload, 'userIds'),
          );
        case 'capability.dispatch':
          return sdk.dispatchCapability(payload);
        case 'connection.notify_network_change':
          return sdk.notifyNetworkChange(
            available: _payloadBool(payload, 'available'),
            interface: _payloadOptionalString(payload, 'interface'),
            expensive: _payloadBool(payload, 'expensive'),
            metered: _payloadBool(payload, 'metered'),
            reason: _payloadOptionalString(payload, 'reason'),
          );
        case 'diagnostics.runtime_health':
          return sdk.runtimeHealth();
        case 'sdk.heartbeat_effective_interval':
          return sdk.heartbeatEffectiveInterval();
        case 'sdk.set_heartbeat_app_state':
          return sdk.setHeartbeatAppState(
            _payloadString(payload, 'appState') == 'background'
                ? core.HeartbeatAppState.background
                : core.HeartbeatAppState.foreground,
          );
        case 'sdk.set_heartbeat_nat_timeout':
          return sdk.setHeartbeatNatTimeout(
            _payloadOptionalInt(payload, 'natTimeoutSecs'),
          );
        case 'sdk.current_user_id':
          return {'userId': await sdk.currentUserId()};
        case 'sdk.session_active':
          final diagnostics = await sdk.diagnosticsSnapshot();
          return {
            'sessionActive': diagnostics['sessionActive'],
            'connected': diagnostics['connected'],
            'connectionState': diagnostics['connectionState'],
          };
        default:
          throw ArgumentError.value(
            templateId,
            'templateId',
            'unknown template',
          );
      }
    });
  }

  Future<void> dispatchCapabilityProbe() {
    return runOperation('capability.dispatch', (sdk) async {
      final userId = _currentUserId();
      return sdk.dispatchCapability({
        'capabilityId': 'sdk.lab.probe',
        'payload': const <String, Object?>{},
        if (userId.isNotEmpty) 'userId': userId,
      });
    });
  }

  Future<void> disconnect() {
    return runOperation('connection.disconnect', (sdk) async {
      await sdk.disconnect();
      return {'disconnected': true};
    });
  }

  Future<void> notifyNetworkChangeProbe() {
    return runOperation('connection.notify_network_change', (sdk) {
      return sdk.notifyNetworkChange(
        available: true,
        interface: 'wifi',
        expensive: false,
        metered: false,
        reason: 'flutter-sdk-lab',
      );
    });
  }

  Future<void> runtimeHealth() {
    return runOperation('diagnostics.runtime_health', (sdk) {
      return sdk.runtimeHealth();
    });
  }

  Future<void> heartbeatEffectiveInterval() {
    return runOperation('sdk.heartbeat_effective_interval', (sdk) {
      return sdk.heartbeatEffectiveInterval();
    });
  }

  Future<void> setHeartbeatForeground() {
    return runOperation('sdk.set_heartbeat_app_state.foreground', (sdk) {
      return sdk.setHeartbeatAppState(core.HeartbeatAppState.foreground);
    });
  }

  Future<void> setHeartbeatBackground() {
    return runOperation('sdk.set_heartbeat_app_state.background', (sdk) {
      return sdk.setHeartbeatAppState(core.HeartbeatAppState.background);
    });
  }

  Future<void> setHeartbeatNatTimeout() {
    return runOperation('sdk.set_heartbeat_nat_timeout', (sdk) {
      return sdk.setHeartbeatNatTimeout(60);
    });
  }

  Future<void> unsubscribeAllEvents() {
    return runOperation('events.unsubscribe_all', (sdk) async {
      await sdk.unsubscribeAllEvents();
      return {'unsubscribedAll': true};
    });
  }

  Future<void> uninit() {
    return runOperation('sdk.uninit', (sdk) async {
      await sdk.uninit();
      return {'uninitialized': true};
    });
  }

  Future<void> hardReset() {
    return runOperation('sdk.hard_reset', (sdk) async {
      await sdk.resetSdk();
      return {'hardReset': true};
    });
  }

  void clearLogs() {
    state = state.copyWith(
      events: const <SdkLabEventEntry>[],
      failures: const <SdkLabFailureEntry>[],
      lastResult: SdkLabOperationResult(
        operation: 'sdk_lab.clear_logs',
        timestamp: DateTime.now(),
        value: const {'cleared': true},
      ),
    );
  }

  Future<void> runOperation(
    String operation,
    Future<Object?> Function(SdkWrapper sdk) action,
  ) async {
    state = state.copyWith(runningOperation: operation, clearError: true);
    final sdk = _ref.read(sdkWrapperProvider);
    try {
      final value = await action(sdk);
      final result = SdkLabOperationResult(
        operation: operation,
        timestamp: DateTime.now(),
        value: value,
      );
      state = state.copyWith(clearRunningOperation: true, lastResult: result);
      if (_shouldRefreshAfter(operation)) {
        await refresh();
        state = state.copyWith(lastResult: result);
      }
    } catch (error) {
      final failure = _failureFromError(operation, error);
      state = state.copyWith(
        clearRunningOperation: true,
        error: failure.message,
        failures: _trimFailures([failure, ...state.failures]),
        lastResult: SdkLabOperationResult(
          operation: operation,
          timestamp: failure.timestamp,
          value: failure.toJson(),
        ),
      );
    }
  }

  void _appendEvent(String domain, String name, Map<String, Object?> payload) {
    if (!mounted) return;
    final entry = SdkLabEventEntry(
      domain: domain,
      name: name,
      timestamp: DateTime.now(),
      payload: payload,
    );
    state = state.copyWith(
      events: [entry, ...state.events].take(_maxEvents).toList(growable: false),
    );
  }

  String _currentUserId() => _ref.read(currentUserProvider)?.userId ?? '';

  String _requireCurrentUserId() {
    final userId = _currentUserId().trim();
    if (userId.isEmpty) {
      throw StateError('SDK Lab operation requires an active logged-in user.');
    }
    return userId;
  }

  bool _shouldRefreshAfter(String operation) {
    return operation.startsWith('media.') ||
        operation.startsWith('capability.') ||
        operation.startsWith('presence.') ||
        operation.startsWith('message.') ||
        operation.startsWith('message_builder.') ||
        operation.startsWith('rich_doc.') ||
        operation.startsWith('auth.') ||
        operation.startsWith('conversation.') ||
        operation.startsWith('connection.') ||
        operation.startsWith('diagnostics.') ||
        operation.startsWith('sdk.');
  }

  List<SdkLabFailureEntry> _trimFailures(List<SdkLabFailureEntry> failures) {
    return failures.take(_maxFailures).toList(growable: false);
  }
}

SdkLabFailureEntry _failureFromError(String operation, Object error) {
  if (error is core.FlareSdkException) {
    return SdkLabFailureEntry(
      operation: error.operation ?? operation,
      code: error.code,
      message: error.message,
      details: {'details': _jsonSafe(error.details)},
      timestamp: DateTime.now(),
      cause: error.toString(),
    );
  }
  return SdkLabFailureEntry(
    operation: operation,
    code: error.runtimeType.toString(),
    message: error.toString(),
    timestamp: DateTime.now(),
    cause: error.toString(),
  );
}

Map<String, dynamic> _decodePayloadJson(String payloadJson) {
  final decoded = jsonDecode(payloadJson);
  if (decoded is! Map) {
    throw ArgumentError.value(
      payloadJson,
      'payloadJson',
      'expected JSON object',
    );
  }
  return _jsonObject(decoded);
}

Map<String, dynamic> _jsonObject(Map source) {
  return source.map<String, dynamic>(
    (key, value) => MapEntry(key.toString(), _jsonValue(value)),
  );
}

Object? _jsonValue(Object? value) {
  if (value is Map) return _jsonObject(value);
  if (value is Iterable) return value.map(_jsonValue).toList(growable: false);
  return value;
}

Map<String, dynamic> _resolveTemplatePayload(
  Map<String, dynamic> source, {
  required String currentUserId,
}) {
  return source.map<String, dynamic>(
    (key, value) => MapEntry(
      key,
      _resolveTemplateValue(value, currentUserId: currentUserId),
    ),
  );
}

Object? _resolveTemplateValue(Object? value, {required String currentUserId}) {
  if (value is String) {
    return value.replaceAll('{{currentUserId}}', currentUserId);
  }
  if (value is Map) {
    return value.map<String, Object?>(
      (key, item) => MapEntry(
        key.toString(),
        _resolveTemplateValue(item, currentUserId: currentUserId),
      ),
    );
  }
  if (value is Iterable) {
    return value
        .map(
          (item) => _resolveTemplateValue(item, currentUserId: currentUserId),
        )
        .toList(growable: false);
  }
  return value;
}

String _payloadString(Map<String, dynamic> payload, String key) {
  final value = payload[key];
  if (value == null) return '';
  return '$value';
}

String _requiredPayloadString(Map<String, dynamic> payload, String key) {
  final value = _payloadString(payload, key).trim();
  if (value.isEmpty) {
    throw ArgumentError.value(payload[key], key, 'must not be empty');
  }
  return value;
}

String? _payloadOptionalString(Map<String, dynamic> payload, String key) {
  final value = payload[key];
  if (value == null) return null;
  final text = '$value'.trim();
  return text.isEmpty ? null : text;
}

int _payloadInt(Map<String, dynamic> payload, String key, int fallback) {
  final value = payload[key];
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

int? _payloadOptionalInt(Map<String, dynamic> payload, String key) {
  if (!payload.containsKey(key) || payload[key] == null) return null;
  return _payloadInt(payload, key, 0);
}

bool? _payloadBool(Map<String, dynamic> payload, String key) {
  final value = payload[key];
  if (value == null) return null;
  if (value is bool) return value;
  final normalized = '$value'.trim().toLowerCase();
  if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
    return true;
  }
  if (normalized == 'false' || normalized == '0' || normalized == 'no') {
    return false;
  }
  return null;
}

List<String> _payloadStringList(Map<String, dynamic> payload, String key) {
  final value = payload[key];
  if (value is Iterable) {
    return value
        .map((item) => '$item'.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
  final single = '$value'.trim();
  return single.isEmpty || single == 'null' ? const <String>[] : [single];
}

String _requiredText(String value, String name) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    throw ArgumentError.value(value, name, 'must not be empty');
  }
  return trimmed;
}

String? _optionalText(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
}

Object? _jsonSafe(Object? value) {
  if (value == null || value is num || value is bool || value is String) {
    return value;
  }
  if (value is Map) {
    return value.map<String, Object?>(
      (key, item) => MapEntry(key.toString(), _jsonSafe(item)),
    );
  }
  if (value is Iterable) {
    return value.map(_jsonSafe).toList(growable: false);
  }
  return value.toString();
}

final class _SdkLabEventListener extends core.FlareImEventListener {
  const _SdkLabEventListener(this.record);

  final void Function(String domain, String name, Map<String, Object?> payload)
  record;

  @override
  void onInitializing(core.LifecycleEvent event) =>
      _lifecycle('initializing', event);

  @override
  void onInitialized(core.LifecycleEvent event) =>
      _lifecycle('initialized', event);

  @override
  void onInitFailed(core.LifecycleEvent event) =>
      _lifecycle('init_failed', event);

  @override
  void onLoginSucceeded(core.LifecycleEvent event) =>
      _lifecycle('login_succeeded', event);

  @override
  void onLoginFailed(core.LifecycleEvent event) =>
      _lifecycle('login_failed', event);

  @override
  void onLoggedOut(core.LifecycleEvent event) =>
      _lifecycle('logged_out', event);

  @override
  void onDisposed(core.LifecycleEvent event) => _lifecycle('disposed', event);

  @override
  void onConnecting(core.ConnectionEvent event) =>
      _connection('connecting', event);

  @override
  void onConnectSuccess(core.ConnectionEvent event) =>
      _connection('connected', event);

  @override
  void onConnectReady(core.ConnectionEvent event) =>
      _connection('ready', event);

  @override
  void onConnectFailed(core.ConnectionEvent event) =>
      _connection('server_error', event);

  @override
  void onDisconnected(core.ConnectionEvent event) =>
      _connection('disconnected', event);

  @override
  void onReconnecting(core.ConnectionEvent event) =>
      _connection('reconnecting', event);

  @override
  void onReconnectFailed(core.ConnectionEvent event) =>
      _connection('reconnect_failed', event);

  @override
  void onKickedOffline(core.ConnectionEvent event) =>
      _connection('kicked_off', event);

  @override
  void onUserTokenExpired(core.ConnectionEvent event) =>
      _connection('token_expired', event);

  @override
  void onMessageReceived(core.MessageReceivedEvent event) {
    record('message', 'received', {
      'message': SdkModelMapper.messageJsonFromCore(event.message),
    });
  }

  @override
  void onMessageReceivedBatch(core.MessageReceivedBatchEvent event) {
    record('message', 'received_batch', {'count': event.messages.length});
  }

  @override
  void onMessageSendAck(core.MessageSendAckEvent event) {
    record('message', 'send_ack', {
      'ack': SdkModelMapper.sendAckJsonFromCore(event.ack),
    });
  }

  @override
  void onMessageSendFailed(core.MessageSendFailedEvent event) {
    record(
      'message',
      'send_failed',
      SdkModelMapper.sendFailureJsonFromCore(event),
    );
  }

  @override
  void onMessageRecalled(core.MessageMutationEvent event) =>
      _mutation('recalled', event);

  @override
  void onMessageEdited(core.MessageMutationEvent event) =>
      _mutation('edited', event);

  @override
  void onMessageDeleted(core.MessageMutationEvent event) =>
      _mutation('deleted', event);

  @override
  void onMessageReadReceipt(core.ReadReceiptEvent event) {
    record('message', 'read_receipt', {
      'conversationId': event.conversationId,
      'userId': event.userId,
      'readSeq': event.readSeq,
    });
  }

  @override
  void onMessageReactionChanged(core.ReactionChangedEvent event) {
    record('message', 'reaction_changed', {
      'conversationId': event.conversationId,
      'serverMsgId': event.serverMsgId,
      'userId': event.userId,
      'emoji': event.emoji,
      'action': event.action,
    });
  }

  @override
  void onInputStatusChanged(core.TypingEvent event) {
    record('message', 'typing', {
      'conversationId': event.conversationId,
      'userId': event.userId,
      'typing': event.typing,
    });
  }

  @override
  void onTypingAggregateChanged(core.TypingAggregateEvent event) {
    record('message', 'typing_aggregate', {
      'conversationId': event.conversationId,
      'typingUserIds': event.typingUserIds,
      'typingCount': event.typingCount,
    });
  }

  @override
  void onMessageBurned(core.MessageMutationEvent event) =>
      _mutation('burned', event);

  @override
  void onMessagePinned(core.MessageMutationEvent event) =>
      _mutation('pinned', event);

  @override
  void onMessageUnpinned(core.MessageMutationEvent event) =>
      _mutation('unpinned', event);

  @override
  void onMessagePluginStateChanged(core.MessageMutationEvent event) =>
      _mutation('plugin_state_changed', event);

  @override
  void onNewConversation(core.ConversationEvent event) =>
      _conversation('created', event);

  @override
  void onConversationChanged(core.ConversationEvent event) =>
      _conversation('updated', event);

  @override
  void onTotalUnreadMessageCountChanged(core.ConversationEvent event) =>
      _conversation('unread_count_changed', event);

  @override
  void onConversationDeleted(core.ConversationEvent event) =>
      _conversation('deleted', event);

  @override
  void onViewUpdated(core.ViewUpdate event) {
    record('view', 'updated', {
      'viewId': event.viewId,
      'kind': event.kind,
      'viewType': event.snapshot?.viewType ?? event.delta?.viewType,
    });
  }

  @override
  void onSyncServerStart(core.SyncEvent event) => _sync('started', event);

  @override
  void onSyncServerFinish(core.SyncEvent event) => _sync('finished', event);

  @override
  void onSyncServerFailed(core.SyncEvent event) => _sync('failed', event);

  @override
  void onSyncProgress(core.ProgressEvent event) =>
      _progress('sync', 'progress', event);

  @override
  void onUploadProgress(core.ProgressEvent event) =>
      _progress('media', 'upload_progress', event);

  @override
  void onDownloadProgress(core.ProgressEvent event) =>
      _progress('media', 'download_progress', event);

  @override
  void onPluginRealtime(core.PluginRealtimeEvent event) {
    record('plugin', 'realtime', {
      'pluginId': event.pluginId,
      'packetType': event.packetType,
      'conversationId': event.conversationId,
      'deliveryId': event.deliveryId,
    });
  }

  @override
  void onPluginCatalogChanged(core.PluginCatalogChangedEvent event) {
    record('plugin', 'catalog_changed', {'version': event.version});
  }

  void _lifecycle(String name, core.LifecycleEvent event) {
    record('lifecycle', name, SdkModelMapper.lifecycleJsonFromCore(event));
  }

  void _connection(String name, core.ConnectionEvent event) {
    record('connection', name, SdkModelMapper.connectionJsonFromCore(event));
  }

  void _conversation(String name, core.ConversationEvent event) {
    record('conversation', name, {
      'conversationId': event.conversationId,
      'unreadCount': event.unreadCount,
    });
  }

  void _mutation(String name, core.MessageMutationEvent event) {
    record('message', name, {
      'conversationId': event.conversationId,
      'messageId': event.messageId,
      'serverMsgId': event.serverMsgId,
    });
  }

  void _sync(String name, core.SyncEvent event) {
    record('sync', name, SdkModelMapper.syncJsonFromCore(event));
  }

  void _progress(String domain, String name, core.ProgressEvent event) {
    record(domain, name, SdkModelMapper.progressJsonFromCore(event));
  }
}
