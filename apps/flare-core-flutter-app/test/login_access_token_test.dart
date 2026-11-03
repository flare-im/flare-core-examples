import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 客户端不再本地签发或持有接入 token（那等于把签名密钥打进安装包）。
/// SDK 托管：init 把网关地址交给核心（auth.tokenEndpoint），login 不传 token。
void main() {
  final loginSource = File(
    'lib/interface/screens/login/login_screen.dart',
  ).readAsStringSync();
  final wrapperSource = File(
    'lib/infrastructure/sdk/flare_core_sdk_wrapper.dart',
  ).readAsStringSync();

  test('登录页不持有 token 或签名密钥', () {
    expect(loginSource.contains('_accessTokenController'), isFalse);
    expect(loginSource.contains('_tokenSecretController'), isFalse);
    expect(loginSource.contains('authGenerateCoreToken'), isFalse);
  });

  test('登录交给核心向网关签发 token', () {
    expect(loginSource.contains('await im.authLogin(userId, null);'), isTrue);
    expect(
      wrapperSource.contains("if (explicit.isNotEmpty) 'token': explicit,"),
      isTrue,
    );
  });

  test('init 把网关地址交给核心', () {
    expect(
      wrapperSource.contains("'auth': {'tokenEndpoint': _httpUrl}"),
      isTrue,
    );
    expect(wrapperSource.contains('generateCoreToken'), isFalse);
    expect(wrapperSource.contains('tokenSecret'), isFalse);
  });

  test('登录页不存在可泄漏的 token 控制器', () {
    expect(loginSource.contains('_accessTokenController'), isFalse);
  });
}
