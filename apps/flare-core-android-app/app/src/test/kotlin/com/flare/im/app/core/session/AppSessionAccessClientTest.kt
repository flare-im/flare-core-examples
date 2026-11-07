package com.flare.im.app.core.session

import com.flare.im.FlareCoreSdk
import com.flare.im.api.FlareImClient
import com.flare.im.app.core.domain.LoginDraft
import com.flare.im.contract.NativeBridge
import com.flare.im.contract.NativeCallDescriptor
import com.flare.im.contract.NativeCallMap
import java.util.Collections
import java.util.concurrent.atomic.AtomicInteger
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.delay
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotSame
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

/** The update center and the network page read through [AppSession.accessClient], before any sign-in and during one. */
class AppSessionAccessClientTest {
    /** Answers every call as its contract says: nothing, or an empty object. */
    private class AnsweringBridge : NativeBridge {
        val operations: MutableList<String> = Collections.synchronizedList(mutableListOf())
        var initGate: CompletableDeferred<Unit>? = null
        var loginGate: CompletableDeferred<Unit>? = null
        var loginFailure: Exception? = null

        @Suppress("UNCHECKED_CAST")
        override suspend fun <T> invoke(descriptor: NativeCallDescriptor, request: Any?): T {
            operations += descriptor.operation
            if (descriptor == NativeCallMap.SDK_INIT) initGate?.await()
            if (descriptor == NativeCallMap.SDK_LOGIN) {
                loginGate?.await()
                loginFailure?.let { throw it }
            }
            return (if (descriptor.responseEncoding == "unit") Unit else emptyMap<String, Any?>()) as T
        }

        fun count(descriptor: NativeCallDescriptor): Int = operations.count { it == descriptor.operation }
    }

    private val bridge = AnsweringBridge()
    private val created = AtomicInteger()
    private val draft = LoginDraft()
    private val session = AppSession(
        newClient = {
            created.incrementAndGet()
            FlareCoreSdk.createClientWithBridge(bridge)
        },
        access = { AppAccess(mapOf("trustMode" to "development")) },
    )

    @Test
    fun readsShareOneClient() {
        runBlocking {
            val first = session.accessClient(draft, DATA_DIR)
            val second = session.accessClient(draft, DATA_DIR)

            assertSame(first, second)
            assertEquals(1, created.get())
            assertEquals(1, bridge.count(NativeCallMap.SDK_INIT))
        }
    }

    /** The first read of the update center and the network page can start together: `init` runs once. */
    @Test
    fun aSecondReadWaitsForTheBringUpUnderWay() {
        runBlocking(Dispatchers.Default) {
            val gate = CompletableDeferred<Unit>()
            bridge.initGate = gate

            val reads = listOf(
                async { session.accessClient(draft, DATA_DIR) },
                async { session.accessClient(draft, DATA_DIR) },
            )
            while (bridge.count(NativeCallMap.SDK_INIT) == 0) delay(1)
            gate.complete(Unit)
            val clients: List<FlareImClient> = reads.awaitAll()

            assertSame(clients[0], clients[1])
            assertEquals(1, created.get())
            assertEquals(1, bridge.count(NativeCallMap.SDK_INIT))
        }
    }

    @Test
    fun aSignInContinuesOnTheClientAReadBroughtUp() {
        runBlocking {
            val read = session.accessClient(draft, DATA_DIR)

            val signedIn = session.start(draft, DATA_DIR) {}

            assertSame(read, signedIn)
            assertEquals(1, created.get())
            assertEquals(1, bridge.count(NativeCallMap.SDK_INIT))
            assertEquals(1, bridge.count(NativeCallMap.SDK_LOGIN))
        }
    }

    /** The update center polls while it checks, so a read lands in the middle of a sign-in: no second core comes up. */
    @Test
    fun aReadDuringASignInUsesTheClientAReadBroughtUp() {
        runBlocking(Dispatchers.Default) {
            val read = session.accessClient(draft, DATA_DIR)
            val gate = CompletableDeferred<Unit>()
            bridge.loginGate = gate

            val signIn = async { session.start(draft, DATA_DIR) {} }
            while (bridge.count(NativeCallMap.SDK_LOGIN) == 0) delay(1)
            val during = session.accessClient(draft, DATA_DIR)
            gate.complete(Unit)

            assertSame(read, during)
            assertSame(read, signIn.await())
            assertEquals(1, created.get())
            assertEquals(1, bridge.count(NativeCallMap.SDK_INIT))
        }
    }

    @Test
    fun aReadDuringAFirstSignInUsesItsClient() {
        runBlocking(Dispatchers.Default) {
            val gate = CompletableDeferred<Unit>()
            bridge.loginGate = gate

            val signIn = async { session.start(draft, DATA_DIR) {} }
            while (bridge.count(NativeCallMap.SDK_LOGIN) == 0) delay(1)
            val during = session.accessClient(draft, DATA_DIR)
            gate.complete(Unit)

            assertSame(signIn.await(), during)
            assertEquals(1, created.get())
            assertEquals(1, bridge.count(NativeCallMap.SDK_INIT))
        }
    }

    @Test
    fun aReadAfterSignInUsesTheSignedInClient() {
        runBlocking {
            val signedIn = session.start(draft, DATA_DIR) {}

            assertSame(signedIn, session.accessClient(draft, DATA_DIR))
            assertEquals(1, created.get())
        }
    }

    /** A saved session resumes on its own client, and every read after it goes there. */
    @Test
    fun aReadAfterAResumeUsesTheResumedClient() {
        runBlocking {
            val resumed = session.resumeLocal(draft, DATA_DIR) {}

            assertSame(resumed, session.accessClient(draft, DATA_DIR))
            assertEquals(1, created.get())
            assertEquals(1, bridge.count(NativeCallMap.SDK_INIT))
        }
    }

    /** Another tenant is another core: what a read brought up cannot serve it. */
    @Test
    fun aSignInForAnotherTenantGetsItsOwnClient() {
        runBlocking {
            val read = session.accessClient(draft, DATA_DIR)

            val signedIn = session.start(draft.copy(tenantId = "7"), DATA_DIR) {}

            assertNotSame(read, signedIn)
            assertEquals(2, created.get())
        }
    }

    /** Only that client knows the server refused this build, so the update center has to go on reading it. */
    @Test
    fun aRefusedSignInKeepsItsClientForTheNextRead() {
        runBlocking {
            bridge.loginFailure = IllegalStateException("UPGRADE_REQUIRED")
            assertTrue(runCatching { session.start(draft, DATA_DIR) {} }.isFailure)

            session.accessClient(draft, DATA_DIR)

            assertEquals(1, created.get())
            assertEquals(1, bridge.count(NativeCallMap.SDK_INIT))
        }
    }

    private companion object {
        const val DATA_DIR = "/data/app"
    }
}
