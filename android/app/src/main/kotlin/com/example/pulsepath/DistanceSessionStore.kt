package com.example.pulsepath

import android.content.ContentValues
import android.content.Context
import android.location.Location
import java.time.Instant
import java.time.format.DateTimeFormatter
import java.util.UUID
import kotlin.math.*

data class SessionRecord(
    val sessionId: String,
    val activityType: String,
    val lifecycleState: String,
    val startTimeUtc: String,
    val startElapsedRealtimeMs: Long,
    val latestEvidenceTimestampUtc: String?,
    val latestElapsedRealtimeMs: Long?,
    val finalizedEndTimeUtc: String?,
    val finalizedEndElapsedRealtimeMs: Long?,
    val observedDurationSeconds: Long?,
    val interruptionReason: String?,
    val accumulatedDistanceMeters: Double?,
    val uploadStatus: String,
    val currentSegmentId: Long,
    val acceptedPointCount: Int,
    val totalPointCount: Int
)

data class ObservationRecord(
    val id: Long = 0,
    val sessionId: String,
    val sequenceNumber: Int,
    val latitude: Double,
    val longitude: Double,
    val wallClockTimestampUtc: String,
    val elapsedRealtimeMs: Long,
    val accuracyMeters: Float?,
    val provider: String,
    val decision: String,
    val rejectionGapReason: String?,
    val segmentId: Long
)

class DistanceSessionStore(context: Context?, dbName: String? = DistanceDatabaseHelper.DATABASE_NAME) {

    private val dbHelper = DistanceDatabaseHelper(context, dbName)

    companion object {
        const val DECISION_ACCEPTED = "ACCEPTED"
        const val DECISION_REJECTED = "REJECTED"
        const val DECISION_GAP = "GAP"

        const val REASON_NON_FINITE = "NON_FINITE_COORDINATES"
        const val REASON_OUT_OF_RANGE = "INVALID_COORDINATE_RANGE"
        const val REASON_NON_MONOTONIC = "NON_MONOTONIC_ORDER"
        const val REASON_DUPLICATE = "DUPLICATE_OBSERVATION"
        const val REASON_MISSING_ORDERING = "MISSING_ORDERING_DATA"
        const val REASON_MISSING_ACCURACY = "MISSING_ACCURACY"

        const val REASON_GPS_DISABLED = "gps_disabled"
        const val REASON_PERMISSION_REVOKED = "permission_revoked"
        const val REASON_SERVICE_RECOVERED = "service_recovered_discontinuity"
        const val REASON_MONOTONIC_RESET = "monotonic_clock_reset"
        const val REASON_EXPLICIT_GAP = "explicit_gap_inserted"

        /**
         * Calculates WGS84 ellipsoid distance in meters between two lat/lon pairs.
         * Uses Android platform Location.distanceBetween when available, falling back
         * to WGS84 formula for unit tests.
         */
        fun calculateWgs84DistanceMeters(
            startLat: Double,
            startLon: Double,
            endLat: Double,
            endLon: Double
        ): Double {
            return try {
                val results = FloatArray(1)
                Location.distanceBetween(startLat, startLon, endLat, endLon, results)
                results[0].toDouble()
            } catch (_: Throwable) {
                // Fallback WGS84 calculation for JVM unit test execution
                computeWgs84FallbackMeters(startLat, startLon, endLat, endLon)
            }
        }

        private fun computeWgs84FallbackMeters(
            lat1: Double, lon1: Double, lat2: Double, lon2: Double
        ): Double {
            val a = 6378137.0 // WGS84 semi-major axis
            val f = 1 / 298.257223563 // WGS84 flattening
            val b = (1 - f) * a

            val radLat1 = Math.toRadians(lat1)
            val radLat2 = Math.toRadians(lat2)
            val radLon1 = Math.toRadians(lon1)
            val radLon2 = Math.toRadians(lon2)

            val u1 = atan((1 - f) * tan(radLat1))
            val u2 = atan((1 - f) * tan(radLat2))
            val L = radLon2 - radLon1
            var lambda = L
            var lambdaP: Double
            var iterLimit = 100

            var cosSqAlpha: Double
            var sinSigma: Double
            var cos2SigmaM: Double
            var cosSigma: Double
            var sigma: Double

            do {
                val sinLambda = sin(lambda)
                val cosLambda = cos(lambda)
                sinSigma = sqrt(
                    (cos(u2) * sinLambda) * (cos(u2) * sinLambda) +
                            (cos(u1) * sin(u2) - sin(u1) * cos(u2) * cosLambda) *
                            (cos(u1) * sin(u2) - sin(u1) * cos(u2) * cosLambda)
                )
                if (sinSigma == 0.0) return 0.0 // Coincident points
                cosSigma = sin(u1) * sin(u2) + cos(u1) * cos(u2) * cosLambda
                sigma = atan2(sinSigma, cosSigma)
                val sinAlpha = cos(u1) * cos(u2) * sinLambda / sinSigma
                cosSqAlpha = 1 - sinAlpha * sinAlpha
                cos2SigmaM = if (cosSqAlpha != 0.0) cosSigma - 2 * sin(u1) * sin(u2) / cosSqAlpha else 0.0
                val C = f / 16 * cosSqAlpha * (4 + f * (4 - 3 * cosSqAlpha))
                lambdaP = lambda
                lambda = L + (1 - C) * f * sinAlpha *
                        (sigma + C * sinSigma * (cos2SigmaM + C * cosSigma * (-1 + 2 * cos2SigmaM * cos2SigmaM)))
            } while (abs(lambda - lambdaP) > 1e-12 && --iterLimit > 0)

            val uSq = cosSqAlpha * (a * a - b * b) / (b * b)
            val A = 1 + uSq / 16384 * (4096 + uSq * (-768 + uSq * (320 - 175 * uSq)))
            val B = uSq / 1024 * (256 + uSq * (-128 + uSq * (74 - 47 * uSq)))
            val deltaSigma = B * sinSigma * (cos2SigmaM + B / 4 * (cosSigma * (-1 + 2 * cos2SigmaM * cos2SigmaM) -
                    B / 6 * cos2SigmaM * (-3 + 4 * sinSigma * sinSigma) * (-3 + 4 * cos2SigmaM * cos2SigmaM)))

            return b * A * (sigma - deltaSigma)
        }
    }

