class AuthUser {
  const AuthUser({
    required this.id,
    required this.username,
    required this.email,
    this.fullName,
    this.weight,
    this.height,
    this.gender,
  });

  final String id;
  final String username;
  final String email;
  final String? fullName;
  final double? weight;
  final double? height;
  final String? gender;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as String,
      username: json['username'] as String,
      email: json['email'] as String,
      fullName: json['fullName'] as String?,
      weight: (json['weight'] as num?)?.toDouble(),
      height: (json['height'] as num?)?.toDouble(),
      gender: json['gender'] as String?,
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
    };
  }
}
