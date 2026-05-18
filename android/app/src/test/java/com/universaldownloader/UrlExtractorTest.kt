package com.universaldownloader

import android.content.Intent
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

@RunWith(RobolectricTestRunner::class)
class UrlExtractorTest {
    @Test
    fun firstUrl_plainText_returnsFirstHttpLink() {
        assertEquals(
            "http://example.com/video",
            UrlExtractor.firstUrl("watch this http://example.com/video and https://example.com/second")
        )
    }

    @Test
    fun firstUrl_plainText_returnsFirstHttpsLink() {
        assertEquals(
            "https://example.com/video",
            UrlExtractor.firstUrl("watch this https://example.com/video")
        )
    }

    @Test
    fun firstUrl_trimsTrailingPeriod() {
        assertEquals("https://example.com/video", UrlExtractor.firstUrl("Saved https://example.com/video."))
    }

    @Test
    fun firstUrl_trimsTrailingComma() {
        assertEquals("https://example.com/video", UrlExtractor.firstUrl("Saved https://example.com/video, thanks"))
    }

    @Test
    fun firstUrl_trimsTrailingClosingParen() {
        assertEquals("https://example.com/video", UrlExtractor.firstUrl("(https://example.com/video)"))
    }

    @Test
    fun firstUrl_noUrl_returnsNull() {
        assertNull(UrlExtractor.firstUrl("no link here"))
    }

    @Test
    fun isSupportedUrl_acceptsHttpsUppercase() {
        assertTrue(UrlExtractor.isSupportedUrl("HTTPS://EXAMPLE.COM/VIDEO"))
    }

    @Test
    fun isSupportedUrl_acceptsHttp() {
        assertTrue(UrlExtractor.isSupportedUrl("http://example.com/video"))
    }

    @Test
    fun isSupportedUrl_rejectsFtp() {
        assertFalse(UrlExtractor.isSupportedUrl("ftp://example.com/video"))
    }

    @Test
    fun isSupportedUrl_rejectsMissingScheme() {
        assertFalse(UrlExtractor.isSupportedUrl("example.com/video"))
    }

    @Test
    fun fromShareIntent_extractsSharedTextUrl() {
        val intent = Intent(Intent.ACTION_SEND)
            .setType("text/plain")
            .putExtra(Intent.EXTRA_TEXT, "Open https://example.com/video")

        assertEquals("https://example.com/video", UrlExtractor.fromShareIntent(intent))
    }

    @Test
    fun fromShareIntent_wrongAction_returnsNull() {
        val intent = Intent(Intent.ACTION_VIEW)
            .setType("text/plain")
            .putExtra(Intent.EXTRA_TEXT, "Open https://example.com/video")

        assertNull(UrlExtractor.fromShareIntent(intent))
    }

    @Test
    fun fromShareIntent_wrongType_returnsNull() {
        val intent = Intent(Intent.ACTION_SEND)
            .setType("image/png")
            .putExtra(Intent.EXTRA_TEXT, "Open https://example.com/video")

        assertNull(UrlExtractor.fromShareIntent(intent))
    }
}
