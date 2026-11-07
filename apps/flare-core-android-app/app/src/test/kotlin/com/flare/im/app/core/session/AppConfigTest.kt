package com.flare.im.app.core.session

import com.flare.im.app.BuildConfig
import com.flare.im.app.core.domain.LoginDraft
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class AppConfigTest {
    /** Without `build` and `distribution` the core has no way to pick a release for this app. */
    @Test
    fun theAppConfigCarriesWhatTheUpdateCenterPicksBy() {
        val app = appConfig()
        assertEquals(BuildConfig.VERSION_NAME, app["version"])
        assertEquals(BuildConfig.VERSION_CODE.toLong(), app["build"])
        assertEquals(BuildConfig.FLARE_UPDATE_CHANNEL, app["channel"])
        assertEquals(BuildConfig.FLARE_DISTRIBUTION, app["distribution"])
        assertTrue((app["locale"] as String).isNotEmpty())
    }

    /** `login` and `prepare` send this text and the core initializes again from it: `app` must be in it, whole. */
    @Test
    fun theStoreConfigKeepsTheWholeApp() {
        val session = AppSession(newClient = { error("no client here") })
        val stored = JSONObject(JSONObject(session.buildSdkConfig(LoginDraft(), "/data/app")).toString())
        val app = stored.getJSONObject("app")
        assertEquals(BuildConfig.VERSION_CODE, app.getInt("build"))
        assertEquals(BuildConfig.VERSION_NAME, app.getString("version"))
        assertEquals(BuildConfig.FLARE_DISTRIBUTION, app.getString("distribution"))
    }
}
