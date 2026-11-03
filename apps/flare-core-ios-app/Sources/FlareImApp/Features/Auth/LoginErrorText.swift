import Foundation

/// 网关拒掉本地签发的 token（密钥/签发者与服务端不一致、过期）时，核心报的是
/// `错误 [AUTHENTICATION_FAILED] connect failed primary=… TOKEN_REJECTED: …`——一长串传输层描述。
/// 登录页只该告诉用户「去核对签名密钥」。与 web 端 kit 的 isTokenRejectedError 同判据。
public enum LoginErrorText {
    public static func isTokenRejected(_ raw: String) -> Bool {
        raw.contains("AUTHENTICATION_FAILED") || raw.contains("TOKEN_REJECTED")
    }

    /// 展示给用户的登录错误：token 被拒换成可操作文案，其余原样。
    public static func display(_ raw: String) -> String {
        isTokenRejected(raw)
            ? String(localized: "The server rejected the access token: the signing secret or issuer does not match the server, or the token has expired. Check the signing secret and try again.")
            : raw
    }
}
