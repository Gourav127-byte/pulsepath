class VeyaActivityFact {
  final String date;
  final double steps;
  final double activeMinutes;
  final double distance;
  final double activeCalories;
  final double dailyScore;
  final String scoreVersion;
  final String source;
  final String recordingStatus;
  final String stepsProvenance;
  final String distanceProvenance;
  final String activeCaloriesProvenance;
  final String activeMinutesProvenance;

  const VeyaActivityFact({
    required this.date,
    required this.steps,
    required this.activeMinutes,
    required this.distance,
    required this.activeCalories,
    required this.dailyScore,
    required this.scoreVersion,
    required this.source,
    required this.recordingStatus,
    required this.stepsProvenance,
    required this.distanceProvenance,
    required this.activeCaloriesProvenance,
    required this.activeMinutesProvenance,
  });

  factory VeyaActivityFact.fromJson(Map<String, dynamic> json) {
    return VeyaActivityFact(
      date: json['date'] as String,
      steps: (json['steps'] as num).toDouble(),
      activeMinutes: (json['active_minutes'] as num).toDouble(),
      distance: (json['distance'] as num).toDouble(),
      activeCalories: (json['active_calories'] as num).toDouble(),
      dailyScore: (json['daily_score'] as num).toDouble(),
      scoreVersion: json['score_version'] as String? ?? 'v2',
      source: json['source'] as String? ?? 'system',
      recordingStatus: json['recording_status'] as String? ?? 'recorded',
      stepsProvenance: json['steps_provenance'] as String? ?? 'system',
      distanceProvenance: json['distance_provenance'] as String? ?? 'system',
      activeCaloriesProvenance:
          json['active_calories_provenance'] as String? ?? 'system',
      activeMinutesProvenance:
          json['active_minutes_provenance'] as String? ?? 'system',
    );
  }
}

class VeyaIntegrityLens {
  final String level; // 'solid' | 'partial' | 'sparse'
  final int confirmedDays;
  final int legacyDays;
  final int missingDays;
  final double confirmedCoverage;
  final String rationale;

  const VeyaIntegrityLens({
    required this.level,
    required this.confirmedDays,
    required this.legacyDays,
    required this.missingDays,
    required this.confirmedCoverage,
    required this.rationale,
  });

  factory VeyaIntegrityLens.fromJson(Map<String, dynamic> json) {
    return VeyaIntegrityLens(
      level: json['level'] as String? ?? 'sparse',
      confirmedDays: (json['confirmed_days'] as num?)?.toInt() ?? 0,
      legacyDays: (json['legacy_days'] as num?)?.toInt() ?? 0,
      missingDays: (json['missing_days'] as num?)?.toInt() ?? 0,
      confirmedCoverage:
          (json['confirmed_coverage'] as num?)?.toDouble() ?? 0.0,
      rationale: json['rationale'] as String? ?? '',
    );
  }
}

class VeyaEvidenceCitation {
  final String fact;
  final String? date;

  const VeyaEvidenceCitation({required this.fact, this.date});

  factory VeyaEvidenceCitation.fromJson(Map<String, dynamic> json) {
    return VeyaEvidenceCitation(
      fact: json['fact'] as String,
      date: json['date'] as String?,
    );
  }
}

class VeyaObservation {
  final String text;
  final String confidence; // 'high' | 'medium' | 'low'
  final String
  category; // 'consistency' | 'trend' | 'goal_progress' | 'routine_recovery'
  final List<VeyaEvidenceCitation> evidence;

  const VeyaObservation({
    required this.text,
    required this.confidence,
    required this.category,
    required this.evidence,
  });

  factory VeyaObservation.fromJson(Map<String, dynamic> json) {
    final rawEvidence = json['evidence'] as List<dynamic>? ?? [];
    return VeyaObservation(
      text: json['text'] as String? ?? '',
      confidence: json['confidence'] as String? ?? 'low',
      category: json['category'] as String? ?? 'consistency',
      evidence: rawEvidence
          .map((e) => VeyaEvidenceCitation.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class VeyaStructuredResponse {
  final String status; // 'generated' | 'provider_unavailable'
  final String summary;
  final List<VeyaObservation> observations;
  final List<String> limitations;
  final bool medicalOrCausalClaims;

  const VeyaStructuredResponse({
    required this.status,
    required this.summary,
    required this.observations,
    required this.limitations,
    required this.medicalOrCausalClaims,
  });

  factory VeyaStructuredResponse.fromJson(Map<String, dynamic> json) {
    final rawObs = json['observations'] as List<dynamic>? ?? [];
    final rawLimits = json['limitations'] as List<dynamic>? ?? [];
    return VeyaStructuredResponse(
      status: json['status'] as String? ?? 'provider_unavailable',
      summary: json['summary'] as String? ?? 'VEYA insights are unavailable.',
      observations: rawObs
          .map((o) => VeyaObservation.fromJson(o as Map<String, dynamic>))
          .toList(),
      limitations: rawLimits.map((l) => l.toString()).toList(),
      medicalOrCausalClaims: json['medical_or_causal_claims'] as bool? ?? false,
    );
  }
}

class VeyaEvidencePacket {
  final String schemaVersion;
  final int rangeDays;
  final List<VeyaActivityFact> activities;
  final VeyaIntegrityLens integrity;

  const VeyaEvidencePacket({
    required this.schemaVersion,
    required this.rangeDays,
    required this.activities,
    required this.integrity,
  });

  factory VeyaEvidencePacket.fromJson(Map<String, dynamic> json) {
    final rawActs = json['activities'] as List<dynamic>? ?? [];
    return VeyaEvidencePacket(
      schemaVersion: json['schema_version'] as String? ?? '1.0',
      rangeDays: (json['range_days'] as num?)?.toInt() ?? 7,
      activities: rawActs
          .map((a) => VeyaActivityFact.fromJson(a as Map<String, dynamic>))
          .toList(),
      integrity: VeyaIntegrityLens.fromJson(
        json['integrity'] as Map<String, dynamic>? ?? {},
      ),
    );
  }
}

class VeyaFoundationResponse {
  final VeyaEvidencePacket evidence;
  final VeyaStructuredResponse response;

  const VeyaFoundationResponse({
    required this.evidence,
    required this.response,
  });

  factory VeyaFoundationResponse.fromJson(Map<String, dynamic> json) {
    return VeyaFoundationResponse(
      evidence: VeyaEvidencePacket.fromJson(
        json['evidence'] as Map<String, dynamic>? ?? {},
      ),
      response: VeyaStructuredResponse.fromJson(
        json['response'] as Map<String, dynamic>? ?? {},
      ),
    );
  }
}