    @Synchronized
    fun createSession(activityType: String, startElapsedRealtimeMs: Long): SessionRecord {
        val sessionId = UUID.randomUUID().toString()
        val startTimeUtc = DateTimeFormatter.ISO_INSTANT.format(Instant.now())

        val db = dbHelper.writableDatabase
        val values = ContentValues().apply {
            put(DistanceDatabaseHelper.COLUMN_SESSION_ID, sessionId)
            put(DistanceDatabaseHelper.COLUMN_ACTIVITY_TYPE, activityType)
            put(DistanceDatabaseHelper.COLUMN_LIFECYCLE_STATE, "RECORDING")
            put(DistanceDatabaseHelper.COLUMN_START_TIME_UTC, startTimeUtc)
            put(DistanceDatabaseHelper.COLUMN_START_ELAPSED_REALTIME_MS, startElapsedRealtimeMs)
            put(DistanceDatabaseHelper.COLUMN_CURRENT_SEGMENT_ID, 1)
            put(DistanceDatabaseHelper.COLUMN_UPLOAD_STATUS, "pending")
        }
        db.insert(DistanceDatabaseHelper.TABLE_SESSIONS, null, values)
        return getSession(sessionId)!!
    }

    @Synchronized
    fun getActiveSession(): SessionRecord? {
        val db = dbHelper.readableDatabase
        val cursor = db.query(
            DistanceDatabaseHelper.TABLE_SESSIONS,
            null,
            "${DistanceDatabaseHelper.COLUMN_LIFECYCLE_STATE} IN ('RECORDING', 'INTERRUPTED')",
            null,
            null, null,
            "${DistanceDatabaseHelper.COLUMN_START_ELAPSED_REALTIME_MS} DESC",
            "1"
        )
        cursor.use {
            if (it.moveToFirst()) {
                return parseSessionRecord(it)
            }
        }
        return null
    }

