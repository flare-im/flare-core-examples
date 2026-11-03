package com.flare.im.app.features.shell

import androidx.compose.material3.MaterialTheme

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.flare.im.app.core.designsystem.FlareTheme
import com.flare.im.app.core.designsystem.color
import com.flare.im.app.core.domain.RuntimeStatus

/** 跨屏共享的小型 UI 原子（internal：同 module 各 feature 包可用）。 */
@Composable
internal fun SectionTitle(text: String) {
    Text(text, style = MaterialTheme.typography.titleLarge, color = FlareTheme.colors.textPrimary, modifier = Modifier.padding(bottom = FlareTheme.tokens.sm))
}

@Composable
internal fun EmptyState(title: String, message: String) {
    Column(Modifier.fillMaxSize(), verticalArrangement = Arrangement.Center, horizontalAlignment = Alignment.CenterHorizontally) {
        com.flare.im.ui.EmptyState(title = title, description = message)
    }
}

@Composable
internal fun StatusDot(status: RuntimeStatus) {
    Box(Modifier.size(8.dp).clip(CircleShape).background(FlareTheme.colors.color(status.tone)))
}

@Composable
internal fun statusLabel(status: RuntimeStatus): String = stringResource(status.productLabelRes)
