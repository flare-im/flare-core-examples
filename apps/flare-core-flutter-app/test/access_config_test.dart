import 'dart:convert';

import 'package:flare_im/shared/config/access_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _endpoints(Map<String, Object?> access) =>
    access['developmentEndpoints']! as Map<String, Object?>;

void main() {
  group('development mode (debug and profile builds)', () {
    test('defaults to the local stack on loopback', () {
      final access = resolveAccessConfig(
        accessJson: '',
        release: false,
        defines: const DevelopmentEndpointDefines(),
        platform: TargetPlatform.macOS,
      );
      expect(access['trustMode'], 'development');
      expect(_endpoints(access), {
        'wsUrl': 'ws://127.0.0.1:60051/ws',
        'coreApiUrl': 'http://127.0.0.1:50050',
        'mediaUrl': 'http://127.0.0.1:50050',
      });
    });

    test('the Android emulator reaches the host at 10.0.2.2', () {
      final access = resolveAccessConfig(
        accessJson: '',
        release: false,
        defines: const DevelopmentEndpointDefines(),
        platform: TargetPlatform.android,
      );
      expect(_endpoints(access)['wsUrl'], 'ws://10.0.2.2:60051/ws');
      expect(_endpoints(access)['coreApiUrl'], 'http://10.0.2.2:50050');
    });

    test('a development host and single endpoints override the defaults', () {
      final access = resolveAccessConfig(
        accessJson: '',
        release: false,
        defines: const DevelopmentEndpointDefines(
          host: '192.168.1.20',
          quic: 'quic://192.168.1.20:60052',
        ),
        platform: TargetPlatform.iOS,
      );
      expect(_endpoints(access), {
        'wsUrl': 'ws://192.168.1.20:60051/ws',
        'quicUrl': 'quic://192.168.1.20:60052',
        'coreApiUrl': 'http://192.168.1.20:50050',
        'mediaUrl': 'http://192.168.1.20:50050',
      });
    });

    test('FLARE_ACCESS_JSON is passed through as is (two access points)', () {
      const twoPoints = {
        'trustMode': 'development',
        'developmentEndpoints': {
          'wsUrl': 'ws://127.0.0.1:60051/ws',
          'coreApiUrl': 'http://127.0.0.1:50050',
          'accessPoints': [
            {
              'id': 'dev-b',
              'wsUrl': 'ws://127.0.0.1:61051/ws',
              'coreApiUrl': 'http://127.0.0.1:51050',
            },
          ],
        },
      };
      expect(
        resolveAccessConfig(accessJson: jsonEncode(twoPoints), release: false),
        twoPoints,
      );
    });
  });

  group('release builds', () {
    test('take the production access config', () {
      const production = {
        'bootstrapId': 'flare-core',
        'trustRoots': [
          {'keyId': 'root-2026', 'publicKey': 'AAAA'},
        ],
        'seed': '{}',
        'trustMode': 'production',
      };
      expect(
        resolveAccessConfig(accessJson: jsonEncode(production), release: true),
        production,
      );
    });

    test('without FLARE_ACCESS_JSON fail instead of using development', () {
      expect(
        () => resolveAccessConfig(accessJson: '', release: true),
        throwsA(isA<AccessConfigError>()),
      );
    });

    test('refuse a development access config', () {
      expect(
        () => resolveAccessConfig(
          accessJson: jsonEncode({'trustMode': 'development'}),
          release: true,
        ),
        throwsA(isA<AccessConfigError>()),
      );
    });
  });

  test('a malformed FLARE_ACCESS_JSON fails', () {
    for (final raw in ['{', '[]', '"access"']) {
      expect(
        () => resolveAccessConfig(accessJson: raw, release: false),
        throwsA(isA<AccessConfigError>()),
        reason: raw,
      );
    }
  });
}
