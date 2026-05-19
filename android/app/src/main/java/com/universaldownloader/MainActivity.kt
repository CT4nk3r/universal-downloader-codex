package com.universaldownloader

import android.app.AlertDialog
import android.content.Intent
import androidx.core.content.FileProvider
import android.os.Bundle
import androidx.activity.ComponentActivity

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val initialUrl = intent.getStringExtra(EXTRA_SHARED_URL).orEmpty()
        setContentView(
            DownloadView(
                context = this,
                downloader = YtDlpDownloader(applicationContext),
                initialUrl = initialUrl,
                onShowAbout = ::showAbout
            )
        )
    }

    private fun showAbout() {
        AlertDialog.Builder(this)
            .setTitle("Universal Downloader")
            .setMessage("Version ${BuildConfig.VERSION_NAME}\n\nDiagnostics can help debug playlist, format, and download issues. Logs redact pasted links to host and length only.")
            .setPositiveButton("Email logs") { _, _ -> shareLogs(emailOnly = true) }
            .setNegativeButton("Share logs") { _, _ -> shareLogs(emailOnly = false) }
            .setNeutralButton("Close", null)
            .show()
    }

    private fun shareLogs(emailOnly: Boolean) {
        val logFile = AppLogger.currentLogFile(this)
        AppLogger.i("Share logs requested: emailOnly=$emailOnly, bytes=${logFile.length()}")
        val uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", logFile)
        val intent = if (emailOnly) {
            Intent(Intent.ACTION_SEND).apply {
                type = "message/rfc822"
                putExtra(Intent.EXTRA_EMAIL, arrayOf(SUPPORT_EMAIL))
                putExtra(Intent.EXTRA_SUBJECT, "Universal Downloader logs")
                putExtra(Intent.EXTRA_TEXT, "Attached are Universal Downloader diagnostic logs.")
                putExtra(Intent.EXTRA_STREAM, uri)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
        } else {
            Intent(Intent.ACTION_SEND).apply {
                type = "text/plain"
                putExtra(Intent.EXTRA_STREAM, uri)
                putExtra(Intent.EXTRA_SUBJECT, "Universal Downloader logs")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
        }
        startActivity(Intent.createChooser(intent, if (emailOnly) "Email logs" else "Share logs"))
    }

    companion object {
        const val EXTRA_SHARED_URL = "com.universaldownloader.EXTRA_SHARED_URL"
        private const val SUPPORT_EMAIL = "59850112+CT4nk3r@users.noreply.github.com"
    }
}
