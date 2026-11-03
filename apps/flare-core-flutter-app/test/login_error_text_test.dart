import 'package:flare_im/interface/screens/login/login_error_text.dart';
import 'package:flare_im/shared/i18n/flare_locale.dart';
import 'package:flare_im/shared/i18n/flare_messages.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final m = FlareMessages.of(FlareLocale.zhCn);

  test('核心报 AUTHENTICATION_FAILED / TOKEN_REJECTED 时换成「核对签名密钥」', () {
    expect(
      friendlyLoginError(
        Exception(
            '错误 [AUTHENTICATION_FAILED] connect failed primary=ws://x/ws: TOKEN_REJECTED: server closed the connection before CONNECT_ACK'),
        m,
      ),
      m.login.tokenRejected,
    );
  });

  test('连不上服务器保持原文', () {
    const raw =
        '错误 [CONNECTION_FAILED] Negotiation timeout after 10s (CONNECT_ACK not received)';
    expect(friendlyLoginError(Exception(raw), m), contains('CONNECTION_FAILED'));
    expect(isTokenRejectedLoginError(Exception(raw)), isFalse);
  });
}
