package com.universaldownloader

import android.content.Context
import android.util.Log
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

internal const val APP_LOG_TAG = "UniversalDownloader"

object AppLogger {
    private const val LOG_FILE_NAME = "universal-downloader.log"
    private const val MAX_LOG_BYTES = 256 * 1024
    private val timestampFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US).apply {
        timeZone = TimeZone.getTimeZone("UTC")
    }

    @Volatile
    private var logFile: File? = null

    fun initialize(context: Context) {
        logFile = File(context.filesDir, LOG_FILE_NAME)
        i("App logger initialized")
    }

    fun d(message: String) {
        Log.d(APP_LOG_TAG, message)
        append("D", message, null)
    }

    fun i(message: String) {
        Log.i(APP_LOG_TAG, message)
        append("I", message, null)
    }

    fun w(message: String) {
        Log.w(APP_LOG_TAG, message)
        append("W", message, null)
    }

    fun e(message: String, throwable: Throwable? = null) {
        if (throwable == null) {
            Log.e(APP_LOG_TAG, message)
        } else {
            Log.e(APP_LOG_TAG, message, throwable)
        }
        append("E", message, throwable)
    }

    fun currentLogFile(context: Context): File {
        return logFile ?: File(context.filesDir, LOG_FILE_NAME).also { logFile = it }
    }

    private fun append(level: String, message: String, throwable: Throwable?) {
        val file = logFile ?: return
        runCatching {
            rotateIfNeeded(file)
            val timestamp = synchronized(timestampFormat) { timestampFormat.format(Date()) }
            val throwableText = throwable?.let { "\n${Log.getStackTraceString(it)}" }.orEmpty()
            file.appendText("$timestamp $level $message$throwableText\n")
        }.onFailure {
            Log.w(APP_LOG_TAG, "Failed to write app log file", it)
        }
    }

    private fun rotateIfNeeded(file: File) {
        if (file.length() <= MAX_LOG_BYTES) return
        val tail = file.readText().takeLast(MAX_LOG_BYTES / 2)
        file.writeText(tail)
    }
}