    @Synchronized
    fun getLatestSession(): SessionRecord? {
        val db = dbHelper.readableDatabase
        val cursor = db.query(
            DistanceDatabaseHelper.TABLE_SESSIONS,
            null,
            null,
            null,
            null, null,
            "${DistanceDatabaseHelper.COLUMN_START_ELAPSED_REALTIME_MS} DESC",
            "1"
        )
        cursor.use {
            if (it.moveToFirst()) {
                return parseSessionRecord(it)
            }
        }
        return null
    }

    @Synchronized
    fun getSession(sessionId: String): SessionRecord? {
        val db = dbHelper.readableDatabase
        val cursor = db.query(
            DistanceDatabaseHelper.TABLE_SESSIONS,
            null,
            "${DistanceDatabaseHelper.COLUMN_SESSION_ID} = ?",
            arrayOf(sessionId),
            null, null, null
        )
        cursor.use {
            if (it.moveToFirst()) {
                return parseSessionRecord(it)
            }
        }
        return null
    }

    @Synchronized
    fun updateSessionState(
        sessionId: String,
        newState: String,
        interruptionReason: String? = null
    ) {
        val db = dbHelper.writableDatabase
        val values = ContentValues().apply {
            put(DistanceDatabaseHelper.COLUMN_LIFECYCLE_STATE, newState)
            if (interruptionReason != null) {
                put(DistanceDatabaseHelper.COLUMN_INTERRUPTION_REASON, interruptionReason)
            }
        }
        db.update(
            DistanceDatabaseHelper.TABLE_SESSIONS,
            values,
            "${DistanceDatabaseHelper.COLUMN_SESSION_ID} = ?",
            arrayOf(sessionId)
        )
    }

    @Synchronized
    fun finalizeSession(sessionId: String, endElapsedRealtimeMs: Long): SessionRecord? {
        val session = getSession(sessionId) ?: return null
        val endTimeUtc = DateTimeFormatter.ISO_INSTANT.format(Instant.now())
        val durationSeconds = maxOf(0L, (endElapsedRealtimeMs - session.startElapsedRealtimeMs) / 1000L)

        val db = dbHelper.writableDatabase
        val values = ContentValues().apply {
            put(DistanceDatabaseHelper.COLUMN_LIFECYCLE_STATE, "FINALIZED")
            put(DistanceDatabaseHelper.COLUMN_FINALIZED_END_TIME_UTC, endTimeUtc)
            put(DistanceDatabaseHelper.COLUMN_FINALIZED_END_ELAPSED_REALTIME_MS, endElapsedRealtimeMs)
            put(DistanceDatabaseHelper.COLUMN_OBSERVED_DURATION_SECONDS, durationSeconds)
        }
        db.update(
            DistanceDatabaseHelper.TABLE_SESSIONS,
            values,
            "${DistanceDatabaseHelper.COLUMN_SESSION_ID} = ?",
            arrayOf(sessionId)
        )
        return getSession(sessionId)
    }

    @Synchronized
    fun incrementSegmentId(sessionId: String): Long {
        val session = getSession(sessionId) ?: return 1L
        val nextSegmentId = session.currentSegmentId + 1
        val db = dbHelper.writableDatabase
        val values = ContentValues().apply {
            put(DistanceDatabaseHelper.COLUMN_CURRENT_SEGMENT_ID, nextSegmentId)
        }
        db.update(
            DistanceDatabaseHelper.TABLE_SESSIONS,
            values,
            "${DistanceDatabaseHelper.COLUMN_SESSION_ID} = ?",
            arrayOf(sessionId)
        )
        return nextSegmentId
    }

