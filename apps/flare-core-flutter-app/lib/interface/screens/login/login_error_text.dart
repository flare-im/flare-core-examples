import 'package:flare_im/shared/i18n/flare_messages.dart';

/// 网关拒掉本地签发的 token（密钥/签发者与服务端不一致、过期）时，核心报的是
/// `错误 [AUTHENTICATION_FAILED] connect failed primary=… TOKEN_REJECTED: …`——
/// 一长串传输层描述。登录页只该告诉用户「去核对签名密钥」。与 web 端 kit 的
/// isTokenRejectedError 同判据。
final RegExp _tokenRejected = RegExp(r'AUTHENTICATION_FAILED|TOKEN_REJECTED');

bool isTokenRejectedLoginError(Object error) =>
    _tokenRejected.hasMatch(error.toString());

/// token 被拒时给一句可读的双语提示（[m] 走当前语言），否则原样返回错误串。
String friendlyLoginError(Object error, FlareMessages m) =>
    isTokenRejectedLoginError(error) ? m.login.tokenRejected : error.toString();
