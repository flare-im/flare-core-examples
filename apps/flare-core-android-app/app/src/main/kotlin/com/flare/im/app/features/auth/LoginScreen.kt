package com.flare.im.app.features.auth

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.res.stringResource
import com.flare.im.app.R
import com.flare.im.app.core.FlareAppStore
import com.flare.im.ui.Button
import com.flare.im.ui.FlareAuthShell
import com.flare.im.ui.FlareControlSize
import com.flare.im.ui.FlareSizes
import com.flare.im.ui.FlareStatusTone
import com.flare.im.ui.FormField
import com.flare.im.ui.Input
import com.flare.im.ui.StatusBanner

/** Account input and SDK submission live here; the shared kit owns all login presentation. */
@Composable
fun LoginScreen(store: FlareAppStore) {
    val auth = store.authViewModel
    val draft by auth.loginDraft.collectAsState()
    val validation by auth.validationMessage.collectAsState()
    val error by auth.lastError.collectAsState()
    val busy by auth.isBusy.collectAsState()

    FlareAuthShell(
        product = stringResource(R.string.brand_name),
        tagline = stringResource(R.string.brand_tagline),
        headline = stringResource(R.string.auth_headline),
        description = stringResource(R.string.auth_description),
        eyebrow = stringResource(R.string.brand_eyebrow),
        title = stringResource(R.string.auth_welcome),
        subtitle = stringResource(R.string.auth_enter_id),
        footer = stringResource(R.string.auth_footer),
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(FlareSizes.spacingLg)) {
            FormField(
                label = stringResource(R.string.auth_user_id),
                hint = stringResource(R.string.auth_id_hint),
                error = validation,
                required = true,
            ) {
                Input(
                    value = draft.userId,
                    onValueChange = { auth.updateDraft { d -> d.copy(userId = it) }; auth.clearValidation() },
                    placeholder = stringResource(R.string.auth_user_id_placeholder),
                    disabled = busy,
                    onSubmit = { if (!busy && draft.userId.isNotBlank()) auth.submit() },
                )
            }
            error?.let { raw ->
                val message = if (LoginErrorText.isTokenRejected(raw)) stringResource(R.string.auth_token_rejected) else raw
                StatusBanner(text = message, tone = FlareStatusTone.Danger)
            }
            Button(
                label = stringResource(if (busy) R.string.auth_signing_in else R.string.auth_sign_in),
                block = true,
                size = FlareControlSize.Lg,
                loading = busy,
                disabled = busy || draft.userId.isBlank(),
                onClick = { auth.submit() },
            )
        }
    }
}
