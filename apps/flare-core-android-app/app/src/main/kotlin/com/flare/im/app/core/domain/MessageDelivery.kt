package com.flare.im.app.core.domain

/**
 * 自己发出的消息该显示什么送达状态。
 *
 * **真源是核心 `domain::message_delivery_state`**；这里是它在 Android 侧的实现，
 * 由 `sdk-spec/message-action-vectors.json` 的 `deliveryState` 逐位钉住
 * （见 `MessageDeliveryVectorsTest`）。
 *
 * 视觉约定与 iOS `DeliveryStatusGlyph` / kit `messageStateToNumber` 一致：
 * SENT(2) 与 PERSISTED(3) **都是单勾** —— 对用户而言"服务端收下了"和"已落库"
 * 没有区别，不值得用两个符号去区分。
 */
enum class MessageDeliveryState { NONE, SENDING, FAILED, DELIVERED, READ }

object MessageDelivery {
    private const val STATUS_FAILED = 4
    private const val STATUS_RECALLED = 5
    private const val STATUS_DELETED = 6

    fun state(
        isSelf: Boolean,
        status: Int,
        isRead: Boolean,
        isPending: Boolean,
        isFailed: Boolean,
    ): MessageDeliveryState {
        // 对方发来的消息不显示送达状态——那是发送方才关心的事。
        if (!isSelf) return MessageDeliveryState.NONE
        // 撤回/删除是终态，由占位气泡接管展示。
        if (status == STATUS_RECALLED || status == STATUS_DELETED) return MessageDeliveryState.NONE
        if (isFailed || status == STATUS_FAILED) return MessageDeliveryState.FAILED
        if (isPending) return MessageDeliveryState.SENDING
        if (isRead) return MessageDeliveryState.READ
        return MessageDeliveryState.DELIVERED
    }
}
