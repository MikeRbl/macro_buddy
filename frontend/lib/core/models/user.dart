class AuthUser {
  const AuthUser({
    required this.id,
    required this.username,
    required this.email,
    this.fullName,
    this.weight,
    this.height,
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
      'gender': gender,
      'targetCalories': targetCalories,
      'targetProtein': targetProtein,
      'targetCarbs': targetCarbs,
      'targetFats': targetFats,
      'isGuidedMode': isGuidedMode,
    };
  }
}
