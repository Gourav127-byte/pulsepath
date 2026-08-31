package com.example.pulsepath

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Binder
import android.os.Build
import android.os.Bundle
import android.os.IBinder
import android.os.SystemClock
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import java.time.Instant
import java.time.format.DateTimeFormatter

class LocationRecordingService : Service(), LocationListener {

    enum class RecorderState {
        IDLE,
        RECORDING,
        FINALIZED,
        INTERRUPTED
    }

    enum class ActivityType {
        WALK,
        RUN;

        companion object {
            fun fromString(value: String?): ActivityType? {
                return when (value?.lowercase()) {
                    "walk" -> WALK
                    "run" -> RUN
                    else -> null
                }
            }
        }
    }

    inner class LocalBinder : Binder() {
        fun getService(): LocationRecordingService = this@LocationRecordingService
    }

    private val binder = LocalBinder()
    private var locationManager: LocationManager? = null
    private lateinit var sessionStore: DistanceSessionStore

    var state: RecorderState = RecorderState.IDLE
        private set

    var currentActivityType: ActivityType? = null
        private set

    var activeSessionId: String? = null
        private set

    var currentInterruptionReason: String? = null
        private set

    private var stateChangeListener: ((RecorderState, ActivityType?, String?) -> Unit)? = null

    companion object {
        const val CHANNEL_ID = "pulsepath_distance_recording"
        const val CHANNEL_NAME = "Distance Recording"
        const val NOTIFICATION_ID = 2026
        const val ACTION_START = "com.example.pulsepath.ACTION_START"
        const val ACTION_FINISH = "com.example.pulsepath.ACTION_FINISH"
        const val EXTRA_ACTIVITY_TYPE = "activity_type"

        // Default location update cadence (Implementation default pending physical evidence)
        const val MIN_TIME_INTERVAL_MS = 1000L
        const val MIN_DISTANCE_METERS = 0f

        @Volatile
        var instance: LocationRecordingService? = null
            private set
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
        sessionStore = DistanceSessionStore(applicationContext)
        locationManager = getSystemService(Context.LOCATION_SERVICE) as? LocationManager
        createNotificationChannel()
        recoverOrRestoreSession()
    }

    override fun onBind(intent: Intent?): IBinder {
        return binder
    }

    fun setStateListener(listener: ((RecorderState, ActivityType?, String?) -> Unit)?) {
        stateChangeListener = listener
    }

