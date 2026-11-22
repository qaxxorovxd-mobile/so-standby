package uz.so.so_standby

import android.app.AutomaticZenRule
import android.app.NotificationManager
import android.app.Service
import android.content.ComponentName
import android.content.Intent
import android.net.Uri
import android.os.*
import android.service.notification.Condition
import android.service.notification.ZenPolicy

/** A bound process owns the rule, so losing the UI process also releases Focus. */
class StandbyFocusService : Service() {
    companion object {
        const val START = 1
        private val conditionId = Uri.parse("condition://uz.so.so_standby/foreground")

        fun matchesPolicy(manager: NotificationManager): Boolean {
            if (Build.VERSION.SDK_INT < 29 || manager.currentInterruptionFilter != NotificationManager.INTERRUPTION_FILTER_PRIORITY) return false
            val policy = manager.consolidatedNotificationPolicy
            val categories = NotificationManager.Policy.PRIORITY_CATEGORY_ALARMS or
                NotificationManager.Policy.PRIORITY_CATEGORY_MEDIA or NotificationManager.Policy.PRIORITY_CATEGORY_SYSTEM or
                NotificationManager.Policy.PRIORITY_CATEGORY_CALLS or NotificationManager.Policy.PRIORITY_CATEGORY_REPEAT_CALLERS
            val legacy = NotificationManager.Policy.SUPPRESSED_EFFECT_SCREEN_ON or NotificationManager.Policy.SUPPRESSED_EFFECT_SCREEN_OFF
            val effects = NotificationManager.Policy.SUPPRESSED_EFFECT_PEEK or NotificationManager.Policy.SUPPRESSED_EFFECT_FULL_SCREEN_INTENT
            // A more restrictive, overlapping user mode must not be bypassed by our UI.
            return policy.priorityCategories == categories &&
                policy.priorityCallSenders == NotificationManager.Policy.PRIORITY_SENDERS_ANY &&
                policy.suppressedVisualEffects and legacy.inv() == effects
        }
    }

    private val manager get() = getSystemService(NotificationManager::class.java)
    private var ruleId: String? = null
    private val messenger = Messenger(Handler(Looper.getMainLooper()) { message ->
        if (message.what == START) {
            val status = activate()
            try {
                message.replyTo?.send(Message.obtain().apply {
                    data = Bundle().apply { putString("status", status) }
                })
            } catch (_: RemoteException) { deactivate() }
        }
        true
    })

    override fun onBind(intent: Intent): IBinder = messenger.binder

    private fun activate(): String {
        if (Build.VERSION.SDK_INT < 29) return "unsupported"
        if (!manager.isNotificationPolicyAccessGranted) return "permission"
        if (ruleId != null) return "active"
        return try {
            // Remove only our stale rule after an abnormal termination or reboot.
            manager.automaticZenRules.filterValues {
                it.conditionId == conditionId && it.configurationActivity == ComponentName(this, MainActivity::class.java)
            }.keys.forEach { manager.removeAutomaticZenRule(it) }
            if (manager.currentInterruptionFilter != NotificationManager.INTERRUPTION_FILTER_ALL) return "otherDnd"
            val builder = ZenPolicy.Builder().disallowAllSounds()
                .allowAlarms(true).allowMedia(true).allowSystem(true)
                .allowCalls(ZenPolicy.PEOPLE_TYPE_ANYONE).allowRepeatCallers(true)
                .showAllVisualEffects().showPeeking(false).showFullScreenIntent(false)
            if (Build.VERSION.SDK_INT >= 30) builder.allowConversations(ZenPolicy.CONVERSATION_SENDERS_NONE)
            if (Build.VERSION.SDK_INT >= 35) builder.allowPriorityChannels(false)
            val rule = AutomaticZenRule(
                "So StandBy", null, ComponentName(this, MainActivity::class.java), conditionId,
                builder.build(), NotificationManager.INTERRUPTION_FILTER_PRIORITY, true,
            )
            ruleId = manager.addAutomaticZenRule(rule)
            manager.setAutomaticZenRuleState(ruleId!!, Condition(conditionId, "StandBy is open", Condition.STATE_TRUE))
            "active"
        } catch (_: Exception) {
            deactivate()
            "error"
        }
    }

    private fun deactivate() {
        val id = ruleId ?: return
        ruleId = null
        if (Build.VERSION.SDK_INT < 29) return
        try {
            manager.setAutomaticZenRuleState(id, Condition(conditionId, "StandBy is closed", Condition.STATE_FALSE))
        } catch (_: Exception) { }
        try { manager.removeAutomaticZenRule(id) } catch (_: Exception) { }
    }

    override fun onUnbind(intent: Intent): Boolean {
        deactivate()
        return false
    }

    override fun onDestroy() {
        deactivate()
        super.onDestroy()
    }
}
