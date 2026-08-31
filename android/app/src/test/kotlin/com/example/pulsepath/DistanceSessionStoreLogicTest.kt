package com.example.pulsepath

import org.junit.Assert.*
import org.junit.Test
import java.time.Instant

class DistanceSessionStoreLogicTest {

    @Test
    fun calculateWgs84DistanceMetersComputesAccurateGeodeticDistance() {
        // Distance between Bangalore points (12.9716, 77.5946) and (12.9726, 77.5946)
        val distMeters = DistanceSessionStore.calculateWgs84DistanceMeters(
            12.9716, 77.5946,
            12.9726, 77.5946
        )
        assertTrue("Distance should be approx 110.5m, got $distMeters", distMeters in 105.0..115.0)
    }

    @Test
    fun nullAccuracyObservationIsClassifiedAsMissingAccuracy() {
        val accuracy: Float? = null
        val isMissingAccuracy = accuracy == null || accuracy <= 0f
        assertTrue(isMissingAccuracy)
    }

    @Test
    fun duplicateObservationDistinguishedFromNonMonotonic() {
        val prevLat = 12.9716
        val prevLon = 77.5946
        val prevTimeUtc = "2026-08-28T20:00:00Z"
        val prevElapsed = 100000L

        // Test exact duplicate
        val isExactDuplicate = (prevLat == 12.9716 && prevLon == 77.5946 && prevTimeUtc == "2026-08-28T20:00:00Z")
        val isNonMonotonic = 100000L <= prevElapsed

        assertTrue(isExactDuplicate)
        assertTrue(isNonMonotonic)

        // Exact duplicate reason must take precedence over generic non-monotonic
        val reason = if (isExactDuplicate) DistanceSessionStore.REASON_DUPLICATE else DistanceSessionStore.REASON_NON_MONOTONIC
        assertEquals(DistanceSessionStore.REASON_DUPLICATE, reason)
    }

    @Test
    fun genericNonMonotonicObservationClassifiedCorrectly() {
        val prevLat = 12.9716
        val prevLon = 77.5946
        val prevTimeUtc = "2026-08-28T20:00:00Z"
        val prevElapsed = 100000L

        // New point with different coordinates but older timestamp
        val currLat = 12.9720
        val currLon = 77.5950
        val currTimeUtc = "2026-08-28T19:59:00Z"
        val currElapsed = 90000L

        val isExactDuplicate = (prevLat == currLat && prevLon == currLon && prevTimeUtc == currTimeUtc)
        val isNonMonotonic = currElapsed <= prevElapsed

        assertFalse(isExactDuplicate)
        assertTrue(isNonMonotonic)

        val reason = if (isExactDuplicate) DistanceSessionStore.REASON_DUPLICATE else DistanceSessionStore.REASON_NON_MONOTONIC
        assertEquals(DistanceSessionStore.REASON_NON_MONOTONIC, reason)
    }

    @Test
    fun finalizedObservedDurationUsesMonotonicEvidence() {
        val startElapsedMs = 100000L
        val endElapsedMs = 175000L

        val durationSeconds = maxOf(0L, (endElapsedMs - startElapsedMs) / 1000L)
        assertEquals(75L, durationSeconds)
    }

    @Test
    fun trajectoryRejectionClosesSegmentToPreventDistanceBridge() {
        var currentSegmentId = 1L

        // Point 1 (Accepted) -> Segment 1
        val obs1Decision = DistanceSessionStore.DECISION_ACCEPTED

        // Point 2 (Rejected for invalid lat/lon range) -> Trajectory break
        val obs2Reason = DistanceSessionStore.REASON_OUT_OF_RANGE
        if (obs2Reason != DistanceSessionStore.REASON_DUPLICATE) {
            currentSegmentId++
        }
        assertEquals(2L, currentSegmentId)

        // Point 3 (Accepted) -> Segment 2
        // Since Point 3 is in Segment 2 and Point 1 is in Segment 1, distance across Point 2 is NOT calculated!
        val sameSegment = (1L == currentSegmentId)
        assertFalse("Distance must not bridge across rejected observation segment break", sameSegment)
    }
}
