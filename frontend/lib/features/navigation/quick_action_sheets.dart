import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/mb_icon.dart';
import '../../theme/app_theme.dart';
import '../auth/auth_controller.dart';
import '../create_program/add_exercises_sheet.dart';
import '../nutrition/food_entry_screen.dart';
import '../nutrition/nutrition_entry_sheets.dart';
import '../nutrition/scan_food_flow.dart';
import '../workout/active_workout_screen.dart';
import '../workout/workout_models.dart';
import '../workouts/create_workout_screen.dart';

class _SheetAction {
  const _SheetAction({
    required this.icon,
    required this.tint,
    required this.title,
    required this.subtitle,
    required this.go,
  });

  final Widget icon;
  final Color tint;
  final String title;
  final String subtitle;

  /// Recibe el contexto y el navegador raíz: sobreviven al pop de la hoja.
  final Future<void> Function(BuildContext rootCtx, NavigatorState rootNav)
  go;
}

/// Menú rápido del Dashboard: Registrar alimento, Registrar peso o
/// Iniciar entrenamiento.
void showDashboardQuickActions(BuildContext context) {
  _showActionSheet(context, 'Acciones rápidas', [
    _SheetAction(
      icon: MbIcon(MbAssets.fruit, color: AppColors.primaryCoral),
      tint: AppColors.primaryCoral,
      title: 'Registrar alimento',
      subtitle: 'Escanear, buscar o registro manual',
      go: (ctx, nav) async => showNutritionQuickActions(ctx),
    ),
    _SheetAction(
      icon: const Icon(Icons.monitor_weight_outlined),
      tint: AppColors.successGreen,
      title: 'Registrar peso corporal',
      subtitle: 'Actualiza tu peso de hoy',
      go: (ctx, nav) async => _showWeightDialog(ctx),
    ),
    _SheetAction(
      icon: MbIcon(MbAssets.dumbbell, color: AppColors.secondaryCyan),
      tint: AppColors.secondaryCyan,
      title: 'Iniciar entrenamiento',
      subtitle: 'Entrenamiento libre desde cero',
      go: (ctx, nav) async => nav.push(
        MaterialPageRoute<void>(
          builder: (_) => const ActiveWorkoutScreen(exercises: []),
        ),
      ),
    ),
  ]);
}

/// Entrada de alimentos para la Nutrición: escáner, búsqueda OFF o manual.
void showNutritionQuickActions(BuildContext context) {
  _showActionSheet(context, 'Ingresar alimento', [
    _SheetAction(
      icon: MbIcon(MbAssets.scanBarcode, color: AppColors.secondaryCyan),
      tint: AppColors.secondaryCyan,
      title: 'Escanear código de barras',
      subtitle: 'Producto real vía OpenFoodFacts',
      go: (ctx, nav) async => scanFoodFlow(ctx),
    ),
    _SheetAction(
      icon: const Icon(Icons.search),
      tint: AppColors.primaryCoral,
      title: 'Buscar en OpenFoodFacts',
      subtitle: 'Nombre, marca o receta',
      go: (ctx, nav) async => nav.push(
        MaterialPageRoute<void>(builder: (_) => const FoodEntryScreen()),
      ),
    ),
    _SheetAction(
      icon: const Icon(Icons.edit_outlined),
      tint: AppColors.tertiaryPurple,
      title: 'Registro manual',
      subtitle: 'Nombre, gramos, kcal, macros y hora',
      go: (ctx, nav) async => showManualEntrySheet(ctx),
    ),
  ]);
}

