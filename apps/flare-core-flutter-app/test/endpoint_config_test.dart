import 'package:flare_im/shared/config/endpoints.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('debug endpoints use the Android emulator host', () {
    expect(resolveCoreEndpoints(endpointsJson: '', release: false, platform: TargetPlatform.android), {
      'baseUrl': 'http://10.0.2.2:50050', 'websocketUrl': 'ws://10.0.2.2:60051/ws',
    });
  });

  test('release builds require a complete explicit endpoint group', () {
    expect(() => resolveCoreEndpoints(endpointsJson: '', release: true), throwsA(isA<EndpointConfigError>()));
    expect(() => resolveCoreEndpoints(endpointsJson: '{}', release: true), throwsA(isA<EndpointConfigError>()));
  });
}