    /**
     * Evaluates a raw location observation using structural acceptance rules only.
     * Calculates WGS84 distance if consecutive ACCEPTED observation in same segment exists.
     */
    @Synchronized
    fun processLocationObservation(
        sessionId: String,
        latitude: Double,
        longitude: Double,
        wallClockUtc: String,
        elapsedRealtimeMs: Long,
        accuracyMeters: Float?,
        provider: String
    ): ObservationRecord {
        val session = getSession(sessionId)
            ?: throw IllegalArgumentException("Session $sessionId does not exist")

        val lastObs = getLastObservation(sessionId)
        val nextSeq = (lastObs?.sequenceNumber ?: 0) + 1

        // Structural rejection rules
        val rejectionReason = when {
            latitude.isNaN() || longitude.isNaN() || latitude.isInfinite() || longitude.isInfinite() ->
                REASON_NON_FINITE
            latitude < -90.0 || latitude > 90.0 || longitude < -180.0 || longitude > 180.0 ->
                REASON_OUT_OF_RANGE
            elapsedRealtimeMs <= 0 ->
                REASON_MISSING_ORDERING
            accuracyMeters == null || accuracyMeters <= 0f ->
                REASON_MISSING_ACCURACY
            lastObs != null && lastObs.latitude == latitude && lastObs.longitude == longitude &&
                    lastObs.wallClockTimestampUtc == wallClockUtc ->
                REASON_DUPLICATE
            lastObs != null && elapsedRealtimeMs <= lastObs.elapsedRealtimeMs ->
                REASON_NON_MONOTONIC
            else -> null
        }

        val decision = if (rejectionReason == null) DECISION_ACCEPTED else DECISION_REJECTED
        var currentSegment = session.currentSegmentId

        // If observation is REJECTED for structural trajectory invalidity, continuity is lost!
        // Increment segment so future accepted points start in a NEW segment and do NOT bridge across the gap.
        if (decision == DECISION_REJECTED && rejectionReason != REASON_DUPLICATE) {
            currentSegment = incrementSegmentId(sessionId)
        }

        val obs = ObservationRecord(
            sessionId = sessionId,
            sequenceNumber = nextSeq,
            latitude = latitude,
            longitude = longitude,
            wallClockTimestampUtc = wallClockUtc,
            elapsedRealtimeMs = elapsedRealtimeMs,
            accuracyMeters = accuracyMeters,
            provider = provider,
            decision = decision,
            rejectionGapReason = rejectionReason,
            segmentId = currentSegment
        )

        insertObservation(obs)

        if (decision == DECISION_ACCEPTED) {
            // Find last accepted observation in the same segment
            val lastAcceptedInSegment = getLastAcceptedObservationInSegment(sessionId, currentSegment, nextSeq)

            if (lastAcceptedInSegment != null) {
                val deltaMeters = calculateWgs84DistanceMeters(
                    lastAcceptedInSegment.latitude,
                    lastAcceptedInSegment.longitude,
                    latitude,
                    longitude
                )
                val currentAccumulated = session.accumulatedDistanceMeters ?: 0.0
                val newAccumulated = currentAccumulated + deltaMeters
                updateAccumulatedDistance(sessionId, newAccumulated, wallClockUtc, elapsedRealtimeMs)
            } else {
                // First accepted point in segment — update timestamps but distance remains unchanged
                updateEvidenceTimestamps(sessionId, wallClockUtc, elapsedRealtimeMs)
            }
        }

        return obs
    }

    /**
     * Inserts an explicit GAP record into observation history using monotonic elapsedRealtimeMs.
     * Route continuity is closed; distance will NOT bridge across this gap.
     */
    @Synchronized
    fun insertGap(
        sessionId: String,
        gapReason: String,
        elapsedRealtimeMs: Long
    ): ObservationRecord {
        val session = getSession(sessionId)
            ?: throw IllegalArgumentException("Session $sessionId does not exist")

        val lastObs = getLastObservation(sessionId)
        val nextSeq = (lastObs?.sequenceNumber ?: 0) + 1
        val currentSegment = session.currentSegmentId

        val nowUtc = DateTimeFormatter.ISO_INSTANT.format(Instant.now())

        val gapObs = ObservationRecord(
            sessionId = sessionId,
            sequenceNumber = nextSeq,
            latitude = 0.0,
            longitude = 0.0,
            wallClockTimestampUtc = nowUtc,
            elapsedRealtimeMs = elapsedRealtimeMs,
            accuracyMeters = null,
            provider = "system",
            decision = DECISION_GAP,
            rejectionGapReason = gapReason,
            segmentId = currentSegment
        )

        insertObservation(gapObs)
        incrementSegmentId(sessionId)
        return gapObs
    }