    private fun recoverOrRestoreSession() {
        val activeSession = sessionStore.getActiveSession()
        if (activeSession != null) {
            activeSessionId = activeSession.sessionId
            currentActivityType = ActivityType.fromString(activeSession.activityType)
            val currentElapsed = SystemClock.elapsedRealtime()

            // Monotonic reset / reboot detection
            val isReboot = currentElapsed < activeSession.startElapsedRealtimeMs ||
                    (activeSession.latestElapsedRealtimeMs != null && currentElapsed < activeSession.latestElapsedRealtimeMs)

            val gapReason = if (isReboot) {
                DistanceSessionStore.REASON_MONOTONIC_RESET
            } else {
                DistanceSessionStore.REASON_SERVICE_RECOVERED
            }

            // Insert GAP and start new segment for process/reboot recovery
            sessionStore.insertGap(activeSession.sessionId, gapReason, currentElapsed)

            val hasFinePerm = ContextCompat.checkSelfPermission(this, android.Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
            val isGpsOn = locationManager?.isProviderEnabled(LocationManager.GPS_PROVIDER) == true

            if (hasFinePerm && isGpsOn) {
                // Resume location listening under new segment
                try {
                    locationManager?.requestLocationUpdates(
                        LocationManager.GPS_PROVIDER,
                        MIN_TIME_INTERVAL_MS,
                        MIN_DISTANCE_METERS,
                        this
                    )
                    updateState(RecorderState.RECORDING, currentActivityType, activeSession.sessionId, null)
                } catch (e: SecurityException) {
                    sessionStore.insertGap(activeSession.sessionId, DistanceSessionStore.REASON_PERMISSION_REVOKED, currentElapsed)
                    sessionStore.updateSessionState(activeSession.sessionId, "INTERRUPTED", DistanceSessionStore.REASON_PERMISSION_REVOKED)
                    updateState(RecorderState.INTERRUPTED, currentActivityType, activeSession.sessionId, DistanceSessionStore.REASON_PERMISSION_REVOKED)
                }
            } else {
                val reason = if (!hasFinePerm) DistanceSessionStore.REASON_PERMISSION_REVOKED else DistanceSessionStore.REASON_GPS_DISABLED
                sessionStore.updateSessionState(activeSession.sessionId, "INTERRUPTED", reason)
                updateState(RecorderState.INTERRUPTED, currentActivityType, activeSession.sessionId, reason)
            }
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action
        when (action) {
            ACTION_START -> {
                val typeStr = intent.getStringExtra(EXTRA_ACTIVITY_TYPE)
                val type = ActivityType.fromString(typeStr) ?: ActivityType.WALK
                startRecordingInternal(type)
            }
            ACTION_FINISH -> {
                finishRecordingInternal()
            }
        }
        return START_STICKY
    }

    fun startRecording(activityType: ActivityType): Boolean {
        return startRecordingInternal(activityType)
    }

    fun finishRecording(): Boolean {
        return finishRecordingInternal()
    }

    private fun startRecordingInternal(activityType: ActivityType): Boolean {
        // Idempotency: If already recording active session, return true safely
        if (state == RecorderState.RECORDING && activeSessionId != null) {
            return true
        }

        val currentElapsed = SystemClock.elapsedRealtime()

        // Explicit SecurityException / runtime permission-loss handling
        if (ContextCompat.checkSelfPermission(this, android.Manifest.permission.ACCESS_FINE_LOCATION)
            != PackageManager.PERMISSION_GRANTED) {
            val session = activeSessionId?.let { sessionStore.getSession(it) }
                ?: sessionStore.createSession(activityType.name.lowercase(), currentElapsed)
            activeSessionId = session.sessionId
            sessionStore.insertGap(session.sessionId, DistanceSessionStore.REASON_PERMISSION_REVOKED, currentElapsed)
            sessionStore.updateSessionState(session.sessionId, "INTERRUPTED", DistanceSessionStore.REASON_PERMISSION_REVOKED)
            updateState(RecorderState.INTERRUPTED, activityType, session.sessionId, DistanceSessionStore.REASON_PERMISSION_REVOKED)
            return false
        }

        val lm = locationManager
        if (lm == null || !lm.isProviderEnabled(LocationManager.GPS_PROVIDER)) {
            val session = activeSessionId?.let { sessionStore.getSession(it) }
                ?: sessionStore.createSession(activityType.name.lowercase(), currentElapsed)
            activeSessionId = session.sessionId
            sessionStore.insertGap(session.sessionId, DistanceSessionStore.REASON_GPS_DISABLED, currentElapsed)
            sessionStore.updateSessionState(session.sessionId, "INTERRUPTED", DistanceSessionStore.REASON_GPS_DISABLED)
            updateState(RecorderState.INTERRUPTED, activityType, session.sessionId, DistanceSessionStore.REASON_GPS_DISABLED)
            return false
        }

        // Create new session in durable store if none active
        val session = activeSessionId?.let { sessionStore.getSession(it) }
            ?: sessionStore.createSession(activityType.name.lowercase(), currentElapsed)

        activeSessionId = session.sessionId
        currentActivityType = activityType

        // Start Foreground Notification
        val typeLabel = activityType.name.lowercase().replaceFirstChar { it.uppercase() }
        val notification = buildNotification("Recording $typeLabel...")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }

        try {
            lm.requestLocationUpdates(
                LocationManager.GPS_PROVIDER,
                MIN_TIME_INTERVAL_MS,
                MIN_DISTANCE_METERS,
                this
            )
            sessionStore.updateSessionState(session.sessionId, "RECORDING")
            updateState(RecorderState.RECORDING, activityType, session.sessionId, null)
            return true
        } catch (e: SecurityException) {
            sessionStore.insertGap(session.sessionId, DistanceSessionStore.REASON_PERMISSION_REVOKED, currentElapsed)
            sessionStore.updateSessionState(session.sessionId, "INTERRUPTED", DistanceSessionStore.REASON_PERMISSION_REVOKED)
            updateState(RecorderState.INTERRUPTED, activityType, session.sessionId, DistanceSessionStore.REASON_PERMISSION_REVOKED)
            return false
        } catch (_: Exception) {
            sessionStore.updateSessionState(session.sessionId, "INTERRUPTED", "start_failed")
            updateState(RecorderState.INTERRUPTED, activityType, session.sessionId, "start_failed")
            return false
        }
    }

    private fun finishRecordingInternal(): Boolean {
        val sId = activeSessionId ?: sessionStore.getActiveSession()?.sessionId
        val currentElapsed = SystemClock.elapsedRealtime()

        if (state != RecorderState.RECORDING && state != RecorderState.INTERRUPTED && sId == null) {
            // Idempotency: If already IDLE/FINALIZED with no session, return true
            return true
        }

        try {
            locationManager?.removeUpdates(this)
        } catch (_: Exception) {}

        if (sId != null) {
            sessionStore.finalizeSession(sId, currentElapsed)
        }

        val prevType = currentActivityType
        val prevSessionId = activeSessionId
        activeSessionId = null
        updateState(RecorderState.FINALIZED, prevType, prevSessionId, null)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf()
        return true
    }

    private fun updateState(
        newState: RecorderState,
        type: ActivityType?,
        sessionId: String?,
        reason: String?
    ) {
        state = newState
        currentActivityType = type
        currentInterruptionReason = reason
        stateChangeListener?.invoke(newState, type, sessionId)

        if (newState == RecorderState.INTERRUPTED) {
            val label = when (reason) {
                DistanceSessionStore.REASON_PERMISSION_REVOKED -> "Location permission revoked"
                DistanceSessionStore.REASON_GPS_DISABLED -> "GPS Disabled"
                else -> "GPS Interrupted"
            }
            updateNotification("Activity Interrupted — $label")
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Persistent notification for PulsePath Distance recording"
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager?.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(text: String): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("PulsePath Activity")
            .setContentText(text)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build()
    }

    private fun updateNotification(text: String) {
        if (state == RecorderState.RECORDING || state == RecorderState.INTERRUPTED) {
            val notification = buildNotification(text)
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            manager?.notify(NOTIFICATION_ID, notification)
        }
    }

    override fun onLocationChanged(location: Location) {
        val sId = activeSessionId ?: return
        if (state != RecorderState.RECORDING) return

        val wallClockUtc = DateTimeFormatter.ISO_INSTANT.format(Instant.ofEpochMilli(location.time))
        val elapsedMs = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN_MR1) {
            location.elapsedRealtimeNanos / 1_000_000L
        } else {
            SystemClock.elapsedRealtime()
        }

        try {
            val obs = sessionStore.processLocationObservation(
                sessionId = sId,
                latitude = location.latitude,
                longitude = location.longitude,
                wallClockUtc = wallClockUtc,
                elapsedRealtimeMs = elapsedMs,
                accuracyMeters = if (location.hasAccuracy()) location.accuracy else null,
                provider = location.provider ?: LocationManager.GPS_PROVIDER
            )

            // Update persistent notification with distance if available
            val session = sessionStore.getSession(sId)
            val dist = session?.accumulatedDistanceMeters
            val typeStr = currentActivityType?.name?.lowercase()?.replaceFirstChar { it.uppercase() } ?: "Activity"

            if (dist != null) {
                val km = dist / 1000.0
                updateNotification("$typeStr • ${String.format("%.2f", km)} km")
            }
        } catch (e: SecurityException) {
            // Permission lost mid-observation
            sessionStore.insertGap(sId, DistanceSessionStore.REASON_PERMISSION_REVOKED, elapsedMs)
            sessionStore.updateSessionState(sId, "INTERRUPTED", DistanceSessionStore.REASON_PERMISSION_REVOKED)
            updateState(RecorderState.INTERRUPTED, currentActivityType, sId, DistanceSessionStore.REASON_PERMISSION_REVOKED)
        } catch (_: Exception) {}
    }

    override fun onProviderDisabled(provider: String) {
        if (provider == LocationManager.GPS_PROVIDER && state == RecorderState.RECORDING) {
            val sId = activeSessionId
            val currentElapsed = SystemClock.elapsedRealtime()
            if (sId != null) {
                sessionStore.insertGap(sId, DistanceSessionStore.REASON_GPS_DISABLED, currentElapsed)
                sessionStore.updateSessionState(sId, "INTERRUPTED", DistanceSessionStore.REASON_GPS_DISABLED)
            }
            updateState(RecorderState.INTERRUPTED, currentActivityType, sId, DistanceSessionStore.REASON_GPS_DISABLED)
        }
    }

    override fun onProviderEnabled(provider: String) {
        if (provider == LocationManager.GPS_PROVIDER && (state == RecorderState.INTERRUPTED || state == RecorderState.RECORDING)) {
            val sId = activeSessionId ?: return
            val currentElapsed = SystemClock.elapsedRealtime()
            val hasFinePerm = ContextCompat.checkSelfPermission(this, android.Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED

            if (hasFinePerm) {
                // Resume recording under a NEW segment ID — never bridge points before & after GPS toggle!
                sessionStore.incrementSegmentId(sId)
                sessionStore.updateSessionState(sId, "RECORDING")
                try {
                    locationManager?.requestLocationUpdates(
                        LocationManager.GPS_PROVIDER,
                        MIN_TIME_INTERVAL_MS,
                        MIN_DISTANCE_METERS,
                        this
                    )
                    updateState(RecorderState.RECORDING, currentActivityType, sId, null)
                } catch (e: SecurityException) {
                    sessionStore.insertGap(sId, DistanceSessionStore.REASON_PERMISSION_REVOKED, currentElapsed)
                    sessionStore.updateSessionState(sId, "INTERRUPTED", DistanceSessionStore.REASON_PERMISSION_REVOKED)
                    updateState(RecorderState.INTERRUPTED, currentActivityType, sId, DistanceSessionStore.REASON_PERMISSION_REVOKED)
                }
            }
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {
    }

    override fun onDestroy() {
        instance = null
        try {
            locationManager?.removeUpdates(this)
        } catch (_: Exception) {}
        super.onDestroy()
    }
}
