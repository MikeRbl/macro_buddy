class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    this.bodyPart,
    this.equipment,
    this.target,
    this.muscleGroup,
    this.secondaryMuscles = const [],
    required this.isBodyweight,
    this.gifUrl,
    this.thumbnailUrl,
    this.instructions,
  });

  final String id;
  final String name;
  final String? bodyPart;
  final String? equipment;
  final String? target;
  final String? muscleGroup;
  final List<String> secondaryMuscles;
  final bool isBodyweight;
  final String? gifUrl;
  final String? thumbnailUrl;
  final String? instructions;

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      id: json['id'] as String,
      name: json['name'] as String,
      bodyPart: json['body_part'] as String?,
      equipment: json['equipment'] as String?,
      target: json['target'] as String?,
      muscleGroup: json['muscle_group'] as String?,
      secondaryMuscles: (json['secondary_muscles'] as List<dynamic>? ?? [])
          .cast<String>(),
      isBodyweight: json['is_bodyweight'] as bool? ?? false,
      gifUrl: json['gif_url'] as String?,
      thumbnailUrl: json['thumbnail_url'] as String?,
      instructions: json['instructions'] as String?,
    );
  }
}
