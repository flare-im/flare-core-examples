// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:io';

import 'package:flare_core_flutter_sdk/flare_core_flutter_sdk.dart' as core;
import 'package:flare_im/infrastructure/paths/sdk_data_url.dart';
import 'package:flare_im/infrastructure/sdk/flare_core_sdk_wrapper.dart';
import 'package:flare_im/shared/config/app_defaults_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// 发送端的 ack/失败回调，用来分辨"调用返回了"和"服务端真的收下了"。
class _AckWatch extends core.FlareImEventListener {
  _AckWatch(this.acked, this.failed);
  final Completer<String> acked;
  final Completer<String> failed;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;

  @override
  void onMessageSendAck(core.MessageSendAckEvent event) {
    if (!acked.isCompleted) acked.complete('${event.runtimeType}');
  }

  @override
  void onMessageSendFailed(core.MessageSendFailedEvent event) {
    if (!failed.isCompleted) failed.complete('${event.runtimeType}');
  }
}

void main() {
  test('flutter 发一条带标记的消息', () async {
    final env = Platform.environment;
    // 没给环境变量就跳过：默认 `flutter test` 不该依赖外部环境。
    // 这里原本用 `!` 强解包，缺变量直接抛异常，把整个测试套件染红。
    final ws = env['FLARE_E2E_WS_URL'] ?? '';
    final token = env['FLARE_E2E_TOKEN'] ?? '';
    final user = env['FLARE_E2E_USER'] ?? '';
    final tag = env['FLARE_E2E_TAG'] ?? '';
    if (ws.isEmpty || token.isEmpty || user.isEmpty || tag.isEmpty) return;
    final peers = (env['FLARE_E2E_PEERS'] ?? '').split(',').where((x) => x.isNotEmpty).toList();
    final root = await Directory.systemTemp.createTemp('flare-x-');
    final sdk = SdkWrapper();
    addTearDown(() async { await sdk.dispose(); await root.delete(recursive: true); });
    const d = AppDefaults.fallback;
    await sdk.init(SdkConfig(wsUrl: ws, tenantId: d.tenantId, httpUrl: 'http://127.0.0.1:50050', dataUrl: toFileDataUrl(root.path)))
      .timeout(const Duration(seconds: 20));
    await sdk.login(user, token).timeout(const Duration(seconds: 30));
    await sdk.syncConversationSummaries().timeout(const Duration(seconds: 30));
    final cid = peers.isEmpty
        ? env['FLARE_E2E_CID']!
        : (await sdk
                .getGroupConversationByUserIds(peers, displayName: 'rt-control')
                .timeout(const Duration(seconds: 30)))
            .conversationId;
    print('SENDER_CID=$cid');
    final acked = Completer<String>(), failed = Completer<String>();
    final watch = sdk.addEventListener(_AckWatch(acked, failed));
    addTearDown(watch.unsubscribe);
    final msg = await sdk.createTextMessage(conversationId: cid, text: tag)
        .timeout(const Duration(seconds: 20));
    await sdk.sendCoreMessage(msg).timeout(const Duration(seconds: 30));
    print('FLUTTER_SENT=$tag');
    final outcome = await Future.any<String>([
      acked.future.then((v) => 'ACK $v'),
      failed.future.then((v) => 'FAILED $v'),
      Future<String>.delayed(const Duration(seconds: 30), () => 'NO_ACK_IN_30S'),
    ]);
    print('SEND_OUTCOME=$outcome');
  }, timeout: const Timeout(Duration(minutes: 3)));
}
