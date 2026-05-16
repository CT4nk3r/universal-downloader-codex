package com.universaldownloader

import android.content.Context
import android.content.res.ColorStateList
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.view.Gravity
import android.view.View
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import androidx.core.view.setPadding
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.lifecycleScope
import androidx.lifecycle.repeatOnLifecycle
import com.google.android.material.button.MaterialButton
import com.google.android.material.button.MaterialButtonToggleGroup
import com.google.android.material.progressindicator.LinearProgressIndicator
import com.google.android.material.textfield.TextInputEditText
import com.google.android.material.textfield.TextInputLayout
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.launch
import java.net.URI

class DownloadView(
    context: Context,
    private val downloader: Downloader,
    initialUrl: String
) : ScrollView(context) {
    private val state = MutableStateFlow<DownloadState>(DownloadState.Idle)
    private val urlInput = TextInputEditText(context)
    private val progress = LinearProgressIndicator(context)
    private val statusCard = LinearLayout(context)
    private val statusTitle = TextView(context)
    private val statusSubtitle = TextView(context)
    private val advancedPanel = LinearLayout(context)
    private val advancedButton: MaterialButton = MaterialButton(
        context,
        null,
        com.google.android.material.R.attr.materialButtonOutlinedStyle
    )
    private var selectedOutputFormat = OutputFormat.Original
    private var selectedQuality = VideoQuality.Auto
    private var selectedAudioMode = AudioMode.VideoWithAudio

    init {
        isFillViewport = true
        setBackgroundColor(0xFFF8FAF7.toInt())

        val content = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            setPadding(24.dp, 54.dp, 24.dp, 24.dp)
        }
        addView(content, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT))

        val header = TextView(context).apply {
            text = "Universal Downloader"
            textSize = 28f
            typeface = Typeface.DEFAULT_BOLD
            setTextColor(0xFF17201D.toInt())
        }

        val subtitle = TextView(context).apply {
            text = "Share or paste a link. Defaults are ready."
            textSize = 15f
            setTextColor(0xFF58635F.toInt())
        }

        val inputLayout = TextInputLayout(context).apply {
            hint = "Video link"
            boxBackgroundMode = TextInputLayout.BOX_BACKGROUND_OUTLINE
            setBoxCornerRadii(16.dpFloat, 16.dpFloat, 16.dpFloat, 16.dpFloat)
            addView(urlInput, LinearLayout.LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT))
        }

        urlInput.apply {
            setSingleLine(true)
            setText(initialUrl)
        }

        val downloadButton = MaterialButton(context).apply {
            text = context.getString(R.string.download)
            textSize = 16f
            isAllCaps = false
            letterSpacing = 0f
            cornerRadius = 18.dp
            minHeight = 56.dp
            setOnClickListener { startDownload(urlInput.text.toString()) }
        }

        advancedButton.apply {
            text = "Hide options"
            isAllCaps = false
            letterSpacing = 0f
            cornerRadius = 18.dp
            minHeight = 50.dp
            strokeWidth = 2.dp
            strokeColor = ColorStateList.valueOf(COLOR_OUTLINE_STRONG)
            setTextColor(COLOR_PRIMARY)
            backgroundTintList = ColorStateList.valueOf(0xFFFFFFFF.toInt())
            setOnClickListener {
                val open = advancedPanel.visibility != View.VISIBLE
                setAdvancedOpen(open)
            }
        }

        progress.max = 100
        progress.isIndeterminate = false
        progress.visibility = View.GONE

        statusTitle.apply {
            textSize = 14f
            typeface = Typeface.DEFAULT_BOLD
            setTextColor(0xFF17201D.toInt())
        }

        statusSubtitle.apply {
            textSize = 13f
            setTextColor(0xFF58635F.toInt())
        }

        statusCard.apply {
            orientation = LinearLayout.VERTICAL
            background = roundedBackground(0xFFFFFFFF.toInt(), 18.dpFloat)
            setPadding(16.dp)
            visibility = View.GONE
            addView(statusTitle, wide())
            addView(statusSubtitle, wide().withTop(4.dp))
        }

        advancedPanel.apply {
            orientation = LinearLayout.VERTICAL
            visibility = View.VISIBLE
            background = roundedBackground(0xFFFFFFFF.toInt(), 22.dpFloat)
            setPadding(20.dp)
        }

        content.addView(header, wide())
        content.addView(subtitle, wide().withTop(6.dp))
        content.addView(inputLayout, wide().withTop(30.dp))
        content.addView(downloadButton, wide().withTop(16.dp))
        content.addView(advancedButton, wide().withTop(8.dp))
        content.addView(advancedPanel, wide().withTop(16.dp))
        content.addView(progress, wide().withTop(18.dp))
        content.addView(statusCard, wide().withTop(12.dp))

        buildAdvancedOptions()
        bindState()
        setAdvancedOpen(true)

        if (initialUrl.isNotBlank()) {
            post { startDownload(initialUrl) }
            } else {
                // Show a friendly, non-placeholder hint when the app opens without a shared link.
                setStatus(
                    title = "Ready to download",
                    subtitle = "Paste a link above, or share one into this app.",
                visible = true
            )
        }
    }

    private fun buildAdvancedOptions() {
        val optionsTitle = TextView(context).apply {
            text = "Download options"
            textSize = 18f
            typeface = Typeface.DEFAULT_BOLD
            setTextColor(0xFF17201D.toInt())
        }

        val formatLabel = label("Format")
        val formatGroup = toggleGroup(OutputFormat.entries.map { it.label }) { index ->
            selectedOutputFormat = OutputFormat.entries[index]
        }

        val qualityLabel = label("Quality")
        val qualityGroup = toggleGroup(VideoQuality.entries.map { it.label }) { index ->
            selectedQuality = VideoQuality.entries[index]
        }

        val audioLabel = label("Audio")
        val audioGroup = toggleGroup(AudioMode.entries.map { it.label }) { index ->
            selectedAudioMode = AudioMode.entries[index]
        }

        advancedPanel.addView(optionsTitle, wide())
        advancedPanel.addView(formatLabel, wide().withTop(18.dp))
        advancedPanel.addView(formatGroup, wide().withTop(8.dp))
        advancedPanel.addView(qualityLabel, wide().withTop(18.dp))
        advancedPanel.addView(qualityGroup, wide().withTop(8.dp))
        advancedPanel.addView(audioLabel, wide().withTop(18.dp))
        advancedPanel.addView(audioGroup, wide().withTop(8.dp))
    }

    private fun toggleGroup(labels: List<String>, onSelected: (Int) -> Unit): MaterialButtonToggleGroup {
        return MaterialButtonToggleGroup(context).apply {
            isSingleSelection = true
            isSelectionRequired = true
            labels.forEachIndexed { index, label ->
                val button = MaterialButton(context, null, com.google.android.material.R.attr.materialButtonOutlinedStyle).apply {
                    id = View.generateViewId()
                    text = label
                    textSize = 12f
                    isAllCaps = false
                    letterSpacing = 0f
                    minWidth = 0
                    minimumWidth = 0
                    minHeight = 44.dp
                    cornerRadius = 14.dp
                    isCheckable = true
                    setPadding(4.dp, 0, 4.dp, 0)

                    strokeWidth = 2.dp
                    strokeColor = ColorStateList.valueOf(COLOR_OUTLINE_STRONG)
                    setTextColor(makeToggleTextColors())
                    backgroundTintList = makeToggleBackgroundColors()
                }
                addView(button, LinearLayout.LayoutParams(0, LayoutParams.WRAP_CONTENT, 1f))
                if (index == 0) check(button.id)
            }

            addOnButtonCheckedListener { group, checkedId, isChecked ->
                if (isChecked) {
                    val index = (0 until group.childCount).firstOrNull { group.getChildAt(it).id == checkedId }
                    if (index != null) onSelected(index)
                }
            }
        }
    }

    private fun label(text: String): TextView {
        return TextView(context).apply {
            this.text = text
            textSize = 13f
            typeface = Typeface.DEFAULT_BOLD
            setTextColor(0xFF58635F.toInt())
        }
    }

    private fun bindState() {
        val owner = context as? LifecycleOwner ?: return
        owner.lifecycleScope.launch {
            owner.repeatOnLifecycle(Lifecycle.State.STARTED) {
                state.collectLatest(::render)
            }
        }
    }

    private fun startDownload(url: String) {
        val owner = context as? LifecycleOwner ?: return
        val normalized = url.trim()
        val auto = autoDefaultsForUrl(normalized)
        val options = DownloadOptions(
            outputFormat = selectedOutputFormat,
            quality = selectedQuality,
            audioMode = selectedAudioMode
        ).withAutoDefaults(auto)
        owner.lifecycleScope.launch {
            downloader.download(normalized, options).collectLatest { state.value = it }
        }
    }

    private fun render(downloadState: DownloadState) {
        when (downloadState) {
            DownloadState.Idle -> {
                progress.visibility = View.GONE
                // Keep whatever initial hint we showed; don't overwrite with a blank/placeholder state.
                if (statusCard.visibility != View.VISIBLE) {
                    setStatus(title = "", subtitle = "", visible = false)
                }
            }
            is DownloadState.Running -> {
                progress.visibility = View.VISIBLE
                progress.progress = downloadState.progress
                setStatus(
                    title = "Downloading",
                    subtitle = sanitizeProgressLine(downloadState.message).ifBlank { "Working…" },
                    visible = true
                )
            }
            is DownloadState.Finished -> {
                progress.visibility = View.GONE
                setStatus(
                    title = "Saved",
                    subtitle = downloadState.fileName,
                    visible = true
                )
            }
            is DownloadState.Failed -> {
                progress.visibility = View.GONE
                setStatus(
                    title = "Couldn’t download",
                    subtitle = downloadState.reason,
                    visible = true
                )
            }
        }
    }

    private fun setStatus(title: String, subtitle: String, visible: Boolean) {
        statusTitle.text = title
        statusSubtitle.text = subtitle
        statusCard.visibility = if (visible) View.VISIBLE else View.GONE
    }

    private fun setAdvancedOpen(open: Boolean) {
        advancedPanel.visibility = if (open) View.VISIBLE else View.GONE
        advancedButton.text = if (open) "Hide options" else "Options"
    }

    private fun sanitizeProgressLine(raw: String): String {
        val trimmed = raw.trim()
        if (trimmed.isBlank()) return ""

        // yt-dlp often prefixes messages with one or more tags like "[youtube]" or "[jsc:quickjs]".
        val noTags = trimmed.replace(Regex("^(?:\\s*\\[[^\\]]+\\]\\s*)+"), "")

        // Keep it readable in the UI: shorten very long lines.
        val singleLine = noTags.replace(Regex("\\s+"), " ")
        return if (singleLine.length <= 72) singleLine else singleLine.take(69) + "..."
    }

    private fun makeToggleTextColors(): ColorStateList {
        val states = arrayOf(
            intArrayOf(android.R.attr.state_checked),
            intArrayOf()
        )
        val colors = intArrayOf(
            COLOR_PRIMARY,
            COLOR_TEXT_MEDIUM
        )
        return ColorStateList(states, colors)
    }

    private fun makeToggleBackgroundColors(): ColorStateList {
        val states = arrayOf(
            intArrayOf(android.R.attr.state_checked),
            intArrayOf()
        )
        val colors = intArrayOf(
            0xFFE6F2EF.toInt(), // subtle tinted fill
            0xFFFFFFFF.toInt()
        )
        return ColorStateList(states, colors)
    }

    private data class AutoDefaults(
        val defaultAudioMode: AudioMode,
        val defaultFormat: OutputFormat
    )

    private fun DownloadOptions.withAutoDefaults(auto: AutoDefaults?): DownloadOptions {
        if (auto == null) return this
        val audioMode = if (this.audioMode == AudioMode.VideoWithAudio && auto.defaultAudioMode != AudioMode.VideoWithAudio) {
            // Preserve explicit user selection; only adjust if user left default.
            auto.defaultAudioMode
        } else {
            this.audioMode
        }
        val format = if (this.outputFormat == OutputFormat.Original) auto.defaultFormat else this.outputFormat
        return copy(audioMode = audioMode, outputFormat = format)
    }

    private fun autoDefaultsForUrl(url: String): AutoDefaults? {
        val host = try {
            URI(url).host?.lowercase().orEmpty().removePrefix("www.")
        } catch (_: Exception) {
            ""
        }
        if (host.isBlank()) return null

        // Small pragmatic set; can be expanded. This is a fallback for when we don't have extractor metadata.
        val audioFirstHosts = setOf(
            "soundcloud.com",
            "bandcamp.com",
            "music.apple.com",
            "open.spotify.com"
        )
        return if (audioFirstHosts.any { host == it || host.endsWith(".$it") }) {
            AutoDefaults(defaultAudioMode = AudioMode.AudioOnly, defaultFormat = OutputFormat.M4a)
        } else {
            AutoDefaults(defaultAudioMode = AudioMode.VideoWithAudio, defaultFormat = OutputFormat.Mp4)
        }
    }

    private fun roundedBackground(color: Int, radius: Float): GradientDrawable {
        return GradientDrawable().apply {
            setColor(color)
            cornerRadius = radius
            setStroke(1, 0xFFE1E7E3.toInt())
        }
    }

    private fun wide(): LinearLayout.LayoutParams {
        return LinearLayout.LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT)
    }

    private fun LinearLayout.LayoutParams.withTop(top: Int): LinearLayout.LayoutParams {
        topMargin = top
        return this
    }

    private val Int.dp: Int
        get() = (this * resources.displayMetrics.density).toInt()

    private val Int.dpFloat: Float
        get() = this * resources.displayMetrics.density

    private companion object {
        private const val COLOR_PRIMARY = 0xFF216C5E.toInt()
        private const val COLOR_TEXT_MEDIUM = 0xFF2D3733.toInt()
        private const val COLOR_OUTLINE_STRONG = 0xFF9CA8A2.toInt()
    }
}
