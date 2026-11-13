import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Piezas visuales compartidas por la sección Workouts (lista del programa,
/// detalle del entrenamiento y registro de series).

/// Color del RIR (repeticiones en reserva): 0–1 al fallo (rojo),
/// 2–3 duro (ámbar), 4–5 cómodo (verde), 6+ muy lejos del fallo (cyan).
Color rirColor(int rir) {
  if (rir <= 1) return AppColors.danger;
  if (rir <= 3) return AppColors.warningAmber;
  if (rir <= 5) return AppColors.successGreen;
  return AppColors.secondaryCyan;
}

/// Círculo pequeño con el RIR objetivo o registrado.
class RirBadge extends StatelessWidget {
  const RirBadge(this.rir, {super.key, this.size = 22});

  final int rir;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = rirColor(rir);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Text(
        rir >= 6 ? '6+' : '$rir',
        style: TextStyle(
          color: rir <= 1 ? Colors.white : AppColors.inkOnAccent,
          fontSize: size * 0.48,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// Chip gris con el nombre de un músculo.
class MuscleChip extends StatelessWidget {
  const MuscleChip(this.label, {super.key, this.primary = true});

  final String label;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final c = ThemeColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: primary ? c.input : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: primary ? null : Border.all(color: c.input),
      ),
      child: Text(
        muscleLabel(label),
        style: TextStyle(color: c.textSecondary, fontSize: 11),
      ),
    );
  }
}

const _muscleEs = <String, String>{
  'chest': 'Pecho',
  'pectorals': 'Pecho',
  'back': 'Espalda',
  'upper back': 'Espalda alta',
  'lower back': 'Espalda baja',
  'lats': 'Dorsales',
  'traps': 'Trapecio',
  'shoulders': 'Hombros',
  'delts': 'Deltoides',
  'front delts': 'Deltoide frontal',
  'side delts': 'Deltoide lateral',
  'rear delts': 'Deltoide posterior',
  'biceps': 'Bíceps',
  'triceps': 'Tríceps',
  'forearms': 'Antebrazos',
  'upper arms': 'Brazos',
  'lower arms': 'Antebrazos',
  'abs': 'Abdomen',
  'abdominals': 'Abdomen',
  'waist': 'Core',
  'core': 'Core',
  'obliques': 'Oblicuos',
  'glutes': 'Glúteos',
  'quads': 'Cuádriceps',
  'quadriceps': 'Cuádriceps',
  'hamstrings': 'Isquiotibiales',
  'calves': 'Pantorrillas',
  'upper legs': 'Piernas',
  'lower legs': 'Pantorrillas',
  'adductors': 'Aductores',
  'abductors': 'Abductores',
  'hip flexors': 'Flexores de cadera',
  'neck': 'Cuello',
  'cardio': 'Cardio',
  'cardiovascular system': 'Cardio',
};

/// Traduce los músculos del catálogo (en inglés) y capitaliza el resto.
String muscleLabel(String raw) {
  final key = raw.trim().toLowerCase();
  final es = _muscleEs[key];
  if (es != null) return es;
  if (key.isEmpty) return raw;
  return key[0].toUpperCase() + key.substring(1);
}

/// Minutos estimados: ~2.5 min por serie (ejecución + descanso de 90 s)
/// más 5 min de preparación.
int estimatedMinutes(int totalSets) =>
    totalSets == 0 ? 0 : (totalSets * 2.5 + 5).round();