    private fun insertObservation(obs: ObservationRecord) {
        val db = dbHelper.writableDatabase
        val values = ContentValues().apply {
            put(DistanceDatabaseHelper.COLUMN_OBS_SESSION_ID, obs.sessionId)
            put(DistanceDatabaseHelper.COLUMN_OBS_SEQUENCE_NUMBER, obs.sequenceNumber)
            put(DistanceDatabaseHelper.COLUMN_OBS_LATITUDE, obs.latitude)
            put(DistanceDatabaseHelper.COLUMN_OBS_LONGITUDE, obs.longitude)
            put(DistanceDatabaseHelper.COLUMN_OBS_WALL_CLOCK_UTC, obs.wallClockTimestampUtc)
            put(DistanceDatabaseHelper.COLUMN_OBS_ELAPSED_REALTIME_MS, obs.elapsedRealtimeMs)
            put(DistanceDatabaseHelper.COLUMN_OBS_ACCURACY_METERS, obs.accuracyMeters)
            put(DistanceDatabaseHelper.COLUMN_OBS_PROVIDER, obs.provider)
            put(DistanceDatabaseHelper.COLUMN_OBS_DECISION, obs.decision)
            put(DistanceDatabaseHelper.COLUMN_OBS_REJECTION_GAP_REASON, obs.rejectionGapReason)
            put(DistanceDatabaseHelper.COLUMN_OBS_SEGMENT_ID, obs.segmentId)
        }
        db.insert(DistanceDatabaseHelper.TABLE_OBSERVATIONS, null, values)
    }

    private fun updateAccumulatedDistance(
        sessionId: String,
        distanceMeters: Double,
        wallClockUtc: String,
        elapsedRealtimeMs: Long
    ) {
        val db = dbHelper.writableDatabase
        val values = ContentValues().apply {
            put(DistanceDatabaseHelper.COLUMN_ACCUMULATED_DISTANCE_METERS, distanceMeters)
            put(DistanceDatabaseHelper.COLUMN_LATEST_EVIDENCE_TIMESTAMP_UTC, wallClockUtc)
            put(DistanceDatabaseHelper.COLUMN_LATEST_ELAPSED_REALTIME_MS, elapsedRealtimeMs)
        }
        db.update(
            DistanceDatabaseHelper.TABLE_SESSIONS,
            values,
            "${DistanceDatabaseHelper.COLUMN_SESSION_ID} = ?",
            arrayOf(sessionId)
        )
    }

    private fun updateEvidenceTimestamps(
        sessionId: String,
        wallClockUtc: String,
        elapsedRealtimeMs: Long
    ) {
        val db = dbHelper.writableDatabase
        val values = ContentValues().apply {
            put(DistanceDatabaseHelper.COLUMN_LATEST_EVIDENCE_TIMESTAMP_UTC, wallClockUtc)
            put(DistanceDatabaseHelper.COLUMN_LATEST_ELAPSED_REALTIME_MS, elapsedRealtimeMs)
        }
        db.update(
            DistanceDatabaseHelper.TABLE_SESSIONS,
            values,
            "${DistanceDatabaseHelper.COLUMN_SESSION_ID} = ?",
            arrayOf(sessionId)
        )
    }

    private fun getLastObservation(sessionId: String): ObservationRecord? {
        val db = dbHelper.readableDatabase
        val cursor = db.query(
            DistanceDatabaseHelper.TABLE_OBSERVATIONS,
            null,
            "${DistanceDatabaseHelper.COLUMN_OBS_SESSION_ID} = ?",
            arrayOf(sessionId),
            null, null,
            "${DistanceDatabaseHelper.COLUMN_OBS_SEQUENCE_NUMBER} DESC",
            "1"
        )
        cursor.use {
            if (it.moveToFirst()) {
                return parseObservationRecord(it)
            }
        }
        return null
    }

