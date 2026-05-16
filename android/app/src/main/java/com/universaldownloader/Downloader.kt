package com.universaldownloader

import kotlinx.coroutines.flow.Flow

interface Downloader {
    fun download(url: String, options: DownloadOptions = DownloadOptions()): Flow<DownloadState>
}

data class DownloadOptions(
    val outputFormat: OutputFormat = OutputFormat.Original,
    val quality: VideoQuality = VideoQuality.Auto,
    val audioMode: AudioMode = AudioMode.VideoWithAudio
)

enum class OutputFormat(val label: String) {
    Original("Orig"),
    Mp4("MP4"),
    Mov("MOV"),
    Mkv("MKV"),
    M4a("M4A"),
    Mp3("MP3"),
    Ogg("OGG"),
    Wav("WAV")
}

enum class VideoQuality(val label: String) {
    Auto("Best"),
    P1080("1080p"),
    P720("720p"),
    P480("480p"),
    P360("360p")
}

enum class AudioMode(val label: String) {
    VideoWithAudio("With audio"),
    AudioOnly("Audio only"),
    VideoOnly("No audio")
}

sealed interface DownloadState {
    data object Idle : DownloadState
    data class Running(val progress: Int, val message: String) : DownloadState
    data class Finished(val fileName: String) : DownloadState
    data class Failed(val reason: String) : DownloadState
}
