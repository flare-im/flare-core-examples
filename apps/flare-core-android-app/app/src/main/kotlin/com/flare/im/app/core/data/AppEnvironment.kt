package com.flare.im.app.core.data

import com.flare.im.app.core.domain.AppSection
import com.flare.im.app.core.domain.ConversationFilter
import com.flare.im.app.core.domain.LabResult
import com.flare.im.app.core.domain.LoginDraft
import com.flare.im.app.core.domain.RuntimeStatus
import com.flare.im.app.core.domain.ThemeChoice
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update

/**
 * 共享 UI 状态：选择态 / 过滤 / 区段 / 主题 / 忙碌 / 运行时状态 /
 * 错误 / Lab 结果 + 登录草稿。`run()` 统一包裹 busy + error + lab 日志。
 */
class AppEnvironment {
    private val _selectedConversationId = MutableStateFlow<String?>(null)
    val selectedConversationId: StateFlow<String?> = _selectedConversationId.asStateFlow()

    private val _filter = MutableStateFlow(ConversationFilter.All)
    val filter: StateFlow<ConversationFilter> = _filter.asStateFlow()

    private val _section = MutableStateFlow(AppSection.Conversations)
    val section: StateFlow<AppSection> = _section.asStateFlow()

    private val _theme = MutableStateFlow(ThemeChoice.System)
    val theme: StateFlow<ThemeChoice> = _theme.asStateFlow()

    private val _isBusy = MutableStateFlow(false)
    val isBusy: StateFlow<Boolean> = _isBusy.asStateFlow()

    private val _runtimeStatus = MutableStateFlow<RuntimeStatus>(RuntimeStatus.Idle)
    val runtimeStatus: StateFlow<RuntimeStatus> = _runtimeStatus.asStateFlow()

    private val _lastError = MutableStateFlow<String?>(null)
    val lastError: StateFlow<String?> = _lastError.asStateFlow()

    private val _labResults = MutableStateFlow<List<LabResult>>(emptyList())
    val labResults: StateFlow<List<LabResult>> = _labResults.asStateFlow()

    private val _loginDraft = MutableStateFlow(LoginDraft())
    val loginDraft: StateFlow<LoginDraft> = _loginDraft.asStateFlow()

    fun setSelectedConversationId(value: String?) { _selectedConversationId.value = value }
    fun setFilter(value: ConversationFilter) { _filter.value = value }
    fun setSection(value: AppSection) { _section.value = value }
    fun setTheme(value: ThemeChoice) { _theme.value = value }
    fun setRuntimeStatus(value: RuntimeStatus) { _runtimeStatus.value = value }
    fun updateLoginDraft(transform: (LoginDraft) -> LoginDraft) { _loginDraft.update(transform) }

    fun appendLab(operation: String, status: String, detail: String) {
        // 用序号而不是毫秒时间戳区分记录：同一毫秒记下两条（嵌套的 run）时，SDK 状态页的
        // LazyColumn key 重复，一打开就崩。序号在 update 里按上一条递增，并发写入也不会重号。
        _labResults.update { (it + LabResult((it.lastOrNull()?.id ?: 0L) + 1, operation, status, detail)).takeLast(200) }
    }

    /** 统一执行包裹：busy 置位 + 清错 + 失败记 lastError/lab。 */
    suspend fun run(operation: String, showBusy: Boolean = true, body: suspend () -> Unit) {
        if (showBusy) _isBusy.value = true
        _lastError.value = null
        try {
            body()
            appendLab(operation, "ok", "")
        } catch (error: Throwable) {
            val message = error.message ?: error.toString()
            _lastError.value = message
            appendLab(operation, "error", message)
        } finally {
            if (showBusy) _isBusy.value = false
        }
    }
}
