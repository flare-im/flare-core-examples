import 'dart:async';
import 'dart:convert';

import 'package:flare_core_flutter_sdk/flare_core_flutter_sdk.dart' as core;
import 'package:flare_im/domain/value_objects/transport_mode.dart';
import 'package:flare_im/infrastructure/mappers/sdk_model_mapper.dart';
import 'package:flutter/foundation.dart';

final class SdkConfig {
  const SdkConfig({
    required this.wsUrl,
    required this.httpUrl,
    this.transportMode = SdkTransportMode.websocket,
    this.quicUrl = 'quic://127.0.0.1:60052',
    this.tlsCaCertPath,
    this.tlsCaCert,
    this.dataUrl,
    this.tenantId = '0',
  });

  final String wsUrl;
  final SdkTransportMode transportMode;
  final String quicUrl;
  final String? tlsCaCertPath;

  /// 内联信任 CA（PEM 或 base64 DER）：QUIC / wss 连自建 CA 签发证书的服务端时必配。
  final String? tlsCaCert;
  final String? dataUrl;
  final String tenantId;

  /// 网关 HTTP 基址：SDK 托管 token 时向 {httpUrl}/api/v1/auth/tokens 签发并自动刷新；
  /// 也是媒体等 HTTP 接口的基址。客户端从不持有签名密钥。
  final String httpUrl;
}

Map<String, Object?> buildSdkTransportConfig(SdkConfig config) {
  final wsUrl = config.wsUrl.trim();
  if (wsUrl.isEmpty) {
    throw ArgumentError('WebSocket URL is required');
  }
  final tlsCaCertPath = config.tlsCaCertPath?.trim();
  final tlsConfig = <String, Object?>{
    if (tlsCaCertPath != null && tlsCaCertPath.isNotEmpty)
      'tlsCaCertPath': tlsCaCertPath,
    if (config.tlsCaCert != null && config.tlsCaCert!.trim().isNotEmpty)
      'tlsCaCert': config.tlsCaCert!.trim(),
  };
  if (config.transportMode == SdkTransportMode.websocket) {
    return {
      'wsUrl': wsUrl,
      ...tlsConfig,
      'transportPolicy': 'websocket_only',
      'defaultTransport': 'websocket',
    };
  }

  final quicUrl = config.quicUrl.trim();
  if (quicUrl.isEmpty) {
    throw ArgumentError('QUIC URL is required for selected transport');
  }
  if (config.transportMode == SdkTransportMode.quic) {
    return {
      'wsUrl': wsUrl,
      'quicUrl': quicUrl,
      ...tlsConfig,
      'transportPolicy': 'auto',
      'defaultTransport': 'quic',
      'protocolRaceOrder': ['quic'],
    };
  }

  return {
    'wsUrl': wsUrl,
    'quicUrl': quicUrl,
    ...tlsConfig,
    'transportPolicy': 'protocol_race',
    'defaultTransport': 'quic',
    'protocolRaceOrder': ['quic', 'websocket'],
  };
}

/// Thin app facade over the generated `flare_core_flutter_sdk` client.
final class SdkWrapper {
  SdkWrapper({core.FlareImClient? client})
    : _client = client ?? core.FlareCoreSdk.createClient();

  final core.FlareImClient _client;
  bool _initialized = false;
  String _wsUrl = '';
  SdkTransportMode _transportMode = SdkTransportMode.websocket;
  String _quicUrl = '';
  String? _tlsCaCertPath;
  String _currentUserId = '';
  String _tenantId = '0';
  String _httpUrl = '';

  /// init 时交给核心的完整 overlay。prepare 的 storeConfigJson 会让核心**重新 init**，
  /// 所以必须原样重发同一份，否则 auth / tlsCaCert 这类字段会被一份只含 ws 的配置冲掉
  /// （实测：QUIC 登录报 connect token required）。
  Map<String, Object?>? _lastInitConfig;
  String? _dataUrl;
  core.ConnectionState _lastState = core.ConnectionState.disconnected;
  Map<String, Object?>? _nativeEventSubscription;

  bool get isInitialized => _initialized;

  Future<void> init(SdkConfig config) async {
    final nextWsUrl = config.wsUrl.trim();
    final nextTransportMode = config.transportMode;
    final nextQuicUrl = config.quicUrl.trim();
    final rawTlsCaCertPath = config.tlsCaCertPath?.trim();
    final nextTlsCaCertPath =
        rawTlsCaCertPath == null || rawTlsCaCertPath.isEmpty
        ? null
        : rawTlsCaCertPath;
    final nextTenantId = config.tenantId.trim().isEmpty
        ? '0'
        : config.tenantId.trim();
    final nextDataUrl = config.dataUrl?.trim();
    final nextHttpUrl = config.httpUrl.trim();
    final transportConfig = buildSdkTransportConfig(config);
    if (_initialized &&
        _wsUrl == nextWsUrl &&
        _transportMode == nextTransportMode &&
        _quicUrl == nextQuicUrl &&
        _tlsCaCertPath == nextTlsCaCertPath &&
        _tenantId == nextTenantId &&
        _dataUrl == nextDataUrl &&
        _httpUrl == nextHttpUrl) {
      return;
    }
    if (_initialized) {
      await _cancelNativeEventSubscription();
      await _client.uninit();
    }
    await _client.hardReset();
    _initialized = false;
    _currentUserId = '';

    _wsUrl = nextWsUrl;
    _transportMode = nextTransportMode;
    _quicUrl = nextQuicUrl;
    _tlsCaCertPath = nextTlsCaCertPath;
    _tenantId = nextTenantId;
    _dataUrl = nextDataUrl;
    _httpUrl = nextHttpUrl;
    debugPrint(
      'flare sdk init transport=${_transportMode.name} ws=$_wsUrl http=$_httpUrl tenant=$_tenantId dataUrl=${_dataUrl ?? ''}',
    );
    _lastInitConfig = <String, Object?>{
      ...transportConfig,
      'tenantId': _tenantId,
      if (_httpUrl.isNotEmpty) 'httpUrl': _httpUrl,
      // SDK 托管 token：核心向 {httpUrl}/api/v1/auth/tokens 签发、到期前刷新。
      // login 传了显式 token 时核心直接用它，不走签发。
      if (_httpUrl.isNotEmpty) 'auth': {'tokenEndpoint': _httpUrl},
      if (_dataUrl != null && _dataUrl!.isNotEmpty) 'dataUrl': _dataUrl,
    };
    await _client.init(Map<String, Object?>.from(_lastInitConfig!));
    await _ensureNativeEventSubscription();
    _initialized = true;
  }

  /// 本地半段登录：开库 + 装配引擎，不连网。热启动据此先本地出图。
  Future<void> prepareLocal(String userId) async {
    _currentUserId = userId;
    debugPrint(
      'flare sdk prepare user=$userId ws=$_wsUrl tenant=$_tenantId dataUrl=${_dataUrl ?? ''}',
    );
    await _client.prepare({
      'userId': userId,
      'storeConfigJson': _storeConfigJson(),
    });
  }

