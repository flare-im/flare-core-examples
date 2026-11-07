package com.flare.im.app.features.auth

import java.io.File
import kotlin.test.Test
import kotlin.test.assertFalse
import kotlin.test.assertTrue

/**
 * 客户端不再本地签发接入 token（那等于把签名密钥打进安装包）。
 * SDK 托管：init 只给 `auth: {}`，核心在当前接入点的 Core API 上签发，login 不传 token；
 * 应用托管：构建期预填的 token 原样传。连哪里只来自构建期的接入配置，登录页没有服务器设置。
 */
class SdkManagedTokenTest {
    private fun src(rel: String): String {
        var dir: File? = File("").absoluteFile
        while (dir != null && !File(dir, "app/src/main").exists()) dir = dir.parentFile
        return File(dir ?: error("repo root not found"), rel).readText()
    }

    @Test
    fun `会话层把签发地址交给核心且不再本地签发`() {
        val s = src("app/src/main/kotlin/com/flare/im/app/core/session/AppSession.kt")
        assertTrue(s.contains("put(\"auth\", emptyMap<String, Any>())"))
        assertFalse(s.contains("tokenEndpoint"))
        assertTrue(s.contains("put(\"access\", access.access)"))
        assertTrue(s.contains("if (pastedToken.isNotEmpty()) put(\"token\", pastedToken)"))
        assertFalse(s.contains("generateCoreToken"))
        assertFalse(s.contains("tokenSecret"))
    }

    @Test
    fun `登录页没有服务器设置且不暴露 token 或签名密钥`() {
        val s = src("app/src/main/kotlin/com/flare/im/app/features/auth/LoginScreen.kt")
        assertFalse(s.contains("ServerAddressSection"))
        assertFalse(s.contains("SegmentedControl"))
        assertFalse(s.contains("value = draft.accessToken"))
        assertFalse(s.contains("tokenSecret"))
    }

    @Test
    fun `会话档案不存服务器地址`() {
        val s = src("app/src/main/kotlin/com/flare/im/app/core/session/SavedSessionStore.kt")
        assertTrue(s.contains("putString(KEY_USER_ID, draft.userId)"))
        assertFalse(s.contains("Url"))
        assertFalse(s.contains("tokenSecret"))
    }

    @Test
    fun `应用不手写网络与前后台上报`() {
        for (rel in listOf(
            "app/src/main/kotlin/com/flare/im/app/features/shell/FlareApp.kt",
            "app/src/main/kotlin/com/flare/im/app/core/FlareAppStore.kt",
        )) {
            val s = src(rel)
            assertFalse(s.contains("ConnectivityManager"), rel)
            assertFalse(s.contains("NetworkChangeRequest"), rel)
            assertFalse(s.contains("SetAppStateRequest"), rel)
            assertFalse(s.contains("LifecycleEventObserver"), rel)
        }
    }
}
