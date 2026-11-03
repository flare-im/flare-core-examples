package com.flare.im.app.features.auth

import kotlin.test.Test
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class LoginErrorTextTest {
    @Test
    fun `核心报 AUTHENTICATION_FAILED 或 TOKEN_REJECTED 时判为 token 被拒`() {
        assertTrue(LoginErrorText.isTokenRejected("错误 [AUTHENTICATION_FAILED] connect failed primary=ws://x/ws: 错误 [AUTHENTICATION_FAILED] TOKEN_REJECTED: server closed the connection before CONNECT_ACK"))
        assertTrue(LoginErrorText.isTokenRejected("TOKEN_REJECTED: x"))
    }

    @Test
    fun `连不上服务器不是 token 被拒`() {
        assertFalse(LoginErrorText.isTokenRejected("错误 [CONNECTION_FAILED] connect failed: Negotiation timeout after 10s (CONNECT_ACK not received)"))
        assertFalse(LoginErrorText.isTokenRejected("Enter user ID"))
    }
}
