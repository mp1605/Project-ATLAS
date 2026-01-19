import 'package:uuid/uuid.dart';

enum ActivityType {
  walking,
  running,
  cycling,
  swimming,
  strengthTraining,
  hiitCircuit,
  sportsGeneral,
  hiking,
  ruckMarch,
  mobilityStretching,
  yogaBreathwork,
  combatTraining,
  manualLabor,
  ptTest,
  other
}

enum Purpose {
  recovery,
  endurance,
  strength,
  speed,
  skills,
  competition,
  duty
}

enum PainSeverity {
  none,
  mild,
  moderate,
  severe
}

enum IndoorOutdoor {
  indoor,
  outdoor
}

enum HeatLevel {
  cool,
  normal,
  hot,
  veryHot
}

class ManualActivityEntry {
  final String id;
  final String userEmail;
  final ActivityType activityType;
  final String? customName;
  final DateTime startTimeUtc;
  final int durationMinutes;
  final int rpe; // 1-10
  final String feelAfter; // better, same, worse
  
  // Advanced fields
  final Purpose? purpose;
  final int? fatigueAfter0to5;
  final PainSeverity painSeverity;
  final String? painLocation;
  final double? distanceValue;
  final String? distanceUnit; // km, mi
  final double? loadValue;
  final String? loadUnit; // kg, lb
  final IndoorOutdoor? indoorOutdoor;
  final HeatLevel? heatLevel;
  final String? notes;
  
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;

  ManualActivityEntry({
    required this.id,
    required this.userEmail,
    required this.activityType,
    this.customName,
    required this.startTimeUtc,
    required this.durationMinutes,
    required this.rpe,
    required this.feelAfter,
    this.purpose,
    this.fatigueAfter0to5,
    this.painSeverity = PainSeverity.none,
    this.painLocation,
    this.distanceValue,
    this.distanceUnit,
    this.loadValue,
    this.loadUnit,
    this.indoorOutdoor,
    this.heatLevel,
    this.notes,
    required this.createdAtUtc,
    required this.updatedAtUtc,
  });

  factory ManualActivityEntry.create({
    required String userEmail,
    required ActivityType activityType,
    String? customName,
    required DateTime startTime,
    required int durationMinutes,
    required int rpe,
    required String feelAfter,
    Purpose? purpose,
    int? fatigueAfter0to5,
    PainSeverity painSeverity = PainSeverity.none,
    String? painLocation,
    double? distanceValue,
    String? distanceUnit,
    double? loadValue,
    String? loadUnit,
    IndoorOutdoor? indoorOutdoor,
    HeatLevel? heatLevel,
    String? notes,
  }) {
    final now = DateTime.now().toUtc();
    return ManualActivityEntry(
      id: const Uuid().v4(),
      userEmail: userEmail,
      activityType: activityType,
      customName: customName,
      startTimeUtc: startTime.toUtc(),
      durationMinutes: durationMinutes,
      rpe: rpe,
      feelAfter: feelAfter,
      purpose: purpose,
      fatigueAfter0to5: fatigueAfter0to5,
      painSeverity: painSeverity,
      painLocation: painLocation,
      distanceValue: distanceValue,
      distanceUnit: distanceUnit,
      loadValue: loadValue,
      loadUnit: loadUnit,
      indoorOutdoor: indoorOutdoor,
      heatLevel: heatLevel,
      notes: notes,
      createdAtUtc: now,
      updatedAtUtc: now,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_email': userEmail,
      'activity_type': activityType.name,
      'custom_name': customName,
      'start_time_utc': startTimeUtc.toIso8601String(),
      'duration_minutes': durationMinutes,
      'rpe': rpe,
      'feel_after': feelAfter,
      'purpose': purpose?.name,
      'fatigue_after_0to5': fatigueAfter0to5,
      'pain_severity': painSeverity.name,
      'pain_location': painLocation,
      'distance_value': distanceValue,
      'distance_unit': distanceUnit,
      'load_value': loadValue,
      'load_unit': loadUnit,
      'indoor_outdoor': indoorOutdoor?.name,
      'heat_level': heatLevel?.name,
      'notes': notes,
      'created_at_utc': createdAtUtc.toIso8601String(),
      'updated_at_utc': updatedAtUtc.toIso8601String(),
    };
  }

  factory ManualActivityEntry.fromMap(Map<String, dynamic> map) {
    return ManualActivityEntry(
      id: map['id'] as String,
      userEmail: map['user_email'] as String,
      activityType: ActivityType.values.byName(map['activity_type'] as String),
      customName: map['custom_name'] as String?,
      startTimeUtc: DateTime.parse(map['start_time_utc'] as String),
      durationMinutes: map['duration_minutes'] as int,
      rpe: map['rpe'] as int,
      feelAfter: map['feel_after'] as String,
      purpose: map['purpose'] != null ? Purpose.values.byName(map['purpose'] as String) : null,
      fatigueAfter0to5: map['fatigue_after_0to5'] as int?,
      painSeverity: PainSeverity.values.byName(map['pain_severity'] as String),
      painLocation: map['pain_location'] as String?,
      distanceValue: map['distance_value'] as double?,
      distanceUnit: map['distance_unit'] as String?,
      loadValue: map['load_value'] as double?,
      loadUnit: map['load_unit'] as String?,
      indoorOutdoor: map['indoor_outdoor'] != null ? IndoorOutdoor.values.byName(map['indoor_outdoor'] as String) : null,
      heatLevel: map['heat_level'] != null ? HeatLevel.values.byName(map['heat_level'] as String) : null,
      notes: map['notes'] as String?,
      createdAtUtc: DateTime.parse(map['created_at_utc'] as String),
      updatedAtUtc: DateTime.parse(map['updated_at_utc'] as String),
    );
  }
}
