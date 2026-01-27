import 'dart:convert';

class ManualLog {
  final int? id;
  final String userEmail;
  final String logType; // 'hydration', 'nutrition', 'stress', 'environment'
  final double value;
  final String? unit;
  final Map<String, dynamic>? metadata;
  final DateTime loggedAt;

  ManualLog({
    this.id,
    required this.userEmail,
    required this.logType,
    required this.value,
    this.unit,
    this.metadata,
    required this.loggedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_email': userEmail,
      'log_type': logType,
      'value': value,
      'unit': unit,
      'metadata': metadata != null ? jsonEncode(metadata) : null,
      'logged_at': loggedAt.millisecondsSinceEpoch,
    };
  }

  factory ManualLog.fromMap(Map<String, dynamic> map) {
    return ManualLog(
      id: map['id'] as int?,
      userEmail: map['user_email'] as String,
      logType: map['log_type'] as String,
      value: (map['value'] as num).toDouble(),
      unit: map['unit'] as String?,
      metadata: map['metadata'] != null 
          ? jsonDecode(map['metadata'] as String) as Map<String, dynamic> 
          : null,
      loggedAt: DateTime.fromMillisecondsSinceEpoch(map['logged_at'] as int),
    );
  }
}
