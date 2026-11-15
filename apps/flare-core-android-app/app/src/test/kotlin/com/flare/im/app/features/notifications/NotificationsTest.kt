package com.flare.im.app.features.notifications

import com.flare.im.push.FlarePushBackgroundDelivery
import com.flare.im.push.FlarePushPermissionStatus
import com.flare.im.ui.FlareBackgroundDelivery
import com.flare.im.ui.FlareNotificationStatus
import com.flare.im.ui.FlarePermissionState
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/** 模块的权限与电池设置在 kit 组件里的说法，以及首次引导什么时候出现。 */
class NotificationsTest {
    @Test
    fun softAskInvitesWhileTheSystemDialogCanStillShow() {
        assertEquals(
            FlarePermissionState.Undetermined,
            notificationSoftAskState(FlarePushPermissionStatus.NOT_DETERMINED, canRequest = true, answered = false),
        )
        // 拒绝过一次、系统还肯再弹：仍然是请求，不是去设置。
        assertEquals(
            FlarePermissionState.Undetermined,
            notificationSoftAskState(FlarePushPermissionStatus.DENIED, canRequest = true, answered = false),
        )
    }

    @Test
    fun softAskPointsToSettingsOnceTheDialogCannotShow() {
        assertEquals(
            FlarePermissionState.Denied,
            notificationSoftAskState(FlarePushPermissionStatus.DENIED, canRequest = false, answered = false),
        )
    }

    @Test
    fun softAskStaysAwayWhenAnsweredUnreadOrOn() {
        assertNull(notificationSoftAskState(FlarePushPermissionStatus.NOT_DETERMINED, canRequest = true, answered = true))
        assertNull(notificationSoftAskState(FlarePushPermissionStatus.DENIED, canRequest = false, answered = true))
        assertNull(notificationSoftAskState(null, canRequest = true, answered = false))
        assertNull(notificationSoftAskState(FlarePushPermissionStatus.GRANTED, canRequest = false, answered = false))
    }

    @Test
    fun statusAndBackgroundMapOneToOne() {
        assertEquals(FlareNotificationStatus.On, notificationStatus(FlarePushPermissionStatus.GRANTED))
        assertEquals(FlareNotificationStatus.Off, notificationStatus(FlarePushPermissionStatus.DENIED))
        assertEquals(FlareNotificationStatus.NotTurnedOn, notificationStatus(FlarePushPermissionStatus.NOT_DETERMINED))
        assertEquals(FlareBackgroundDelivery.Unrestricted, backgroundDelivery(FlarePushBackgroundDelivery.UNRESTRICTED))
        assertEquals(FlareBackgroundDelivery.Optimized, backgroundDelivery(FlarePushBackgroundDelivery.OPTIMIZED))
        assertEquals(FlareBackgroundDelivery.Restricted, backgroundDelivery(FlarePushBackgroundDelivery.RESTRICTED))
    }
}
