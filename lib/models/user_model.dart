class AppUser {
  final String uid;
  final String email;
  final String displayName;
  final int age;
  final double weight;
  final double height;
  final String fitnessGoal;
  final double? targetWeightKg;
  final double? dailyCalorieTarget;
  final String? workoutGoal;
  final DateTime? workoutEndDate;
  final String gender;
  final String activityLevel;
  final String dietPreference;
  final String spotifyConnected;
  final String smartwatchConnected;
  final bool hasSeenQuickTour;
  final String themeMode;
  final int accentColor;
  final DateTime createdAt;
  final DateTime lastActive;
  final String? selectedPlanId;
  final String? photoUrl;

  AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    this.age = 25,
    this.weight = 65.0,
    this.height = 170.0,
    this.fitnessGoal = 'general_fitness',
    this.gender = 'male',
    this.activityLevel = 'moderate',
    this.dietPreference = 'none',
    this.targetWeightKg,
    this.dailyCalorieTarget,
    this.workoutGoal,
    this.workoutEndDate,
    this.spotifyConnected = 'disconnected',
    this.smartwatchConnected = 'disconnected',
    this.hasSeenQuickTour = false,
    this.themeMode = 'light',
    this.accentColor = 0xFF6366F1,
    DateTime? createdAt,
    DateTime? lastActive,
    this.selectedPlanId,
    this.photoUrl,
  })  : createdAt = createdAt ?? DateTime.now(),
        lastActive = lastActive ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'email': email,
        'displayName': displayName,
        'age': age,
        'weight': weight,
        'height': height,
        'fitnessGoal': fitnessGoal,
        'gender': gender,
        'activityLevel': activityLevel,
        'dietPreference': dietPreference,
        if (targetWeightKg != null) 'targetWeightKg': targetWeightKg,
        if (dailyCalorieTarget != null) 'dailyCalorieTarget': dailyCalorieTarget,
        if (workoutGoal != null) 'workoutGoal': workoutGoal,
        if (workoutEndDate != null)
          'workoutEndDate': workoutEndDate!.toIso8601String(),
        'spotifyConnected': spotifyConnected,
        'smartwatchConnected': smartwatchConnected,
        'hasSeenQuickTour': hasSeenQuickTour,
        'themeMode': themeMode,
        'accentColor': accentColor,
        'createdAt': createdAt.toIso8601String(),
        'lastActive': lastActive.toIso8601String(),
        'selectedPlanId': selectedPlanId,
        if (photoUrl != null) 'photoUrl': photoUrl,
      };

  factory AppUser.fromMap(Map<String, dynamic> map) => AppUser(
        uid: map['uid'] as String,
        email: map['email'] as String,
        displayName: map['displayName'] as String? ?? '',
        age: map['age'] as int? ?? 25,
        weight: (map['weight'] as num?)?.toDouble() ?? 65.0,
        height: (map['height'] as num?)?.toDouble() ?? 170.0,
        fitnessGoal: map['fitnessGoal'] as String? ?? 'general_fitness',
        gender: map['gender'] as String? ?? 'male',
        activityLevel: map['activityLevel'] as String? ?? 'moderate',
        dietPreference: map['dietPreference'] as String? ?? 'none',
        targetWeightKg: (map['targetWeightKg'] as num?)?.toDouble(),
        dailyCalorieTarget: (map['dailyCalorieTarget'] as num?)?.toDouble(),
        workoutGoal: map['workoutGoal'] as String?,
        workoutEndDate: map['workoutEndDate'] != null
            ? DateTime.parse(map['workoutEndDate'] as String)
            : null,
        spotifyConnected: map['spotifyConnected'] as String? ?? 'disconnected',
        smartwatchConnected:
            map['smartwatchConnected'] as String? ?? 'disconnected',
        hasSeenQuickTour: map['hasSeenQuickTour'] as bool? ?? false,
        themeMode: map['themeMode'] as String? ?? 'light',
        accentColor: map['accentColor'] as int? ?? 0xFF6366F1,
        createdAt: map['createdAt'] != null
            ? DateTime.parse(map['createdAt'] as String)
            : null,
        lastActive: map['lastActive'] != null
            ? DateTime.parse(map['lastActive'] as String)
            : null,
        selectedPlanId: map['selectedPlanId'] as String?,
        photoUrl: map['photoUrl'] as String?,
      );

  double get bmi => height > 0 ? weight / ((height / 100) * (height / 100)) : 0;

  AppUser copyWith({
    String? displayName,
    int? age,
    double? weight,
    double? height,
    String? fitnessGoal,
    String? gender,
    String? activityLevel,
    String? dietPreference,
    double? targetWeightKg,
    double? dailyCalorieTarget,
    String? workoutGoal,
    DateTime? workoutEndDate,
    String? spotifyConnected,
    String? smartwatchConnected,
    bool? hasSeenQuickTour,
    String? selectedPlanId,
    String? photoUrl,
  }) =>
      AppUser(
        uid: uid,
        email: email,
        displayName: displayName ?? this.displayName,
        age: age ?? this.age,
        weight: weight ?? this.weight,
        height: height ?? this.height,
        fitnessGoal: fitnessGoal ?? this.fitnessGoal,
        gender: gender ?? this.gender,
        activityLevel: activityLevel ?? this.activityLevel,
        dietPreference: dietPreference ?? this.dietPreference,
        targetWeightKg: targetWeightKg ?? this.targetWeightKg,
        dailyCalorieTarget: dailyCalorieTarget ?? this.dailyCalorieTarget,
        workoutGoal: workoutGoal ?? this.workoutGoal,
        workoutEndDate: workoutEndDate ?? this.workoutEndDate,
        spotifyConnected: spotifyConnected ?? this.spotifyConnected,
        smartwatchConnected: smartwatchConnected ?? this.smartwatchConnected,
        hasSeenQuickTour: hasSeenQuickTour ?? this.hasSeenQuickTour,
        createdAt: createdAt,
        lastActive: lastActive,
        selectedPlanId: selectedPlanId ?? this.selectedPlanId,
        photoUrl: photoUrl ?? this.photoUrl,
      );
}
