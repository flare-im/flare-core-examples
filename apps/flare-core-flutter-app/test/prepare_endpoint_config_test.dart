import 'package:flare_core_flutter_sdk/flare_core_flutter_sdk.dart' as core;
import 'package:flare_im/infrastructure/sdk/flare_core_sdk_wrapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('prepare uses the initialized client and its current endpoints', () async {
    final client = _Client();
    Map<String, Object?>? initialized;
    final sdk = SdkWrapper(createClient: (config) async {
      initialized = config;
      return client;
    });
    const endpoints = {
      'baseUrl': 'https://im.example.com',
      'websocketUrl': 'wss://im.example.com/ws',
    };
    await sdk.init(const SdkConfig(endpoints: endpoints));
    await sdk.prepareLocal('alice');

    expect(initialized?['endpoints'], endpoints);
    expect(client.prepareRequest, {'userId': 'alice'});
  });
}

final class _Client implements core.FlareImClient {
  Map<String, Object?>? prepareRequest;

  @override
  final core.EventsApi events = _Events();

  @override
  Future<void> prepare(Map<String, Object?> request) async {
    prepareRequest = request;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _Events implements core.EventsApi {
  @override
  Future<Map<String, Object?>> subscribeEventsBatch(
    Map<String, Object?> request,
  ) async => {'subscription': 1};

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
