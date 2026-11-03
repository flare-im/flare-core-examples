package com.flare.im.app

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.flare.im.app.core.FlareAppStore
import com.flare.im.app.core.session.SavedSessionStore

/**
 * 顶层 androidx ViewModel：持有组合根 [FlareAppStore]（用 `viewModelScope` 作为应用作用域），
 * 跨配置变更存活。Compose 屏经 `store.xxxViewModel` 取各特性 VM。
 */
class FlareRootViewModel(dataDir: String, savedSessionStore: SavedSessionStore?) : ViewModel() {
    val store = FlareAppStore(dataDir, viewModelScope, savedSessionStore)

    companion object {
        fun factory(dataDir: String, savedSessionStore: SavedSessionStore?): ViewModelProvider.Factory =
            object : ViewModelProvider.Factory {
                @Suppress("UNCHECKED_CAST")
                override fun <T : ViewModel> create(modelClass: Class<T>): T =
                    FlareRootViewModel(dataDir, savedSessionStore) as T
            }
    }
}
