package com.flare.im.app

import android.content.Context
import com.flare.im.update.FlareUpdateInstaller

/** Direct distribution: update packages through a system install session, which only this flavor's manifest allows. */
internal fun updateInstaller(context: Context): FlareUpdateInstaller = FlareUpdateInstaller.system(context)
