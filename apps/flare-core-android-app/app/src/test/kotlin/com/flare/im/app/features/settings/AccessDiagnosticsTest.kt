package com.flare.im.app.features.settings

import com.flare.im.api.access.AccessApi
import com.flare.im.model.command.AccessImportRecoveryRequest
import com.flare.im.model.command.AccessPinRequest
import com.flare.im.model.entity.AccessConnectAck
import com.flare.im.model.entity.AccessPin
import com.flare.im.model.entity.AccessPointInfo
import com.flare.im.model.entity.AccessRecoveringStatus
import com.flare.im.model.entity.AccessRecoveryImport
import com.flare.im.model.entity.AccessRefreshReport
import com.flare.im.model.entity.AccessStatus
import com.flare.im.ui.FlareAccessConnectAck
import com.flare.im.ui.FlareAccessPoint
import com.flare.im.ui.FlareAccessRecovering
import com.flare.im.ui.FlareAccessStatus
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import org.json.JSONObject
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

class AccessDiagnosticsTest {
    private class FakeAccess : AccessApi {
        var serial = 7L
        val links = mutableListOf<String>()
        val pins = mutableListOf<String>()
        val failing = mutableSetOf<String>()
        var imported = AccessRecoveryImport(outcome = "adopted", serial = 9)

        private fun check(op: String) { if (op in failing) error("refused") }

        override suspend fun getStatus() = AccessStatus(loaded = true, serial = serial)
        override suspend fun listAccessPoints() =
            listOf(AccessPointInfo(accessPointId = "ap-a", status = "active", breaker = "closed", current = true))
        override suspend fun pin(request: AccessPinRequest): AccessPin {
            check("pin")
            pins += request.accessPointId
            return AccessPin(accessPointId = request.accessPointId)
        }
        override suspend fun unpin() {}
        override suspend fun refresh(): AccessRefreshReport {
            check("refresh")
            return AccessRefreshReport(outcome = "upToDate")
        }
        override suspend fun importRecovery(request: AccessImportRecoveryRequest): AccessRecoveryImport {
            links += request.link
            check("import")
            return imported
        }
        override suspend fun exportDiagnostics(): Map<String, Any?> {
            check("export")
            return mapOf("status" to mapOf("serial" to 7))
        }
    }

    private fun host(core: FakeAccess, subscribe: (() -> Unit) -> () -> Unit = { {} }) = AccessDiagnosticsHost(
        access = { core },
        subscribeLinkEvents = subscribe,
        scope = CoroutineScope(Dispatchers.Unconfined),
        warn = { _, _ -> },
    )

    @Test
    fun keepsARecoveryLinkAsItArrivedAndLeavesOtherLinksAlone() {
        assertEquals("flare-recover://v1?p=aB-_&k=root&s=c2ln", parseRecoveryLink(" flare-recover://v1?p=aB-_&k=root&s=c2ln "))
        assertNull(parseRecoveryLink(null))
        assertNull(parseRecoveryLink("https://example.com/flare-recover://v1"))
    }

    @Test
    fun theSdkResultsReachTheKitFieldForField() {
        val status = AccessStatus(
            loaded = true, serial = 42, source = "recovery", stale = true, developmentMode = true,
            regionId = "cn-east", accessPointId = "ap-a", protocol = "quic",
            connectAck = AccessConnectAck(accessPointId = "ap-b", accessPointMismatch = true),
            recovering = AccessRecoveringStatus(sinceMs = 1, rounds = 2, nextRoundAtMs = null),
        ).toKitStatus()
        assertEquals(
            FlareAccessStatus(
                loaded = true, serial = 42, source = "recovery", stale = true, developmentMode = true,
                regionId = "cn-east", accessPointId = "ap-a", protocol = "quic",
                connectAck = FlareAccessConnectAck("ap-b", true),
                recovering = FlareAccessRecovering(2, null),
            ),
            status,
        )
        assertEquals(
            FlareAccessPoint("ap-a", null, null, "draining", 12.5, "open", true, true),
            AccessPointInfo(accessPointId = "ap-a", status = "draining", rttMs = 12.5, breaker = "open", pinned = true, current = true).toKitPoint(),
        )
    }

    @Test
    fun followsLinkEventsUntilStopped() {
        val core = FakeAccess()
        var notify: () -> Unit = {}
        var stopped = 0
        val page = host(core) { handler ->
            notify = handler
            ({ stopped++ })
        }
        val stop = page.follow()
        assertEquals(7L, page.status?.serial)
        assertEquals(listOf("ap-a"), page.accessPoints.map { it.accessPointId })

        core.serial = 8
        notify()
        assertEquals(8L, page.status?.serial)

        stop()
        assertEquals(1, stopped)
    }

    @Test
    fun aRefusedPinReadsAsRefusedAndTheDirectoryIsReadAgain() = runBlocking {
        val core = FakeAccess()
        val page = host(core)
        assertTrue(page.pin("ap-a"))
        assertEquals(listOf("ap-a"), core.pins)

        core.failing += "pin"
        core.serial = 8
        assertFalse(page.pin("ap-gone"))
        assertEquals(8L, page.status?.serial)
    }

    @Test
    fun aRefreshFillsItsOutcomeAndAThrowReadsFailed() = runBlocking {
        val core = FakeAccess()
        val page = host(core)
        page.refresh()
        assertEquals("upToDate", page.refreshOutcome)

        core.failing += "refresh"
        page.refresh()
        assertEquals("failed", page.refreshOutcome)
        assertFalse(page.refreshing)
    }

    @Test
    fun aRejectedLinkCarriesItsCodeBackToThePage() = runBlocking {
        val core = FakeAccess()
        core.imported = AccessRecoveryImport(outcome = "rejected", code = "rollback", serial = 7)
        val page = host(core)
        page.importRecovery("flare-recover://v1?p=a&k=b&s=c")
        assertEquals(listOf("flare-recover://v1?p=a&k=b&s=c"), core.links)
        assertEquals("rejected", page.importOutcome)
        assertEquals("rollback", page.importCode)
    }

    @Test
    fun anImportThatThrowsIsNotSilent() = runBlocking {
        val core = FakeAccess()
        core.failing += "import"
        val page = host(core)
        page.importRecovery("flare-recover://x")
        assertEquals("rejected", page.importOutcome)
        assertNull(page.importCode)
        assertFalse(page.importing)
    }

    @Test
    fun anOpenedLinkShowsThePageAndImports() {
        val page = host(FakeAccess())
        page.openRecoveryLink("flare-recover://x")
        assertTrue(page.presented)
        assertEquals("adopted", page.importOutcome)
    }

    @Test
    fun theDiagnosticsGoToTheClipboardAsJson() = runBlocking {
        val core = FakeAccess()
        val page = host(core)
        val copied = mutableListOf<String>()
        page.exportDiagnostics { copied += it }
        assertEquals("copied", page.exportOutcome)
        assertEquals(7, JSONObject(copied.single()).getJSONObject("status").getInt("serial"))

        core.failing += "export"
        page.exportDiagnostics { copied += it }
        assertEquals("failed", page.exportOutcome)
        assertFalse(page.exporting)
    }
}
