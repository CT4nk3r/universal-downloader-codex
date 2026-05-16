package com.universaldownloader

import android.content.Intent
import java.util.regex.Pattern

object UrlExtractor {
    private val urlPattern: Pattern = Pattern.compile(
        "(https?://[^\\s]+)",
        Pattern.CASE_INSENSITIVE
    )

    fun fromShareIntent(intent: Intent): String? {
        if (intent.action != Intent.ACTION_SEND || intent.type != "text/plain") return null
        val sharedText = intent.getStringExtra(Intent.EXTRA_TEXT).orEmpty()
        return firstUrl(sharedText)
    }

    fun firstUrl(text: String): String? {
        val matcher = urlPattern.matcher(text)
        return if (matcher.find()) matcher.group(1)?.trimEnd('.', ',', ')') else null
    }

    fun isSupportedUrl(text: String): Boolean {
        return text.startsWith("http://", ignoreCase = true) ||
            text.startsWith("https://", ignoreCase = true)
    }
}

