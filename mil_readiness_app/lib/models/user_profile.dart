class UserProfile {
  final String email;
  final String fullName;
  final int age;
  final double heightCm;
  final double weightKg;

  final String? backgroundInfo;
  
  // NEW: Demographics for military readiness scoring
  final String? gender; // 'male', 'female', 'other'
  final int? hrMax; // Maximum heart rate (beats per minute)
  final int targetSleep; // Target sleep duration in minutes (default 450 = 7.5 hours)
  final int? soldierId; // ID in backend dashboard database (for sync)

  // Secure fields (stored locally only)
  final String passwordSalt;
  final String passwordHash;

  const UserProfile({
    required this.email,
    required this.fullName,
    required this.age,
    required this.heightCm,
    required this.weightKg,
    this.backgroundInfo,
    this.gender,
    this.hrMax,
    this.targetSleep = 450, // Default 7.5 hours
    this.soldierId,
    this.passwordSalt = "",
    this.passwordHash = "",
  });


  UserProfile copyWith({
    String? email,
    String? fullName,
    int? age,
    double? heightCm,
    double? weightKg,
    String? backgroundInfo,
    String? gender,
    int? hrMax,
    int? targetSleep,
    int? soldierId,
    String? passwordSalt,
    String? passwordHash,
  }) {
    return UserProfile(
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      age: age ?? this.age,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      backgroundInfo: backgroundInfo ?? this.backgroundInfo,
      gender: gender ?? this.gender,
      hrMax: hrMax ?? this.hrMax,
      targetSleep: targetSleep ?? this.targetSleep,
      soldierId: soldierId ?? this.soldierId,
      passwordSalt: passwordSalt ?? this.passwordSalt,
      passwordHash: passwordHash ?? this.passwordHash,
    );
  }

  Map<String, dynamic> toJson() => {
        "email": email,
        "fullName": fullName,
        "age": age,
        "heightCm": heightCm,
        "weightKg": weightKg,
        "backgroundInfo": backgroundInfo,
        "gender": gender,
        "hrMax": hrMax,
        "targetSleep": targetSleep,
        "soldierId": soldierId,
        "passwordSalt": passwordSalt,
        "passwordHash": passwordHash,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      email: (json["email"] ?? "").toString(),
      fullName: (json["fullName"] ?? "").toString(),
      age: (json["age"] ?? 0) is int ? json["age"] : int.tryParse("${json["age"]}") ?? 0,
      heightCm: (json["heightCm"] ?? 0).toDouble(),
      weightKg: (json["weightKg"] ?? 0).toDouble(),
      backgroundInfo: json["backgroundInfo"]?.toString(),
      gender: json["gender"]?.toString(),
      hrMax: json["hrMax"] != null ? int.tryParse(json["hrMax"].toString()) : null,
      targetSleep: json["targetSleep"] != null ? int.tryParse(json["targetSleep"].toString()) ?? 450 : 450,
      soldierId: json["soldierId"] != null ? int.tryParse(json["soldierId"].toString()) : null,
      passwordSalt: (json["passwordSalt"] ?? "").toString(),
      passwordHash: (json["passwordHash"] ?? "").toString(),
    );
  }
  
  /// Estimate HR_max using Tanaka formula if not provided
  int getHrMax() {
    if (hrMax != null && hrMax! > 0) {
      return hrMax!;
    }
    // Estimate: HR_max = 208 - 0.7 × age
    return (208 - (0.7 * age)).round();
  }
}
