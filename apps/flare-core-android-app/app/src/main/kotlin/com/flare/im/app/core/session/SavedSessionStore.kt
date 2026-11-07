package com.flare.im.app.core.session

import android.content.Context
import com.flare.im.app.core.domain.LoginDraft

/**
 * 热启动会话档案：登录成功后保存，下次启动免登录直接
 * prepare(本地库) → 本地出图 → 后台 connect。
 * 只存登录表单里的身份与信任设置；连哪里由构建期的接入配置决定（[AppAccess]），不进档案。
 * SDK 托管 token 由核心签发与刷新，token 本身不持久化。
 */
class SavedSessionStore(context: Context) {
    private val prefs = context.applicationContext
        .getSharedPreferences("flare_saved_session", Context.MODE_PRIVATE)

    fun save(draft: LoginDraft) {
        prefs.edit()
            .putString(KEY_USER_ID, draft.userId)
            .putString(KEY_TLS_CA_CERT_PATH, draft.tlsCaCertPath)
            .putString(KEY_TENANT_ID, draft.tenantId)
            .apply()
    }

    fun load(): LoginDraft? {
        val userId = prefs.getString(KEY_USER_ID, null)?.trim().orEmpty()
        if (userId.isEmpty()) return null
        val defaults = LoginDraft()
        return defaults.copy(
            userId = userId,
            tlsCaCertPath = prefs.getString(KEY_TLS_CA_CERT_PATH, null) ?: defaults.tlsCaCertPath,
            tenantId = prefs.getString(KEY_TENANT_ID, null)?.takeIf { it.isNotBlank() } ?: defaults.tenantId,
        )
    }

    fun clear() {
        prefs.edit().clear().apply()
    }

    private companion object {
        const val KEY_USER_ID = "userId"
        const val KEY_TLS_CA_CERT_PATH = "tlsCaCertPath"
        const val KEY_TENANT_ID = "tenantId"
    }
}
