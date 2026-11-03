import 'dart:async';
import 'dart:io';

import 'package:flare_core_flutter_sdk/flare_core_flutter_sdk.dart' as core;
import 'package:flare_im/infrastructure/paths/sdk_data_url.dart';
import 'package:flare_im/infrastructure/sdk/flare_core_sdk_wrapper.dart';
import 'package:flare_im/shared/config/app_defaults_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// 实时投递的接收端：登录、打开会话、等带 tag 的推送。
/// 发送端是另一个进程（test/x_send_test.dart），因为一个进程里同时跑两个
/// 会话时第二次 login 之后第一个会话的调用会直接返回错误码 1。
class _Collector extends core.FlareImEventListener {
  _Collector(this.tag, this.done);
  final String tag;
  final Completer<Duration> done;
  final Stopwatch sw = Stopwatch()..start();

  @override
  dynamic noSuchMethod(Invocation invocation) => null;

  @override
  void onMessageReceivedBatch(core.MessageReceivedBatchEvent event) {
    // ignore: avoid_print
    print('BATCH n=${event.messages.length}');
    for (final m in event.messages) {
      final text = m.content?.data['text']?.toString() ?? '';
      if (text.contains(tag) && !done.isCompleted) {
        done.complete(sw.elapsed);
      }
    }
  }
}

void main() {
  test('接收端等待带 tag 的实时推送', () async {
    final e = Platform.environment;
    final ws = e['FLARE_E2E_WS_URL'], tag = e['FLARE_E2E_TAG'];
    final user = e['FLARE_E2E_USER'], token = e['FLARE_E2E_TOKEN'];
    final peers = (e['FLARE_E2E_PEERS'] ?? '').split(',').where((x) => x.isNotEmpty).toList();
    if ([ws, tag, user, token].any((x) => x == null || x.isEmpty) || peers.isEmpty) return;

    final root = await Directory.systemTemp.createTemp('flare-listen-');
    final sdk = SdkWrapper();
    addTearDown(() async {
      await sdk.dispose();
      if (await root.exists()) await root.delete(recursive: true);
    });

    const d = AppDefaults.fallback;
    await sdk.init(SdkConfig(
      wsUrl: ws!, tenantId: d.tenantId, httpUrl: 'http://127.0.0.1:50050',
      dataUrl: toFileDataUrl(root.path),
    )).timeout(const Duration(seconds: 25));
    await sdk.login(user!, token!).timeout(const Duration(seconds: 30));

    final done = Completer<Duration>();
    final sub = sdk.addEventListener(_Collector(tag!, done));
    addTearDown(sub.unsubscribe);

    await sdk.syncConversationSummaries().timeout(const Duration(seconds: 40));
    final conv = await sdk
        .getGroupConversationByUserIds(peers, displayName: 'rt-control')
        .timeout(const Duration(seconds: 40));
    final cid = conv.conversationId;
    await sdk.openConversationTimeline(conversationId: cid, messageLimit: 20)
        .timeout(const Duration(seconds: 40));
    await File(e['FLARE_E2E_CID_OUT'] ?? '/tmp/rt_cid.txt').writeAsString(cid);
    // ignore: avoid_print
    print('LISTENER_READY cid=$cid');

    final got = await done.future.timeout(
      const Duration(seconds: 300),
      onTimeout: () => throw StateError('300 秒内没有收到推送 [$tag]'),
    );
    // ignore: avoid_print
    print('RECEIVED_IN_MS=${got.inMilliseconds}');
  }, timeout: const Timeout(Duration(minutes: 8)));
}
