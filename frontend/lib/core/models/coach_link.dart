/// Vínculo del usuario con un profesional (`GET /api/links/me`).
class CoachLink {
  const CoachLink({
    required this.id,
    required this.isActive,
    required this.role,
    required this.professionalName,
    this.setMacros = false,
    this.manageRoutines = false,
    this.viewData = false,
  });

  final String id;

  /// `false`: solicitud enviada, el profesional aún no la acepta.
  final bool isActive;
  final String role;
  final String professionalName;
  final bool setMacros;
  final bool manageRoutines;
  final bool viewData;

  String get roleLabel => switch (role) {
    'nutritionist' => 'Nutriólogo',
    'trainer' => 'Entrenador',
    'doctor' => 'Médico',
    _ => 'Nutriólogo y entrenador',
  };

  factory CoachLink.fromJson(Map<String, dynamic> json) {
    final p = (json['permissions'] as Map<String, dynamic>?) ?? const {};
    final pro = (json['professional'] as Map<String, dynamic>?) ?? const {};
    return CoachLink(
      id: json['id'] as String,
      isActive: json['status'] == 'active',
      role: json['role'] as String? ?? 'both',
      professionalName: pro['displayName'] as String? ?? 'Tu profesional',
      setMacros: p['setMacros'] == true,
      manageRoutines: p['manageRoutines'] == true,
      viewData: p['viewData'] == true,
    );
  }
}
