package com.flare.im.app.core.session

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertFalse
import kotlin.test.assertTrue

/** Where the SDK connects comes from the build ([AppAccess.resolve]); the app has no server settings of its own. */
class AppAccessTest {
    private fun resolve(vararg settings: Pair<String, String>, allowDevelopment: Boolean = true) =
        AppAccess.resolve({ settings.toMap()[it] }, allowDevelopment)

    private fun endpoints(access: AppAccess) = access.access["developmentEndpoints"] as Map<*, *>

    @Test
    fun aDebugBuildWithoutSettingsUsesTheLocalStackFromTheEmulator() {
        val access = resolve()
        assertEquals("development", access.access["trustMode"])
        assertTrue(access.developmentMode)
        assertEquals(
            mapOf("wsUrl" to "ws://10.0.2.2:60051", "coreApiUrl" to "http://10.0.2.2:50050", "mediaUrl" to "http://10.0.2.2:50050"),
            endpoints(access),
        )
    }

    @Test
    fun developmentEndpointsComeFromTheBuildAndQuicOnlyWhenGiven() {
        val access = resolve(
            "FLARE_DEV_WS_URL" to " ws://192.168.1.20:60051 ",
            "FLARE_DEV_QUIC_URL" to "quic://192.168.1.20:60052",
            "FLARE_DEV_CORE_API_URL" to "http://192.168.1.20:50050",
        )
        val endpoints = endpoints(access)
        assertEquals("ws://192.168.1.20:60051", endpoints["wsUrl"])
        assertEquals("quic://192.168.1.20:60052", endpoints["quicUrl"])
        assertEquals("http://192.168.1.20:50050", endpoints["mediaUrl"])
        assertFalse(endpoints(resolve("FLARE_DEV_QUIC_URL" to "  ")).containsKey("quicUrl"))
    }

    @Test
    fun theWholeAccessObjectIsTakenAsGivenIncludingASecondAccessPoint() {
        val access = resolve(
            "FLARE_ACCESS_JSON" to """
                {"trustMode":"development","developmentEndpoints":{"wsUrl":"ws://10.0.2.2:60051","coreApiUrl":"http://10.0.2.2:50050",
                 "accessPoints":[{"id":"dev-b","wsUrl":"ws://10.0.2.2:61051","coreApiUrl":"http://10.0.2.2:51050"}]}}
            """.trimIndent(),
            "FLARE_DEV_WS_URL" to "ws://ignored:1",
        )
        val endpoints = endpoints(access)
        assertEquals("ws://10.0.2.2:60051", endpoints["wsUrl"])
        assertEquals("dev-b", ((endpoints["accessPoints"] as List<*>)[0] as Map<*, *>)["id"])
    }

    @Test
    fun aReleaseBuildTakesOnlyItsProductionConfiguration() {
        val production = resolve(
            "FLARE_ACCESS_JSON" to """{"bootstrapId":"flare-core","trustMode":"production","trustRoots":[{"keyId":"root","publicKey":"AA"}],"seed":"{}"}""",
            allowDevelopment = false,
        )
        assertEquals("flare-core", production.access["bootstrapId"])
        assertFalse(production.developmentMode)

        assertFailsWith<AppAccess.ConfigurationError> { resolve(allowDevelopment = false) }
        assertFailsWith<AppAccess.ConfigurationError> {
            resolve("FLARE_DEV_WS_URL" to "ws://10.0.2.2:60051", allowDevelopment = false)
        }
        assertFailsWith<AppAccess.ConfigurationError> {
            resolve("FLARE_ACCESS_JSON" to """{"trustMode":"development","developmentEndpoints":{}}""", allowDevelopment = false)
        }
        assertFailsWith<AppAccess.ConfigurationError> { resolve("FLARE_ACCESS_JSON" to "not json") }
    }
}