  /// 网络半段：建立连接并完成首次同步。热启动在后台调用。
  Future<void> connectRemote(String userId, String? token) async {
    _lastState = await getConnectionState();
    debugPrint('flare sdk connect user=$userId state=${_lastState.name}');
    final explicit = token?.trim() ?? '';
    await _client.connect({
      'userId': userId,
      if (explicit.isNotEmpty) 'token': explicit,
    });
    await _waitForConnectionReady();
    final dataRoot = await _client.diagnostics.getDataRoot();
    final currentUser = await _client.currentUserId();
    debugPrint(
      'flare sdk login ready nativeDataRoot=${dataRoot['dataRoot'] ?? ''} '
      'currentUser=${currentUser['userId'] ?? currentUser['value'] ?? ''}',
    );
  }

  Future<void> login(String userId, [String? token]) async {
    await prepareLocal(userId);
    await connectRemote(userId, token);
  }

  Future<void> _waitForConnectionReady({
    Duration timeout = const Duration(seconds: 15),
    Duration interval = const Duration(milliseconds: 150),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (true) {
      final state = await getConnectionState();
      if (state == core.ConnectionState.ready) return;
      if (state == core.ConnectionState.disconnected &&
          DateTime.now().isAfter(deadline)) {
        throw TimeoutException('SDK connection did not reach Ready: $state');
      }
      if (DateTime.now().isAfter(deadline)) {
        throw TimeoutException('SDK connection did not reach Ready: $state');
      }
      await Future<void>.delayed(interval);
    }
  }

  Future<void> updateAccessToken(String accessToken, {String? tenantId}) {
    return _client.updateAccessToken({
      'accessToken': accessToken,
      'tenantId': tenantId ?? _tenantId,
    });
  }

  Future<void> logout() async {
    await _client.logout();
    _currentUserId = '';
  }

  Future<void> dispose() async {
    await _cancelNativeEventSubscription();
    await _client.dispose();
    _initialized = false;
    _currentUserId = '';
  }

  core.EventSubscription addEventListener(core.FlareImEventListener listener) {
    return _client.events.addEventListener(listener);
  }

  Future<String> currentUserId() async {
    if (_currentUserId.isNotEmpty) return _currentUserId;
    final result = await _client.currentUserId();
    return '${result['userId'] ?? result['value'] ?? ''}';
  }

  Future<core.ConnectionState> getConnectionState() async {
    _lastState = await _client.connection.getConnectionState();
    return _lastState;
  }

  String sdkVersionSync() => 'flare_core_flutter_sdk';

  Future<Map<String, dynamic>> diagnosticsSnapshot() async {
    final sdkVersion = await _client.diagnostics.getSdkVersion();
    final ffiVersion = await _client.diagnostics.getFfiContractVersion();
    final dataRoot = await _client.diagnostics.getDataRoot();
    final runtimeHealth = await _client.diagnostics.getRuntimeHealth();
    final connected = await _client.isConnected();
    final sessionActive = await _client.sessionActive();
    _lastState = await getConnectionState();
    var conversationCount = 0;
    String? conversationListError;
    try {
      conversationCount = (await getConversations()).length;
    } catch (e) {
      conversationListError = '$e';
    }
    return {
      'sdkVersion': sdkVersion['version'],
      'ffiContract': ffiVersion['version'],
      'nativeDataRoot': dataRoot['dataRoot'],
      'runtimeHealth': _runtimeHealthJson(runtimeHealth),
      'connected': connected,
      'sessionActive': sessionActive,
      'connectionState': _lastState.name,
      'currentUserId': _currentUserId,
      'conversationCount': conversationCount,
      'conversationListError': ?conversationListError,
      'wsUrl': _wsUrl,
      'tenantId': _tenantId,
      'dataUrl': _dataUrl,
    };
  }

  Future<Map<String, dynamic>> listCapabilities() async {
    return _dynamicMap(await _client.capabilities.listCapabilities({}));
  }

  Future<Map<String, dynamic>> listUserCapabilities(String userId) async {
    return _dynamicMap(
      await _client.capabilities.listUserCapabilities({'userId': userId}),
    );
  }

  Future<Map<String, dynamic>> dispatchCapability(
    Map<String, Object?> request,
  ) async {
    return _dynamicMap(await _client.capabilities.dispatchCapability(request));
  }

  Future<void> grantCapability(Map<String, Object?> request) {
    return _client.capabilities.grantCapability(request);
  }

  Future<void> revokeCapability(Map<String, Object?> request) {
    return _client.capabilities.revokeCapability(request);
  }

  Future<List<Map<String, Object?>>> listMessageBuildOperations() async {
    final response = await _client.messageBuilder
        .listSupportedBuildOperations();
    return response.entries
        .map(
          (entry) => <String, Object?>{
            'op': entry.op.name,
            'method': entry.method,
            'requestType': entry.requestType,
            'contentType': entry.contentType.name,
            'messageType': entry.messageType,
            'summary': entry.summary,
            'stability': entry.stability,
          },
        )
        .toList(growable: false);
  }

  Future<void> syncConversationSummaries() {
    return _client.sync.syncConversationSummaries();
  }

  Future<Map<String, dynamic>> getUserPresence(String userId) async {
    return _dynamicMap(
      await _client.presence.getUserPresence({
        'userIds': [userId],
      }),
    );
  }

  Future<void> disconnect() => _client.connection.disconnect();

  Future<Map<String, dynamic>> notifyNetworkChange({
    bool? available,
    String? interface,
    bool? expensive,
    bool? metered,
    String? reason,
  }) async {
    final response = await _client.connection.notifyNetworkChange(
      core.NetworkChangeRequest(
        available: available,
        interface: _networkInterfaceKind(interface),
        expensive: expensive,
        metered: metered,
        reason: reason?.trim().isEmpty == true ? null : reason,
      ),
    );
    _lastState = await getConnectionState();
    return {
      'reconnected': response.reconnected,
      'connectionState': _lastState.name,
    };
  }

  Future<Map<String, dynamic>> runtimeHealth() async {
    return _runtimeHealthJson(await _client.diagnostics.getRuntimeHealth());
  }

  Future<Map<String, dynamic>> heartbeatEffectiveInterval() async {
    return _heartbeatIntervalJson(await _client.heartbeatEffectiveInterval());
  }

  Future<Map<String, dynamic>> setHeartbeatAppState(
    core.HeartbeatAppState appState,
  ) async {
    await _client.setHeartbeatAppState(
      core.SetHeartbeatAppStateRequest(appState: appState),
    );
    return heartbeatEffectiveInterval();
  }

  Future<Map<String, dynamic>> setHeartbeatNatTimeout(int? timeoutSecs) async {
    await _client.setHeartbeatNatTimeout(
      core.SetHeartbeatNatTimeoutRequest(natTimeoutSecs: timeoutSecs),
    );
    return heartbeatEffectiveInterval();
  }

  Future<void> unsubscribeEvents(Map<String, Object?> request) {
    return _client.events.unsubscribe(request);
  }

  Future<void> unsubscribeAllEvents() => _client.events.unsubscribeAll();

  Future<void> uninit() async {
    await _cancelNativeEventSubscription();
    await _client.uninit();
    _initialized = false;
    _currentUserId = '';
  }

  Future<void> resetSdk() async {
    await _cancelNativeEventSubscription();
    await _client.hardReset();
    _initialized = false;
    _currentUserId = '';
  }

  Future<void> _ensureNativeEventSubscription() async {
    if (_nativeEventSubscription != null) return;
    final subscription = await _client.events.subscribeEventsBatch({});
    _nativeEventSubscription = Map<String, Object?>.from(subscription);
    debugPrint(
      'flare sdk native event subscription=batch '
      'subscription=${subscription['subscription'] ?? subscription['subscriptionId'] ?? ''} '
      'context=${subscription['context'] ?? ''}',
    );
  }

  Future<void> _cancelNativeEventSubscription() async {
    final subscription = _nativeEventSubscription;
    if (subscription == null) return;
    _nativeEventSubscription = null;
    try {
      await _client.events.unsubscribe(subscription);
      debugPrint(
        'flare sdk native event subscription cancelled '
        'subscription=${subscription['subscription'] ?? subscription['subscriptionId'] ?? ''}',
      );
    } catch (e, st) {
      debugPrint('flare sdk native event unsubscribe failed: $e\n$st');
    }
  }

  Future<Map<String, dynamic>> mediaCacheStats() async {
    return _dynamicMap(await _client.media.getMediaCacheStats());
  }

  Future<Map<String, dynamic>> uploadFile(
    String path, {
    Map<String, Object?>? options,
  }) async {
    return _dynamicMap(
      await _client.media.uploadFile({'path': path, 'options': ?options}),
    );
  }

  Future<Map<String, dynamic>> uploadImage(
    String path, {
    Map<String, Object?>? options,
  }) async {
    return _dynamicMap(
      await _client.media.uploadImage({'path': path, 'options': ?options}),
    );
  }

  Future<Map<String, dynamic>> uploadVideo(
    String path, {
    Map<String, Object?>? options,
  }) async {
    return _dynamicMap(
      await _client.media.uploadVideo({'path': path, 'options': ?options}),
    );
  }

  Future<Map<String, dynamic>> uploadBytes({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    Map<String, Object?>? options,
  }) async {
    return _dynamicMap(
      await _client.media.uploadBytes({
        'bytes': bytes,
        'fileName': fileName,
        'mimeType': mimeType,
        'options': ?options,
      }),
    );
  }

  Future<Map<String, dynamic>> deleteMediaFile(
    String fileId, {
    bool hardDelete = false,
  }) async {
    return _dynamicMap(
      await _client.media.deleteFile({
        'fileId': fileId,
        'hardDelete': hardDelete,
      }),
    );
  }

  Future<Map<String, dynamic>> getMediaUrl(
    String mediaId, {
    int expiresIn = 3600,
  }) async {
    return _dynamicMap(
      await _client.media.getMediaUrl({
        'mediaId': mediaId,
        'expiresIn': expiresIn,
      }),
    );
  }

  Future<Map<String, dynamic>> getTempDownloadUrl(
    String fileId, {
    int expiresIn = 3600,
  }) async {
    return _dynamicMap(
      await _client.media.getTempDownloadUrl({
        'fileId': fileId,
        'expiresIn': expiresIn,
      }),
    );
  }

  /// 本地缓存有就给本机路径（`source: local`, `localPath`），否则给短时地址
  /// （`remote.url`）；[autoCache] 时核心再在后台把没缓存的文件存进本地缓存。
  Future<Map<String, dynamic>> resolveMediaAccess(
    String fileId, {
    int expiresIn = 3600,
    bool autoCache = false,
  }) async {
    return _dynamicMap(
      await _client.media.resolveMediaAccess({
        'fileId': fileId,
        'expiresIn': expiresIn,
        if (autoCache) 'autoCache': true,
      }),
    );
  }

  Future<Map<String, dynamic>> cacheRemoteMedia(
    String fileId, {
    int expiresIn = 3600,
  }) async {
    return _dynamicMap(
      await _client.media.cacheRemoteMedia({
        'fileId': fileId,
        'expiresIn': expiresIn,
      }),
    );
  }

  Future<void> setMediaCacheMaxBytes(int maxBytes) {
    return _client.media.setMediaCacheMaxBytes({'maxBytes': maxBytes});
  }

  Future<void> setMediaCacheRoot(String? absolutePath) {
    return _client.media.setMediaCacheRoot({'absolutePath': absolutePath});
  }

  Future<void> clearMediaCache() => _client.media.clearMediaCache();

  Future<String> getUserDownloadSubfolder() async {
    final result = await _client.media.getUserDownloadSubfolder();
    return '${result['subfolder'] ?? ''}';
  }

  Future<void> setUserDownloadSubfolder(String name) {
    return _client.media.setUserDownloadSubfolder({'name': name});
  }

  Future<String> getUserDownloadSavedPath(String downloadKey) async {
    final result = await _client.media.getUserDownloadSavedPath({
      'downloadKey': downloadKey,
    });
    return '${result['path'] ?? ''}';
  }

  Future<void> deleteUserDownloadRecord(String downloadKey) {
    return _client.media.deleteUserDownloadRecord({'downloadKey': downloadKey});
  }

  Future<bool> cancelUserFileDownload(String downloadKey) {
    return _client.media.cancelUserFileDownload({'downloadKey': downloadKey});
  }

  /// 「下载位置」：`{directory, defaultDirectory, customDirectory?, isCustom, subfolder}`。
  Future<Map<String, dynamic>> getUserDownloadDirectory() async {
    return _dynamicMap(await _client.media.getUserDownloadDirectory());
  }

  /// 改「下载位置」；[directory] 为 null 回到平台默认。文件夹不能写时核心报错。
  Future<Map<String, dynamic>> setUserDownloadDirectory(
    String? directory,
  ) async {
    return _dynamicMap(
      await _client.media.setUserDownloadDirectory({'directory': directory}),
    );
  }

  /// 保存到「下载位置」。来源优先级（核心）：[sourcePath] → 本地媒体缓存（按 [fileId]）
  /// → [sourceUrl] → [fileId]（经网关取附件直链）。[fileName] 没有扩展名时核心按类型补。
  /// 返回 `{path, directory, fileName, sizeBytes, fromCache, downloadKey}`。
  Future<Map<String, dynamic>> downloadToUserDirectory({
    required String fileName,
    String? fileId,
    String? sourceUrl,
    String? sourcePath,
    String? downloadKey,
    int expiresIn = 3600,
  }) async {
    return _dynamicMap(
      await _client.media.downloadToUserDirectory({
        'fileName': fileName,
        'fileId': ?fileId,
        'sourceUrl': ?sourceUrl,
        'sourcePath': ?sourcePath,
        'downloadKey': ?downloadKey,
        'expiresIn': expiresIn,
      }),
    );
  }

  Future<String> downloadFileToDownloads({
    required String downloadKey,
    required String displayFileName,
    String? sourcePath,
    String? sourceUrl,
    String? remoteFileId,
    int expiresIn = 3600,
  }) async {
    final result = await _client.media.downloadFileToDownloads({
      'downloadKey': downloadKey,
      'displayFileName': displayFileName,
      'sourcePath': sourcePath,
      'sourceUrl': sourceUrl,
      'remoteFileId': remoteFileId,
      'expiresIn': expiresIn,
    });
    return '${result['path'] ?? ''}';
  }

  Future<List<core.Conversation>> getConversations() async {
    final result = await _client.conversations.listConversations();
    final items = result.conversations;
    debugPrint(
      'flare sdk conversation.list items=${items.length} '
      'first=${items.isEmpty ? '' : items.first.conversationId}',
    );
    return items;
  }

  Future<List<core.Conversation>> getConversationsIncludingArchived() async {
    final result = await _client.conversations
        .listConversationsIncludingArchived();
    return result.conversations;
  }

  Future<List<core.Conversation>> getConversationsByQuery(
    core.ConversationListQuery query,
  ) async {
    final response = await _client.conversations.listConversationsByQuery(
      query,
    );
    return response.conversations;
  }

  Future<List<core.Conversation>> getRawConversations() async {
    final response = await _client.conversations.listRawConversations();
    return response.conversations;
  }

  Future<List<core.Conversation>> getConversationsPaginated({
    String? cursor,
    int limit = 50,
  }) async {
    final response = await _client.conversations.listConversationsPaginated({
      'cursor': cursor,
      'limit': limit,
    });
    return response.conversations;
  }

  Future<core.HomeTimelineSnapshot> bootstrapHomeTimeline({
    int conversationLimit = 50,
  }) async {
    return _client.conversations.bootstrapHomeTimeline(
      core.BootstrapHomeTimelineRequest(conversationLimit: conversationLimit),
    );
  }

  Future<core.ConversationTimelineSnapshot> openConversationTimeline({
    required String conversationId,
    int messageLimit = 30,
  }) async {
    return _client.conversations.openConversationTimeline(
      core.OpenConversationTimelineRequest(
        conversationId: conversationId,
        messageLimit: messageLimit,
      ),
    );
  }

  Future<core.ViewOpenResponse> openConversationListView({
    int conversationLimit = 100,
  }) {
    return _client.views.openConversationList(
      core.OpenConversationListViewRequest(
        conversationLimit: conversationLimit,
      ),
    );
  }

  Future<core.ViewOpenResponse> openTimelineView({
    required String conversationId,
    int messageLimit = 50,
  }) {
    return _client.views.openTimeline(
      core.OpenTimelineViewRequest(
        conversationId: conversationId,
        messageLimit: messageLimit,
      ),
    );
  }

  Future<core.ViewOpenResponse> timelineViewSnapshot(String viewId) {
    return _client.views.timelineSnapshot(
      core.TimelineViewRequest(viewId: viewId),
    );
  }

  Future<core.CloseViewResponse> closeView(String viewId) {
    return _client.views.close(core.CloseViewRequest(viewId: viewId));
  }

  Future<List<core.Conversation>> getMultipleConversations(
    List<String> conversationIds,
  ) async {
    final response = await _client.conversations.getMultipleConversations({
      'conversationIds': conversationIds,
    });
    return response.conversations;
  }

  Future<core.Conversation?> getConversation(String conversationId) async {
    final result = await _client.conversations.getConversation({
      'conversationId': conversationId,
    });
    return result;
  }

  Future<core.Conversation> getConversationOne(
    String sourceId,
    String conversationType,
  ) async {
    return _client.conversations.getOneConversation({
      'sourceId': sourceId,
      'conversationType': conversationType,
    });
  }

  Future<core.Conversation> getGroupConversationByUserIds(
    List<String> userIds, {
    String? displayName,
  }) async {
    return _client.conversations.getGroupConversationByUserIds({
      'userIds': userIds,
      'displayName': displayName,
    });
  }

  Future<void> conversationDelete(String conversationId) {
    return _client.conversations.deleteConversation({
      'conversationId': conversationId,
    });
  }

  Future<void> conversationSetPinned(String conversationId, bool pinned) {
    return _client.conversations.setConversationPinned({
      'conversationId': conversationId,
      'pinned': pinned,
    });
  }

  Future<void> conversationSetMuted(String conversationId, bool muted) {
    return _client.conversations.setConversationMuted({
      'conversationId': conversationId,
      'muted': muted,
    });
  }

  Future<void> conversationSetArchived(String conversationId, bool archived) {
    return _client.conversations.setConversationArchived({
      'conversationId': conversationId,
      'archived': archived,
    });
  }

  Future<void> conversationMarkUnread(String conversationId) {
    return _client.conversations.markConversationUnread({
      'conversationId': conversationId,
    });
  }

  Future<void> conversationMarkRead(String conversationId, int readSeq) {
    return _client.conversations.markConversationRead({
      'conversationId': conversationId,
      'readSeq': readSeq,
    });
  }

  Future<void> conversationUpdateDraft(String conversationId, String? draft) {
    return _client.conversations.updateConversationDraft(
      core.UpdateConversationDraftRequest(
        conversationId: conversationId,
        draft: draft,
      ),
    );
  }

  Future<void> clearLocalChatHistory(String conversationId) {
    return _client.conversations.clearLocalChatHistory({
      'conversationId': conversationId,
    });
  }

  Future<void> syncConversation(String conversationId) {
    return _client.sync.syncConversation({'conversationId': conversationId});
  }

  Future<List<core.Message>> getMessages({
    required String conversationId,
    required int beforeSeq,
    required int limit,
  }) async {
    final result = await _client.messages.listMessages(
      core.ListMessagesRequest(
        conversationId: conversationId,
        beforeSeq: beforeSeq,
        limit: limit,
      ),
    );
    return result.messages;
  }

  Future<void> syncMessages(
    String conversationId, {
    int lastSeq = 0,
    int limit = 50,
  }) {
    return _client.sync.syncMessages({
      'conversationId': conversationId,
      'lastSeq': lastSeq,
      'limit': limit,
    });
  }

  Future<void> subscribeUserPresence(List<String> userIds) {
    return _client.presence.subscribeUserPresence({'userIds': userIds});
  }

  /// 业务端推送用户资料(名称/头像)到本地身份缓存。读路径(消息/会话)批量 join
  /// 缓存渲染当前身份;缓存 miss 回退消息内嵌的发送时快照。业务同步好友/群成员时调用。
  Future<void> upsertUserProfiles(List<Map<String, String>> profiles) {
    final sanitized = profiles
        .map((p) => {
              'userId': (p['userId'] ?? '').trim(),
              'nickname': p['nickname'] ?? '',
              'avatarUrl': p['avatarUrl'] ?? '',
            })
        .where((p) => (p['userId'] as String).isNotEmpty)
        .toList();
    if (sanitized.isEmpty) return Future<void>.value();
    return _client.user.upsertUserProfiles({'profiles': sanitized});
  }

  Future<Map<String, dynamic>> batchGetUserPresence(
    List<String> userIds,
  ) async {
    return _dynamicMap(
      await _client.presence.batchGetUserPresence({'userIds': userIds}),
    );
  }

  Future<core.Message> createTextMessage({
    required String conversationId,
    required String text,
  }) async {
    return _client.messageBuilder.buildText(
      core.BuildTextMessageRequest(conversationId: conversationId, text: text),
    );
  }

  Future<core.Message> messageBuild(Map<String, dynamic> request) {
    return _buildMessageFromJson(request);
  }

  Future<Map<String, dynamic>> messageBuildJson(
    Map<String, dynamic> request,
  ) async {
    final message = await messageBuild(request);
    return SdkModelMapper.messageJsonFromCore(message);
  }

  Future<Map<String, dynamic>> normalizeRichDocFromMarkdown(
    String markdown,
  ) async {
    final normalized = await _client.messageBuilder
        .normalizeRichDocFromMarkdown(
          core.NormalizeRichDocFromMarkdownRequest(markdown: markdown),
        );
    return _richDocNormalizedJson(normalized);
  }

  Future<Map<String, dynamic>> normalizeRichDocFromHtml(String html) async {
    final normalized = await _client.messageBuilder.normalizeRichDocFromHtml(
      core.NormalizeRichDocFromHtmlRequest(html: html),
    );
    return _richDocNormalizedJson(normalized);
  }

  Future<Map<String, dynamic>> normalizeRichDocFromDocJson(
    String docJson,
  ) async {
    final normalized = await _client.messageBuilder.normalizeRichDocFromDocJson(
      core.NormalizeRichDocFromDocJsonRequest(docJson: docJson),
    );
    return _richDocNormalizedJson(normalized);
  }

  Future<Map<String, dynamic>> messageDispatchJson(
    String op,
    Map<String, dynamic> params,
  ) async {
    if (op == 'typing') {
      final request = _objectMap(params);
      await _client.messages.setTyping({
        'conversationId': request['conversationId'],
        'isTyping': request['isTyping'],
      });
      return {'success': true};
    }
    return _dynamicMap(
      await _client.messages.dispatchMessage({'op': op, ..._objectMap(params)}),
    );
  }

  Future<Map<String, dynamic>> messageCommandJson(
    String op,
    Map<String, dynamic> params,
  ) async {
    final request = _objectMap(params);
    switch (op) {
      case 'edit_text_by_message_id':
        await _client.messages.editTextByMessageId(request);
      case 'delete_for_self':
        await _client.messages.deleteMessageForSelf(request);
      case 'delete_for_everyone':
        await _client.messages.deleteMessageForEveryone(request);
      case 'mark_read_and_burn':
        await _client.messages.markMessageReadAndBurn(request);
      case 'add_reaction':
        await _client.messages.addReaction(request);
      case 'remove_reaction':
        await _client.messages.removeReaction(request);
      case 'pin':
        await _client.messages.pinMessage(request);
      case 'unpin':
        await _client.messages.unpinMessage(request);
      case 'pin_by_message_id':
        await _client.messages.pinMessageById(request);
      case 'unpin_by_message_id':
        await _client.messages.unpinMessageById(request);
      case 'mark':
        await _client.messages.markMessage(request);
      case 'mark_with_color':
        await _client.messages.markMessageWithColor(request);
      case 'unmark':
        await _client.messages.unmarkMessage(request);
      case 'mark_by_message_id':
        await _client.messages.markMessageById(request);
      case 'unmark_by_message_id':
        await _client.messages.unmarkMessageById(request);
      case 'edit_rich_doc_by_message_id':
        await _client.messages.editRichDocByMessageId(request);
      default:
        return messageDispatchJson(op, params);
    }
    return {'success': true, 'op': op};
  }

  Future<Map<String, dynamic>> getMessageJson(
    Map<String, dynamic> request,
  ) async {
    final message = await getMessage(request);
    return SdkModelMapper.messageJsonFromCore(message);
  }

  Future<core.Message> getMessage(Map<String, dynamic> request) {
    return _client.messages.getMessage(_objectMap(request));
  }

  Future<Map<String, dynamic>> getRawMessageJson(
    Map<String, dynamic> request,
  ) async {
    return _dynamicMap(
      await _client.messages.getRawMessage(_objectMap(request)),
    );
  }

  Future<Map<String, dynamic>> sendMessageNoOss(
    Map<String, dynamic> buildRequest,
  ) async {
    final message = await _buildMessageFromJson(buildRequest);
    final response = await _client.messages.sendMessageNoOss(
      core.SendMessageRequest(message: message),
    );
    return {
      'success': true,
      ...SdkModelMapper.sendAckJsonFromCore(response),
      'message': SdkModelMapper.messageJsonFromCore(message),
    };
  }

  Future<Map<String, dynamic>> sendCoreMessage(
    core.Message message, {
    void Function(Map<String, dynamic> progress)? onProgress,
    void Function(Map<String, dynamic> ack)? onSuccess,
    void Function(Map<String, dynamic> failure)? onFailure,
  }) async {
    final clientMsgId = message.clientMsgId;
    final conversationId = message.conversationId;
    final callback = _CoreMessageSendCallback(
      onProgress: onProgress,
      onSuccess: onSuccess,
      onFailure: onFailure,
    );
    try {
      final response = await _client.messages.sendMessage(
        core.SendMessageRequest(message: message),
        callback,
      );
      final ack = SdkModelMapper.sendAckJsonFromCore(response);
      return {
        'success': true,
        if (callback.lastAck != null) ...callback.lastAck!,
        ...ack,
        if (callback.lastProgress != null) 'progress': callback.lastProgress,
      };
    } catch (error, stackTrace) {
      final failure = callback.lastFailure;
      debugPrintSynchronously(
        '[flare-im] sdk.message.send native failure '
        'conversationId=$conversationId '
        'clientMsgId=$clientMsgId '
        'error=$error '
        'failure=${_safeSdkJsonForLog(failure)}',
      );
      if (failure != null) return failure;
      debugPrintSynchronously(
        '[flare-im] sdk.message.send exception stack '
        'conversationId=$conversationId '
        'clientMsgId=$clientMsgId\n$stackTrace',
      );
      rethrow;
    }
  }

  Future<Map<String, dynamic>> sendMessage(
    String messageJson, {
    void Function(Map<String, dynamic> progress)? onProgress,
    void Function(Map<String, dynamic> ack)? onSuccess,
    void Function(Map<String, dynamic> failure)? onFailure,
  }) async {
    final decoded = jsonDecode(messageJson);
    if (decoded is! Map) {
      throw ArgumentError.value(
        messageJson,
        'messageJson',
        'expected JSON object',
      );
    }
    final request = decoded.map<String, Object?>(
      (key, value) => MapEntry(key.toString(), value as Object?),
    );
    final message = _coreMessageFromSdkJson(request);
    return sendCoreMessage(
      message,
      onProgress: onProgress,
      onSuccess: onSuccess,
      onFailure: onFailure,
    );
  }

  Future<void> messageRecall(String conversationId, String messageId) {
    return _client.messages.recallMessage({
      'conversationId': conversationId,
      'messageId': messageId,
    });
  }

  Future<void> messageDelete(String conversationId, String messageId) {
    return _client.messages.deleteMessage({
      'conversationId': conversationId,
      'messageId': messageId,
    });
  }

  Future<List<core.Message>> searchMessages({
    required String keyword,
    String? conversationId,
    required List<core.MessageSearchKind> kinds,
    int limit = 50,
  }) async {
    final query = core.MessageSearchQuery(
      keyword: keyword.trim(),
      conversationId: conversationId?.trim().isEmpty == true
          ? null
          : conversationId?.trim(),
      kinds: kinds,
      limit: limit,
    );
    final cid = conversationId?.trim() ?? '';
    final core.ListMessagesResponse response;
    if (cid.isNotEmpty) {
      response = await _client.messages.searchMessagesInConversation(query);
    } else {
      response = await _client.messages.searchMessagesByQuery(query);
    }
    return response.messages;
  }

  Map<String, Object?> _objectMap(Map<String, dynamic> source) {
    return source.map((key, value) => MapEntry(key, value as Object?));
  }

  Future<core.Message> _buildMessageFromJson(Map<String, dynamic> request) {
    final op = _stringParam(request, 'op').trim();
    final conversationId = _stringParam(request, 'conversationId');
    final builder = _client.messageBuilder;
    switch (op) {
      case 'create_text':
      case 'buildText':
        return builder.buildText(
          core.BuildTextMessageRequest(
            conversationId: conversationId,
            text: _stringParam(request, 'text', 'body'),
          ),
        );
      case 'create_quote':
        return builder.buildQuote(
          core.BuildQuoteMessageRequest(
            conversationId: conversationId,
            quotedMessageId: _stringParam(request, 'quotedMessageId'),
            text: _stringParam(request, 'text'),
            quotedSenderId: _optionalStringParam(request, 'quotedSenderId'),
            quotedTextPreview: _optionalStringParam(
              request,
              'quotedTextPreview',
            ),
            quotedContent: _messageContentParam(request, 'quotedContent'),
          ),
        );
      case 'create_thread_reply':
        return builder.buildThreadReply(
          core.BuildThreadReplyMessageRequest(
            conversationId: conversationId,
            threadId: _stringParam(request, 'threadId'),
            text: _stringParam(request, 'text'),
          ),
        );
      case 'create_forward':
        return builder.buildForward(
          core.BuildForwardMessageRequest(
            conversationId: conversationId,
            merge: _boolValue(request['merge']),
            title: _stringParam(request, 'title'),
            sourceMessages: _forwardSourceMessages(request['sourceMessages']),
          ),
        );
      case 'create_image':
        return builder.buildImage(
          core.BuildImageMessageRequest(
            conversationId: conversationId,
            imageId: _stringParam(request, 'imageId', 'fileId'),
          ),
        );
      case 'create_video':
        return builder.buildVideo(
          core.BuildVideoMessageRequest(
            conversationId: conversationId,
            videoId: _stringParam(request, 'videoId', 'fileId'),
          ),
        );
      case 'create_audio':
        return builder.buildAudio(
          core.BuildAudioMessageRequest(
            conversationId: conversationId,
            audioId: _stringParam(request, 'audioId', 'fileId'),
          ),
        );
      case 'create_file':
        return builder.buildFile(
          core.BuildFileMessageRequest(
            conversationId: conversationId,
            fileId: _stringParam(request, 'fileId'),
          ),
        );
      case 'create_emoji':
        return builder.buildEmoji(
          core.BuildEmojiMessageRequest(
            conversationId: conversationId,
            emoji: _stringParam(request, 'emoji', 'text'),
          ),
        );
      case 'create_location':
        return builder.buildLocation(
          core.BuildLocationMessageRequest(
            conversationId: conversationId,
            latitude: _doubleParam(request, 'latitude', 'lat'),
            longitude: _doubleParam(request, 'longitude', 'lng', 'lon'),
            title: _optionalStringParam(request, 'title'),
            address: _optionalStringParam(request, 'address'),
          ),
        );
      case 'create_sticker':
        return builder.buildSticker(
          core.BuildStickerMessageRequest(
            conversationId: conversationId,
            stickerId: _stringParam(request, 'stickerId'),
            packageId: _optionalStringParam(request, 'packageId'),
            payload: core.StickerContentPayload(
              stickerId: _stringParam(request, 'stickerId'),
              packageId: _optionalStringParam(request, 'packageId'),
              url: _optionalStringParam(request, 'url'),
              width: _optionalInt(request['width']),
              height: _optionalInt(request['height']),
              format: _optionalStringParam(request, 'format'),
            ),
          ),
        );
      case 'create_link_card':
        return builder.buildLinkCard(
          core.BuildLinkCardMessageRequest(
            conversationId: conversationId,
            url: _stringParam(request, 'url'),
            title: _optionalStringParam(request, 'title'),
            description: _optionalStringParam(request, 'description'),
          ),
        );
      case 'create_card':
        return builder.buildCard(
          core.BuildCardMessageRequest(
            conversationId: conversationId,
            id: _stringParam(request, 'id'),
            cardType: _optionalStringParam(request, 'cardType'),
            title: _optionalStringParam(request, 'title'),
            subtitle: _optionalStringParam(request, 'subtitle'),
            avatar: _optionalStringParam(request, 'avatar'),
          ),
        );
      case 'create_mini_program':
        return builder.buildMiniProgram(
          core.BuildMiniProgramMessageRequest(
            conversationId: conversationId,
            appId: _stringParam(request, 'appId'),
            pagePath: _optionalStringParam(request, 'pagePath', 'path'),
            title: _optionalStringParam(request, 'title'),
            thumbnailUrl: _optionalStringParam(request, 'thumbnailUrl'),
            extra: _optionalStringMap(request['extra']),
          ),
        );
      case 'create_rich_doc':
        return builder.buildRichDoc(
          core.BuildRichDocMessageRequest(
            conversationId: conversationId,
            docJson: _stringParam(request, 'docJson'),
            contentSchema:
                _stringParam(request, 'contentSchema', 'schema').isEmpty
                ? 'rich_doc'
                : _stringParam(request, 'contentSchema', 'schema'),
            plainText: _stringParam(
              request,
              'plainText',
              'searchText',
              'title',
            ),
            inputFormat: _optionalStringParam(request, 'inputFormat'),
            inputFormatVersion: _optionalInt(request['inputFormatVersion']),
            sourcePayload: _optionalStringMap(request['sourcePayload']),
            title: _optionalStringParam(request, 'title'),
            searchText: _optionalStringParam(request, 'searchText'),
            renderHintsJson: _optionalStringParam(request, 'renderHintsJson'),
          ),
        );
      case 'create_system':
        return builder.buildSystem(
          core.BuildSystemMessageRequest(
            conversationId: conversationId,
            eventKind: _stringParam(request, 'eventKind', 'kind', 'type'),
            body: _stringParam(request, 'body', 'text'),
          ),
        );
      case 'create_notification':
        return builder.buildNotification(
          core.BuildNotificationMessageRequest(
            conversationId: conversationId,
            title: _stringParam(request, 'title'),
            body: _stringParam(request, 'body', 'text'),
          ),
        );
      case 'create_vote':
        return builder.buildVote(
          core.BuildVoteMessageRequest(
            conversationId: conversationId,
            voteId: _stringParam(request, 'voteId', 'id'),
            title: _stringParam(request, 'title'),
            options: _stringList(request['options']),
            participantUserIds: _stringList(request['participantUserIds']),
          ),
        );
      case 'create_task':
        return builder.buildTask(
          core.BuildTaskMessageRequest(
            conversationId: conversationId,
            taskId: _stringParam(request, 'taskId', 'id'),
            title: _stringParam(request, 'title'),
            status: _optionalStringParam(request, 'status'),
            participantUserIds: _stringList(request['participantUserIds']),
          ),
        );
      case 'create_schedule':
        return builder.buildSchedule(
          core.BuildScheduleMessageRequest(
            conversationId: conversationId,
            scheduleId: _stringParam(request, 'scheduleId', 'id'),
            title: _stringParam(request, 'title'),
            startTimeMs: _intValue(request['startTimeMs']),
            endTimeMs: _intValue(request['endTimeMs']),
            participantUserIds: _stringList(request['participantUserIds']),
          ),
        );
      case 'create_announcement':
        return builder.buildAnnouncement(
          core.BuildAnnouncementMessageRequest(
            conversationId: conversationId,
            title: _stringParam(request, 'title'),
            body: _stringParam(request, 'body', 'text'),
          ),
        );
      case 'create_custom':
        return builder.buildCustom(
          core.BuildCustomMessageRequest(
            conversationId: conversationId,
            type: _stringParam(request, 'type', 'typeKey'),
          ),
        );
      case 'create_placeholder':
        return builder.buildPlaceholder(
          core.BuildPlaceholderMessageRequest(
            conversationId: conversationId,
            reason: _stringParam(request, 'reason', 'hint', 'text'),
          ),
        );
      case 'create_image_group':
        return builder.buildImageGroup(
          core.BuildImageGroupMessageRequest(
            conversationId: conversationId,
            payload: core.ImageGroupContentPayload(
              images: const [],
              title: _optionalStringParam(request, 'title'),
            ),
          ),
        );
      case 'create_with_content':
      case 'buildWithContent':
        return builder.buildWithContent(
          core.BuildWithContentMessageRequest(
            conversationId: conversationId,
            content: _messageContentFromBuildRequest(request),
          ),
        );
      default:
        return builder.buildWithContent(
          core.BuildWithContentMessageRequest(
            conversationId: conversationId,
            content: _messageContentFromBuildRequest(request),
          ),
        );
    }
  }

  String _storeConfigJson() {
    final config = _lastInitConfig ??
        <String, Object?>{
          'wsUrl': _wsUrl,
          'tenantId': _tenantId,
          if (_dataUrl != null && _dataUrl!.isNotEmpty) 'dataUrl': _dataUrl,
        };
    return jsonEncode(config);
  }

  /// 测试用：prepare 重发的配置必须与 init 的一致。
  @visibleForTesting
  Map<String, Object?>? get lastInitConfigForTest => _lastInitConfig;
}

core.NetworkInterfaceKind? _networkInterfaceKind(String? value) {
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) return null;
  switch (normalized) {
    case 'unknown':
      return core.NetworkInterfaceKind.unknown;
    case 'wifi':
      return core.NetworkInterfaceKind.wifi;
    case 'cellular':
      return core.NetworkInterfaceKind.cellular;
    case 'ethernet':
      return core.NetworkInterfaceKind.ethernet;
    case 'other':
      return core.NetworkInterfaceKind.other;
    default:
      throw ArgumentError('Invalid network interface kind: $value');
  }
}

