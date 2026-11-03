package com.flare.im.app.core.platform

import com.flare.im.ui.FlareCapabilitySupport
import com.flare.im.ui.FlarePickedFile
import com.flare.im.ui.FlarePlatformErrorCode
import com.flare.im.ui.FlarePlatformResult
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/**
 * Layer 5（spec/platform-contract.json）宿主侧：这台宿主声明的能力必须等于它真正实现的操作，
 * 且「用户取消 / 空选择」只能是 CANCELLED，不能冒充空成功。
 */
class AndroidPlatformAdapterTest {

    @Test
    fun `declares exactly the pickers it implements`() {
        val capabilities = androidHostCapabilities(widthDp = 411)
        assertEquals(FlareCapabilitySupport.Supported, capabilities.filePicker)
        assertEquals(FlareCapabilitySupport.Supported, capabilities.imagePicker)
        // 未实现的操作保持 unsupported：宿主不声明自己做不到的事。
        assertEquals(FlareCapabilitySupport.Unsupported, capabilities.share)
        assertTrue(capabilities.nativeBack)
        assertTrue(capabilities.bottomSheet, "411dp 手机宽度应走 bottom sheet")
    }

    @Test
    fun `tablet width turns off the bottom sheet form factor`() {
        assertEquals(false, androidHostCapabilities(widthDp = 840).bottomSheet)
    }

    @Test
    fun `empty selection is cancelled, never an empty success`() {
        val result = settlePickedUris(emptyList(), multiple = true)
        assertEquals(FlarePlatformErrorCode.CANCELLED, result.code)
    }

    @Test
    fun `single select keeps only the first file`() {
        val files = listOf(file("a.pdf"), file("b.pdf"))
        val single = settlePickedUris(files, multiple = false)
        assertTrue(single is FlarePlatformResult.Ok)
        assertEquals(listOf("a.pdf"), single.value.map { it.name })

        val many = settlePickedUris(files, multiple = true)
        assertTrue(many is FlarePlatformResult.Ok)
        assertEquals(listOf("a.pdf", "b.pdf"), many.value.map { it.name })
    }

    private fun file(name: String) = FlarePickedFile(name = name, uri = "content://docs/$name")
}
