package uz.so.so_standby

import android.app.KeyguardManager
import android.app.Notification
import android.app.NotificationManager
import android.app.PendingIntent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import java.io.ByteArrayOutputStream

/** Uses the existing notification access grant for media and foreground StandBy banners. */
class MediaListenerService : NotificationListenerService() {
    companion object {
        var instance: MediaListenerService? = null
            private set
        var onEvent: ((Map<String, Any?>) -> Unit)? = null
            set(value) {
                field = value
                if (value == null) instance?.clearHandoffs()
            }
        var foreground = false
            set(value) {
                field = value
                if (!value) instance?.clearHandoffs()
            }
        var enabled = false
            set(value) {
                field = value
                if (!value) instance?.clearHandoffs()
            }
        var showPreviews = true
    }

    // Bounded fingerprints, never a history of message bodies.
    private val seen = object : LinkedHashMap<String, Int>(128, .75f, true) {
        override fun removeEldestEntry(eldest: MutableMap.MutableEntry<String, Int>?) = size > 128
    }
    private val keyguard get() = getSystemService(KeyguardManager::class.java)
    private val handler = Handler(Looper.getMainLooper())
    private val canPresent get() = foreground && enabled && onEvent != null

    private class Handoff(
        val postTime: Long,
        val payload: Map<String, Any?>,
        val intent: PendingIntent?,
        var confirmed: Boolean = false,
    )

    // Only the short-lived banner actions survive removal from Android's shade.
    private val handoffs = object : LinkedHashMap<String, Handoff>(16, .75f, true) {
        override fun removeEldestEntry(eldest: MutableMap.MutableEntry<String, Handoff>?): Boolean {
            if (size <= 16) return false
            eldest?.value?.let { handler.removeCallbacksAndMessages(it) }
            eldest?.key?.let { seen.remove(it) }
            return true
        }
    }

    private fun clearHandoffs() {
        handler.removeCallbacksAndMessages(null)
        handoffs.keys.forEach { seen.remove(it) }
        handoffs.clear()
    }

    override fun onListenerConnected() {
        instance = this
        clearHandoffs()
        seen.clear()
        // Never replay the notification shade when access is enabled or the service reconnects.
        activeNotifications?.forEach { seen[it.key] = fingerprint(it.notification) }
    }

    override fun onListenerDisconnected() {
        clearHandoffs()
        if (instance === this) instance = null
        seen.clear()
        onEvent?.invoke(mapOf("type" to "clear"))
    }

    override fun onDestroy() {
        clearHandoffs()
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
        if (!canPresent) return
        if (sbn.packageName == packageName || !sbn.isClearable || sbn.isOngoing ||
            n.flags and Notification.FLAG_GROUP_SUMMARY != 0 ||
            n.category == Notification.CATEGORY_TRANSPORT || n.category == Notification.CATEGORY_CALL ||
            n.category == Notification.CATEGORY_ALARM || n.fullScreenIntent != null) return
        val ranking = Ranking()
        if (!rankingMap.getRanking(sbn.key, ranking) || !ranking.matchesInterruptionFilter()) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N && ranking.importance < NotificationManager.IMPORTANCE_DEFAULT) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P && ranking.isSuspended) return
        val locked = keyguard.isKeyguardLocked
        if (n.visibility == Notification.VISIBILITY_SECRET) return
        val rawTitle = text(n, Notification.EXTRA_TITLE)
        val rawBody = body(n)
        if (rawTitle.isBlank() && rawBody.isBlank()) return
        if (previous == signature) {
            // Some apps repost an identical notification after it has been consumed.
            // Remove that duplicate too, without replaying the StandBy animation.
            if (handoffs.containsKey(sbn.key)) {
                try { cancelNotification(sbn.key) } catch (_: SecurityException) { }
            }
            return
        }
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
        val payload = mapOf(
            "type" to "posted", "key" to sbn.key, "app" to app,
            "title" to if (redacted) "New notification" else rawTitle.ifBlank { app }.take(140),
            "body" to if (redacted) (if (locked) "Unlock your phone to view it." else "Message previews are hidden.") else rawBody.take(300),
            "icon" to icon, "canOpen" to (!locked && n.contentIntent != null), "redacted" to redacted,
        )
        val handoff = Handoff(sbn.postTime, payload, n.contentIntent)
        handoffs.put(sbn.key, handoff)?.let { handler.removeCallbacksAndMessages(it) }
        try {
            // Remove only the notification we can actually present. Never cancel all,
            // change DND, or modify another app's notification channel settings.
            cancelNotification(sbn.key)
        } catch (_: SecurityException) {
            handoffs.remove(sbn.key)
            return
        }
        handler.postAtTime({
            // If Android declines removal (e.g. a protected notification), leave
            // presentation to the system instead of showing two banners.
            if (handoffs[sbn.key] === handoff && !handoff.confirmed) {
                handoffs.remove(sbn.key)
                handler.removeCallbacksAndMessages(handoff)
            }
        }, handoff, SystemClock.uptimeMillis() + 1500)
        handler.postAtTime({
            if (handoffs[sbn.key] === handoff) {
                handoffs.remove(sbn.key)
                seen.remove(sbn.key)
            }
        }, handoff, SystemClock.uptimeMillis() + 60_000)
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification, rankingMap: RankingMap) {
        // Android 7 does not supply a removal reason.
        removed(sbn, null)
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification, rankingMap: RankingMap, reason: Int) {
        removed(sbn, reason)
    }

    private fun removed(sbn: StatusBarNotification, reason: Int?) {
        val handoff = handoffs[sbn.key]
        if (handoff != null && (reason == null || reason == REASON_LISTENER_CANCEL)) {
            if (handoff.confirmed || sbn.postTime != handoff.postTime) return
            handoff.confirmed = true
            // Give SystemUI time to finish removing its heads-up surface before
            // expanding ours. Its removal callback must not dismiss our new card.
            handler.postAtTime({
                if (canPresent && handoffs[sbn.key] === handoff) {
                    // Recheck privacy after the handoff, in case the phone locked.
                    val event = if (keyguard.isKeyguardLocked || !showPreviews) handoff.payload + mapOf(
                        "title" to "New notification",
                        "body" to if (keyguard.isKeyguardLocked) "Unlock your phone to view it." else "Message previews are hidden.",
                        "redacted" to true,
                        "canOpen" to false,
                    ) else handoff.payload
                    onEvent?.invoke(event)
                }
            }, handoff, SystemClock.uptimeMillis() + 180)
            return
        }
        handoffs.remove(sbn.key)?.let { handler.removeCallbacksAndMessages(it) }
        seen.remove(sbn.key)
        onEvent?.invoke(mapOf("type" to "removed", "key" to sbn.key))
    }

    fun openNotification(key: String): Boolean {
        if (!foreground || !enabled || keyguard.isKeyguardLocked) return false
        return try {
            val intent = handoffs[key]?.takeIf { it.confirmed }?.intent ?: return false
            intent.send()
            true
        } catch (_: Exception) { false }
    }
}
