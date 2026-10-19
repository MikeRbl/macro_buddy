import 'package:flutter/material.dart';

import '../../core/config/api_config.dart';
import '../../theme/app_theme.dart';
import 'workout_models.dart';

class ExerciseInfoSheet extends StatelessWidget {
  const ExerciseInfoSheet({super.key, required this.exercise});

  final PreviewExercise exercise;

  Widget _media(BuildContext context) {
    final c = ThemeColors.of(context);
    final Widget placeholder = Container(
      height: 200,
      color: c.input,
      child: Icon(Icons.fitness_center, color: c.textSecondary, size: 48),
    );

    final Widget fallback =
        exercise.thumbnailUrl != null && exercise.thumbnailUrl!.isNotEmpty
        ? Image.network(
            ApiConfig.baseUrl + exercise.thumbnailUrl!,
            height: 200,
            width: double.infinity,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => placeholder,
          )
        : placeholder;

    if (exercise.gifUrl == null || exercise.gifUrl!.isEmpty) {
      return fallback;
    }

    return Image.network(
      ApiConfig.baseUrl + exercise.gifUrl!,
      height: 200,
      width: double.infinity,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => fallback,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = ThemeColors.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppColors.radiusCard),
              child: _media(context),
            ),
            const SizedBox(height: 16),
            Text(
              exercise.name,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            if (exercise.muscles.isNotEmpty)
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 6,
                runSpacing: 6,
                children: exercise.muscles
                    .map(
                      (muscle) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: c.input,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          muscle,
                          style: TextStyle(color: c.textPrimary, fontSize: 12),
                        ),
                      ),
                    )
                    .toList(),
              ),
            const SizedBox(height: 16),
            if (exercise.target != null) ...[
              _InfoRow(label: 'Objetivo', value: exercise.target!),
              const SizedBox(height: 8),
            ],
            if (exercise.equipment != null) ...[
              _InfoRow(label: 'Equipo', value: exercise.equipment!),
              const SizedBox(height: 8),
            ],
            if (exercise.instructions != null &&
                exercise.instructions!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Instrucciones',
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                exercise.instructions!,
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = ThemeColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: c.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(color: c.textPrimary, fontSize: 14),
          ),
        ),
      ],
    );
  }
}
