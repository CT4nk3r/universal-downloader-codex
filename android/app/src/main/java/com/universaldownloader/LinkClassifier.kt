package com.universaldownloader

import java.net.URI

internal object LinkClassifier {
    private val audioFirstHosts = setOf(
        "soundcloud.com",
        "bandcamp.com",
        "music.apple.com",
        "open.spotify.com"
    )

    fun isAudioFirst(url: String): Boolean {
        val normalized = url.trim()
        val host = try {
            URI(normalized).host?.lowercase().orEmpty().removePrefix("www.")
        } catch (_: Exception) {
            ""
        }
        if (host.isBlank()) return false
        return audioFirstHosts.any { host == it || host.endsWith(".$it") }
    }
}

