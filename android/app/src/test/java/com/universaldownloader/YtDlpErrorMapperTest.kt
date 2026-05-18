package com.universaldownloader

import com.yausername.youtubedl_android.YoutubeDLException
import java.io.EOFException
import java.io.FileNotFoundException
import java.io.IOException
import java.net.ConnectException
import java.net.SocketTimeoutException
import java.net.UnknownHostException
import javax.net.ssl.SSLException
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class YtDlpErrorMapperTest {
    @Test
    fun unsupportedUrlMapsToFriendlyMessage() {
        assertMaps("ERROR: Unsupported URL: https://example.com", "Unsupported link or site.")
    }

    @Test
    fun missingFormatMapsToOptionsHint() {
        assertMaps(
            "ERROR: requested format is not available",
            "No downloadable media found for these options. Try \"Original\" quality."
        )
    }

    @Test
    fun geoRestrictionMapsToRegionMessage() {
        assertMaps("ERROR: This video is not available in your country", "This media is not available in your region.")
    }

    @Test
    fun ageRestrictionMapsToVerificationMessage() {
        assertMaps("ERROR: Sign in to confirm your age", "This media requires age verification.")
    }

    @Test
    fun loginRequiredMapsToSignInMessage() {
        assertMaps("ERROR: login required to view", "This media requires sign-in.")
    }

    @Test
    fun unavailableMapsToUnavailableMessage() {
        assertMaps("ERROR: this video is unavailable", "This media is unavailable.")
    }

    @Test
    fun rateLimitMapsToRetryMessage() {
        assertMaps("ERROR: HTTP Error 429: Too Many Requests", "The site is rate limiting downloads. Try again later.")
    }

    @Test
    fun forbiddenMapsToAccessDeniedMessage() {
        assertMaps("ERROR: HTTP Error 403: Forbidden", "The site denied access to this media.")
    }

    @Test
    fun notFoundMapsTo404Message() {
        assertMaps("ERROR: HTTP Error 404: Not Found", "Media not found (404).")
    }

    @Test
    fun extractorFailureMapsToUpdateHint() {
        assertMaps(
            "ERROR: Unable to extract uploader id",
            "Failed to extract media info. The site may have changed - try updating yt-dlp."
        )
    }

    @Test
    fun ffmpegFailureMapsToPostProcessingMessage() {
        assertMaps("ERROR: ffmpeg not found", "Post-processing failed (FFmpeg).")
    }

    @Test
    fun unknownYtDlpLineIsTruncatedForUi() {
        val message = "ERROR: " + "a".repeat(200)

        val mapped = YtDlpErrorMapper.userFacingMessage(YoutubeDLException(message))

        assertEquals(160, mapped.length)
        assertTrue(mapped.endsWith("..."))
    }

    @Test
    fun lastErrorLineIsPreferredFromMultilineYtDlpMessage() {
        assertMaps(
            """
            [download] retrying
            ERROR: HTTP Error 403: Forbidden
            """.trimIndent(),
            "The site denied access to this media."
        )
    }

    @Test
    fun unknownHostMapsToNetworkMessage() {
        assertEquals("Network error: cannot resolve host.", YtDlpErrorMapper.userFacingMessage(UnknownHostException()))
    }

    @Test
    fun connectExceptionMapsToNetworkMessage() {
        assertEquals("Network error: cannot connect to the server.", YtDlpErrorMapper.userFacingMessage(ConnectException()))
    }

    @Test
    fun timeoutMapsToTimeoutMessage() {
        assertEquals("Network timeout while downloading.", YtDlpErrorMapper.userFacingMessage(SocketTimeoutException()))
    }

    @Test
    fun sslMapsToSecurityMessage() {
        assertEquals("Network security error (TLS/SSL).", YtDlpErrorMapper.userFacingMessage(SSLException("bad cert")))
    }

    @Test
    fun fileNotFoundMapsToOutputPathMessage() {
        assertEquals("File error: output path not found.", YtDlpErrorMapper.userFacingMessage(FileNotFoundException()))
    }

    @Test
    fun eofMapsToConnectionClosedMessage() {
        assertEquals("Network connection closed unexpectedly.", YtDlpErrorMapper.userFacingMessage(EOFException()))
    }

    @Test
    fun noSpaceMessageMapsToStorageMessage() {
        assertEquals(
            "Not enough storage space to save the download.",
            YtDlpErrorMapper.userFacingMessage(IOException("No space left on device"))
        )
    }

    @Test
    fun permissionDeniedMessageMapsToStoragePermissionMessage() {
        assertEquals(
            "Storage permission denied.",
            YtDlpErrorMapper.userFacingMessage(IOException("EACCES permission denied"))
        )
    }

    @Test
    fun genericIOExceptionFallsBackToRawCauseMessage() {
        assertEquals("disk woke up cranky", YtDlpErrorMapper.userFacingMessage(IOException("disk woke up cranky")))
    }

    @Test
    fun nestedIOExceptionIsMappedFromCauseChain() {
        assertEquals(
            "Network timeout while downloading.",
            YtDlpErrorMapper.userFacingMessage(RuntimeException("wrapper", SocketTimeoutException()))
        )
    }

    @Test
    fun blankUnknownExceptionFallsBackToGenericFailure() {
        assertEquals("Download failed.", YtDlpErrorMapper.userFacingMessage(RuntimeException()))
    }

    private fun assertMaps(raw: String, expected: String) {
        assertEquals(expected, YtDlpErrorMapper.userFacingMessage(YoutubeDLException(raw)))
    }
}
