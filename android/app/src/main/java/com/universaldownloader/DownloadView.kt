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
import androidx.core.widget.addTextChangedListener
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.lifecycleScope
import androidx.lifecycle.repeatOnLifecycle
import com.google.android.material.button.MaterialButton
import com.google.android.material.button.MaterialButtonToggleGroup
import com.google.android.material.progressindicator.LinearProgressIndicator
import com.google.android.material.textfield.TextInputEditText
import com.google.android.material.textfield.TextInputLayout
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.launch

class DownloadView(
    context: Context,
    private val downloader: Downloader,
    initialUrl: String,
    private val onShowAbout: () -> Unit
) : ScrollView(context) {
    private val state = MutableStateFlow<DownloadState>(DownloadState.Idle)
    private val urlInput = TextInputEditText(context)
    private val progress = LinearProgressIndicator(context)
    private val statusCard = LinearLayout(context)
    private val statusTitle = TextView(context)
    private val statusSubtitle = TextView(context)
    private val itemList = LinearLayout(context)
    private val advancedPanel = LinearLayout(context)
    private val advancedButton: MaterialButton = MaterialButton(
        context,
        null,
        com.google.android.material.R.attr.materialButtonOutlinedStyle
    )
    private var selectedOutputFormat = OutputFormat.Original
    private var selectedVideoFormat = OutputFormat.Original
    private var selectedAudioFormat = OutputFormat.Original
    private var selectedQuality = VideoQuality.Auto
    private var selectedAudioMode = AudioMode.VideoWithAudio
    private var selectedAudioQuality = AudioQuality.Auto
    private var urlDebounceJob: Job? = null
    private var downloadJob: Job? = null

    private lateinit var formatGroup: MaterialButtonToggleGroup
    private lateinit var formatLabelView: TextView
    private lateinit var qualityLabelView: TextView
    private lateinit var qualityGroup: MaterialButtonToggleGroup
    private lateinit var audioGroup: MaterialButtonToggleGroup
    private lateinit var stopButton: MaterialButton

    init {
        isFillViewport = true
        setBackgroundColor(0xFFF8FAF7.toInt())

        val content = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            setPadding(24.dp, 54.dp, 24.dp, 24.dp)
        }
        addView(content, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT))

        val headerRow = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }

        val header = TextView(context).apply {
            text = "Universal Downloader"
            textSize = 28f
            typeface = Typeface.DEFAULT_BOLD
            setTextColor(0xFF17201D.toInt())
        }

        val aboutButton = MaterialButton(context, null, com.google.android.material.R.attr.materialButtonOutlinedStyle).apply {
            text = "i"
            textSize = 16f
            isAllCaps = false
            letterSpacing = 0f
            minWidth = 0
            minimumWidth = 0
            minHeight = 44.dp
            cornerRadius = 22.dp
            strokeWidth = 2.dp
            strokeColor = ColorStateList.valueOf(COLOR_OUTLINE_STRONG)
            setTextColor(COLOR_PRIMARY)
            backgroundTintList = ColorStateList.valueOf(0xFFFFFFFF.toInt())
            setPadding(0, 0, 0, 0)
            setOnClickListener { onShowAbout() }
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

        stopButton = MaterialButton(context, null, com.google.android.material.R.attr.materialButtonOutlinedStyle).apply {
            text = "Stop"
            textSize = 16f
            isAllCaps = false
            letterSpacing = 0f
            cornerRadius = 18.dp
            minHeight = 56.dp
            strokeWidth = 2.dp
            strokeColor = ColorStateList.valueOf(COLOR_OUTLINE_STRONG)
            setTextColor(0xFF9B2C2C.toInt())
            backgroundTintList = ColorStateList.valueOf(0xFFFFFFFF.toInt())
            visibility = View.GONE
            setOnClickListener { stopDownload() }
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
            addView(stopButton, wide().withTop(12.dp))
        }

        itemList.apply {
            orientation = LinearLayout.VERTICAL
            visibility = View.GONE
            background = roundedBackground(0xFFFFFFFF.toInt(), 18.dpFloat)
            setPadding(16.dp)
        }

        advancedPanel.apply {
            orientation = LinearLayout.VERTICAL
            visibility = View.VISIBLE
            background = roundedBackground(0xFFFFFFFF.toInt(), 22.dpFloat)
            setPadding(20.dp)
        }

        headerRow.addView(header, LinearLayout.LayoutParams(0, LayoutParams.WRAP_CONTENT, 1f))
        headerRow.addView(aboutButton, LinearLayout.LayoutParams(44.dp, 44.dp))

        content.addView(headerRow, wide())
        content.addView(subtitle, wide().withTop(6.dp))
        content.addView(inputLayout, wide().withTop(30.dp))
        content.addView(downloadButton, wide().withTop(16.dp))
        content.addView(advancedButton, wide().withTop(8.dp))
        content.addView(advancedPanel, wide().withTop(16.dp))
        content.addView(progress, wide().withTop(18.dp))
        content.addView(statusCard, wide().withTop(12.dp))
        content.addView(itemList, wide().withTop(12.dp))

        buildAdvancedOptions()
        bindState()
        setAdvancedOpen(true)

        val owner = context as? LifecycleOwner
        urlInput.addTextChangedListener(
            afterTextChanged = {
                val text = it?.toString().orEmpty()
                urlDebounceJob?.cancel()
                urlDebounceJob = owner?.lifecycleScope?.launch {
                    delay(350)
                    AppLogger.d("URL input changed: ${text.trim().redactedUrlSummary()}")
                    applyAutoUiForUrl(text.trim())
                }
            }
        )

        applyAutoUiForUrl(initialUrl.trim())

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

        formatLabelView = label("Format")
        formatGroup = formatToggleGroup(videoFormats(), AudioMode.VideoWithAudio)

        qualityLabelView = label("Video quality")
        qualityGroup = toggleGroup(VideoQuality.entries.map { it.label }) { index ->
            selectedQuality = VideoQuality.entries[index]
        }

        val audioLabel = label("Audio")
        audioGroup = toggleGroup(AudioMode.entries.map { it.label }) { index ->
            selectedAudioMode = AudioMode.entries[index]
            applyUiForAudioMode(selectedAudioMode)
        }

        advancedPanel.addView(optionsTitle, wide())
        advancedPanel.addView(formatLabelView, wide().withTop(18.dp))
        advancedPanel.addView(formatGroup, wide().withTop(8.dp))
        advancedPanel.addView(qualityLabelView, wide().withTop(18.dp))
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
        downloadJob?.cancel()
        val normalized = url.trim()
        val options = DownloadOptions(
            outputFormat = selectedOutputFormat,
            quality = selectedQuality,
            audioMode = selectedAudioMode,
            audioQuality = selectedAudioQuality
        )
        AppLogger.i("Download requested: ${normalized.redactedUrlSummary()}, options=$options")
        downloadJob = owner.lifecycleScope.launch {
            downloader.download(normalized, options).collectLatest {
                AppLogger.d("Download state: ${it.logSummary()}")
                state.value = it
            }
        }
    }

    private fun stopDownload() {
        AppLogger.i("Stop requested by user")
        downloadJob?.cancel()
        downloadJob = null
        progress.visibility = View.GONE
        stopButton.visibility = View.GONE
        setStatus(
            title = "Stopped",
            subtitle = "Completed downloads are kept. Partial files are being removed.",
            visible = true
        )
    }

    private fun render(downloadState: DownloadState) {
        when (downloadState) {
            DownloadState.Idle -> {
                progress.visibility = View.GONE
                stopButton.visibility = View.GONE
                // Keep whatever initial hint we showed; don't overwrite with a blank/placeholder state.
                if (statusCard.visibility != View.VISIBLE) {
                    setStatus(title = "", subtitle = "", visible = false)
                }
            }
            is DownloadState.Running -> {
                progress.visibility = View.VISIBLE
                stopButton.visibility = View.VISIBLE
                progress.progress = downloadState.progress
                renderItems(downloadState.items)
                setStatus(
                    title = "Downloading",
                    subtitle = sanitizeProgressLine(downloadState.message).ifBlank { "Working…" },
                    visible = true
                )
            }
            is DownloadState.Finished -> {
                progress.visibility = View.GONE
                stopButton.visibility = View.GONE
                setStatus(
                    title = "Saved",
                    subtitle = downloadState.fileName,
                    visible = true
                )
            }
            is DownloadState.Stopped -> {
                progress.visibility = View.GONE
                stopButton.visibility = View.GONE
                setStatus(
                    title = "Stopped",
                    subtitle = "Completed downloads are kept. Removed partial files. Finished: ${downloadState.completedCount}",
                    visible = true
                )
            }
            is DownloadState.Failed -> {
                progress.visibility = View.GONE
                stopButton.visibility = View.GONE
                setStatus(
                    title = "Couldn’t download",
                    subtitle = downloadState.reason,
                    visible = true
                )
            }
        }
    }

    private fun renderItems(items: List<DownloadItem>) {
        itemList.removeAllViews()
        if (items.isEmpty()) {
            itemList.visibility = View.GONE
            return
        }

        itemList.visibility = View.VISIBLE
        itemList.addView(label("Playlist progress"), wide())

        val activeItems = items.filter { it.status == DownloadItemStatus.Running }.takeLast(4)
        val finishedItems = items.filter { it.status == DownloadItemStatus.Finished }.takeLast(8)

        activeItems.forEach { item ->
            itemList.addView(itemRow(item), wide().withTop(8.dp))
        }

        if (finishedItems.isNotEmpty()) {
            itemList.addView(label("Downloaded"), wide().withTop(14.dp))
        }

        finishedItems.forEach { item ->
            itemList.addView(itemRow(item), wide().withTop(8.dp))
        }
    }

    private fun itemRow(item: DownloadItem): LinearLayout {
        return LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            val title = TextView(context).apply {
                text = item.titleLine()
                textSize = 14f
                setTextColor(0xFF17201D.toInt())
            }
            val file = TextView(context).apply {
                text = item.fileName.orEmpty()
                textSize = 12f
                setTextColor(0xFF58635F.toInt())
                visibility = if (item.fileName.isNullOrBlank()) View.GONE else View.VISIBLE
            }
            addView(title, wide())
            addView(file, wide().withTop(2.dp))
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
        return ProgressLineSanitizer.sanitize(raw)
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

    private fun applyAutoUiForUrl(url: String) {
        val isAudioFirst = LinkClassifier.isAudioFirst(url)
        AppLogger.d("Applying URL defaults: ${url.redactedUrlSummary()}, audioFirst=$isAudioFirst")

        if (isAudioFirst) {
            // Switch to audio-only mode with audio-only formats; quality isn't meaningful.
            selectedAudioMode = AudioMode.AudioOnly
            setAudioModeSelection(AudioMode.AudioOnly)
        } else {
            selectedAudioMode = AudioMode.VideoWithAudio
            setAudioModeSelection(AudioMode.VideoWithAudio)
        }
    }

    private fun applyUiForAudioMode(mode: AudioMode) {
        AppLogger.d(
            "Audio mode selected: mode=$mode, rememberedVideoFormat=$selectedVideoFormat, rememberedAudioFormat=$selectedAudioFormat"
        )
        when (mode) {
            AudioMode.AudioOnly -> {
                setFormatChoices(audioFormats(), selectedAudioFormat, AudioMode.AudioOnly)
                setQualityModeAudio()
            }
            AudioMode.VideoWithAudio,
            AudioMode.VideoOnly -> {
                setFormatChoices(videoFormats(), selectedVideoFormat, mode)
                setQualityModeVideo()
            }
        }
    }

    private fun setAudioModeSelection(mode: AudioMode) {
        val index = AudioMode.entries.indexOf(mode).takeIf { it >= 0 } ?: return
        val id = audioGroup.getChildAt(index).id
        audioGroup.check(id)
    }

    private fun setQualityModeVideo() {
        qualityLabelView.text = "Video quality"
        replaceQualityChoices(VideoQuality.entries.map { it.label }) { index ->
            selectedQuality = VideoQuality.entries[index]
        }
        qualityLabelView.visibility = View.VISIBLE
        qualityGroup.visibility = View.VISIBLE
    }

    private fun setQualityModeAudio() {
        qualityLabelView.text = "Audio quality"
        replaceQualityChoices(AudioQuality.entries.map { it.label }) { index ->
            selectedAudioQuality = AudioQuality.entries[index]
        }
        qualityLabelView.visibility = View.VISIBLE
        qualityGroup.visibility = View.VISIBLE
    }

    private fun replaceQualityChoices(labels: List<String>, onSelected: (Int) -> Unit) {
        val parent = qualityGroup.parent as? LinearLayout ?: return
        val qualityIndex = parent.indexOfChild(qualityGroup)
        parent.removeView(qualityGroup)
        qualityGroup = toggleGroup(labels, onSelected)
        parent.addView(qualityGroup, qualityIndex, wide().withTop(8.dp))
    }

    private fun setFormatChoices(
        formats: List<OutputFormat>,
        desired: OutputFormat,
        mode: AudioMode
    ) {
        advancedPanel.removeView(formatGroup)
        formatGroup = formatToggleGroup(formats, mode)
        // Re-insert after the "Format" label (which is always right before it).
        val formatLabelIndex = advancedPanel.indexOfChild(formatLabelView)
        advancedPanel.addView(formatGroup, formatLabelIndex + 1, wide().withTop(8.dp))

        val selected = formats.indexOfFirst { it == desired }.takeIf { it >= 0 } ?: 0
        val selectedId = (formatGroup.getChildAt(selected) as? View)?.id
        if (selectedId != null) formatGroup.check(selectedId)
        selectedOutputFormat = formats[selected]
    }

    private fun formatToggleGroup(
        formats: List<OutputFormat>,
        mode: AudioMode
    ): MaterialButtonToggleGroup {
        return toggleGroup(formats.map { it.label }) { index ->
            val selectedFormat = formats[index]
            selectedOutputFormat = selectedFormat
            when (mode) {
                AudioMode.AudioOnly -> {
                    selectedAudioFormat = selectedFormat
                    AppLogger.d("Format selected: mode=$mode, format=$selectedFormat")
                }
                AudioMode.VideoWithAudio,
                AudioMode.VideoOnly -> {
                    selectedVideoFormat = selectedFormat
                    AppLogger.d("Format selected: mode=$mode, format=$selectedFormat")
                }
            }
        }
    }

    private fun String.redactedUrlSummary(): String {
        if (isBlank()) return "blank"
        val host = runCatching { java.net.URI(this).host }.getOrNull()
        return "length=$length, host=${host ?: "unknown"}"
    }

    private fun DownloadState.logSummary(): String {
        return when (this) {
            DownloadState.Idle -> "Idle"
            is DownloadState.Running -> "Running(progress=$progress, messageLength=${message.length})"
            is DownloadState.Finished -> "Finished(fileName=$fileName)"
            is DownloadState.Stopped -> "Stopped(completedCount=$completedCount)"
            is DownloadState.Failed -> "Failed(reasonLength=${reason.length})"
        }
    }

    private fun DownloadItem.titleLine(): String {
        val totalLabel = total?.let { "/$it" }.orEmpty()
        val statusLabel = when (status) {
            DownloadItemStatus.Running -> "$progress%"
            DownloadItemStatus.Finished -> "Done"
        }
        return "$index$totalLabel  $statusLabel  $title"
    }

    private fun videoFormats(): List<OutputFormat> =
        listOf(OutputFormat.Original, OutputFormat.Mp4, OutputFormat.Mov, OutputFormat.Mkv, OutputFormat.Webm)

    private fun audioFormats(): List<OutputFormat> =
        listOf(OutputFormat.Original, OutputFormat.Mp3, OutputFormat.Wav, OutputFormat.Ogg, OutputFormat.M4a)

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
