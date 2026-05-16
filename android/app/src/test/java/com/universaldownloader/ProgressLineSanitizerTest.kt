package com.universaldownloader

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class ProgressLineSanitizerTest {
    @Test
    fun stripsSingleTag() {
        val out = ProgressLineSanitizer.sanitize("[youtube] abc: Downloading player API JSON")
        assertEquals("abc: Downloading player API JSON", out)
    }

    @Test
    fun stripsMultipleTags() {
        val out = ProgressLineSanitizer.sanitize("[jsc:quickjs] [youtube] Solving JS challenges using quickjs")
        assertEquals("Solving JS challenges using quickjs", out)
    }

    @Test
    fun truncatesLongLines() {
        val input = "[youtube] " + "a".repeat(200)
        val out = ProgressLineSanitizer.sanitize(input, maxLen = 20)
        assertTrue(out.length == 20)
        assertTrue(out.endsWith("..."))
    }
}

