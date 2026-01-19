import 'package:uuid/uuid.dart';

/// Data model for manual sleep entries (local-only, never synced)
/// 
/// Stores user-entered sleep data when Apple Watch sleep is missing or low-confidence.
/// Date represents the WAKE-UP DAY (morning date) to align with LastSleepService.
class ManualSleepEntry {
  final String id;
  final String userEmail;
  final String date; // WAKE-UP DAY in YYYY-MM-DD format (local timezone)
  final int totalSleepMinutes; // Calculated from bedtime → wake time
  final DateTime? sleepStart; // Bedtime (ISO8601 timestamp)
  final DateTime? sleepEnd; // Wake time (ISO8601 timestamp)
  
  // Comprehensive Sleep Quality Metrics (validated questions)
  final int? sleepQuality1to5; // Q3: Overall sleep quality (1=Very poor → 5=Excellent)
  final int? wakeFrequency; // Q4: How often woke up (0=Not at all, 1=Once, 2=2-3 times, 3=Many times)
  final int? restedFeeling1to5; // Q5: Morning recovery state (1=Exhausted → 5=Fully recovered)
  final List<String>? physiologicalSymptoms; // Q6: Multi-select (muscle_soreness, joint_pain, headache, illness, none)
  
  // Legacy fields (deprecated but kept for backwards compat)
  final DateTime? bedtime; // Legacy - use sleepStart instead
  final DateTime? wakeTime; // Legacy - use sleepEnd instead
  final int? awakenings; // Legacy - use wakeFrequency instead
  
  final DateTime createdAt;
  final DateTime updatedAt;
  final String source; // Always 'manual'
  final bool isUserOverride; // True if user wants manual to override auto for this date

  ManualSleepEntry({
    required this.id,
    required this.userEmail,
    required this.date,
    required this.totalSleepMinutes,
    this.sleepStart,
    this.sleepEnd,
    this.sleepQuality1to5,
    this.wakeFrequency,
    this.restedFeeling1to5,
    this.physiologicalSymptoms,
    this.bedtime,
    this.wakeTime,
    this.awakenings,
    required this.createdAt,
    required this.updatedAt,
    this.source = 'manual',
    this.isUserOverride = false,
  });

  /// Create a new manual sleep entry with generated ID and timestamps
  factory ManualSleepEntry.create({
    required String userEmail,
    required String date,
    required int totalSleepMinutes,
    DateTime? sleepStart,
    DateTime? sleepEnd,
    int? sleepQuality1to5,
    int? wakeFrequency,
    int? restedFeeling1to5,
    List<String>? physiologicalSymptoms,
    DateTime? bedtime,
    DateTime? wakeTime,
    int? awakenings,
    bool isUserOverride = false,
  }) {
    final now = DateTime.now();
    return ManualSleepEntry(
      id: const Uuid().v4(),
      userEmail: userEmail,
      date: date,
      totalSleepMinutes: totalSleepMinutes,
      sleepStart: sleepStart,
      sleepEnd: sleepEnd,
      sleepQuality1to5: sleepQuality1to5,
      wakeFrequency: wakeFrequency,
      restedFeeling1to5: restedFeeling1to5,
      physiologicalSymptoms: physiologicalSymptoms,
      bedtime: bedtime,
      wakeTime: wakeTime,
      awakenings: awakenings,
      createdAt: now,
      updatedAt: now,
      source: 'manual',
      isUserOverride: isUserOverride,
    );
  }

  /// Create from database map
  factory ManualSleepEntry.fromMap(Map<String, dynamic> map) {
    // Parse physiological symptoms from JSON string
    List<String>? symptoms;
    if (map['physiological_symptoms'] != null) {
      final symptomsStr = map['physiological_symptoms'] as String;
      symptoms = symptomsStr.split(',').where((s) => s.isNotEmpty).toList();
    }
    
    return ManualSleepEntry(
      id: map['id'] as String,
      userEmail: map['user_email'] as String,
      date: map['date'] as String,
      totalSleepMinutes: map['total_sleep_minutes'] as int,
      sleepStart: map['sleep_start'] != null ? DateTime.parse(map['sleep_start'] as String) : null,
      sleepEnd: map['sleep_end'] != null ? DateTime.parse(map['sleep_end'] as String) : null,
      sleepQuality1to5: map['sleep_quality_1to5'] as int?,
      wakeFrequency: map['wake_frequency'] as int?,
      restedFeeling1to5: map['rested_feeling_1to5'] as int?,
      physiologicalSymptoms: symptoms,
      bedtime: map['bedtime'] != null ? DateTime.parse(map['bedtime'] as String) : null,
      wakeTime: map['wake_time'] != null ? DateTime.parse(map['wake_time'] as String) : null,
      awakenings: map['awakenings'] as int?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      source: map['source'] as String? ?? 'manual',
      isUserOverride: (map['is_user_override'] as int? ?? 0) == 1,
    );
  }

  /// Convert to database map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_email': userEmail,
      'date': date,
      'total_sleep_minutes': totalSleepMinutes,
      'sleep_start': sleepStart?.toIso8601String(),
      'sleep_end': sleepEnd?.toIso8601String(),
      'sleep_quality_1to5': sleepQuality1to5,
      'wake_frequency': wakeFrequency,
      'rested_feeling_1to5': restedFeeling1to5,
      'physiological_symptoms': physiologicalSymptoms?.join(','), // Store as CSV
      'bedtime': bedtime?.toIso8601String(),
      'wake_time': wakeTime?.toIso8601String(),
      'awakenings': awakenings,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'source': source,
      'is_user_override': isUserOverride ? 1 : 0,
    };
  }

  /// Create a copy with updated fields
  ManualSleepEntry copyWith({
    String? id,
    String? userEmail,
    String? date,
    int? totalSleepMinutes,
    DateTime? sleepStart,
    DateTime? sleepEnd,
    DateTime? bedtime,
    DateTime? wakeTime,
    int? sleepQuality1to5,
    int? awakenings,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? source,
    bool? isUserOverride,
  }) {
    return ManualSleepEntry(
      id: id ?? this.id,
      userEmail: userEmail ?? this.userEmail,
      date: date ?? this.date,
      totalSleepMinutes: totalSleepMinutes ?? this.totalSleepMinutes,
      sleepStart: sleepStart ?? this.sleepStart,
      sleepEnd: sleepEnd ?? this.sleepEnd,
      bedtime: bedtime ?? this.bedtime,
      wakeTime: wakeTime ?? this.wakeTime,
      sleepQuality1to5: sleepQuality1to5 ?? this.sleepQuality1to5,
      awakenings: awakenings ?? this.awakenings,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      source: source ?? this.source,
      isUserOverride: isUserOverride ?? this.isUserOverride,
    );
  }

  /// Format duration as "7h 15m"
  String get formattedDuration {
    final hours = totalSleepMinutes ~/ 60;
    final mins = totalSleepMinutes % 60;
    return '${hours}h ${mins}m';
  }

  @override
  String toString() {
    return 'ManualSleepEntry(date: $date, minutes: $totalSleepMinutes, override: $isUserOverride)';
  }
}