Map<String, dynamic> _richDocNormalizedJson(core.RichDocV2Normalized value) {
  return {
    'docJson': value.docJson,
    'contentSchema': value.contentSchema,
    'version': value.version,
    'plainText': value.plainText,
    'searchText': value.searchText,
    'renderHints': _dynamicMap(value.renderHints),
    'inputFormat': value.inputFormat,
    'sourcePayload': value.sourcePayload == null
        ? null
        : _dynamicMap(value.sourcePayload!),
  };
}

Map<String, dynamic> _runtimeHealthJson(core.RuntimeHealthResponse value) {
  return {
    'metricsEnabled': value.metricsEnabled,
    'state': value.state,
    'stateCode': value.stateCode,
    'sessionGeneration': value.sessionGeneration,
    'rawSubscriberDroppedTotal': value.rawSubscriberDroppedTotal,
    'metricsJson': value.metricsJson,
  };
}

Map<String, dynamic> _heartbeatIntervalJson(
  core.HeartbeatEffectiveIntervalResponse value,
) {
  return {
    'connected': value.connected,
    'intervalMs': value.intervalMs,
    'intervalSecs': value.intervalSecs,
  };
}

String _stringParam(
  Map<String, dynamic> source,
  String first, [
  String? second,
  String? third,
]) {
  for (final key in [first, second, third]) {
    if (key == null) continue;
    final value = source[key];
    if (value == null) continue;
    final text = value.toString().trim();
    if (text.isNotEmpty) return text;
  }
  return '';
}

