// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:io';

import 'package:flare_core_flutter_sdk/flare_core_flutter_sdk.dart' as core;
import 'package:flare_im/infrastructure/paths/sdk_data_url.dart';
import 'package:flare_im/infrastructure/sdk/flare_core_sdk_wrapper.dart';
import 'package:flare_im/shared/config/app_defaults_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// 跨端实时投递联调：A 端订阅事件、B 端发送，断言 A 收到推送。
///
/// 只认 `onMessageReceivedBatch`：批量是规范路径，逐条回调对聊天消息不触发。
class _Collector extends core.FlareImEventListener {
  _Collector(this.tag, this.done);
  final String tag;
  final Completer<Duration> done;
  final Stopwatch sw = Stopwatch()..start();

  // 只关心批量消息回调，其余回调用 noSuchMethod 自动转发成空实现。
  @override
  dynamic noSuchMethod(Invocation invocation) => null;

  @override
  void onMessageReceivedBatch(core.MessageReceivedBatchEvent event) {
    for (final m in event.messages) {
      final text = m.content?.data['text']?.toString() ?? '';
      if (text.contains(tag) && !done.isCompleted) {
        done.complete(sw.elapsed);
      }
    }
  }
}

Future<SdkWrapper> _session(String user, String token, String ws) async {
  final root = await Directory.systemTemp.createTemp('flare-rt-');
  final sdk = SdkWrapper();
  const d = AppDefaults.fallback;
  await sdk.init(SdkConfig(
    wsUrl: ws, tenantId: d.tenantId, httpUrl: 'http://127.0.0.1:50050',
    dataUrl: toFileDataUrl(root.path),
  )).timeout(const Duration(seconds: 25));
  await sdk.login(user, token).timeout(const Duration(seconds: 30));
  return sdk;
}

void main() {
  test('B 发送后 A 应当收到实时推送', () async {
    final e = Platform.environment;
    final ws = e['FLARE_E2E_WS_URL'], cid = e['FLARE_E2E_CID'], tag = e['FLARE_E2E_TAG'];
    final ua = e['FLARE_E2E_USER_A'], ta = e['FLARE_E2E_TOKEN_A'];
    final ub = e['FLARE_E2E_USER_B'], tb = e['FLARE_E2E_TOKEN_B'];
    if ([ws, cid, tag, ua, ta, ub, tb].any((x) => x == null || x.isEmpty)) return;

    final a = await _session(ua!, ta!, ws!);
    final b = await _session(ub!, tb!, ws);
    addTearDown(() async { await a.dispose(); await b.dispose(); });

    final done = Completer<Duration>();
    final sub = a.addEventListener(_Collector(tag!, done));
    addTearDown(sub.unsubscribe);

    await a.syncConversationSummaries().timeout(const Duration(seconds: 30));
    await a.openConversationTimeline(conversationId: cid!, messageLimit: 20)
        .timeout(const Duration(seconds: 30));
    await Future<void>.delayed(const Duration(seconds: 2));

    final msg = await b.createTextMessage(conversationId: cid, text: tag)
        .timeout(const Duration(seconds: 20));
    await b.sendCoreMessage(msg).timeout(const Duration(seconds: 30));
    print('SENT_BY_B=$tag');

    final got = await done.future.timeout(
      const Duration(seconds: 60),
      onTimeout: () => throw StateError('A 在 60 秒内没有收到推送 [$tag]'),
    );
    print('A_RECEIVED_IN_MS=${got.inMilliseconds}');
  }, timeout: const Timeout(Duration(minutes: 4)));
}
