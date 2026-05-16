package com.universaldownloader

import kotlinx.coroutines.flow.Flow

interface Downloader {
    fun download(url: String, options: DownloadOptions = DownloadOptions()): Flow<DownloadState>
}

data class DownloadOptions(
    val outputFormat: OutputFormat = OutputFormat.Original,
    val quality: VideoQuality = VideoQuality.Auto,
    val audioMode: AudioMode = AudioMode.VideoWithAudio,
    val audioQuality: AudioQuality = AudioQuality.Auto
)

enum class OutputFormat(val label: String) {
    Original("Source"),
    Mp4("MP4"),
    Mov("MOV"),
    Mkv("MKV"),
    Webm("WEBM"),
    M4a("M4A"),
    Mp3("MP3"),
    Ogg("OGG"),
    Wav("WAV")
}

enum class VideoQuality(val label: String) {
    Auto("Original"),
    P1080("1080p"),
    P720("720p"),
    P480("480p"),
    P360("360p")
}

enum class AudioQuality(val label: String, val kbps: Int?) {
    Auto("Original", null),
    K320("320k", 320),
    K192("192k", 192),
    K128("128k", 128),
    K96("96k", 96)
}

enum class AudioMode(val label: String) {
    VideoWithAudio("With audio"),
    AudioOnly("Audio only"),
    VideoOnly("No audio")
}

sealed interface DownloadState {
    data object Idle : DownloadState
    data class Running(
        val progress: Int,
        val message: String,
        val items: List<DownloadItem> = emptyList()
    ) : DownloadState
    data class Finished(val fileName: String) : DownloadState
    data class Stopped(val completedCount: Int) : DownloadState
    data class Failed(val reason: String) : DownloadState
}

data class DownloadItem(
    val index: Int,
    val total: Int?,
    val title: String,
    val fileName: String?,
    val progress: Int,
    val status: DownloadItemStatus
)

enum class DownloadItemStatus {
    Running,
    Finished
}
