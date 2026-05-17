package com.universaldownloader

import android.app.Application
import com.yausername.ffmpeg.FFmpeg
import com.yausername.youtubedl_android.YoutubeDL
import com.yausername.youtubedl_android.YoutubeDLException

class UniversalDownloaderApp : Application() {
    override fun onCreate() {
        super.onCreate()
        AppLogger.initialize(this)

        try {
            YoutubeDL.getInstance().init(this)
            FFmpeg.getInstance().init(this)
        } catch (exception: YoutubeDLException) {
            AppLogger.e("Failed to initialize yt-dlp runtime", exception)
        }
    }
}
