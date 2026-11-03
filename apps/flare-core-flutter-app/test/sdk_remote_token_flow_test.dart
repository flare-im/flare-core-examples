import 'dart:io';

import 'package:flare_core_flutter_sdk/flare_core_flutter_sdk.dart' as core;
import 'package:flare_im/infrastructure/paths/sdk_data_url.dart';
import 'package:flare_im/infrastructure/sdk/flare_core_sdk_wrapper.dart';
import 'package:flare_im/shared/config/app_defaults_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// 用**服务端签好的 token** 连真实网关，跑通登录 → 会话列表 → 打开时间线。
///
/// 与 sdk_login_business_flow_test 的区别：那条不传 token（SDK 向网关签发），
/// 只能连"自己握有密钥"的服务器；这条把 token 当输入，可以指向任意环境，
/// 客户端不需要持有签名密钥（把密钥放进客户端等于让任何拿到安装包的人伪造身份）。
///
/// 默认跳过。要跑就给两个环境变量——**别把 token 写进仓库**：
///   `FLARE_E2E_WS_URL=wss://host/ws` \
///   `FLARE_E2E_TOKEN="$(ssh server mint_token.py user)"` \
///   `FLARE_E2E_USER=user flutter test test/sdk_remote_token_flow_test.dart`
void main() {
  test('用服务端签发的 token 登录远端网关并拉起会话', () async {
    final wsUrl = Platform.environment['FLARE_E2E_WS_URL'];
    final token = Platform.environment['FLARE_E2E_TOKEN'];
    final userId = Platform.environment['FLARE_E2E_USER'];
    if (wsUrl == null || token == null || userId == null) {
      // 没给环境变量就跳过，保持默认 `flutter test` 不依赖外部环境。
      return;
    }

    final root = await Directory.systemTemp.createTemp('flare-remote-token-');
    final sdk = SdkWrapper();
    addTearDown(() async {
      await sdk.dispose();
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });

    const defaults = AppDefaults.fallback;
    await sdk
        .init(
          SdkConfig(
            wsUrl: wsUrl,
            tenantId: defaults.tenantId,
            httpUrl: 'http://127.0.0.1:50050',
            dataUrl: toFileDataUrl(root.path),
          ),
        )
        .timeout(const Duration(seconds: 20));

    await sdk.login(userId, token).timeout(const Duration(seconds: 30));
    expect(await sdk.currentUserId(), userId);

    final state = await sdk.getConnectionState();
    expect(
      state,
      isIn([core.ConnectionState.connected, core.ConnectionState.ready]),
      reason: '登录后连接应当已建立，实际是 $state',
    );

    await sdk.syncConversationSummaries().timeout(const Duration(seconds: 30));
    final list = await sdk
        .openConversationListView()
        .timeout(const Duration(seconds: 30));
    expect(list, isNotNull);

    final diagnostics = await sdk.diagnosticsSnapshot();
    expect(diagnostics['currentUserId'], userId);
    expect(diagnostics['sessionActive'], isTrue);
  }, timeout: const Timeout(Duration(minutes: 3)));
}
