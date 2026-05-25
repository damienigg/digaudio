package com.digaudio.digaudio

import android.content.Intent
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import android.view.KeyEvent

/**
 * Quick Settings tile that toggles digaudio playback from anywhere
 * on the device.
 *
 * The tile sends a paired DOWN/UP `ACTION_MEDIA_BUTTON` broadcast
 * with `KEYCODE_MEDIA_PLAY_PAUSE`, which is picked up by the
 * `com.ryanheise.audioservice.MediaButtonReceiver` (declared in the
 * manifest by the `audio_service` plugin) and routed to the running
 * AudioService → toggles `play()` / `pause()` on the engine. No
 * direct binding needed — relies entirely on Android's standard
 * media-button plumbing.
 *
 * Label/state sync is intentionally minimal in v1: we set the tile
 * to INACTIVE with a static "digaudio" label whenever the system
 * asks us to render. Two-way sync with the live PlaybackState would
 * require either a NotificationListenerService (intrusive runtime
 * permission) or a bound connection to the audio service, both of
 * which add complexity the user can already get from the existing
 * notification + lockscreen controls.
 *
 * User onboarding: Android API doesn't let an app auto-add its tile
 * to Quick Settings. The user has to drag it in from the "edit
 * tiles" mode the first time. CHANGELOG covers this.
 */
class PlaybackTileService : TileService() {

    override fun onClick() {
        super.onClick()

        val downIntent = Intent(Intent.ACTION_MEDIA_BUTTON).apply {
            setPackage(packageName)
            putExtra(
                Intent.EXTRA_KEY_EVENT,
                KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE)
            )
        }
        val upIntent = Intent(Intent.ACTION_MEDIA_BUTTON).apply {
            setPackage(packageName)
            putExtra(
                Intent.EXTRA_KEY_EVENT,
                KeyEvent(KeyEvent.ACTION_UP, KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE)
            )
        }
        sendBroadcast(downIntent)
        sendBroadcast(upIntent)
    }

    override fun onStartListening() {
        super.onStartListening()
        // Cold-bind: stamp the tile so it shows our label + icon even
        // when nothing's playing yet. The icon comes from the
        // `android:icon` attr in the manifest, so just refresh state.
        qsTile?.apply {
            state = Tile.STATE_INACTIVE
            label = "digaudio"
            updateTile()
        }
    }
}
