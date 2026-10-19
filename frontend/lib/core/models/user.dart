/// Peso corporal registrado en un día ("YYYY-MM-DD").
class WeightEntry {
  const WeightEntry({required this.date, required this.weight});

  final String date;
  final double weight;

  factory WeightEntry.fromJson(Map<String, dynamic> json) {
    return WeightEntry(
      date: json['date'] as String,
      weight: (json['weight'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {'date': date, 'weight': weight};
}

class AuthUser {
  const AuthUser({
    required this.id,
    required this.username,
    required this.email,
    this.fullName,
    this.weight,
    this.height,
    this.bodyFat,
    this.weightHistory = const [],
    this.gender,
    this.targetCalories,
    this.targetProtein,
    this.targetCarbs,
    this.targetFats,
    this.isGuidedMode = false,
  });

  final String id;
  final String username;
  final String email;
  final String? fullName;
  final double? weight;
  final double? height;

  /// Grasa corporal estimada (%) reportada por el usuario.
  final double? bodyFat;

  /// Historial de peso diario ("YYYY-MM-DD") hasta 365 entradas.
  final List<WeightEntry> weightHistory;
  final String? gender;

  // Objetivos de macros asignados por el profesional (modo guiado).
  final double? targetCalories;
  final double? targetProtein;
  final double? targetCarbs;
  final double? targetFats;
  final bool isGuidedMode;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as String,
      username: json['username'] as String,
      email: json['email'] as String,
      fullName: json['fullName'] as String?,
      weight: (json['weight'] as num?)?.toDouble(),
      height: (json['height'] as num?)?.toDouble(),
      bodyFat: (json['bodyFat'] as num?)?.toDouble(),
      weightHistory: ((json['weightHistory'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(WeightEntry.fromJson)
          .toList(),
      gender: json['gender'] as String?,
      targetCalories: (json['targetCalories'] as num?)?.toDouble(),
      targetProtein: (json['targetProtein'] as num?)?.toDouble(),
      targetCarbs: (json['targetCarbs'] as num?)?.toDouble(),
      targetFats: (json['targetFats'] as num?)?.toDouble(),
      isGuidedMode: json['isGuidedMode'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'fullName': fullName,
      'weight': weight,
      'height': height,
      'bodyFat': bodyFat,
      'weightHistory': [for (final w in weightHistory) w.toJson()],
      'gender': gender,
      'targetCalories': targetCalories,
      'targetProtein': targetProtein,
      'targetCarbs': targetCarbs,
      'targetFats': targetFats,
      'isGuidedMode': isGuidedMode,
    };
  }
}
