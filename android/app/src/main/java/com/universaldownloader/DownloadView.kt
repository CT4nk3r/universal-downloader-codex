package com.universaldownloader

import android.content.Context
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

class DownloadView(
    context: Context,
    private val downloader: Downloader,
    initialUrl: String
) : ScrollView(context) {
    private val state = MutableStateFlow<DownloadState>(DownloadState.Idle)
    private val urlInput = TextInputEditText(context)
    private val progress = LinearProgressIndicator(context)
    private val status = TextView(context)
    private val advancedPanel = LinearLayout(context)
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

        val advancedButton = MaterialButton(context, null, com.google.android.material.R.attr.materialButtonOutlinedStyle).apply {
            text = "Options"
            isAllCaps = false
            letterSpacing = 0f
            cornerRadius = 18.dp
            minHeight = 50.dp
            setOnClickListener {
                advancedPanel.visibility = if (advancedPanel.visibility == View.VISIBLE) View.GONE else View.VISIBLE
            }
        }

        progress.max = 100
        progress.isIndeterminate = false
        progress.visibility = View.GONE

        status.apply {
            text = if (initialUrl.isBlank()) "Ready" else context.getString(R.string.shared_link_received)
            textSize = 14f
            setTextColor(0xFF3F4A46.toInt())
        }

        advancedPanel.apply {
            orientation = LinearLayout.VERTICAL
            visibility = View.GONE
            background = roundedBackground(0xFFFFFFFF.toInt(), 22.dpFloat)
            setPadding(20.dp)
        }

        content.addView(header, wide())
        content.addView(subtitle, wide().withTop(6.dp))
        content.addView(inputLayout, wide().withTop(30.dp))
        content.addView(downloadButton, wide().withTop(16.dp))
        content.addView(advancedButton, wide().withTop(8.dp))
        content.addView(advancedPanel, wide().withTop(16.dp))
        content.addView(progress, wide().withTop(20.dp))
        content.addView(status, wide().withTop(12.dp))

        buildAdvancedOptions()
        bindState()

        if (initialUrl.isNotBlank()) {
            post { startDownload(initialUrl) }
        }
    }

    private fun buildAdvancedOptions() {
        val optionsTitle = TextView(context).apply {
            text = "Download options"
            textSize = 18f
            typeface = Typeface.DEFAULT_BOLD
            setTextColor(0xFF17201D.toInt())
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
        val options = DownloadOptions(selectedQuality, selectedAudioMode)
        owner.lifecycleScope.launch {
            downloader.download(url, options).collectLatest { state.value = it }
        }
    }

    private fun render(downloadState: DownloadState) {
        when (downloadState) {
            DownloadState.Idle -> {
                progress.visibility = View.GONE
                status.text = "Ready"
            }
            is DownloadState.Running -> {
                progress.visibility = View.VISIBLE
                progress.progress = downloadState.progress
                status.text = downloadState.message
            }
            is DownloadState.Finished -> {
                progress.visibility = View.GONE
                status.text = "Saved ${downloadState.fileName}"
            }
            is DownloadState.Failed -> {
                progress.visibility = View.GONE
                status.text = downloadState.reason
            }
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
}