String? _optionalStringParam(
  Map<String, dynamic> source,
  String first, [
  String? second,
  String? third,
]) {
  final value = _stringParam(source, first, second, third);
  return value.isEmpty ? null : value;
}

double _doubleParam(
  Map<String, dynamic> source,
  String first, [
  String? second,
  String? third,
]) {
  for (final key in [first, second, third]) {
    if (key == null) continue;
    final value = source[key];
    if (value is num) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value.trim());
      if (parsed != null) return parsed;
    }
  }
  return 0.0;
}

Map<String, Object?> _payloadData(Map<String, dynamic> source) {
  final raw = source['data'] ?? source['payload'];
  if (raw is Map) return _objectPayloadMap(raw);
  final data = <String, Object?>{};
  for (final entry in source.entries) {
    if (entry.key == 'op' || entry.key == 'conversationId') {
      continue;
    }
    data[entry.key] = entry.value as Object?;
  }
  return data;
}

/// 转发的源必须是**完整消息**，不是 id 存根。
///
/// 转发载荷要把原文嵌进去，核心侧 forward_item_from_source 会读
/// content / senderId / conversationId；早先按 { sourceMessageId } 传，
/// 反序列化成 IMMessage 时缺必填字段直接 INVALID_PARAMETER，转发每次都失败，
/// 契约因此改成了 Message。这里一度还在构造 ForwardSourceMessage，
/// 类型对不上，`flutter analyze` 直接报错。
///
/// 上游 provider 用 getRawMessageById 取的就是完整消息的原始 map，
/// 直接交给 SDK 的 messageFromJson 解析即可，不要再手工拼字段。
List<core.Message> _forwardSourceMessages(Object? raw) {
  if (raw is! List) return const [];
  final messages = <core.Message>[];
  for (final item in raw) {
    if (item is! Map) continue;
    messages.add(core.messageFromJson(item.cast<String, dynamic>()));
  }
  return messages;
}

