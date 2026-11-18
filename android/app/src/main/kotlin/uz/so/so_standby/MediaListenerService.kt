package uz.so.so_standby

import android.service.notification.NotificationListenerService

/** Exists so the user can grant notification access, which unlocks MediaSession visibility. */
class MediaListenerService : NotificationListenerService()
