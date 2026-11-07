package com.flare.im.app.core.session

import com.flare.im.app.BuildConfig
import java.util.Locale

/**
 * The init config's `app`, whole. `login` and `prepare` hand the core `storeConfigJson` and it initializes again from
 * that alone, so what the bridge fills in at `init` would be gone after sign-in, and the update center with it.
 */
internal fun appConfig(): Map<String, Any> = mapOf(
    "version" to BuildConfig.VERSION_NAME,
    "build" to BuildConfig.VERSION_CODE.toLong(),
    "channel" to BuildConfig.FLARE_UPDATE_CHANNEL,
    "distribution" to BuildConfig.FLARE_DISTRIBUTION,
    "locale" to Locale.getDefault().toLanguageTag(),
)
