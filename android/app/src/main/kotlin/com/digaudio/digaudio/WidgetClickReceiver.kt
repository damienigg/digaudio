package com.digaudio.digaudio

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.view.KeyEvent

/**
 * Single-tap → DOWN+UP `ACTION_MEDIA_BUTTON` pair adapter.
 *
 * PendingIntents from widget buttons fire once per tap and most
 * MediaButtonReceivers expect a complete DOWN+UP pair (matches what
 * `PlaybackTileService` from v0.20.0 does). This receiver wraps the
 * tap, expands it into the pair, and re-broadcasts to the audio
 * service's MediaButtonReceiver (declared in the manifest by the
 * audio_service plugin).
 */
class WidgetClickReceiver : BroadcastReceiver() {

    companion object {
        const val ACTION_WIDGET_CLICK = "com.digaudio.WIDGET_CLICK"
        const val EXTRA_KEYCODE = "keycode"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val keycode = intent.getIntExtra(EXTRA_KEYCODE, -1)
        if (keycode == -1) return
        val down = Intent(Intent.ACTION_MEDIA_BUTTON).apply {
            setPackage(context.packageName)
            putExtra(Intent.EXTRA_KEY_EVENT,
                KeyEvent(KeyEvent.ACTION_DOWN, keycode))
        }
        val up = Intent(Intent.ACTION_MEDIA_BUTTON).apply {
            setPackage(context.packageName)
            putExtra(Intent.EXTRA_KEY_EVENT,
                KeyEvent(KeyEvent.ACTION_UP, keycode))
        }
        context.sendBroadcast(down)
        context.sendBroadcast(up)
    }
}
