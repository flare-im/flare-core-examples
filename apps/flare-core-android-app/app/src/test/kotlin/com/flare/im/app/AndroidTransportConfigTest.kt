package com.flare.im.app

import com.flare.im.app.core.domain.LoginDraft
import com.flare.im.app.core.domain.LoginTransportMode
import kotlin.test.Test
import kotlin.test.assertEquals

/** 校验 [LoginDraft.transportConfig]（取代旧 androidTransportConfig）。 */
class AndroidTransportConfigTest {
    @Test
    fun defaultsToWebSocketTransport() {
        val config = LoginDraft(
            transportMode = LoginTransportMode.WebSocket,
            wsUrl = " ws://10.0.2.2:60051/ws ",
            quicUrl = "quic://10.0.2.2:60052",
            tlsCaCertPath = "",
        ).transportConfig()

        assertEquals("ws://10.0.2.2:60051/ws", config["wsUrl"])
        assertEquals("websocket_only", config["transportPolicy"])
        assertEquals("websocket", config["defaultTransport"])
    }

    @Test
    fun mapsQuicAndRaceTransport() {
        val quic = LoginDraft(
            transportMode = LoginTransportMode.Quic,
            wsUrl = "ws://10.0.2.2:60051/ws",
            quicUrl = " quic://10.0.2.2:60052 ",
            tlsCaCertPath = " /tmp/flare-server.crt ",
        ).transportConfig()

        assertEquals("auto", quic["transportPolicy"])
        assertEquals("quic", quic["defaultTransport"])
        assertEquals("quic://10.0.2.2:60052", quic["quicUrl"])
        assertEquals("/tmp/flare-server.crt", quic["tlsCaCertPath"])
        assertEquals(listOf("quic"), quic["protocolRaceOrder"])

        val race = LoginDraft(
            transportMode = LoginTransportMode.Race,
            wsUrl = "ws://10.0.2.2:60051/ws",
            quicUrl = "quic://10.0.2.2:60052",
            tlsCaCertPath = "",
        ).transportConfig()

        assertEquals("protocol_race", race["transportPolicy"])
        assertEquals(listOf("quic", "websocket"), race["protocolRaceOrder"])
    }
}