    private fun getLastAcceptedObservationInSegment(
        sessionId: String,
        segmentId: Long,
        currentSeq: Int
    ): ObservationRecord? {
        val db = dbHelper.readableDatabase
        val cursor = db.query(
            DistanceDatabaseHelper.TABLE_OBSERVATIONS,
            null,
            "${DistanceDatabaseHelper.COLUMN_OBS_SESSION_ID} = ? AND " +
                    "${DistanceDatabaseHelper.COLUMN_OBS_SEGMENT_ID} = ? AND " +
                    "${DistanceDatabaseHelper.COLUMN_OBS_DECISION} = ? AND " +
                    "${DistanceDatabaseHelper.COLUMN_OBS_SEQUENCE_NUMBER} < ?",
            arrayOf(sessionId, segmentId.toString(), DECISION_ACCEPTED, currentSeq.toString()),
            null, null,
            "${DistanceDatabaseHelper.COLUMN_OBS_SEQUENCE_NUMBER} DESC",
            "1"
        )
        cursor.use {
            if (it.moveToFirst()) {
                return parseObservationRecord(it)
            }
        }
        return null
    }

    private fun parseSessionRecord(cursor: android.database.Cursor): SessionRecord {
        val sessionId = cursor.getString(cursor.getColumnIndexOrThrow(DistanceDatabaseHelper.COLUMN_SESSION_ID))
        val activityType = cursor.getString(cursor.getColumnIndexOrThrow(DistanceDatabaseHelper.COLUMN_ACTIVITY_TYPE))
        val lifecycleState = cursor.getString(cursor.getColumnIndexOrThrow(DistanceDatabaseHelper.COLUMN_LIFECYCLE_STATE))
        val startTimeUtc = cursor.getString(cursor.getColumnIndexOrThrow(DistanceDatabaseHelper.COLUMN_START_TIME_UTC))
        val startElapsed = cursor.getLong(cursor.getColumnIndexOrThrow(DistanceDatabaseHelper.COLUMN_START_ELAPSED_REALTIME_MS))
        val latestUtc = cursor.getString(cursor.getColumnIndexOrThrow(DistanceDatabaseHelper.COLUMN_LATEST_EVIDENCE_TIMESTAMP_UTC))
        val latestElapsed = if (cursor.isNull(cursor.getColumnIndexOrThrow(DistanceDatabaseHelper.COLUMN_LATEST_ELAPSED_REALTIME_MS))) null else cursor.getLong(cursor.getColumnIndexOrThrow(DistanceDatabaseHelper.COLUMN_LATEST_ELAPSED_REALTIME_MS))
        val finalizedUtc = cursor.getString(cursor.getColumnIndexOrThrow(DistanceDatabaseHelper.COLUMN_FINALIZED_END_TIME_UTC))
        val finalizedElapsed = if (cursor.isNull(cursor.getColumnIndexOrThrow(DistanceDatabaseHelper.COLUMN_FINALIZED_END_ELAPSED_REALTIME_MS))) null else cursor.getLong(cursor.getColumnIndexOrThrow(DistanceDatabaseHelper.COLUMN_FINALIZED_END_ELAPSED_REALTIME_MS))
        val observedDurationSec = if (cursor.isNull(cursor.getColumnIndexOrThrow(DistanceDatabaseHelper.COLUMN_OBSERVED_DURATION_SECONDS))) null else cursor.getLong(cursor.getColumnIndexOrThrow(DistanceDatabaseHelper.COLUMN_OBSERVED_DURATION_SECONDS))
        val interruptionReason = cursor.getString(cursor.getColumnIndexOrThrow(DistanceDatabaseHelper.COLUMN_INTERRUPTION_REASON))
        val distance = if (cursor.isNull(cursor.getColumnIndexOrThrow(DistanceDatabaseHelper.COLUMN_ACCUMULATED_DISTANCE_METERS))) null else cursor.getDouble(cursor.getColumnIndexOrThrow(DistanceDatabaseHelper.COLUMN_ACCUMULATED_DISTANCE_METERS))
        val uploadStatus = cursor.getString(cursor.getColumnIndexOrThrow(DistanceDatabaseHelper.COLUMN_UPLOAD_STATUS))
        val segmentId = cursor.getLong(cursor.getColumnIndexOrThrow(DistanceDatabaseHelper.COLUMN_CURRENT_SEGMENT_ID))

        val (acceptedCount, totalCount) = getObservationCounts(sessionId)

        return SessionRecord(
            sessionId = sessionId,
            activityType = activityType,
            lifecycleState = lifecycleState,
            startTimeUtc = startTimeUtc,
            startElapsedRealtimeMs = startElapsed,
            latestEvidenceTimestampUtc = latestUtc,
            latestElapsedRealtimeMs = latestElapsed,
            finalizedEndTimeUtc = finalizedUtc,
            finalizedEndElapsedRealtimeMs = finalizedElapsed,
            observedDurationSeconds = observedDurationSec,
            interruptionReason = interruptionReason,
            accumulatedDistanceMeters = distance,
            uploadStatus = uploadStatus,
            currentSegmentId = segmentId,
            acceptedPointCount = acceptedCount,
            totalPointCount = totalCount
        )
    }

