package com.flare.im.app.features.auth

import java.io.File
import kotlin.test.Test
import kotlin.test.assertFalse
import kotlin.test.assertTrue

/**
 * 客户端不再本地签发接入 token（那等于把签名密钥打进安装包）。
 * SDK 托管：init 把网关地址交给核心（auth.tokenEndpoint），login 不传 token；
 * 应用托管：高级区粘贴 token 原样传。
 */
class SdkManagedTokenTest {
    private fun src(rel: String): String {
        var dir: File? = File("").absoluteFile
        while (dir != null && !File(dir, "app/src/main").exists()) dir = dir.parentFile
        return File(dir ?: error("repo root not found"), rel).readText()
    }

    @Test
    fun `会话层把网关地址交给核心且不再本地签发`() {
        val s = src("app/src/main/kotlin/com/flare/im/app/core/session/AppSession.kt")
        assertTrue(s.contains("\"auth\" to mapOf(\"tokenEndpoint\" to draft.httpUrl.trim())"))
        assertTrue(s.contains("if (pastedToken.isNotEmpty()) put(\"token\", pastedToken)"))
        assertFalse(s.contains("generateCoreToken"))
        assertFalse(s.contains("tokenSecret"))
    }

    @Test
    fun `登录页只有网关入口且不暴露 token 或签名密钥`() {
        val s = src("app/src/main/kotlin/com/flare/im/app/features/auth/LoginScreen.kt")
        assertTrue(s.contains("value = draft.httpUrl"))
        assertFalse(s.contains("value = draft.accessToken"))
        assertFalse(s.contains("tokenSecret"))
    }

    @Test
    fun `会话档案持久化网关地址`() {
        val s = src("app/src/main/kotlin/com/flare/im/app/core/session/SavedSessionStore.kt")
        assertTrue(s.contains("putString(KEY_HTTP_URL, draft.httpUrl)"))
        assertFalse(s.contains("tokenSecret"))
    }
}
