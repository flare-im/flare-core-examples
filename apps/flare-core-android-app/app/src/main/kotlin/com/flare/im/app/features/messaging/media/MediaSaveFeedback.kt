package com.flare.im.app.features.messaging.media

import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.platform.LocalContext
import com.flare.im.app.R
import com.flare.im.app.core.domain.AppMessage
import com.flare.im.app.core.domain.isUnwritableFolderError
import com.flare.im.app.core.domain.shortDownloadLocation
import com.flare.im.app.features.messaging.MessagingViewModel
import com.flare.im.ui.FlareStatusTone
import com.flare.im.ui.LocalFlareToast
import com.flare.im.ui.ToastVariant

/**
 * 「保存到本机」的界面一半：点下去就说「正在保存…」，核心保存完说存到了哪里（`Download/flare`），
 * 没存成说「没有保存成功，请重试」——核心拒绝的是文件夹本身时，说那个文件夹不能写入。
 * 保存本身在 [MessagingViewModel.saveMedia]（核心 `media.download_to_user_directory`）；
 * 这里曾经什么都不说：失败只进了 lastError 和 SDK 实验室日志，用户点了保存看不到任何反应。
 */
@Composable
fun rememberMediaSaver(vm: MessagingViewModel): (AppMessage) -> Unit {
    val toast = LocalFlareToast.current
    val context = LocalContext.current
    return remember(vm, toast, context) {
        { message: AppMessage ->
            // The kit toast state takes calls from any thread and outlives this row, so the answer is shown even
            // when the row has scrolled away by the time the core finishes.
            val dismissSaving = toast.show(context.getString(R.string.media_saving), variant = ToastVariant.Loading, durationMs = 0)
            val started = vm.saveMedia(message) { result ->
                dismissSaving()
                result.onSuccess { saved ->
                    toast.show(
                        context.getString(R.string.media_saved_to, shortDownloadLocation(saved.directory)),
                        tone = FlareStatusTone.Success,
                    )
                }.onFailure { error ->
                    toast.show(
                        context.getString(if (isUnwritableFolderError(error)) R.string.settings_download_location_unwritable else R.string.media_save_failed),
                        tone = FlareStatusTone.Danger,
                    )
                }
            }
            // A second tap while the same message is being saved does nothing: the first save answers.
            if (!started) dismissSaving()
        }
    }
}
