import 'dart:convert';
import 'dart:io';

import 'package:flare_im/infrastructure/sdk/flare_core_sdk_wrapper.dart';
import 'package:flare_im/shared/config/app_defaults_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('defaults carry no server address', () {
    expect(AppDefaults.fallback.tenantId, '0');
    expect(AppDefaults.fallback.defaultTlsCaCertPath, isEmpty);
    expect(AppDefaults.fallback.defaultUserId, isEmpty);
  });

  test('the shipped account entrance has no implicit demo identity', () {
    final bundled =
        jsonDecode(File('assets/config/app_defaults.json').readAsStringSync())
            as Map<String, dynamic>;
    expect(AppDefaults.fromJson(bundled).defaultUserId, isEmpty);
    for (final value in [null, '', '   ']) {
      expect(AppDefaults.fromJson({'userId': value}).defaultUserId, isEmpty);
    }
    expect(
      AppDefaults.fromJson({
        'userId': '  administrator-provided-id  ',
      }).defaultUserId,
      'administrator-provided-id',
    );
  });

  test('loads tenant, trust and user from app defaults json shape', () {
    final defaults = AppDefaults.fromJson(const {
      'defaultTlsCaCertPath': '/tmp/flare-server.crt',
      'tenantId': '0',
      'userId': 'bob',
    });

    expect(defaults.defaultTlsCaCertPath, '/tmp/flare-server.crt');
    expect(defaults.tenantId, '0');
    expect(defaults.defaultUserId, 'bob');
  });

  test('the init overlay is the access config plus run settings', () {
    const endpoints = {'baseUrl': 'http://127.0.0.1:50050', 'websocketUrl': 'ws://127.0.0.1:60051/ws'};
    expect(
      const SdkConfig(
        endpoints: endpoints,
        tlsCaCertPath: ' /tmp/flare-server.crt ',
        tenantId: ' ',
        dataUrl: 'file:///data/',
      ).toInitConfig(),
      {
        'endpoints': endpoints,
        'tenantId': '0',
        'tlsCaCertPath': '/tmp/flare-server.crt',
        'auth': <String, Object?>{},
        'dataUrl': 'file:///data/',
      },
    );
    // Tokens are SDK-managed through the Core API: no token address at all.
    expect(const SdkConfig(endpoints: endpoints).toInitConfig()['auth'], isEmpty);
  });
}
