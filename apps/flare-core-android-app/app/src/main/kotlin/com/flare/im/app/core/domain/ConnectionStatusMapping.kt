package com.flare.im.app.core.domain

import com.flare.im.model.entity.ConnectionPhase
import com.flare.im.model.entity.ConnectionQuality
import com.flare.im.model.entity.ConnectionStatus
import com.flare.im.ui.FlareConnectionPhase
import com.flare.im.ui.FlareConnectionQuality
import com.flare.im.ui.FlareConnectionStatus

/** The SDK's `connection://status` as the kit's ConnectionNotice reads it: the same fields, field for field. */
fun ConnectionStatus.toKitStatus(): FlareConnectionStatus = FlareConnectionStatus(
    phase = when (phase) {
        ConnectionPhase.IDLE -> FlareConnectionPhase.Idle
        ConnectionPhase.CONNECTING -> FlareConnectionPhase.Connecting
        ConnectionPhase.SYNCING -> FlareConnectionPhase.Syncing
        ConnectionPhase.ONLINE -> FlareConnectionPhase.Online
        ConnectionPhase.SWITCHING -> FlareConnectionPhase.Switching
        ConnectionPhase.RECONNECTING -> FlareConnectionPhase.Reconnecting
        ConnectionPhase.WAITING_FOR_NETWORK -> FlareConnectionPhase.WaitingForNetwork
        ConnectionPhase.SERVICE_UNAVAILABLE -> FlareConnectionPhase.ServiceUnavailable
        ConnectionPhase.ACTION_REQUIRED -> FlareConnectionPhase.ActionRequired
    },
    quality = when (quality) {
        ConnectionQuality.GOOD -> FlareConnectionQuality.Good
        ConnectionQuality.POOR -> FlareConnectionQuality.Poor
        null -> null
    },
    nextRetryAt = nextRetryAt,
    attempt = attempt,
    reason = reason,
    developmentMode = developmentMode,
)
