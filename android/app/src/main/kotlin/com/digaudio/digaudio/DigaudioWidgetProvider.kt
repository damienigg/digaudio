package com.digaudio.digaudio

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.view.KeyEvent
import android.widget.RemoteViews

/**
 * Homescreen mini-player widget. Stateless on the Android side — all
 * metadata + play state flows from Dart via [WidgetChannel.pushUpdate],
 * which calls back into [refresh] to mutate the RemoteViews tree.
 *
 * Click targets:
 *   - root (icon + text column) → opens MainActivity
 *   - play/pause + skip-next → fires a paired DOWN/UP media-button
 *     broadcast via [WidgetClickReceiver]; the AudioService's
 *     MediaButtonReceiver (declared by the audio_service plugin)
 *     picks it up.
 *
 * Why a relay receiver instead of direct ACTION_MEDIA_BUTTON intents
 * on the buttons: a single PendingIntent fires once per tap and most
 * MediaButtonReceivers expect a DOWN+UP pair (Quick Settings tile
 * `PlaybackTileService` from v0.20.0 already established this).
 * The receiver fans the single tap into both events.
 */
class DigaudioWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        manager: AppWidgetManager,
        ids: IntArray
    ) {
        // Cold-bind: stamp every widget instance with the static
        // skeleton + PendingIntents. Live metadata arrives later when
        // Dart calls pushUpdate.
        for (id in ids) {
            refresh(context, manager, id,
                title = "digaudio", artist = "Open the app", isPlaying = false)
        }
    }

    companion object {
        /**
         * Push the latest engine state to every active widget instance.
         * Called from [WidgetChannel] when Dart side broadcasts a track
         * change or play-state change. Safe to call when there are no
         * widget instances — getAppWidgetIds returns an empty array.
         */
        fun pushUpdate(
            context: Context,
            title: String?,
            artist: String?,
            isPlaying: Boolean
        ) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, DigaudioWidgetProvider::class.java)
            )
            for (id in ids) {
                refresh(context, manager, id,
                    title = title ?: "digaudio",
                    artist = artist ?: "Open the app",
                    isPlaying = isPlaying)
            }
        }

        private fun refresh(
            context: Context,
            manager: AppWidgetManager,
            id: Int,
            title: String,
            artist: String,
            isPlaying: Boolean
        ) {
            val views = RemoteViews(context.packageName, R.layout.digaudio_widget)
            views.setTextViewText(R.id.widget_title, title)
            views.setTextViewText(R.id.widget_artist, artist)
            views.setImageViewResource(
                R.id.widget_play,
                if (isPlaying)
                    android.R.drawable.ic_media_pause
                else
                    android.R.drawable.ic_media_play
            )
            views.setOnClickPendingIntent(R.id.widget_root, launchAppIntent(context))
            views.setOnClickPendingIntent(R.id.widget_play,
                clickIntent(context, KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE))
            views.setOnClickPendingIntent(R.id.widget_skip_next,
                clickIntent(context, KeyEvent.KEYCODE_MEDIA_NEXT))
            manager.updateAppWidget(id, views)
        }

        private fun launchAppIntent(context: Context): PendingIntent {
            val intent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            return PendingIntent.getActivity(
                context, 0, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        }

        private fun clickIntent(context: Context, keycode: Int): PendingIntent {
            val intent = Intent(WidgetClickReceiver.ACTION_WIDGET_CLICK).apply {
                setPackage(context.packageName)
                putExtra(WidgetClickReceiver.EXTRA_KEYCODE, keycode)
            }
            return PendingIntent.getBroadcast(
                context, keycode, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        }
    }
}
