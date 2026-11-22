package uz.so.so_standby

import android.app.NotificationManager
import android.content.*
import android.os.*
import android.service.notification.NotificationListenerService

object FocusSession {
    private var connection: ServiceConnection? = null
    private var state = "idle"

    fun status(context: Context): Map<String, Any> = mapOf(
        "supported" to (Build.VERSION.SDK_INT >= 29),
        "access" to context.getSystemService(NotificationManager::class.java).isNotificationPolicyAccessGranted,
        "state" to state,
    )

    fun update(context: Context, enabled: Boolean) {
        val app = context.applicationContext
        val manager = app.getSystemService(NotificationManager::class.java)
        if (!enabled || Build.VERSION.SDK_INT < 29 || !manager.isNotificationPolicyAccessGranted) {
            state = "idle"
            connection?.let { try { app.unbindService(it) } catch (_: IllegalArgumentException) { } }
            connection = null
            return
        }
        if (connection != null) return
        state = "starting"
        val next = object : ServiceConnection {
            override fun onServiceConnected(name: ComponentName, binder: IBinder) {
                if (connection !== this) return
                val owner = this
                val reply = Messenger(Handler(Looper.getMainLooper()) { message ->
                    if (connection === owner) state = message.data.getString("status") ?: "error"
                    true
                })
                try {
                    Messenger(binder).send(Message.obtain(null, StandbyFocusService.START).apply { replyTo = reply })
                } catch (_: RemoteException) { state = "error" }
            }
            override fun onServiceDisconnected(name: ComponentName) { if (connection === this) state = "error" }
            override fun onBindingDied(name: ComponentName) {
                if (connection === this) update(app, false)
            }
        }
        connection = next
        try {
            if (!app.bindService(Intent(app, StandbyFocusService::class.java), next, Context.BIND_AUTO_CREATE)) {
                connection = null
                state = "error"
            }
        } catch (_: Exception) {
            connection = null
            state = "error"
        }
    }

    fun canPresent(context: Context, ranking: NotificationListenerService.Ranking): Boolean {
        if (state != "active" || Build.VERSION.SDK_INT < 29) return false
        val manager = context.getSystemService(NotificationManager::class.java)
        // Do not assume a successful API call means Android suppressed this banner.
        // Bypass-DND channels and OEM exceptions stay system-managed, without a duplicate.
        return try {
            manager.isNotificationPolicyAccessGranted && StandbyFocusService.matchesPolicy(manager) &&
                !ranking.matchesInterruptionFilter() &&
                ranking.suppressedVisualEffects and NotificationManager.Policy.SUPPRESSED_EFFECT_PEEK != 0
        } catch (_: SecurityException) { false }
    }
}
