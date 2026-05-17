package com.universaldownloader

import android.content.Context
import android.os.Environment
import com.yausername.youtubedl_android.YoutubeDL
import com.yausername.youtubedl_android.YoutubeDLRequest
import java.io.File
import java.util.UUID
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicReference
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.launch

class YtDlpDownloader(
    private val context: Context
) : Downloader {
    override fun download(url: String, options: DownloadOptions): Flow<DownloadState> = callbackFlow {
        val processId = UUID.randomUUID().toString()
        val wasStopped = AtomicBoolean(false)
        val activeDownloadDirRef = AtomicReference<File?>(null)
        val normalized = url.trim()
        if (!UrlExtractor.isSupportedUrl(normalized)) {
            AppLogger.w("Rejected unsupported URL: ${normalized.redactedUrlSummary()}")
            trySend(DownloadState.Failed("No downloadable URL found."))
            close()
            return@callbackFlow
        }
        AppLogger.i("Preparing yt-dlp request: ${normalized.redactedUrlSummary()}, options=$options")

        trySend(DownloadState.Running(5, "Preparing download"))

        val job = launch(Dispatchers.IO) {
            var downloadDir: File? = null
            val playlistProgress = PlaylistProgress()
            try {
                val activeDownloadDir = File(
                    Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS),
                    "UniversalDownloader"
                ).apply { mkdirs() }
                downloadDir = activeDownloadDir
                activeDownloadDirRef.set(activeDownloadDir)
                AppLogger.d("Download directory ready: ${activeDownloadDir.absolutePath}")

                val request = YoutubeDLRequest(normalized).apply {
                    val selector = options.formatSelector()
                    addOption("-P", activeDownloadDir.absolutePath)
                    addOption("-o", "%(title).180B.%(ext)s")
                    addOption("-f", selector)
                    addOption("--concurrent-fragments", MAX_CONCURRENT_FRAGMENTS.toString())
                    addOption("--no-mtime")
                    addOption("--restrict-filenames")
                    addOption("--newline")
                    AppLogger.d("yt-dlp format selector: $selector")
                    AppLogger.d("yt-dlp concurrent fragments: $MAX_CONCURRENT_FRAGMENTS")
                    when (options.audioMode) {
                        AudioMode.VideoWithAudio -> {
                            addOption("--merge-output-format", "mp4")
                            AppLogger.d("yt-dlp merge output format: mp4")
                        }
                        AudioMode.AudioOnly -> {
                            addOption("-x")
                            addOption("--audio-format", "m4a")
                            options.audioQuality.kbps?.let { kbps ->
                                addOption("--audio-quality", "${kbps}K")
                            }
                            AppLogger.d("yt-dlp audio extract defaults: format=m4a, quality=${options.audioQuality}")
                        }
                        AudioMode.VideoOnly -> Unit
                    }

                    when (options.outputFormat) {
                        OutputFormat.Original -> AppLogger.d("Output format: source")
                        OutputFormat.Mp4 -> {
                            addOption("--remux-video", "mp4")
                            AppLogger.d("Output format: remux mp4")
                        }
                        OutputFormat.Mov -> {
                            addOption("--remux-video", "mov")
                            AppLogger.d("Output format: remux mov")
                        }
                        OutputFormat.Mkv -> {
                            addOption("--remux-video", "mkv")
                            AppLogger.d("Output format: remux mkv")
                        }
                        OutputFormat.Webm -> {
                            addOption("--remux-video", "webm")
                            AppLogger.d("Output format: remux webm")
                        }
                        OutputFormat.M4a -> {
                            addOption("-x")
                            addOption("--audio-format", "m4a")
                            options.audioQuality.kbps?.let { kbps ->
                                addOption("--audio-quality", "${kbps}K")
                            }
                            AppLogger.d("Output format: audio m4a")
                        }
                        OutputFormat.Mp3 -> {
                            addOption("-x")
                            addOption("--audio-format", "mp3")
                            options.audioQuality.kbps?.let { kbps ->
                                addOption("--audio-quality", "${kbps}K")
                            }
                            AppLogger.d("Output format: audio mp3")
                        }
                        OutputFormat.Ogg -> {
                            addOption("-x")
                            addOption("--audio-format", "ogg")
                            options.audioQuality.kbps?.let { kbps ->
                                addOption("--audio-quality", "${kbps}K")
                            }
                            AppLogger.d("Output format: audio ogg")
                        }
                        OutputFormat.Wav -> {
                            addOption("-x")
                            addOption("--audio-format", "wav")
                            // WAV is uncompressed; ignore bitrate selection.
                            AppLogger.d("Output format: audio wav")
                        }
                    }
                }

                YoutubeDL.getInstance().execute(request, processId) { progress, _, line ->
                    val percent = progress.toInt().coerceIn(0, 100)
                    val message = line.ifBlank { "Downloading media" }
                    val items = playlistProgress.update(message, percent)
                    trySend(DownloadState.Running(percent, message, items))
                }

                val fileName = downloadDir
                    .listFiles()
                    ?.maxByOrNull { it.lastModified() }
                    ?.name
                    ?: "Downloads/UniversalDownloader"

                AppLogger.i("Download finished: fileName=$fileName")
                trySend(DownloadState.Finished(fileName))
            } catch (exception: CancellationException) {
                // Preserve structured concurrency: cancellation should propagate.
                AppLogger.d("Download cancelled")
                throw exception
            } catch (exception: YoutubeDL.CanceledException) {
                AppLogger.i("Download stopped by user")
                downloadDir?.deletePartialFiles()
                trySend(DownloadState.Stopped(playlistProgress.finishedCount()))
            } catch (exception: Exception) {
                if (wasStopped.get()) {
                    AppLogger.i("Download stopped by user after process termination")
                    downloadDir?.deletePartialFiles()
                    trySend(DownloadState.Stopped(playlistProgress.finishedCount()))
                    return@launch
                }
                AppLogger.e("Download failed", exception)
                trySend(DownloadState.Failed(YtDlpErrorMapper.userFacingMessage(exception)))
            } finally {
                close()
            }
        }

        awaitClose {
            if (!job.isActive) return@awaitClose
            wasStopped.set(true)
            AppLogger.i("Stopping yt-dlp process: processId=$processId")
            YoutubeDL.getInstance().destroyProcessById(processId)
            activeDownloadDirRef.get()?.deletePartialFiles()
            job.cancel()
        }
    }

    private fun DownloadOptions.formatSelector(): String {
        val heightLimit = when (quality) {
            VideoQuality.Auto -> null
            VideoQuality.P1080 -> 1080
            VideoQuality.P720 -> 720
            VideoQuality.P480 -> 480
            VideoQuality.P360 -> 360
        }

        val videoFilter = heightLimit?.let { "[height<=$it]" }.orEmpty()

        return when (audioMode) {
            AudioMode.VideoWithAudio ->
                "bestvideo$videoFilter[ext=mp4]+bestaudio[ext=m4a]/best$videoFilter[ext=mp4]/best$videoFilter"
            AudioMode.AudioOnly ->
                "bestaudio[ext=m4a]/bestaudio/best"
            AudioMode.VideoOnly ->
                "bestvideo$videoFilter[ext=mp4]/bestvideo$videoFilter"
        }
    }

    private fun String.redactedUrlSummary(): String {
        if (isBlank()) return "blank"
        val host = runCatching { java.net.URI(this).host }.getOrNull()
        return "length=$length, host=${host ?: "unknown"}"
    }

    private fun File.deletePartialFiles() {
        val deleted = listFiles()
            ?.filter { it.isFile && it.name.endsWith(".part") }
            ?.count { file ->
                AppLogger.i("Deleting partial download: ${file.name}")
                file.delete()
            }
            ?: 0
        AppLogger.i("Partial cleanup complete: deleted=$deleted")
    }

    private class PlaylistProgress {
        private val items = linkedMapOf<Int, DownloadItem>()
        private var currentIndex = 1
        private var total: Int? = null
        private var currentFileName: String? = null

        fun update(line: String, percent: Int): List<DownloadItem> {
            playlistItemRegex.find(line)?.let { match ->
                finishPreviousRunningItem()
                currentIndex = match.groupValues[1].toInt()
                total = match.groupValues[2].toInt()
                currentFileName = null
            }

            destinationRegex.find(line)?.let { match ->
                currentFileName = match.groupValues[1].substringAfterLast('/')
                ensureItem(currentIndex, currentFileName, percent, DownloadItemStatus.Running)
            }

            downloadPercentRegex.find(line)?.let { match ->
                currentFileName?.let { fileName ->
                    ensureItem(
                        currentIndex,
                        fileName,
                        match.groupValues[1].toFloat().toInt().coerceIn(0, 100),
                        DownloadItemStatus.Running
                    )
                }
            }

            if (line.contains("100%")) {
                currentFileName?.let { fileName ->
                    ensureItem(currentIndex, fileName, 100, DownloadItemStatus.Finished)
                }
            }

            return items.values.toList()
        }

        fun finishedCount(): Int = items.values.count { it.status == DownloadItemStatus.Finished }

        private fun finishPreviousRunningItem() {
            items[currentIndex]?.takeIf { it.status == DownloadItemStatus.Running }?.let { item ->
                items[currentIndex] = item.copy(progress = 100, status = DownloadItemStatus.Finished)
            }
        }

        private fun ensureItem(index: Int, fileName: String?, progress: Int, status: DownloadItemStatus) {
            val existing = items[index]
            val resolvedFileName = fileName ?: existing?.fileName
            if (resolvedFileName == null) return
            val title = resolvedFileName
                .substringBeforeLast('.')
                .replace('_', ' ')
                .replace("  ", " ")
                .trim()
            items[index] = DownloadItem(
                index = index,
                total = total,
                title = title.ifBlank { resolvedFileName },
                fileName = resolvedFileName,
                progress = progress,
                status = status
            )
        }

        companion object {
            private val playlistItemRegex = Regex("""Downloading item (\d+) of (\d+)""")
            private val destinationRegex = Regex("""Destination:\s+(.+)""")
            private val downloadPercentRegex = Regex("""\[download]\s+(\d+(?:\.\d+)?)%""")
        }
    }

    private companion object {
        private const val MAX_CONCURRENT_FRAGMENTS = 4
    }
}
