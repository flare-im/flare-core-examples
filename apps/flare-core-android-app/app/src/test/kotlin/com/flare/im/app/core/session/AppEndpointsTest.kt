package com.flare.im.app.core.session

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith

class AppEndpointsTest {
    @Test fun localDefaultsUseTheEmulatorHost() {
        val result = AppEndpoints.resolve({ null }, allowDevelopment = true)
        assertEquals("development", result.environment)
        assertEquals("http://10.0.2.2:50050", result.endpoints["baseUrl"])
        assertEquals("ws://10.0.2.2:60051", result.endpoints["websocketUrl"])
    }

    @Test fun aReleaseRequiresEndpoints() {
        assertFailsWith<AppEndpoints.ConfigurationError> {
            AppEndpoints.resolve({ null }, allowDevelopment = false)
        }
    }
}
