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

/// The build's endpoints are missing or unusable.
class EndpointConfigError implements Exception {
  const EndpointConfigError(this.message);

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

/// Core deployment endpoints for this build.
///
/// [endpointsJson] (`FLARE_CORE_ENDPOINTS_JSON`) wins when given. Without it a release
/// build fails; any other build uses local addresses on [platform]'s
/// development host with [defines] applied.
Map<String, Object?> resolveCoreEndpoints({
  String endpointsJson = const String.fromEnvironment('FLARE_CORE_ENDPOINTS_JSON'),
  bool release = kReleaseMode,
  DevelopmentEndpointDefines defines =
      DevelopmentEndpointDefines.fromEnvironment,
  TargetPlatform? platform,
}) {
  final raw = endpointsJson.trim();
  if (raw.isNotEmpty) {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      throw const EndpointConfigError('FLARE_CORE_ENDPOINTS_JSON is not valid JSON');
    }
    if (decoded is! Map) {
      throw const EndpointConfigError('FLARE_CORE_ENDPOINTS_JSON must be a JSON object');
    }
    final endpoints = decoded.map((key, value) => MapEntry('$key', value));
    if (endpoints['baseUrl'] is! String || endpoints['websocketUrl'] is! String) {
      throw const EndpointConfigError('baseUrl and websocketUrl are required');
    }
    return endpoints;
  }
  if (release) {
    throw const EndpointConfigError(
      'A release build needs FLARE_CORE_ENDPOINTS_JSON (baseUrl and websocketUrl)',
    );
  }
  final host = _hostOf(defines, platform);
  final coreApi = _or(defines.coreApi, 'http://$host:$kDevCoreApiPort');
  return {
    'websocketUrl': _or(defines.ws, 'ws://$host:$kDevWsPort/ws'),
    if (defines.quic.trim().isNotEmpty) 'quicUrl': defines.quic.trim(),
    'baseUrl': coreApi,
    if (defines.media.trim().isNotEmpty) 'mediaBaseUrl': defines.media.trim(),
  };
}
