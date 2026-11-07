/// 这个构建连哪套服务：构建期用 `--dart-define` 写进产物，登录页没有服务器地址设置。
///
/// 正式构建给核心的接入配置（`sdkConfig.access`，签名清单与信任根）：
///
/// ```bash
/// flutter build apk --release \
///   --dart-define=FLARE_ACCESS_JSON='{"bootstrapId":"…","trustRoots":[…],"seed":"…","trustMode":"production"}'
/// ```
///
/// release 构建缺 `FLARE_ACCESS_JSON`、或它是开发模式，初始化时明确报错，不会回落到开发模式。
///
/// debug / profile 构建不给 `FLARE_ACCESS_JSON` 时走开发模式（未签名的本地接入点，Kit 横幅带
/// 「开发模式」角标）。默认是本机开发栈的端口，主机默认 `127.0.0.1`，Android 上默认
/// `10.0.2.2`（模拟器里的宿主机）；真机或别的主机用 `FLARE_DEV_HOST` 换主机，单个入口用
/// `FLARE_DEV_*_URL` 整条覆盖：
///
/// | define | 默认 |
/// |---|---|
/// | `FLARE_DEV_WS_URL` | `ws://<host>:60051/ws` |
/// | `FLARE_DEV_QUIC_URL` | 不给（只走 WebSocket；本机 QUIC 要证书） |
/// | `FLARE_DEV_CORE_API_URL` | `http://<host>:50050` |
/// | `FLARE_DEV_MEDIA_URL` | 同 Core API |
///
/// 双接入点等完整的开发配置直接给 `FLARE_ACCESS_JSON`（`trustMode: "development"` 加
/// `developmentEndpoints.accessPoints`），见 README。
///
/// 连接令牌由 SDK 托管（`auth: {}`）：核心经接入点的 Core API 签发并到期前刷新，开发模式即
/// `developmentEndpoints.coreApiUrl`；客户端不持有签名密钥，也不配令牌地址。
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';

/// The local development stack's ports (gateway WebSocket, Core HTTP): the
/// defaults this app shipped in `assets/config/app_defaults.json` before the
/// access config replaced single addresses.
const int kDevWsPort = 60051;
const int kDevCoreApiPort = 50050;

/// Development endpoints given one by one at build time; an empty value takes
/// the default on the development host.
@immutable
class DevelopmentEndpointDefines {
  const DevelopmentEndpointDefines({
    this.host = '',
    this.ws = '',
    this.quic = '',
    this.coreApi = '',
    this.media = '',
  });

  /// The `FLARE_DEV_*` defines of this build.
  static const fromEnvironment = DevelopmentEndpointDefines(
    host: String.fromEnvironment('FLARE_DEV_HOST'),
    ws: String.fromEnvironment('FLARE_DEV_WS_URL'),
    quic: String.fromEnvironment('FLARE_DEV_QUIC_URL'),
    coreApi: String.fromEnvironment('FLARE_DEV_CORE_API_URL'),
    media: String.fromEnvironment('FLARE_DEV_MEDIA_URL'),
  );

  final String host;
  final String ws;
  final String quic;
  final String coreApi;
  final String media;
}

/// The build's access config is missing or unusable.
class AccessConfigError implements Exception {
  const AccessConfigError(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Where the development host is reached from this device: the Android
/// emulator sees the host machine at `10.0.2.2`, everything else at loopback.
String defaultDevelopmentHost(TargetPlatform platform) =>
    platform == TargetPlatform.android ? '10.0.2.2' : '127.0.0.1';

String _hostOf(DevelopmentEndpointDefines defines, TargetPlatform? platform) =>
    defines.host.trim().isNotEmpty
    ? defines.host.trim()
    : defaultDevelopmentHost(platform ?? defaultTargetPlatform);

String _or(String value, String fallback) =>
    value.trim().isEmpty ? fallback : value.trim();

/// The core access config (`sdkConfig.access`) for this build.
///
/// [accessJson] (`FLARE_ACCESS_JSON`) wins when given. Without it a release
/// build fails; any other build uses development mode on [platform]'s
/// development host with [defines] applied.
Map<String, Object?> resolveAccessConfig({
  String accessJson = const String.fromEnvironment('FLARE_ACCESS_JSON'),
  bool release = kReleaseMode,
  DevelopmentEndpointDefines defines =
      DevelopmentEndpointDefines.fromEnvironment,
  TargetPlatform? platform,
}) {
  final raw = accessJson.trim();
  if (raw.isNotEmpty) {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      throw const AccessConfigError('FLARE_ACCESS_JSON is not valid JSON');
    }
    if (decoded is! Map) {
      throw const AccessConfigError('FLARE_ACCESS_JSON must be a JSON object');
    }
    final access = decoded.map((key, value) => MapEntry('$key', value));
    if (release && access['trustMode'] == 'development') {
      throw const AccessConfigError(
        'A release build needs a production FLARE_ACCESS_JSON, not development mode',
      );
    }
    return access;
  }
  if (release) {
    throw const AccessConfigError(
      'A release build needs FLARE_ACCESS_JSON (the signed access config)',
    );
  }
  final host = _hostOf(defines, platform);
  final coreApi = _or(defines.coreApi, 'http://$host:$kDevCoreApiPort');
  return {
    'trustMode': 'development',
    'developmentEndpoints': {
      'wsUrl': _or(defines.ws, 'ws://$host:$kDevWsPort/ws'),
      if (defines.quic.trim().isNotEmpty) 'quicUrl': defines.quic.trim(),
      'coreApiUrl': coreApi,
      'mediaUrl': _or(defines.media, coreApi),
    },
  };
}
