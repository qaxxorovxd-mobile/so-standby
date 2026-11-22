package uz.so.so_standby

import android.app.KeyguardManager
import android.app.Notification
import android.app.NotificationManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.os.Build
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import java.io.ByteArrayOutputStream

/** Uses the existing notification access grant for media and foreground StandBy banners. */
class MediaListenerService : NotificationListenerService() {
    companion object {
        var instance: MediaListenerService? = null
            private set
        var onEvent: ((Map<String, Any?>) -> Unit)? = null
        var foreground = false
        var enabled = false
        var showPreviews = true
    }

    // Bounded fingerprints, never a history of message bodies.
    private val seen = object : LinkedHashMap<String, Int>(128, .75f, true) {
        override fun removeEldestEntry(eldest: MutableMap.MutableEntry<String, Int>?) = size > 128
    }
    private val keyguard get() = getSystemService(KeyguardManager::class.java)

    override fun onListenerConnected() {
        instance = this
        seen.clear()
        // Never replay the notification shade when access is enabled or the service reconnects.
        activeNotifications?.forEach { seen[it.key] = fingerprint(it.notification) }
    }

    override fun onListenerDisconnected() {
        if (instance === this) instance = null
        seen.clear()
        onEvent?.invoke(mapOf("type" to "clear"))
    }

    override fun onDestroy() {
        if (instance === this) instance = null
        seen.clear()
        super.onDestroy()
    }

    private fun text(n: Notification, key: String): String =
        n.extras?.getCharSequence(key)?.toString()?.trim().orEmpty()

    private fun body(n: Notification): String = text(n, Notification.EXTRA_BIG_TEXT)
        .ifBlank { text(n, Notification.EXTRA_TEXT) }

    private fun fingerprint(n: Notification) =
        (text(n, Notification.EXTRA_TITLE) + '\u0000' + body(n)).hashCode()

    override fun onNotificationPosted(sbn: StatusBarNotification, rankingMap: RankingMap) {
        val n = sbn.notification
        val signature = fingerprint(n)
        val previous = seen.put(sbn.key, signature)
        if (previous == signature || !foreground || !enabled || onEvent == null) return
        if (sbn.packageName == packageName || sbn.isOngoing ||
            n.flags and Notification.FLAG_GROUP_SUMMARY != 0 || n.category == Notification.CATEGORY_TRANSPORT) return
        val ranking = Ranking()
        if (!rankingMap.getRanking(sbn.key, ranking) || !ranking.matchesInterruptionFilter()) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N && ranking.importance < NotificationManager.IMPORTANCE_DEFAULT) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P && ranking.isSuspended) return
        val locked = keyguard.isKeyguardLocked
        if (n.visibility == Notification.VISIBILITY_SECRET) return
        val rawTitle = text(n, Notification.EXTRA_TITLE)
        val rawBody = body(n)
        if (rawTitle.isBlank() && rawBody.isBlank()) return
        val app = try {
            packageManager.getApplicationLabel(packageManager.getApplicationInfo(sbn.packageName, 0)).toString().take(60)
        } catch (_: Exception) { sbn.packageName }
        val redacted = locked || !showPreviews
        val icon = try {
            val drawable = packageManager.getApplicationIcon(sbn.packageName)
            val bitmap = Bitmap.createBitmap(96, 96, Bitmap.Config.ARGB_8888)
            drawable.setBounds(0, 0, 96, 96)
            drawable.draw(Canvas(bitmap))
            val output = ByteArrayOutputStream()
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, output)
            bitmap.recycle()
            output.toByteArray()
        } catch (_: Exception) { null }
        onEvent?.invoke(mapOf(
            "type" to "posted", "key" to sbn.key, "app" to app,
            "title" to if (redacted) "New notification" else rawTitle.ifBlank { app }.take(140),
            "body" to if (redacted) (if (locked) "Unlock your phone to view it." else "Message previews are hidden.") else rawBody.take(300),
            "icon" to icon, "canOpen" to (!locked && n.contentIntent != null), "redacted" to redacted,
        ))
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification) {
        seen.remove(sbn.key)
        onEvent?.invoke(mapOf("type" to "removed", "key" to sbn.key))
    }

    fun openNotification(key: String): Boolean {
        if (!foreground || !enabled || keyguard.isKeyguardLocked) return false
        return try {
            val notification = activeNotifications?.firstOrNull { it.key == key }?.notification ?: return false
            val intent = notification.contentIntent ?: return false
            intent.send()
            true
        } catch (_: Exception) { false }
    }
}
