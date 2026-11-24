package com.flare.im.app.core.session

import com.flare.im.app.BuildConfig
import org.json.JSONObject

data class AppEndpoints(
    val endpoints: Map<String, Any?>,
    val environment: String = "production",
) {
    class ConfigurationError(message: String) : IllegalStateException(message)

    companion object {
        fun resolve(lookup: (String) -> String?, allowDevelopment: Boolean): AppEndpoints {
            fun value(name: String) = lookup(name)?.trim()?.takeIf { it.isNotEmpty() }
            val environment = if (allowDevelopment) "development" else "production"
            val supplied = value("FLARE_CORE_ENDPOINTS_JSON")
            if (supplied != null) {
                val json = runCatching { JSONObject(supplied) }.getOrElse {
                    throw ConfigurationError("FLARE_CORE_ENDPOINTS_JSON must be an object")
                }
                val endpoints = listOf("baseUrl", "websocketUrl", "quicUrl", "mediaBaseUrl")
                    .mapNotNull { key -> (json.opt(key) as? String)?.trim()?.takeIf(String::isNotEmpty)?.let { key to it } }
                    .toMap()
                if (!endpoints.keys.containsAll(listOf("baseUrl", "websocketUrl"))) {
                    throw ConfigurationError("baseUrl and websocketUrl are required")
                }
                return AppEndpoints(endpoints, environment)
            }
            if (!allowDevelopment) throw ConfigurationError("Configure FLARE_CORE_ENDPOINTS_JSON")
            return AppEndpoints(
                buildMap {
                    put("baseUrl", value("FLARE_DEV_CORE_API_URL") ?: "http://10.0.2.2:50050")
                    put("websocketUrl", value("FLARE_DEV_WS_URL") ?: "ws://10.0.2.2:60051")
                    value("FLARE_DEV_QUIC_URL")?.let { put("quicUrl", it) }
                    value("FLARE_DEV_MEDIA_URL")?.let { put("mediaBaseUrl", it) }
                },
                environment,
            )
        }

        /** The build's settings by name (BuildConfig). */
        private fun buildSetting(name: String): String? = when (name) {
            "FLARE_CORE_ENDPOINTS_JSON" -> BuildConfig.FLARE_CORE_ENDPOINTS_JSON
            "FLARE_DEV_WS_URL" -> BuildConfig.FLARE_DEV_WS_URL
            "FLARE_DEV_QUIC_URL" -> BuildConfig.FLARE_DEV_QUIC_URL
            "FLARE_DEV_CORE_API_URL" -> BuildConfig.FLARE_DEV_CORE_API_URL
            "FLARE_DEV_MEDIA_URL" -> BuildConfig.FLARE_DEV_MEDIA_URL
            else -> null
        }

        /** This build's configuration, read once. A build without a usable one stops here with the reason. */
        val current: AppEndpoints by lazy { resolve(::buildSetting, allowDevelopment = BuildConfig.DEBUG) }
    }
}
