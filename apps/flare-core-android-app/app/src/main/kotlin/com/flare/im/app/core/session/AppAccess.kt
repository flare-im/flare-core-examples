package com.flare.im.app.core.session

import com.flare.im.app.BuildConfig
import org.json.JSONArray
import org.json.JSONObject

/**
 * The access configuration this build hands the core SDK (`sdkConfig.access`). Line choice, protocol racing and
 * reconnecting are the SDK's, and so is where connect tokens are issued (the Core API of the access point it is on);
 * the app only passes this on. The values come from the build (Gradle property or environment variable, see
 * app/build.gradle.kts).
 */
data class AppAccess(
    /** `sdkConfig.access`. */
    val access: Map<String, Any?>,
) {
    /** Whether the endpoints come from development configuration. */
    val developmentMode: Boolean
        get() = access["trustMode"] == "development" || access.containsKey("developmentEndpoints")

    /**
     * The local stack seen from the Android emulator (10.0.2.2 is the host's loopback). Ports:
     * IM `flare-core-server/config/services/access-gateway.toml` (WebSocket 60051, QUIC 60052), Core HTTP and media
     * `flare-core-server/config/services/api-gateway.toml` (50050).
     */
    object LocalDevelopment {
        const val WS = "ws://10.0.2.2:60051"
        const val CORE_API = "http://10.0.2.2:50050"
    }

    /** No usable access configuration: a release build needs its production one and never falls back to development. */
    class ConfigurationError(message: String) : IllegalStateException(message)

    companion object {
        /**
         * - `FLARE_ACCESS_JSON`: the whole `access` object as given (production: `bootstrapId`, `trustRoots`, `seed`,
         *   `trustMode: production`; or a complete development one, for example with `accessPoints` for a second entry).
         * - Otherwise, debug builds only ([allowDevelopment]), development endpoints from `FLARE_DEV_WS_URL`,
         *   `FLARE_DEV_QUIC_URL` (QUIC only when given), `FLARE_DEV_CORE_API_URL` and `FLARE_DEV_MEDIA_URL` (Core HTTP
         *   when missing), each defaulting to [LocalDevelopment].
         *
         * A release build without `FLARE_ACCESS_JSON`, or with a development one, throws [ConfigurationError].
         */
        fun resolve(lookup: (String) -> String?, allowDevelopment: Boolean): AppAccess {
            fun value(name: String) = lookup(name)?.trim()?.takeIf { it.isNotEmpty() }
            val raw = value("FLARE_ACCESS_JSON")
            val access: Map<String, Any?> = if (raw != null) {
                val parsed = runCatching { JSONObject(raw) }.getOrNull()
                    ?: throw ConfigurationError("FLARE_ACCESS_JSON is not a JSON object")
                val map = parsed.toMap()
                if (!allowDevelopment && (map["trustMode"] == "development" || map.containsKey("developmentEndpoints"))) {
                    throw ConfigurationError("a release build cannot use development access (FLARE_ACCESS_JSON)")
                }
                map
            } else {
                if (!allowDevelopment) {
                    throw ConfigurationError("a release build needs its production access configuration in FLARE_ACCESS_JSON")
                }
                val coreApi = value("FLARE_DEV_CORE_API_URL") ?: LocalDevelopment.CORE_API
                val endpoints = buildMap<String, Any?> {
                    put("wsUrl", value("FLARE_DEV_WS_URL") ?: LocalDevelopment.WS)
                    value("FLARE_DEV_QUIC_URL")?.let { put("quicUrl", it) }
                    put("coreApiUrl", coreApi)
                    put("mediaUrl", value("FLARE_DEV_MEDIA_URL") ?: coreApi)
                }
                mapOf("trustMode" to "development", "developmentEndpoints" to endpoints)
            }
            return AppAccess(access)
        }

        /** The build's settings by name (BuildConfig). */
        private fun buildSetting(name: String): String? = when (name) {
            "FLARE_ACCESS_JSON" -> BuildConfig.FLARE_ACCESS_JSON
            "FLARE_DEV_WS_URL" -> BuildConfig.FLARE_DEV_WS_URL
            "FLARE_DEV_QUIC_URL" -> BuildConfig.FLARE_DEV_QUIC_URL
            "FLARE_DEV_CORE_API_URL" -> BuildConfig.FLARE_DEV_CORE_API_URL
            "FLARE_DEV_MEDIA_URL" -> BuildConfig.FLARE_DEV_MEDIA_URL
            else -> null
        }

        /** This build's configuration, read once. A build without a usable one stops here with the reason. */
        val current: AppAccess by lazy { resolve(::buildSetting, allowDevelopment = BuildConfig.DEBUG) }
    }
}

private fun JSONObject.toMap(): Map<String, Any?> = keys().asSequence().associateWith { unwrap(opt(it)) }

private fun JSONArray.toList(): List<Any?> = (0 until length()).map { unwrap(opt(it)) }

private fun unwrap(value: Any?): Any? = when (value) {
    is JSONObject -> value.toMap()
    is JSONArray -> value.toList()
    JSONObject.NULL -> null
    else -> value
}
