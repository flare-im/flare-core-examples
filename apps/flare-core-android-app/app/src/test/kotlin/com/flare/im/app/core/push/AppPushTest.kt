package com.flare.im.app.core.push

import com.flare.im.push.FlarePushHost
import com.flare.im.push.PlatformPushOutcome
import com.flare.im.push.PlatformPushToken
import com.flare.im.push.PlatformTapRoute
import kotlinx.coroutines.async
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.yield
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Test

/** 推送宿主跟着会话走：没有会话时没有，登录或恢复中等它出结果，只有登记它的一方能撤下。 */
class AppPushTest {
    private class Host : FlarePushHost {
        override suspend fun updatePushToken(token: PlatformPushToken) = Unit
        override suspend fun setPushPermission(allowed: Boolean) = Unit
        override suspend fun reconcilePush() = Unit
        override suspend fun handleRemoteMessage(provider: String, payload: Map<String, String>, budgetMs: Int): PlatformPushOutcome =
            error("not used")
        override suspend fun resolveNotificationTap(payload: Map<String, String>): PlatformTapRoute? = null
        override suspend fun totalUnread(): Int = 0
    }

    @Test
    fun withoutASessionThereIsNoHost() = runBlocking {
        val owner = Any()
        AppPush.sessionStarting(owner)
        AppPush.sessionEnded(owner)
        assertNull(AppPush.currentHost())
    }

    @Test
    fun aSessionInProgressIsWaitedFor() = runBlocking {
        val owner = Any()
        AppPush.sessionStarting(owner)
        val waiting = async { AppPush.currentHost() }
        yield()
        assertFalse(waiting.isCompleted)

        val host = Host()
        AppPush.sessionReady(owner, host)
        assertSame(host, waiting.await())
        AppPush.sessionEnded(owner)
    }

    @Test
    fun onlyTheOwnerEndsItsSession() = runBlocking {
        val owner = Any()
        val host = Host()
        AppPush.sessionReady(owner, host)
        AppPush.sessionEnded(Any())
        assertSame(host, AppPush.currentHost())

        AppPush.signedOut(owner)
        assertNull(AppPush.currentHost())
    }
}
