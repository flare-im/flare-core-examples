import 'package:flare_im/domain/value_objects/transport_mode.dart';
import 'package:flare_im/infrastructure/sdk/flare_core_sdk_wrapper.dart';
import 'package:flare_im/shared/config/app_defaults_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('defaults use the access-gateway websocket route', () {
    expect(AppDefaults.fallback.defaultWsUrl, 'ws://127.0.0.1:60051/ws');
    expect(AppDefaults.fallback.defaultQuicUrl, 'quic://127.0.0.1:60052');
    expect(AppDefaults.fallback.defaultTlsCaCertPath, isEmpty);
    // 断言 fallback 是**不可用的占位**：原先只查长度 ≥32，一个真实密钥硬编码
    // 在这里照样能过 —— 事实上正是这么混进来的。
    expect(AppDefaults.fallback.httpUrl, 'http://127.0.0.1:50050');
    expect(AppDefaults.fallback.defaultUserId, isEmpty);
  });

  test('loads gateway and token settings from app defaults json shape', () {
    final defaults = AppDefaults.fromJson(const {
      'defaultWsUrl': 'ws://127.0.0.1:60051/ws',
      'defaultQuicUrl': 'quic://127.0.0.1:60052',
      'defaultTlsCaCertPath': '/tmp/flare-server.crt',
      'tenantId': '0',
      'defaultHttpUrl': 'http://h:50050',
      'userId': 'bob',
    });

    expect(defaults.defaultWsUrl, 'ws://127.0.0.1:60051/ws');
    expect(defaults.defaultQuicUrl, 'quic://127.0.0.1:60052');
    expect(defaults.defaultTlsCaCertPath, '/tmp/flare-server.crt');
    expect(defaults.tenantId, '0');
    expect(defaults.httpUrl, 'http://h:50050');
    expect(defaults.defaultUserId, 'bob');
  });

  test('maps Flutter login transport choices to SDK init config', () {
    expect(
      buildSdkTransportConfig(
        SdkConfig(
          wsUrl: ' ws://127.0.0.1:60051/ws ',
          httpUrl: AppDefaults.fallback.httpUrl,
        ),
      ),
      {
        'wsUrl': 'ws://127.0.0.1:60051/ws',
        'transportPolicy': 'websocket_only',
        'defaultTransport': 'websocket',
      },
    );

    expect(
      buildSdkTransportConfig(
        SdkConfig(
          wsUrl: 'ws://127.0.0.1:60051/ws',
          transportMode: SdkTransportMode.quic,
          quicUrl: ' quic://127.0.0.1:60052 ',
          tlsCaCertPath: ' /tmp/flare-server.crt ',
          httpUrl: AppDefaults.fallback.httpUrl,
        ),
      ),
      {
        'wsUrl': 'ws://127.0.0.1:60051/ws',
        'quicUrl': 'quic://127.0.0.1:60052',
        'tlsCaCertPath': '/tmp/flare-server.crt',
        'transportPolicy': 'auto',
        'defaultTransport': 'quic',
        'protocolRaceOrder': ['quic'],
      },
    );

    expect(
      buildSdkTransportConfig(
        SdkConfig(
          wsUrl: 'ws://127.0.0.1:60051/ws',
          transportMode: SdkTransportMode.race,
          quicUrl: 'quic://127.0.0.1:60052',
          httpUrl: AppDefaults.fallback.httpUrl,
        ),
      ),
      {
        'wsUrl': 'ws://127.0.0.1:60051/ws',
        'quicUrl': 'quic://127.0.0.1:60052',
        'transportPolicy': 'protocol_race',
        'defaultTransport': 'quic',
        'protocolRaceOrder': ['quic', 'websocket'],
      },
    );
  });
}
