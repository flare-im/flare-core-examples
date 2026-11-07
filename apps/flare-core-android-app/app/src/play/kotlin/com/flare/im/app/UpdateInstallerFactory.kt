package com.flare.im.app

import android.content.Context
import com.flare.im.update.FlareResumedActivity
import com.flare.im.update.FlareUpdateInstaller
import com.flare.im.update.play.FlarePlayUpdateInstaller

/** Play distribution: Play In-App Updates, whose dialog runs on the activity on screen. */
internal fun updateInstaller(context: Context): FlareUpdateInstaller =
    FlarePlayUpdateInstaller(context, { FlareResumedActivity.current })