    private fun getObservationCounts(sessionId: String): Pair<Int, Int> {
        val db = dbHelper.readableDatabase
        var accepted = 0
        var total = 0

        val totalCursor = db.rawQuery(
            "SELECT COUNT(*) FROM ${DistanceDatabaseHelper.TABLE_OBSERVATIONS} WHERE ${DistanceDatabaseHelper.COLUMN_OBS_SESSION_ID} = ?",
            arrayOf(sessionId)
        )
        totalCursor.use {
            if (it.moveToFirst()) total = it.getInt(0)
        }

        val acceptedCursor = db.rawQuery(
            "SELECT COUNT(*) FROM ${DistanceDatabaseHelper.TABLE_OBSERVATIONS} WHERE ${DistanceDatabaseHelper.COLUMN_OBS_SESSION_ID} = ? AND ${DistanceDatabaseHelper.COLUMN_OBS_DECISION} = ?",
            arrayOf(sessionId, DECISION_ACCEPTED)
        )
        acceptedCursor.use {
            if (it.moveToFirst()) accepted = it.getInt(0)
        }

        return Pair(accepted, total)
    }

    private fun parseObservationRecord(cursor: android.database.Cursor): ObservationRecord {
        return ObservationRecord(
            id = cursor.getLong(cursor.getColumnIndexOrThrow(DistanceDatabaseHelper.COLUMN_OBS_ID)),
            sessionId = cursor.getString(cursor.getColumnIndexOrThrow(DistanceDatabaseHelper.COLUMN_OBS_SESSION_ID)),
            sequenceNumber = cursor.getInt(cursor.getColumnIndexOrThrow(DistanceDatabaseHelper.COLUMN_OBS_SEQUENCE_NUMBER)),
            latitude = cursor.getDouble(cursor.getColumnIndexOrThrow(DistanceDatabaseHelper.COLUMN_OBS_LATITUDE)),
            longitude = cursor.getDouble(cursor.getColumnIndexOrThrow(DistanceDatabaseHelper.COLUMN_OBS_LONGITUDE)),
            wallClockTimestampUtc = cursor.getString(cursor.getColumnIndexOrThrow(DistanceDatabaseHelper.COLUMN_OBS_WALL_CLOCK_UTC)),
            elapsedRealtimeMs = cursor.getLong(cursor.getColumnIndexOrThrow(DistanceDatabaseHelper.COLUMN_OBS_ELAPSED_REALTIME_MS)),
            accuracyMeters = if (cursor.isNull(cursor.getColumnIndexOrThrow(DistanceDatabaseHelper.COLUMN_OBS_ACCURACY_METERS))) null else cursor.getFloat(cursor.getColumnIndexOrThrow(DistanceDatabaseHelper.COLUMN_OBS_ACCURACY_METERS)),
            provider = cursor.getString(cursor.getColumnIndexOrThrow(DistanceDatabaseHelper.COLUMN_OBS_PROVIDER)),
            decision = cursor.getString(cursor.getColumnIndexOrThrow(DistanceDatabaseHelper.COLUMN_OBS_DECISION)),
            rejectionGapReason = cursor.getString(cursor.getColumnIndexOrThrow(DistanceDatabaseHelper.COLUMN_OBS_REJECTION_GAP_REASON)),
            segmentId = cursor.getLong(cursor.getColumnIndexOrThrow(DistanceDatabaseHelper.COLUMN_OBS_SEGMENT_ID))
        )
    }

    fun close() {
        try {
            dbHelper.close()
        } catch (_: Exception) {}
    }
}