/// Opciones de la pestaña Workouts: iniciar, crear rutina o añadir ejercicio.
void showWorkoutQuickActions(BuildContext context) {
  _showActionSheet(context, 'Workout', [
    _SheetAction(
      icon: const Icon(Icons.play_arrow),
      tint: AppColors.secondaryCyan,
      title: 'Iniciar entrenamiento vacío',
      subtitle: 'Entrenamiento libre desde cero',
      go: (ctx, nav) async => nav.push(
        MaterialPageRoute<void>(
          builder: (_) => const ActiveWorkoutScreen(exercises: []),
        ),
      ),
    ),
    _SheetAction(
      icon: const Icon(Icons.post_add_outlined),
      tint: AppColors.secondaryCyan,
      title: 'Crear nueva rutina',
      subtitle: 'Define tus series y repeticiones',
      go: (ctx, nav) async => nav.push(
        MaterialPageRoute<void>(builder: (_) => const CreateWorkoutScreen()),
      ),
    ),
    _SheetAction(
      icon: MbIcon(MbAssets.dumbbell, color: AppColors.secondaryCyan),
      tint: AppColors.secondaryCyan,
      title: 'Añadir ejercicio',
      subtitle: 'Del catálogo a tu entrenamiento',
      go: (ctx, nav) async {
        final exercise = await showAddExercisesSheet(ctx);
        if (exercise == null || !ctx.mounted) return;
        await nav.push(
          MaterialPageRoute<void>(
            builder: (_) => ActiveWorkoutScreen(
              exercises: [PreviewExercise.fromCatalog(exercise)],
            ),
          ),
        );
      },
    ),
  ]);
}

/// Registro de peso corporal para el Dashboard.
Future<void> _showWeightDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _WeightDialog(),
  );
}

class _WeightDialog extends ConsumerStatefulWidget {
  const _WeightDialog();

  @override
  ConsumerState<_WeightDialog> createState() => _WeightDialogState();
}

class _WeightDialogState extends ConsumerState<_WeightDialog> {
  final _controller = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final weight = double.tryParse(
      _controller.text.trim().replaceAll(',', '.'),
    );
    if (weight == null || weight <= 0) return;
    setState(() => _saving = true);
    final user = ref.read(authControllerProvider).user;
    if (user == null) return;
    final error = await ref
        .read(authControllerProvider.notifier)
        .updateProfile(
          fullName: user.fullName ?? '',
          username: user.username,
          weight: weight,
        );
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: ThemeColors.dark.card,
        content: Text(
          error ?? 'Peso actualizado.',
          style: TextStyle(color: ThemeColors.dark.textPrimary),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const c = ThemeColors.dark;
    return AlertDialog(
      backgroundColor: c.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppColors.radiusCard),
        side: const BorderSide(color: AppColors.border),
      ),
      title: const Text(
        'Registrar peso',
        style: TextStyle(fontSize: 18),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d*[.,]?\d*')),
        ],
        style: TextStyle(color: c.textPrimary).merge(AppTypography.numeric),
        decoration: InputDecoration(
          labelText: 'Peso (kg)',
          labelStyle: const TextStyle(fontSize: 13),
          filled: true,
          fillColor: c.input,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancelar', style: TextStyle(color: c.textSecondary)),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.inkOnAccent,
                  ),
                )
              : const Text('Guardar'),
        ),
      ],
    );
  }
}

Future<void> _showActionSheet(
  BuildContext context,
  String title,
  List<_SheetAction> actions,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: ThemeColors.dark.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _ActionSheet(title: title, actions: actions),
  );
}

class _ActionSheet extends StatelessWidget {
  const _ActionSheet({required this.title, required this.actions});

  final String title;
  final List<_SheetAction> actions;

  void _run(BuildContext sheetCtx, _SheetAction action) {
    final rootNav = Navigator.of(sheetCtx, rootNavigator: true);
    final rootCtx = rootNav.context;
    Navigator.of(sheetCtx).pop();
    action.go(rootCtx, rootNav);
  }

  @override
  Widget build(BuildContext context) {
    final c = ThemeColors.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: c.input,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 44,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close, color: c.textPrimary),
                    ),
                  ),
                  Text(
                    title,
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: c.input),
            for (final action in actions)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: action.tint.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: action.icon,
                ),
                title: Text(
                  action.title,
                  style: TextStyle(color: c.textPrimary, fontSize: 16),
                ),
                subtitle: Text(
                  action.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: c.textSecondary, fontSize: 12),
                ),
                trailing: Icon(Icons.chevron_right, color: c.textSecondary),
                onTap: () => _run(context, action),
              ),
          ],
        ),
      ),
    );
  }
}
