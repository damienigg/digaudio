package com.digaudio.digaudio

import android.content.ContentUris
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaMetadataRetriever
import android.provider.MediaStore
import android.util.Size
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.ByteArrayOutputStream

/**
 * Native MediaStore query for digaudio's local library.
 *
 * Two methods only — we own this channel so we expose exactly the fields we
 * use (no third-party plugin rot, no AGP/Gradle compatibility coupling).
 *  - `getAllSongs`            → List<Map> with id, title, artist*, album*, duration, track, mime
 *  - `getArtwork(id, size)`   → PNG bytes (Uint8List) or null
 *
 * minSdk is 29: `ContentResolver.loadThumbnail` exists, so artwork is one
 * line. No legacy `albumart` URI fallback needed.
 */
class MediaStoreChannel(private val context: Context) : MethodCallHandler {

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, "digaudio/media_store").setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "getAllSongs" -> result.success(getAllSongs())
            "getArtwork" -> {
                val id = (call.argument<Number>("id") ?: 0L).toLong()
                val size = call.argument<Int>("size") ?: 400
                result.success(getArtwork(id, size))
            }
            else -> result.notImplemented()
        }
    }

    private fun getAllSongs(): List<Map<String, Any?>> {
        val cols = arrayOf(
            MediaStore.Audio.Media._ID,
            MediaStore.Audio.Media.TITLE,
            MediaStore.Audio.Media.ARTIST,
            MediaStore.Audio.Media.ARTIST_ID,
            MediaStore.Audio.Media.ALBUM,
            MediaStore.Audio.Media.ALBUM_ID,
            MediaStore.Audio.Media.DURATION,
            MediaStore.Audio.Media.TRACK,
            MediaStore.Audio.Media.MIME_TYPE,
        )
        val sel = "${MediaStore.Audio.Media.IS_MUSIC} != 0"
        val out = ArrayList<Map<String, Any?>>(256)
        context.contentResolver.query(
            MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
            cols, sel, null,
            "${MediaStore.Audio.Media.TITLE} COLLATE NOCASE ASC",
        )?.use { c ->
            while (c.moveToNext()) {
                out.add(
                    mapOf(
                        "id" to c.getLong(0),
                        "title" to c.getString(1),
                        "artist" to c.getString(2),
                        "artistId" to c.getLong(3),
                        "album" to c.getString(4),
                        "albumId" to c.getLong(5),
                        "duration" to c.getLong(6),
                        "track" to c.getInt(7),
                        "mime" to c.getString(8),
                    ),
                )
            }
        }
        return out
    }

    private fun getArtwork(id: Long, size: Int): ByteArray? {
        val uri = ContentUris.withAppendedId(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, id)
        // Path 1: ContentResolver.loadThumbnail — uses MediaStore's
        // own cache + extractor. Fast when it works, but on many
        // devices it returns null / throws for MP3s whose embedded
        // APIC frame wasn't pre-indexed by the system (logcat:
        // "getEmbeddedPicture: extractAlbumArt was failed or the
        // media file has no albumart image").
        try {
            val bmp = context.contentResolver.loadThumbnail(uri, Size(size, size), null)
            return ByteArrayOutputStream().use {
                bmp.compress(Bitmap.CompressFormat.PNG, 100, it)
                it.toByteArray()
            }
        } catch (_: Throwable) {
            // Fall through to MediaMetadataRetriever.
        }
        // Path 2: open the file ourselves and read the embedded
        // picture directly. This works for MP3s whose APIC frame
        // exists but MediaStore failed to thumbnail. Downscales to
        // the requested size to keep the round-trip bytes small.
        return try {
            val mmr = MediaMetadataRetriever()
            try {
                mmr.setDataSource(context, uri)
                val raw = mmr.embeddedPicture ?: return null
                val full = BitmapFactory.decodeByteArray(raw, 0, raw.size) ?: return null
                val scaled = if (full.width <= size && full.height <= size) {
                    full
                } else {
                    Bitmap.createScaledBitmap(full, size, size, true)
                }
                ByteArrayOutputStream().use {
                    scaled.compress(Bitmap.CompressFormat.PNG, 90, it)
                    it.toByteArray()
                }
            } finally {
                mmr.release()
            }
        } catch (_: Throwable) {
            null
        }
    }
}