core.MessageContent _messageContentFromBuildRequest(
  Map<String, dynamic> request,
) {
  final raw = request['content'];
  if (raw is Map) {
    final contentJson = _objectPayloadMap(raw);
    return core.MessageContent(
      contentType: _coreMessageContentType(contentJson['contentType']),
      data: _coreMessageContentData(contentJson),
    );
  }
  return core.MessageContent(
    contentType: _coreMessageContentType(request['contentType']),
    data: _payloadData(request),
  );
}

core.MessageContent _messageContentParam(
  Map<String, dynamic> request,
  String key,
) {
  final raw = request[key];
  if (raw is! Map) {
    throw ArgumentError.value(raw, key, 'expected SDK MessageContent map');
  }
  final contentJson = _objectPayloadMap(raw);
  return core.MessageContent(
    contentType: _coreMessageContentType(contentJson['contentType']),
    data: _coreMessageContentData(contentJson),
  );
}

core.Message _coreMessageFromSdkJson(Map<String, Object?> json) {
  final clientMsgId = json['clientMsgId']?.toString().trim() ?? '';
  final conversationId = json['conversationId']?.toString().trim() ?? '';
  if (clientMsgId.isEmpty || conversationId.isEmpty) {
    throw ArgumentError.value(
      json,
      'messageJson',
      'expected camelCase SDK message JSON with clientMsgId and conversationId',
    );
  }

  final rawContent = json['content'];
  core.MessageContent? content;
  if (rawContent is Map) {
    final contentJson = _objectPayloadMap(rawContent);
    content = core.MessageContent(
      contentType: _coreMessageContentType(contentJson['contentType']),
      data: _coreMessageContentData(contentJson),
    );
  }
  return core.Message(
    serverId: json['serverId']?.toString() ?? '',
    clientMsgId: clientMsgId,
    conversationId: conversationId,
    conversationType: _intValue(json['conversationType']),
    channelId: json['channelId']?.toString() ?? '',
    senderId: json['senderId']?.toString() ?? '',
    source: _intValue(json['source']),
    conversationSeq: _intValue(json['conversationSeq']),
    createdAt: _intValue(json['createdAt']),
    clientCreatedAt: _intValue(json['clientCreatedAt']),
    messageType: _intValue(json['messageType']),
    content: content,
    senderName: json['senderName']?.toString() ?? '',
    senderAvatar: json['senderAvatar']?.toString() ?? '',
    senderDisplayName: json['senderDisplayName']?.toString() ?? '',
    replyTo: json['replyTo']?.toString(),
    quotePreview: json['quotePreview']?.toString(),
    status: _intValue(json['status']),
    isRead: _boolValue(json['isRead']),
    isRecalled: _boolValue(json['isRecalled']),
    isEdited: _boolValue(json['isEdited']),
    mentionUsers: _stringList(json['mentionUsers']),
    mentionAll: _boolValue(json['mentionAll']),
    attributes: _stringMap(json['attributes']),
    extensions: _bytesMap(json['extensions']),
    reactions: _reactionList(json['reactions']),
    version: _intValue(json['version']),
    updatedAt: _intValue(json['updatedAt']),
    localState: _localStateFromJson(json['localState']),
    timelineKey: _requiredStringField(json, 'timelineKey', 'Message'),
    timelineSortTs: _requiredIntField(json, 'timelineSortTs', 'Message'),
  );
}

