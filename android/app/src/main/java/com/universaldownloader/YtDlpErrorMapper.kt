package com.universaldownloader

import com.yausername.youtubedl_android.YoutubeDLException
import java.io.EOFException
import java.io.FileNotFoundException
import java.io.IOException
import java.net.ConnectException
import java.net.SocketTimeoutException
import java.net.UnknownHostException
import java.util.Locale
import javax.net.ssl.SSLException

internal object YtDlpErrorMapper {
    fun userFacingMessage(error: Throwable): String {
        val all = generateSequence(error) { it.cause }.toList()
        val youtubeDl = all.filterIsInstance<YoutubeDLException>().firstOrNull()
        val io = all.filterIsInstance<IOException>().firstOrNull()

        youtubeDl?.message
            ?.let(::extractRelevantYtDlpLine)
            ?.let(::mapYtDlpLine)
            ?.let { return it }

        io?.let(::mapIoException)?.let { return it }

        val rawMessage = all.asSequence().mapNotNull { it.message?.trim() }.firstOrNull { it.isNotBlank() }
        return rawMessage?.let(::truncateForUi) ?: "Download failed."
    }

    private fun extractRelevantYtDlpLine(message: String): String {
        val lines = message.lineSequence().map { it.trim() }.filter { it.isNotBlank() }.toList()
        val errorLine = lines.lastOrNull { it.startsWith("ERROR:", ignoreCase = true) }
        return errorLine ?: lines.lastOrNull() ?: message.trim()
    }

    private fun mapYtDlpLine(line: String): String? {
        val cleaned = line.removePrefixCaseInsensitive("ERROR:").trim()
        val lowered = cleaned.lowercase(Locale.ROOT)

        return when {
            lowered.contains("unsupported url") ||
                lowered.contains("no suitable extractor") ||
                lowered.contains("no extractor") ->
                "Unsupported link or site."

            lowered.contains("no video formats found") ||
                lowered.contains("requested format is not available") ||
                lowered.contains("requested format not available") ->
                "No downloadable media found for these options. Try \"Best\" quality."

            lowered.contains("this video is not available in your country") ||
                lowered.contains("not available in your country") ||
                lowered.contains("geo") && lowered.contains("restricted") ->
                "This media is not available in your region."

            lowered.contains("age-restricted") ||
                lowered.contains("age restricted") ||
                lowered.contains("confirm your age") ->
                "This media requires age verification."

            lowered.contains("private video") ||
                lowered.contains("this video is private") ||
                lowered.contains("login required") ||
                (lowered.contains("sign in") && lowered.contains("confirm")) ->
                "This media requires sign-in."

            lowered.contains("video unavailable") ||
                lowered.contains("this video is unavailable") ||
                lowered.contains("has been removed") ->
                "This media is unavailable."

            lowered.contains("http error 429") ||
                lowered.contains("too many requests") ->
                "The site is rate limiting downloads. Try again later."

            lowered.contains("http error 403") ||
                lowered.contains("forbidden") ->
                "The site denied access to this media."

            lowered.contains("http error 404") ||
                (lowered.contains("not found") && lowered.contains("http")) ->
                "Media not found (404)."

            lowered.contains("unable to extract") ||
                (lowered.contains("extractor") && lowered.contains("failed")) ->
                "Failed to extract media info. The site may have changed — try updating yt-dlp."

            (lowered.contains("ffmpeg") && (lowered.contains("not found") || lowered.contains("error"))) ||
                (lowered.contains("postprocessing") && lowered.contains("error")) ||
                lowered.contains("conversion failed") ->
                "Post-processing failed (FFmpeg)."

            else -> cleaned.takeIf { it.isNotBlank() }?.let(::truncateForUi)
        }
    }

    private fun mapIoException(exception: IOException): String? {
        return when (exception) {
            is UnknownHostException -> "Network error: cannot resolve host."
            is ConnectException -> "Network error: cannot connect to the server."
            is SocketTimeoutException -> "Network timeout while downloading."
            is SSLException -> "Network security error (TLS/SSL)."
            is FileNotFoundException -> "File error: output path not found."
            is EOFException -> "Network connection closed unexpectedly."
            else -> {
                val message = exception.message?.lowercase(Locale.ROOT).orEmpty()
                when {
                    message.contains("no space left on device") -> "Not enough storage space to save the download."
                    message.contains("permission denied") || message.contains("eacces") -> "Storage permission denied."
                    else -> null
                }
            }
        }
    }

    private fun String.removePrefixCaseInsensitive(prefix: String): String {
        return if (startsWith(prefix, ignoreCase = true)) drop(prefix.length) else this
    }

    private fun truncateForUi(value: String): String {
        val trimmed = value.trim()
        if (trimmed.length <= 160) return trimmed
        return trimmed.take(157) + "..."
    }
}
