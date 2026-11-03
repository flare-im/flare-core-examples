import 'dart:io';

import 'package:flare_core_flutter_sdk/flare_core_flutter_sdk.dart' as core;
import 'package:flare_im/infrastructure/paths/sdk_data_url.dart';
import 'package:flare_im/infrastructure/sdk/flare_core_sdk_wrapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'logs in with a core generated token when the local gateway is running',
    () async {
      if (Platform.environment['FLARE_RUN_GATEWAY_LOGIN_TEST'] != '1') {
        return;
      }
      if (!await _gatewayAvailable()) {
        return;
      }

      final root = await Directory.systemTemp.createTemp(
        'flare-sdk-login-flow-test-',
      );
      final sdk = SdkWrapper();
      addTearDown(() async {
        await sdk.dispose();
        if (await root.exists()) {
          await root.delete(recursive: true);
        }
      });

      await sdk
          .init(
            SdkConfig(
              wsUrl: 'ws://127.0.0.1:60051/ws',
              tenantId: '0',
              httpUrl: 'http://127.0.0.1:50050',
              dataUrl: toFileDataUrl(root.path),
            ),
          )
          .timeout(const Duration(seconds: 5));

      // 不传 token：SDK 向网关签发（联调网关需开 AUTH_DEV_ISSUE）。
      await sdk.login('hugo').timeout(const Duration(seconds: 15));
      expect(await sdk.currentUserId(), 'hugo');

      final state = await sdk.getConnectionState();
      expect(
        state,
        isIn([core.ConnectionState.connected, core.ConnectionState.ready]),
      );
      final diagnostics = await sdk.diagnosticsSnapshot();
      expect(diagnostics['currentUserId'], 'hugo');
      expect(diagnostics['sessionActive'], isTrue);

      final capabilities = await sdk.listCapabilities().timeout(
        const Duration(seconds: 5),
      );
      expect(capabilities, isA<Map<String, dynamic>>());
      final buildOperations = await sdk.listMessageBuildOperations().timeout(
        const Duration(seconds: 5),
      );
      expect(buildOperations, isA<List<Map<String, Object?>>>());
      final conversations = await sdk.getConversations().timeout(
        const Duration(seconds: 5),
      );
      expect(conversations, isA<List<Map<String, dynamic>>>());
      final rawConversations = await sdk.getRawConversations().timeout(
        const Duration(seconds: 5),
      );
      expect(rawConversations, isA<List<Map<String, dynamic>>>());

      await sdk.logout().timeout(const Duration(seconds: 5));
    },
  );
}

Future<bool> _gatewayAvailable() async {
  try {
    final socket = await Socket.connect(
      '127.0.0.1',
      60051,
      timeout: const Duration(milliseconds: 500),
    );
    socket.destroy();
    return true;
  } on Object {
    return false;
  }
}
