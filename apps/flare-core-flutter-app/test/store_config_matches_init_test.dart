import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// prepare 的 storeConfigJson 会让核心重新 init：必须与 init 时交给核心的是同一份，
/// 否则 access / auth / tlsCaCert 会被冲掉（实测 QUIC 登录报 connect token required）。
void main() {
  test('storeConfigJson 重发 init 的完整 overlay', () {
    final src = File('lib/infrastructure/sdk/flare_core_sdk_wrapper.dart').readAsStringSync();
    expect(src.contains('_lastInitConfig = initConfig;'), isTrue);
    expect(src.contains('final config = _lastInitConfig ??'), isTrue);
    expect(src.contains("'access': access,"), isTrue);
  });
}
