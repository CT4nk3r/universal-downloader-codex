package com.universaldownloader

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity

class ShareReceiverActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val sharedUrl = UrlExtractor.fromShareIntent(intent)
        val targetIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
            putExtra(MainActivity.EXTRA_SHARED_URL, sharedUrl)
        }

        startActivity(targetIntent)
        finish()
    }
}
