package com.universaldownloader

import android.content.Context
import android.os.Environment
import com.yausername.youtubedl_android.YoutubeDL
import com.yausername.youtubedl_android.YoutubeDLRequest
import java.io.File
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.launch

class YtDlpDownloader(
    private val context: Context
) : Downloader {
    override fun download(url: String, options: DownloadOptions): Flow<DownloadState> = callbackFlow {
        val normalized = url.trim()
        if (!UrlExtractor.isSupportedUrl(normalized)) {
            trySend(DownloadState.Failed("No downloadable URL found."))
            close()
            return@callbackFlow
        }

        trySend(DownloadState.Running(5, "Preparing download"))

        val job = launch(Dispatchers.IO) {
            try {
                val downloadDir = File(
                    Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS),
                    "UniversalDownloader"
                ).apply { mkdirs() }

                val request = YoutubeDLRequest(normalized).apply {
                    addOption("-P", downloadDir.absolutePath)
                    addOption("-o", "%(title).180B.%(ext)s")
                    addOption("-f", options.formatSelector())
                    addOption("--no-mtime")
                    addOption("--restrict-filenames")
                    addOption("--newline")
                    when (options.audioMode) {
                        AudioMode.VideoWithAudio -> addOption("--merge-output-format", "mp4")
                        AudioMode.AudioOnly -> {
                            addOption("-x")
                            addOption("--audio-format", "m4a")
                        }
                        AudioMode.VideoOnly -> Unit
                    }
                }

                YoutubeDL.getInstance().execute(request) { progress, _, line ->
                    val percent = progress.toInt().coerceIn(0, 100)
                    trySend(DownloadState.Running(percent, line.ifBlank { "Downloading media" }))
                }

                val fileName = downloadDir
                    .listFiles()
                    ?.maxByOrNull { it.lastModified() }
                    ?.name
                    ?: "Downloads/UniversalDownloader"

                trySend(DownloadState.Finished(fileName))
            } catch (exception: Exception) {
                trySend(DownloadState.Failed(exception.message ?: "Download failed."))
            } finally {
                close()
            }
        }

        awaitClose { job.cancel() }
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
}
