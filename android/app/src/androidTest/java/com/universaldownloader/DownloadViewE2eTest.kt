package com.universaldownloader

import androidx.test.espresso.Espresso.onView
import androidx.test.espresso.action.ViewActions.click
import androidx.test.espresso.action.ViewActions.closeSoftKeyboard
import androidx.test.espresso.action.ViewActions.replaceText
import androidx.test.espresso.action.ViewActions.scrollTo
import androidx.test.espresso.assertion.ViewAssertions.matches
import androidx.test.espresso.matcher.ViewMatchers.isDisplayed
import androidx.test.espresso.matcher.ViewMatchers.withHint
import androidx.test.espresso.matcher.ViewMatchers.withText
import androidx.test.core.app.ActivityScenario
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import java.io.FileInputStream

@RunWith(AndroidJUnit4::class)
class DownloadViewE2eTest {
    @Before
    fun wakeAndUnlockDevice() {
        val device = InstrumentationRegistry.getInstrumentation().uiAutomation
        listOf(
            "input keyevent KEYCODE_WAKEUP",
            "wm dismiss-keyguard",
            "input keyevent KEYCODE_MENU"
        ).forEach { command ->
            device.executeShellCommand(command).use { output ->
                FileInputStream(output.fileDescriptor).use { it.readBytes() }
            }
        }
    }

    @Test
    fun soundcloudSwitchesToAudioFirst() {
        ActivityScenario.launch(MainActivity::class.java).use { scenario ->
            scenario.onActivity { activity ->
                // Drive the same classifier the UI uses.
                assertTrue(LinkClassifier.isAudioFirst("https://soundcloud.com/artist/track"))
            }
        }
    }

    @Test
    fun launchShowsAppTitle() = launchAndAssertText("Universal Downloader")

    @Test
    fun launchShowsSubtitle() = launchAndAssertText("Share or paste a link. Defaults are ready.")

    @Test
    fun launchShowsUrlInput() {
        launch {
            onView(withHint("Video link")).check(matches(isDisplayed()))
        }
    }

    @Test
    fun launchShowsDownloadButton() = launchAndAssertText("Download")

    @Test
    fun launchShowsAboutButton() = launchAndAssertText("i")

    @Test
    fun aboutDialogShowsVersionNumber() {
        launch {
            onView(withText("i")).perform(click())
            onView(withText("Version ${BuildConfig.VERSION_NAME}\n\nDiagnostics can help debug playlist, format, and download issues. Logs redact pasted links to host and length only."))
                .check(matches(isDisplayed()))
        }
    }

    @Test
    fun launchShowsHideOptionsButton() = launchAndAssertText("Hide options")

    @Test
    fun launchShowsDownloadOptionsTitle() = launchAndAssertText("Download options")

    @Test
    fun launchShowsFormatLabel() = launchAndAssertText("Format")

    @Test
    fun launchShowsMp4Format() = launchAndAssertText("MP4")

    @Test
    fun launchShowsMovFormat() = launchAndAssertText("MOV")

    @Test
    fun launchShowsMkvFormat() = launchAndAssertText("MKV")

    @Test
    fun launchShowsWebmFormat() = launchAndAssertText("WEBM")

    @Test
    fun launchShowsVideoQualityLabel() = launchAndAssertText("Video quality")

    @Test
    fun launchShows1080pQuality() = launchAndAssertText("1080p")

    @Test
    fun launchShows720pQuality() = launchAndAssertText("720p")

    @Test
    fun launchShows480pQuality() = launchAndAssertText("480p")

    @Test
    fun launchShows360pQuality() = launchAndAssertText("360p")

    @Test
    fun launchShowsAudioLabel() = launchAndAssertText("Audio")

    @Test
    fun launchShowsWithAudioMode() = launchAndAssertText("With audio")

    @Test
    fun launchShowsAudioOnlyMode() = launchAndAssertText("Audio only")

    @Test
    fun launchShowsNoAudioMode() = launchAndAssertText("No audio")

    @Test
    fun optionsCanCollapse() {
        launch {
            onView(withText("Hide options")).perform(scrollTo(), click())
            onView(withText("Options")).check(matches(isDisplayed()))
        }
    }

    @Test
    fun optionsCanExpandAfterCollapse() {
        launch {
            onView(withText("Hide options")).perform(scrollTo(), click())
            onView(withText("Options")).perform(scrollTo(), click())
            onView(withText("Download options")).perform(scrollTo()).check(matches(isDisplayed()))
        }
    }

    @Test
    fun soundcloudUrlShowsMp3Format() = enterUrlAndAssertText(
        "https://soundcloud.com/artist/track",
        "MP3"
    )

    @Test
    fun soundcloudUrlShowsWavFormat() = enterUrlAndAssertText(
        "https://soundcloud.com/artist/track",
        "WAV"
    )

    @Test
    fun soundcloudUrlShowsOggFormat() = enterUrlAndAssertText(
        "https://soundcloud.com/artist/track",
        "OGG"
    )

    @Test
    fun soundcloudUrlShowsM4aFormat() = enterUrlAndAssertText(
        "https://soundcloud.com/artist/track",
        "M4A"
    )

    @Test
    fun spotifyUrlShowsAudioQuality() = enterUrlAndAssertText(
        "https://open.spotify.com/track/demo",
        "Audio quality"
    )

    @Test
    fun youtubeUrlKeepsVideoFormat() = enterUrlAndAssertText(
        "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
        "MP4"
    )

    private fun launchAndAssertText(text: String) {
        launch {
            onView(withText(text)).perform(scrollTo()).check(matches(isDisplayed()))
        }
    }

    private fun enterUrlAndAssertText(url: String, expectedText: String) {
        launch {
            onView(withHint("Video link")).perform(replaceText(url), closeSoftKeyboard())
            Thread.sleep(500)
            onView(withText(expectedText)).perform(scrollTo()).check(matches(isDisplayed()))
        }
    }

    private fun launch(assertions: () -> Unit) {
        ActivityScenario.launch(MainActivity::class.java).use {
            assertions()
        }
    }
}
