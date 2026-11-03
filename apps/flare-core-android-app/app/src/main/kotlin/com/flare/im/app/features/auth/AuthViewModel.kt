package com.flare.im.app.features.auth

import com.flare.im.app.core.data.AppEnvironment
import com.flare.im.app.core.domain.LoginDraft
import com.flare.im.app.core.session.AppLifecycle
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

/** 登录特性 ViewModel：登录草稿 + 校验 + submit→lifecycle.login。 */
class AuthViewModel(
    private val environment: AppEnvironment,
    private val scope: CoroutineScope,
) {
    private var lifecycle: AppLifecycle? = null
    fun bind(lifecycle: AppLifecycle) { this.lifecycle = lifecycle }

    val loginDraft: StateFlow<LoginDraft> = environment.loginDraft
    val isBusy = environment.isBusy
    val lastError = environment.lastError

    private val _validationMessage = MutableStateFlow<String?>(null)
    val validationMessage: StateFlow<String?> = _validationMessage.asStateFlow()
    fun clearValidation() { _validationMessage.value = null }

    fun updateDraft(transform: (LoginDraft) -> LoginDraft) = environment.updateLoginDraft(transform)

    fun submit() = scope.launch {
        val userId = environment.loginDraft.value.userId.trim()
        if (userId.isEmpty()) {
            _validationMessage.value = "Enter user ID"
            return@launch
        }
        if (userId != environment.loginDraft.value.userId) {
            environment.updateLoginDraft { it.copy(userId = userId) }
        }
        _validationMessage.value = null
        lifecycle?.login()
    }
}
