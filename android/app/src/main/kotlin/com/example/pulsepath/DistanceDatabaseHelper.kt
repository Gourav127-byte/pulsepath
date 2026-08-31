package com.example.pulsepath

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper

class DistanceDatabaseHelper(context: Context?, dbName: String? = DATABASE_NAME) :
    SQLiteOpenHelper(context, dbName, null, DATABASE_VERSION) {

    companion object {
        const val DATABASE_NAME = "pulsepath_distance.db"
        const val DATABASE_VERSION = 2

        const val TABLE_SESSIONS = "distance_sessions"
        const val COLUMN_SESSION_ID = "session_id"
        const val COLUMN_ACTIVITY_TYPE = "activity_type"
        const val COLUMN_LIFECYCLE_STATE = "lifecycle_state"
        const val COLUMN_START_TIME_UTC = "start_time_utc"
        const val COLUMN_START_ELAPSED_REALTIME_MS = "start_elapsed_realtime_ms"
        const val COLUMN_LATEST_EVIDENCE_TIMESTAMP_UTC = "latest_evidence_timestamp_utc"
        const val COLUMN_LATEST_ELAPSED_REALTIME_MS = "latest_elapsed_realtime_ms"
        const val COLUMN_FINALIZED_END_TIME_UTC = "finalized_end_time_utc"
        const val COLUMN_FINALIZED_END_ELAPSED_REALTIME_MS = "finalized_end_elapsed_realtime_ms"
        const val COLUMN_OBSERVED_DURATION_SECONDS = "observed_duration_seconds"
        const val COLUMN_INTERRUPTION_REASON = "interruption_reason"
        const val COLUMN_ACCUMULATED_DISTANCE_METERS = "accumulated_distance_meters"
        const val COLUMN_UPLOAD_STATUS = "upload_status"
        const val COLUMN_CURRENT_SEGMENT_ID = "current_segment_id"

        const val TABLE_OBSERVATIONS = "gps_observations"
        const val COLUMN_OBS_ID = "id"
        const val COLUMN_OBS_SESSION_ID = "session_id"
        const val COLUMN_OBS_SEQUENCE_NUMBER = "sequence_number"
        const val COLUMN_OBS_LATITUDE = "latitude"
        const val COLUMN_OBS_LONGITUDE = "longitude"
        const val COLUMN_OBS_WALL_CLOCK_UTC = "wall_clock_timestamp_utc"
        const val COLUMN_OBS_ELAPSED_REALTIME_MS = "elapsed_realtime_ms"
        const val COLUMN_OBS_ACCURACY_METERS = "accuracy_meters"
        const val COLUMN_OBS_PROVIDER = "provider"
        const val COLUMN_OBS_DECISION = "decision"
        const val COLUMN_OBS_REJECTION_GAP_REASON = "rejection_gap_reason"
        const val COLUMN_OBS_SEGMENT_ID = "segment_id"
    }

    override fun onCreate(db: SQLiteDatabase) {
        val createSessionsTable = """
            CREATE TABLE $TABLE_SESSIONS (
                $COLUMN_SESSION_ID TEXT PRIMARY KEY,
                $COLUMN_ACTIVITY_TYPE TEXT NOT NULL,
                $COLUMN_LIFECYCLE_STATE TEXT NOT NULL,
                $COLUMN_START_TIME_UTC TEXT NOT NULL,
                $COLUMN_START_ELAPSED_REALTIME_MS INTEGER NOT NULL,
                $COLUMN_LATEST_EVIDENCE_TIMESTAMP_UTC TEXT,
                $COLUMN_LATEST_ELAPSED_REALTIME_MS INTEGER,
                $COLUMN_FINALIZED_END_TIME_UTC TEXT,
                $COLUMN_FINALIZED_END_ELAPSED_REALTIME_MS INTEGER,
                $COLUMN_OBSERVED_DURATION_SECONDS INTEGER,
                $COLUMN_INTERRUPTION_REASON TEXT,
                $COLUMN_ACCUMULATED_DISTANCE_METERS REAL,
                $COLUMN_UPLOAD_STATUS TEXT NOT NULL DEFAULT 'pending',
                $COLUMN_CURRENT_SEGMENT_ID INTEGER NOT NULL DEFAULT 1
            );
        """.trimIndent()

        val createObservationsTable = """
            CREATE TABLE $TABLE_OBSERVATIONS (
                $COLUMN_OBS_ID INTEGER PRIMARY KEY AUTOINCREMENT,
                $COLUMN_OBS_SESSION_ID TEXT NOT NULL,
                $COLUMN_OBS_SEQUENCE_NUMBER INTEGER NOT NULL,
                $COLUMN_OBS_LATITUDE REAL NOT NULL,
                $COLUMN_OBS_LONGITUDE REAL NOT NULL,
                $COLUMN_OBS_WALL_CLOCK_UTC TEXT NOT NULL,
                $COLUMN_OBS_ELAPSED_REALTIME_MS INTEGER NOT NULL,
                $COLUMN_OBS_ACCURACY_METERS REAL,
                $COLUMN_OBS_PROVIDER TEXT NOT NULL,
                $COLUMN_OBS_DECISION TEXT NOT NULL,
                $COLUMN_OBS_REJECTION_GAP_REASON TEXT,
                $COLUMN_OBS_SEGMENT_ID INTEGER NOT NULL,
                FOREIGN KEY ($COLUMN_OBS_SESSION_ID) REFERENCES $TABLE_SESSIONS ($COLUMN_SESSION_ID) ON DELETE CASCADE
            );
        """.trimIndent()

        val createObservationsIndex = """
            CREATE INDEX idx_obs_session_seq ON $TABLE_OBSERVATIONS ($COLUMN_OBS_SESSION_ID, $COLUMN_OBS_SEQUENCE_NUMBER);
        """.trimIndent()

        db.execSQL(createSessionsTable)
        db.execSQL(createObservationsTable)
        db.execSQL(createObservationsIndex)
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        if (oldVersion < 2) {
            db.execSQL("ALTER TABLE $TABLE_SESSIONS ADD COLUMN $COLUMN_FINALIZED_END_TIME_UTC TEXT;")
            db.execSQL("ALTER TABLE $TABLE_SESSIONS ADD COLUMN $COLUMN_FINALIZED_END_ELAPSED_REALTIME_MS INTEGER;")
            db.execSQL("ALTER TABLE $TABLE_SESSIONS ADD COLUMN $COLUMN_OBSERVED_DURATION_SECONDS INTEGER;")
        }
    }
}