core.MessageContentType _coreMessageContentType(Object? value) {
  if (value is num) {
    final index = value.toInt().clamp(
      0,
      core.MessageContentType.values.length - 1,
    );
    return core.MessageContentType.values[index];
  }
  final normalized = value
      ?.toString()
      .replaceAll('-', '_')
      .trim()
      .toLowerCase();
  if (normalized == null || normalized.isEmpty) {
    return core.MessageContentType.custom;
  }
  for (final type in core.MessageContentType.values) {
    if (_snakeCase(type.name) == normalized) {
      return type;
    }
  }
  return core.MessageContentType.custom;
}

Map<String, Object?> _coreMessageContentData(Map<String, Object?> contentJson) {
  final data = contentJson['data'];
  if (data is Map && data.isNotEmpty) {
    return _objectPayloadMap(data);
  }
  final out = <String, Object?>{};
  for (final entry in contentJson.entries) {
    switch (entry.key) {
      case 'contentType':
      case 'messageType':
      case 'data':
        break;
      default:
        out[entry.key] = entry.value;
    }
  }
  return out;
}

Map<String, Object?> _objectPayloadMap(Map source) {
  return source.map<String, Object?>(
    (key, value) => MapEntry(key.toString(), _dynamicValue(value)),
  );
}

int _intValue(Object? value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

String _requiredStringField(
  Map<String, Object?> json,
  String key,
  String context,
) {
  final text = json[key]?.toString();
  if (text == null || text.trim().isEmpty) {
    throw ArgumentError.value(json, context, '$context.$key is required');
  }
  return text;
}

int _requiredIntField(Map<String, Object?> json, String key, String context) {
  final value = json[key];
  if (value == null || (value is String && value.trim().isEmpty)) {
    throw ArgumentError.value(json, context, '$context.$key is required');
  }
  if (value is num) return value.toInt();
  if (value is String) {
    final parsed = int.tryParse(value);
    if (parsed != null) return parsed;
  }
  throw ArgumentError.value(json, context, '$context.$key must be an integer');
}

int? _optionalInt(Object? value) {
  if (value == null) return null;
  return _intValue(value);
}

bool _boolValue(Object? value) => value == true;

List<String> _stringList(Object? value) {
  if (value is! List) return const [];
  return value.map((item) => item.toString()).toList(growable: false);
}

Map<String, String> _stringMap(Object? value) {
  if (value is! Map) return const {};
  return value.map((key, entry) => MapEntry(key.toString(), entry.toString()));
}

Map<String, String>? _optionalStringMap(Object? value) {
  final map = _stringMap(value);
  return map.isEmpty ? null : map;
}

Map<String, List<int>> _bytesMap(Object? value) {
  if (value is! Map) return const {};
  final out = <String, List<int>>{};
  for (final entry in value.entries) {
    final raw = entry.value;
    if (raw is List) {
      out[entry.key.toString()] = raw
          .whereType<num>()
          .map((item) => item.toInt())
          .toList(growable: false);
    }
  }
  return out;
}

List<core.ReactionEntry> _reactionList(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) {
        final json = _objectPayloadMap(item);
        return core.ReactionEntry(
          emoji: json['emoji']?.toString() ?? '',
          userIds: _stringList(json['userIds']),
          count: _intValue(json['count']),
        );
      })
      .toList(growable: false);
}

