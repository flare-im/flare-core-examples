package com.flare.im.app

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.flare.im.app.core.FlareAppStore
import com.flare.im.app.core.session.SavedSessionStore
import com.flare.im.api.FlareImClient
import com.flare.im.update.FlareUpdateInstaller

/**
 * 顶层 androidx ViewModel：持有组合根 [FlareAppStore]（用 `viewModelScope` 作为应用作用域），
 * 跨配置变更存活。Compose 屏经 `store.xxxViewModel` 取各特性 VM。
 */
class FlareRootViewModel(
    dataDir: String,
    savedSessionStore: SavedSessionStore?,
    updateInstaller: FlareUpdateInstaller,
    newClient: () -> FlareImClient,
) : ViewModel() {
    val store = FlareAppStore(dataDir, viewModelScope, savedSessionStore, updateInstaller, newClient)

    override fun onCleared() {
        store.updateCenter.dispose()
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
