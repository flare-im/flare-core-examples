package com.flare.im.app.core.designsystem

import androidx.compose.ui.graphics.Color
import com.flare.im.ui.FlareColors as KitColors
import com.flare.im.ui.FlareResourceOverlay
import com.flare.im.ui.FlareResourcePack
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** The app's palette comes from whatever Kit colours are in effect, so a resource pack changes pages and Kit alike. */
class FlareAppColorsTest {
    private val overlay = FlareResourceOverlay(
        listOf(
            FlareResourcePack(
                id = "tokens",
                kind = "tokens",
                packVersion = 1,
                contentJson = """{"schema":"flare.resource.v1","kind":"tokens",""" +
                    """"colors":{"bgSecondary":"#112233","primary":"#445566"},""" +
                    """"dark":{"bgSecondary":"#778899"}}""",
            ),
        ),
    )

    @Test
    fun theBuiltInPaletteNamesTheKitTokens() {
        val colors = flareAppColors(KitColors.Light, dark = false)
        assertEquals(KitColors.Light.primary, colors.brand)
        assertEquals(KitColors.Light.bgSecondary, colors.background)
        assertEquals(KitColors.Light.bgPrimary, colors.surface)
        assertEquals(KitColors.Light.error, colors.danger)
        assertEquals(KitColors.Light.messageOutgoingForeground, colors.outgoingText)
        assertEquals(KitColors.Light.borderPrimary, colors.hairline)
        assertFalse(colors.isDark)
    }

    @Test
    fun aPackReachesThePage() {
        val colors = flareAppColors(overlay.colors(KitColors.Light, dark = false), dark = false)
        assertEquals(Color(0xFF112233), colors.background)
        assertEquals(Color(0xFF445566), colors.brand)
    }

    /** `colors` and `dark` of a pack do not reach each other. */
    @Test
    fun aPackKeepsToItsMode() {
        val colors = flareAppColors(overlay.colors(KitColors.Dark, dark = true), dark = true)
        assertEquals(Color(0xFF778899), colors.background)
        assertEquals(KitColors.Dark.primary, colors.brand)
        assertTrue(colors.isDark)
    }
}
