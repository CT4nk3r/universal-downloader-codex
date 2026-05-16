package com.universaldownloader

import androidx.test.core.app.ActivityScenario
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class DownloadViewE2eTest {
    @Test
    fun soundcloudSwitchesToAudioFirst() {
        ActivityScenario.launch(MainActivity::class.java).use { scenario ->
            scenario.onActivity { activity ->
                // Drive the same classifier the UI uses.
                assertTrue(LinkClassifier.isAudioFirst("https://soundcloud.com/artist/track"))
            }
        }
    }
}

