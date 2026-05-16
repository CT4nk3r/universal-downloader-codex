package com.universaldownloader

internal object ProgressLineSanitizer {
    fun sanitize(raw: String, maxLen: Int = 72): String {
        val trimmed = raw.trim()
        if (trimmed.isBlank()) return ""

        // yt-dlp often prefixes messages with one or more tags like "[youtube]" or "[jsc:quickjs]".
        val noTags = trimmed.replace(Regex("^(?:\\s*\\[[^\\]]+\\]\\s*)+"), "")
        val singleLine = noTags.replace(Regex("\\s+"), " ").trim()
        if (singleLine.length <= maxLen) return singleLine
        return singleLine.take(maxLen - 3) + "..."
    }
}

