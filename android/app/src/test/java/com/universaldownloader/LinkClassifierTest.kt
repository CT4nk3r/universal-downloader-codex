package com.universaldownloader

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class LinkClassifierTest {
    @Test
    fun audioFirst_soundcloud_isTrue() {
        assertTrue(LinkClassifier.isAudioFirst("https://soundcloud.com/artist/track"))
        assertTrue(LinkClassifier.isAudioFirst("https://www.soundcloud.com/artist/track"))
    }

    @Test
    fun audioFirst_youtube_isFalse() {
        assertFalse(LinkClassifier.isAudioFirst("https://www.youtube.com/watch?v=dQw4w9WgXcQ"))
    }

    @Test
    fun audioFirst_invalidUrl_isFalse() {
        assertFalse(LinkClassifier.isAudioFirst("not a url"))
    }
}

