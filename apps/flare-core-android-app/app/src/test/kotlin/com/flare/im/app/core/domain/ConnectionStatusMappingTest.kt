package com.flare.im.app.core.domain

import com.flare.im.model.entity.ConnectionPhase
import com.flare.im.model.entity.ConnectionQuality
import com.flare.im.model.entity.ConnectionStatus
import com.flare.im.ui.FlareConnectionActionReason
import com.flare.im.ui.FlareConnectionPhase
import com.flare.im.ui.FlareConnectionQuality
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

/** The kit's ConnectionNotice gets the SDK's `connection://status` field for field. */
class ConnectionStatusMappingTest {
    @Test
    fun everyPhaseHasTheKitsOwn() {
        val expected = listOf(
            FlareConnectionPhase.Idle, FlareConnectionPhase.Connecting, FlareConnectionPhase.Syncing,
            FlareConnectionPhase.Online, FlareConnectionPhase.Switching, FlareConnectionPhase.Reconnecting,
            FlareConnectionPhase.WaitingForNetwork, FlareConnectionPhase.ServiceUnavailable,
            FlareConnectionPhase.ActionRequired,
        )
        assertEquals(expected, ConnectionPhase.entries.map { ConnectionStatus(phase = it).toKitStatus().phase })
    }

    @Test
    fun theFieldsTheNoticeReadsPassThrough() {
        val reconnecting = ConnectionStatus(
            phase = ConnectionPhase.RECONNECTING,
            accessPointId = "development",
            protocol = "ws",
            attempt = 2,
            nextRetryAt = 1_762_250_000_000,
            developmentMode = true,
        ).toKitStatus()
        assertEquals(2, reconnecting.attempt)
        assertEquals(1_762_250_000_000, reconnecting.nextRetryAt)
        assertEquals(true, reconnecting.developmentMode)
        assertNull(reconnecting.quality)

        assertEquals(FlareConnectionQuality.Poor, ConnectionStatus(ConnectionPhase.ONLINE, quality = ConnectionQuality.POOR).toKitStatus().quality)
        // The reason is the SDK's text: switching carries its own, actionRequired the four the notice explains.
        assertEquals("drain", ConnectionStatus(ConnectionPhase.SWITCHING, reason = "drain").toKitStatus().reason)
        assertEquals(
            FlareConnectionActionReason.Kicked,
            ConnectionStatus(ConnectionPhase.ACTION_REQUIRED, reason = "kicked").toKitStatus().actionReason,
        )
    }
}
