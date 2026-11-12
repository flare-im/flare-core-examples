package com.flare.im.app

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.flare.im.app.core.FlareAppStore
import com.flare.im.app.core.push.AppPush
import com.flare.im.app.core.session.SavedSessionStore
import com.flare.im.api.FlareImClient
import com.flare.im.update.FlareUpdateInstaller

/**
 * 顶层 androidx ViewModel：持有组合根 [FlareAppStore]（用 `viewModelScope` 作为应用作用域）。它放在
 * [FlareCoreApplication] 的进程级 ViewModelStore 里，活到进程结束：界面关掉、Activity 重建都不释放客户端。
 * Compose 屏经 `store.xxxViewModel` 取各特性 VM。
 */
class FlareRootViewModel(
    dataDir: String,
    savedSessionStore: SavedSessionStore?,
    updateInstaller: FlareUpdateInstaller,
    newClient: () -> FlareImClient,
) : ViewModel() {
    val store = FlareAppStore(dataDir, viewModelScope, savedSessionStore, updateInstaller, newClient)

    // 进程级的 ViewModelStore 从不清空，这里只在它被清空时（不会发生在应用运行期间）收尾。
    override fun onCleared() {
        store.updateCenter.dispose()
        // 这个组合根不在了：它登记的推送宿主一并撤下，之后的推送按载荷展示，直到下一个会话就绪。
        AppPush.sessionEnded(store)
    }

    companion object {
        fun factory(
            dataDir: String,
            savedSessionStore: SavedSessionStore?,
            updateInstaller: FlareUpdateInstaller,
            newClient: () -> FlareImClient,
        ): ViewModelProvider.Factory =
            object : ViewModelProvider.Factory {
                @Suppress("UNCHECKED_CAST")
                override fun <T : ViewModel> create(modelClass: Class<T>): T =
                    FlareRootViewModel(dataDir, savedSessionStore, updateInstaller, newClient) as T
            }
    }
}
