package com.flare.im.app.core.session

import android.content.Context
import com.flare.im.app.core.domain.LoginDraft
import com.flare.im.app.core.domain.LoginTransportMode

/**
 * 热启动会话档案：登录成功后保存，下次启动免登录直接
 * prepare(本地库) → 本地出图 → 后台 connect。
 * dev token 由本地 secret 重签，token 本身无需持久化；但**签名密钥要存**——
 * 它现在是运行时输入的（不再打进安装包），不存的话每次重启都得重填。
 */
class SavedSessionStore(context: Context) {
    private val prefs = context.applicationContext
        .getSharedPreferences("flare_saved_session", Context.MODE_PRIVATE)

    fun save(draft: LoginDraft) {
        prefs.edit()
            .putString(KEY_USER_ID, draft.userId)
            .putString(KEY_TRANSPORT_MODE, draft.transportMode.name)
            .putString(KEY_WS_URL, draft.wsUrl)
            .putString(KEY_QUIC_URL, draft.quicUrl)
            .putString(KEY_TLS_CA_CERT_PATH, draft.tlsCaCertPath)
            .putString(KEY_TENANT_ID, draft.tenantId)
            .putString(KEY_HTTP_URL, draft.httpUrl)
            .apply()
    }

    fun load(): LoginDraft? {
        val userId = prefs.getString(KEY_USER_ID, null)?.trim().orEmpty()
        if (userId.isEmpty()) return null
        val defaults = LoginDraft()
        val transportMode = prefs.getString(KEY_TRANSPORT_MODE, null)
            ?.let { name -> LoginTransportMode.entries.firstOrNull { it.name == name } }
            ?: defaults.transportMode
        return defaults.copy(
            userId = userId,
            transportMode = transportMode,
            wsUrl = prefs.getString(KEY_WS_URL, null)?.takeIf { it.isNotBlank() } ?: defaults.wsUrl,
            quicUrl = prefs.getString(KEY_QUIC_URL, null)?.takeIf { it.isNotBlank() } ?: defaults.quicUrl,
            tlsCaCertPath = prefs.getString(KEY_TLS_CA_CERT_PATH, null) ?: defaults.tlsCaCertPath,
            tenantId = prefs.getString(KEY_TENANT_ID, null)?.takeIf { it.isNotBlank() } ?: defaults.tenantId,
            httpUrl = prefs.getString(KEY_HTTP_URL, null)?.takeIf { it.isNotBlank() } ?: defaults.httpUrl,
        )
    }

    fun clear() {
        prefs.edit().clear().apply()
    }

    private companion object {
        const val KEY_USER_ID = "userId"
        const val KEY_HTTP_URL = "httpUrl"
        const val KEY_TRANSPORT_MODE = "transportMode"
        const val KEY_WS_URL = "wsUrl"
        const val KEY_QUIC_URL = "quicUrl"
        const val KEY_TLS_CA_CERT_PATH = "tlsCaCertPath"
        const val KEY_TENANT_ID = "tenantId"
    }
}
