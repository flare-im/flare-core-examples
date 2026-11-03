package com.flare.im.app.core.session

/**
 * 跨切面会话生命周期（由组合根实现）。特性 ViewModel 经此触发登录/登出/释放，
 * 不直接依赖组合根。
 */
interface AppLifecycle {
    suspend fun login()
    suspend fun logout()
    suspend fun dispose()
}
