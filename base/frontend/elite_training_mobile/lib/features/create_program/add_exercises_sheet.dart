import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/exercises_provider.dart';
import '../../core/models/exercise.dart';
import '../../core/widgets/exercise_thumbnail.dart';
import '../../theme/app_theme.dart';

Future<Exercise?> showAddExercisesSheet(BuildContext context) {
  final c = ThemeColors.of(context);
  return showModalBottomSheet<Exercise>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: c.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    constraints: BoxConstraints(
      maxHeight: MediaQuery.of(context).size.height * 0.9,
    ),
    builder: (_) => const _AddExercisesSheet(),
  );
}

const _bodyPartLabels = <String, String>{
  'back': 'Espalda',
  'chest': 'Pecho',
  'shoulders': 'Hombros',
  'upper arms': 'Brazos',
  'lower arms': 'Antebrazos',
  'upper legs': 'Piernas',
  'lower legs': 'Gemelos',
  'waist': 'Abdomen',
  'cardio': 'Cardio',
  'neck': 'Cuello',
};

String _bodyPartLabel(String value) => _bodyPartLabels[value] ?? value;

const _equipmentLabels = <String, String>{
  'body weight': 'Peso corporal',
  'dumbbell': 'Mancuerna',
  'barbell': 'Barra',
  'cable': 'Polea',
  'machine': 'Máquina',
  'leverage machine': 'Máquina de palanca',
  'kettlebell': 'Pesa rusa',
  'band': 'Banda',
  'smith machine': 'Máquina Smith',
  'stability ball': 'Fitball',
  'ez barbell': 'Barra EZ',
  'weighted': 'Con peso',
  'other': 'Otro',
};

String _equipmentLabel(String value) => _equipmentLabels[value] ?? value;

class _AddExercisesSheet extends ConsumerStatefulWidget {
  const _AddExercisesSheet();

  @override
  ConsumerState<_AddExercisesSheet> createState() => _AddExercisesSheetState();
}

class _AddExercisesSheetState extends ConsumerState<_AddExercisesSheet> {
  static const _muscleShortcuts = [
    ('Pecho', 'chest'),
    ('Espalda', 'back'),
    ('Hombros', 'shoulders'),
    ('Brazos', 'upper arms'),
    ('Abdomen', 'waist'),
    ('Piernas', 'upper legs'),
    ('Cardio', 'cardio'),
  ];

  final _searchController = TextEditingController();
  String _search = '';
  String? _bodyPart;
  String? _equipment;
  String? _type;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<T?> _pickOption<T>(String title, List<(T, String)> options) {
    final c = ThemeColors.of(context);
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    title,
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                for (final (value, label) in options)
                  ListTile(
                    title: Text(
                      label,
                      style: TextStyle(color: c.textPrimary, fontSize: 16),
                    ),
                    onTap: () => Navigator.of(sheetContext).pop(value),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  bool _matches(Exercise e) {
    if (_search.isNotEmpty &&
        !e.name.toLowerCase().contains(_search.toLowerCase())) {
      return false;
    }
    if (_bodyPart != null && e.bodyPart != _bodyPart) return false;
    if (_equipment != null && e.equipment != _equipment) return false;
    if (_type == 'bodyweight' && !e.isBodyweight) return false;
    if (_type == 'weighted' && e.isBodyweight) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final c = ThemeColors.of(context);
    final exercisesAsync = ref.watch(exercisesProvider);
    final all = exercisesAsync.value ?? const <Exercise>[];
    final bodyParts = {
      for (final e in all) e.bodyPart,
    }.whereType<String>().toList()..sort();
    final equipments = {
      for (final e in all) e.equipment,
    }.whereType<String>().toList()..sort();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _search = value),
                  decoration: InputDecoration(
                    hintText: 'Buscar ejercicio',
                    prefixIcon: Icon(Icons.search, color: c.textSecondary),
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(Icons.close, color: c.textPrimary),
              ),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _FilterChip(
                label: _bodyPart == null
                    ? 'Parte del cuerpo'
                    : _bodyPartLabel(_bodyPart!),
                onTap: () async {
                  final picked =
                      await _pickOption<String?>('Parte del cuerpo', [
                        (null, 'Todos'),
                        for (final part in bodyParts)
                          (part, _bodyPartLabel(part)),
                      ]);
                  if (picked != _bodyPart) setState(() => _bodyPart = picked);
                },
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: switch (_type) {
                  'bodyweight' => 'Peso corporal',
                  'weighted' => 'Pesas libres',
                  _ => 'Tipo',
                },
                onTap: () async {
                  final picked = await _pickOption<String?>('Tipo', [
                    (null, 'Todos'),
                    ('bodyweight', 'Peso corporal'),
                    ('weighted', 'Pesas libres y máquinas'),
                  ]);
                  if (picked != _type) setState(() => _type = picked);
                },
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: _equipment == null
                    ? 'Equipo'
                    : _equipmentLabel(_equipment!),
                onTap: () async {
                  final picked = await _pickOption<String?>('Equipo', [
                    (null, 'Todos'),
                    for (final eq in equipments) (eq, _equipmentLabel(eq)),
                  ]);
                  if (picked != _equipment) {
                    setState(() => _equipment = picked);
                  }
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _muscleShortcuts.map((shortcut) {
              final selected = _bodyPart == shortcut.$2;
              return GestureDetector(
                onTap: () =>
                    setState(() => _bodyPart = selected ? null : shortcut.$2),
                child: Container(
                  width: 72,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.input,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: selected
                          ? AppColors.accentOrange
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Text(
                    shortcut.$1,
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        Divider(height: 24, color: c.input),
        Expanded(
          child: exercisesAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.accentOrange),
            ),
            error: (error, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Error al cargar ejercicios',
                    style: TextStyle(color: c.textSecondary, fontSize: 14),
                  ),
                  TextButton(
                    onPressed: () => ref.invalidate(exercisesProvider),
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
            data: (_) {
              final filtered = all.where(_matches).toList();
              final bodyweight = filtered.where((e) => e.isBodyweight).toList();
              final weighted = filtered.where((e) => !e.isBodyweight).toList();

              return ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  if (bodyweight.isNotEmpty) ...[
                    const _GroupHeader('Peso corporal y personal'),
                    ...bodyweight.map((e) => _ExerciseItem(exercise: e)),
                  ],
                  if (weighted.isNotEmpty) ...[
                    const _GroupHeader('Pesas libres y máquinas'),
                    ...weighted.map((e) => _ExerciseItem(exercise: e)),
                  ],
                  if (filtered.isEmpty)
                    Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'No hay ejercicios que coincidan',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: c.textSecondary, fontSize: 14),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = ThemeColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: c.input,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(color: c.textPrimary, fontSize: 13)),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, color: c.textSecondary, size: 18),
          ],
        ),
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final c = ThemeColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          color: c.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _ExerciseItem extends StatelessWidget {
  const _ExerciseItem({required this.exercise});

  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    final c = ThemeColors.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: ExerciseThumbnail(url: exercise.thumbnailUrl, size: 44),
      title: Text(
        exercise.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: c.textPrimary, fontSize: 15),
      ),
      subtitle: Text(
        exercise.target ?? exercise.muscleGroup ?? '',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: c.textSecondary, fontSize: 12),
      ),
      trailing: GestureDetector(
        onTap: () => Navigator.of(context).pop(exercise),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(color: c.input, shape: BoxShape.circle),
          child: Icon(Icons.add, color: c.textPrimary, size: 18),
        ),
      ),
      onTap: () => Navigator.of(context).pop(exercise),
    );
  }
}
