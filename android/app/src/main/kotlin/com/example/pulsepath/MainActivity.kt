package com.example.pulsepath

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity(), MethodChannel.MethodCallHandler {

    companion object {
        const val METHOD_CHANNEL = "com.pulsepath.app/distance_recorder"
        const val EVENT_CHANNEL = "com.pulsepath.app/distance_recorder_events"
        const val PERMISSION_REQUEST_CODE = 2026
    }

    private var eventSink: EventChannel.EventSink? = null
    private var pendingPermissionResult: MethodChannel.Result? = null
    private lateinit var sessionStore: DistanceSessionStore

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        sessionStore = DistanceSessionStore(applicationContext)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler(this)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    sendCurrentStateEvent()
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            })

        // Attach listener to service if running
        LocationRecordingService.instance?.setStateListener { state, activityType, sessionId ->
            sendStateEvent(state, activityType, sessionId)
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startRecording" -> {
                val activityTypeStr = call.argument<String>("activityType")
                val activityType = LocationRecordingService.ActivityType.fromString(activityTypeStr)
                    ?: LocationRecordingService.ActivityType.WALK

                if (!hasLocationPermission()) {
                    val active = sessionStore.getActiveSession()
                    result.success(buildSessionStateMap(
                        LocationRecordingService.RecorderState.INTERRUPTED,
                        activityType,
                        active?.sessionId
                    ))
                    return
                }

                val intent = Intent(this, LocationRecordingService::class.java).apply {
                    action = LocationRecordingService.ACTION_START
                    putExtra(LocationRecordingService.EXTRA_ACTIVITY_TYPE, activityType.name)
                }

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    startForegroundService(intent)
                } else {
                    startService(intent)
                }

                val service = LocationRecordingService.instance
                if (service != null) {
                    service.setStateListener { state, type, sId ->
                        sendStateEvent(state, type, sId)
                    }
                    service.startRecording(activityType)
                    result.success(buildSessionStateMap(service.state, service.currentActivityType, service.activeSessionId))
                } else {
                    val active = sessionStore.getActiveSession()
                    result.success(buildSessionStateMap(
                        LocationRecordingService.RecorderState.RECORDING,
                        activityType,
                        active?.sessionId
                    ))
                }
            }
            "finishRecording" -> {
                val service = LocationRecordingService.instance
                if (service != null) {
                    val activeId = service.activeSessionId
                    service.finishRecording()
                    result.success(buildSessionStateMap(service.state, service.currentActivityType, activeId))
                } else {
                    val active = sessionStore.getActiveSession()
                    if (active != null) {
                        sessionStore.updateSessionState(active.sessionId, "FINALIZED")
                    }
                    val intent = Intent(this, LocationRecordingService::class.java).apply {
                        action = LocationRecordingService.ACTION_FINISH
                    }
                    startService(intent)
                    result.success(buildSessionStateMap(
                        LocationRecordingService.RecorderState.FINALIZED,
                        null,
                        active?.sessionId
                    ))
                }
            }
            "getRecorderState" -> {
                val service = LocationRecordingService.instance
                if (service != null) {
                    result.success(buildSessionStateMap(service.state, service.currentActivityType, service.activeSessionId))
                } else {
                    val active = sessionStore.getActiveSession() ?: sessionStore.getLatestSession()
                    val stateEnum = when (active?.lifecycleState) {
                        "RECORDING" -> LocationRecordingService.RecorderState.RECORDING
                        "FINALIZED" -> LocationRecordingService.RecorderState.FINALIZED
                        "INTERRUPTED" -> LocationRecordingService.RecorderState.INTERRUPTED
                        else -> LocationRecordingService.RecorderState.IDLE
                    }
                    val typeEnum = LocationRecordingService.ActivityType.fromString(active?.activityType)
                    result.success(buildSessionStateMap(stateEnum, typeEnum, active?.sessionId))
                }
            }
            "hasLocationPermission" -> {
                result.success(hasLocationPermission())
            }
            "requestLocationPermission" -> {
                if (hasLocationPermission()) {
                    result.success(true)
                } else {
                    pendingPermissionResult = result
                    ActivityCompat.requestPermissions(
                        this,
                        arrayOf(
                            Manifest.permission.ACCESS_FINE_LOCATION,
                            Manifest.permission.ACCESS_COARSE_LOCATION
                        ),
                        PERMISSION_REQUEST_CODE
                    )
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun hasLocationPermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == PERMISSION_REQUEST_CODE) {
            val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingPermissionResult?.success(granted)
            pendingPermissionResult = null
        }
    }

    private fun sendCurrentStateEvent() {
        val service = LocationRecordingService.instance
        if (service != null) {
            sendStateEvent(service.state, service.currentActivityType, service.activeSessionId)
        } else {
            val active = sessionStore.getActiveSession() ?: sessionStore.getLatestSession()
            val stateEnum = when (active?.lifecycleState) {
                "RECORDING" -> LocationRecordingService.RecorderState.RECORDING
                "FINALIZED" -> LocationRecordingService.RecorderState.FINALIZED
                "INTERRUPTED" -> LocationRecordingService.RecorderState.INTERRUPTED
                else -> LocationRecordingService.RecorderState.IDLE
            }
            val typeEnum = LocationRecordingService.ActivityType.fromString(active?.activityType)
            sendStateEvent(stateEnum, typeEnum, active?.sessionId)
        }
    }

    private fun sendStateEvent(
        state: LocationRecordingService.RecorderState,
        activityType: LocationRecordingService.ActivityType?,
        sessionId: String?
    ) {
        eventSink?.success(buildSessionStateMap(state, activityType, sessionId))
    }

    private fun buildSessionStateMap(
        state: LocationRecordingService.RecorderState,
        activityType: LocationRecordingService.ActivityType?,
        sessionId: String?
    ): Map<String, Any?> {
        val session = if (sessionId != null) sessionStore.getSession(sessionId)
        else sessionStore.getActiveSession() ?: sessionStore.getLatestSession()

        val distanceMeters = session?.accumulatedDistanceMeters
        val isMissing = distanceMeters == null

        return mapOf(
            "sessionId" to (session?.sessionId ?: sessionId),
            "state" to (session?.lifecycleState ?: state.name),
            "activityType" to (session?.activityType ?: activityType?.name?.lowercase()),
            "distanceMeters" to distanceMeters,
            "isDistanceMissing" to isMissing,
            "interruptionReason" to (session?.interruptionReason ?: LocationRecordingService.instance?.currentInterruptionReason),
            "startTimeUtc" to session?.startTimeUtc,
            "acceptedPointCount" to (session?.acceptedPointCount ?: 0),
            "segmentCount" to (session?.currentSegmentId?.toInt() ?: 1)
        )
    }
}
