package com.universaldownloader

import android.os.Bundle
import androidx.activity.ComponentActivity

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val initialUrl = intent.getStringExtra(EXTRA_SHARED_URL).orEmpty()
        setContentView(DownloadView(this, YtDlpDownloader(applicationContext), initialUrl))
    }

    companion object {
        const val EXTRA_SHARED_URL = "com.universaldownloader.EXTRA_SHARED_URL"
    }
}

