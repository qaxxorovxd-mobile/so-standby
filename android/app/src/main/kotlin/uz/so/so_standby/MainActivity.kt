package uz.so.so_standby

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.media.MediaMetadata
import android.media.session.MediaController
import android.media.session.MediaSessionManager
import android.media.session.PlaybackState
import android.os.Build
import android.os.Bundle
import android.os.SystemClock
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class MainActivity : FlutterActivity() {
    private val channelName = "so_standby/media"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            window.attributes.layoutInDisplayCutoutMode =
                WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "hasAccess" -> result.success(hasAccess())
                    "openAccessSettings" -> {
                        val i = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                        i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(i)
                        result.success(true)
                    }
                    "nowPlaying" -> {
                        val withArt = call.argument<Boolean>("art") ?: false
                        result.success(nowPlaying(withArt))
                    }
                    "command" -> {
                        val c = controller()
                        val tc = c?.transportControls
                        when (call.argument<String>("cmd")) {
                            "play" -> tc?.play()
                            "pause" -> tc?.pause()
                            "toggle" -> {
                                if (c?.playbackState?.state == PlaybackState.STATE_PLAYING) tc?.pause() else tc?.play()
                            }
                            "next" -> tc?.skipToNext()
                            "prev" -> tc?.skipToPrevious()
                            "seek" -> {
                                val pos = (call.argument<Number>("pos") ?: 0).toLong()
                                tc?.seekTo(pos)
                            }
                        }
                        result.success(c != null)
                    }
                    "openPlayer" -> {
                        val pkg = controller()?.packageName
                        val launch = pkg?.let { packageManager.getLaunchIntentForPackage(it) }
                        if (launch != null) startActivity(launch)
                        result.success(launch != null)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("ERR", e.message, null)
            }
        }
    }

    private fun hasAccess(): Boolean {
        val flat = Settings.Secure.getString(contentResolver, "enabled_notification_listeners") ?: return false
        return flat.split(":").any {
            ComponentName.unflattenFromString(it)?.packageName == packageName
        }
    }

    private fun controller(): MediaController? {
        if (!hasAccess()) return null
        val msm = getSystemService(Context.MEDIA_SESSION_SERVICE) as MediaSessionManager
        val sessions = try {
            msm.getActiveSessions(ComponentName(this, MediaListenerService::class.java))
        } catch (e: SecurityException) {
            return null
        }
        if (sessions.isEmpty()) return null
        return sessions.firstOrNull { it.playbackState?.state == PlaybackState.STATE_PLAYING }
            ?: sessions.first()
    }

    private fun nowPlaying(withArt: Boolean): Map<String, Any?>? {
        val c = controller() ?: return null
        val md = c.metadata ?: return null
        val st = c.playbackState
        val title = md.getString(MediaMetadata.METADATA_KEY_TITLE)
            ?: md.getString(MediaMetadata.METADATA_KEY_DISPLAY_TITLE) ?: return null
        val artist = md.getString(MediaMetadata.METADATA_KEY_ARTIST)
            ?: md.getString(MediaMetadata.METADATA_KEY_ALBUM_ARTIST)
            ?: md.getString(MediaMetadata.METADATA_KEY_DISPLAY_SUBTITLE) ?: ""
        val album = md.getString(MediaMetadata.METADATA_KEY_ALBUM) ?: ""
        val duration = md.getLong(MediaMetadata.METADATA_KEY_DURATION)
        var position = st?.position ?: 0L
        val playing = st?.state == PlaybackState.STATE_PLAYING
        if (playing && st != null && st.lastPositionUpdateTime > 0) {
            position += ((SystemClock.elapsedRealtime() - st.lastPositionUpdateTime) * st.playbackSpeed).toLong()
        }
        if (duration > 0 && position > duration) position = duration
        if (position < 0) position = 0
        val appName = try {
            val ai = packageManager.getApplicationInfo(c.packageName, 0)
            packageManager.getApplicationLabel(ai).toString()
        } catch (e: Exception) {
            c.packageName
        }

        var art: ByteArray? = null
        if (withArt) {
            val bmp: Bitmap? = md.getBitmap(MediaMetadata.METADATA_KEY_ALBUM_ART)
                ?: md.getBitmap(MediaMetadata.METADATA_KEY_ART)
                ?: md.getBitmap(MediaMetadata.METADATA_KEY_DISPLAY_ICON)
            if (bmp != null) {
                val scaled = if (bmp.width > 640)
                    Bitmap.createScaledBitmap(bmp, 640, (640f * bmp.height / bmp.width).toInt(), true)
                else bmp
                val out = ByteArrayOutputStream()
                scaled.compress(Bitmap.CompressFormat.JPEG, 90, out)
                art = out.toByteArray()
            }
        }
        return mapOf(
            "title" to title,
            "artist" to artist,
            "album" to album,
            "duration" to duration,
            "position" to position,
            "playing" to playing,
            "app" to appName,
            "package" to c.packageName,
            "art" to art,
        )
    }
}