core.MessageLocalState? _localStateFromJson(Object? value) {
  if (value is! Map) return null;
  final json = _objectPayloadMap(value);
  return core.MessageLocalState(
    sending: _boolValue(json['sending']),
    failed: _boolValue(json['failed']),
    isLocal: _boolValue(json['isLocal']),
    sortTs: _intValue(json['sortTs']),
  );
}

String _snakeCase(String value) {
  final buffer = StringBuffer();
  for (var i = 0; i < value.length; i++) {
    final char = value[i];
    final lower = char.toLowerCase();
    if (i > 0 && char != lower) buffer.write('_');
    buffer.write(lower);
  }
  return buffer.toString();
}

String _safeSdkJsonForLog(Object? value) {
  try {
    return jsonEncode(value);
  } catch (_) {
    return value.toString();
  }
}

final class _CoreMessageSendCallback extends core.MessageSendCallback {
  _CoreMessageSendCallback({
    void Function(Map<String, dynamic> progress)? onProgress,
    void Function(Map<String, dynamic> ack)? onSuccess,
    void Function(Map<String, dynamic> failure)? onFailure,
  }) : _onProgress = onProgress,
       _onSuccess = onSuccess,
       _onFailure = onFailure;

  final void Function(Map<String, dynamic> progress)? _onProgress;
  final void Function(Map<String, dynamic> ack)? _onSuccess;
  final void Function(Map<String, dynamic> failure)? _onFailure;

