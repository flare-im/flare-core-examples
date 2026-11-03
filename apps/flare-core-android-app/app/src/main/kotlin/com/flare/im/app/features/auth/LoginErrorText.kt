package com.flare.im.app.features.auth

/**
 * 网关拒掉本地签发的 token（密钥/签发者与服务端不一致、过期）时，核心报的是
 * `错误 [AUTHENTICATION_FAILED] connect failed primary=… TOKEN_REJECTED: …`——一长串传输层描述。
 * 登录页只该告诉用户「去核对签名密钥」。与 web 端 kit 的 isTokenRejectedError 同判据。
 */
object LoginErrorText {
    private val tokenRejected = Regex("AUTHENTICATION_FAILED|TOKEN_REJECTED")

    fun isTokenRejected(raw: String): Boolean = tokenRejected.containsMatchIn(raw)
}