  Map<String, dynamic>? lastProgress;
  Map<String, dynamic>? lastAck;
  Map<String, dynamic>? lastFailure;

  @override
  void onProgress(core.ProgressEvent event) {
    lastProgress = SdkModelMapper.progressJsonFromCore(event);
    _onProgress?.call(lastProgress!);
  }

  @override
  void onSuccess(core.MessageSendAckEvent event) {
    lastAck = {
      'success': true,
      ...SdkModelMapper.sendAckJsonFromCore(event.ack),
      'progress': lastProgress,
    };
    _onSuccess?.call(lastAck!);
  }

  @override
  void onFailure(core.MessageSendFailedEvent event) {
    lastFailure = {
      'success': false,
      'clientMsgId': event.clientMsgId,
      'reason': event.reason,
      'error': SdkModelMapper.errorJsonFromCore(event.error),
      'progress': lastProgress,
    };
    _onFailure?.call(lastFailure!);
  }
}

Map<String, dynamic> _dynamicMap(Map source) {
  return source.map(
    (key, value) => MapEntry(key.toString(), _dynamicValue(value)),
  );
}

Object? _dynamicValue(Object? value) {
  if (value is Map) return _dynamicMap(value);
  if (value is List) return value.map(_dynamicValue).toList(growable: false);
  return value;
}
