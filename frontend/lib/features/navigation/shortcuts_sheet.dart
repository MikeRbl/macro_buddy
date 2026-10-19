import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../nutrition/scan_food_flow.dart';
import '../tools/stopwatch_screen.dart';
import '../tools/timer_screen.dart';
import '../workout/active_workout_screen.dart';
import '../workouts/create_workout_screen.dart';

class ShortcutsSheet extends StatelessWidget {
  const ShortcutsSheet({super.key});

  static const _toolActions = [
    (icon: Icons.timer_outlined, label: 'Cronómetro'),
    (icon: Icons.hourglass_bottom, label: 'Temporizador'),
  ];

  static const _createActions = [
    (icon: Icons.play_arrow, label: 'Iniciar entrenamiento vacío'),
    (icon: Icons.qr_code_scanner, label: 'Escanear comida'),
    (icon: Icons.fitness_center, label: 'Crear entrenamiento'),
  ];

  void _open(BuildContext context, Widget screen) {
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.push(MaterialPageRoute<void>(builder: (_) => screen));
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
                    'Atajos',
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
            const SizedBox(height: 16),
            for (final action in _toolActions)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(action.icon, color: c.textPrimary),
                title: Text(
                  action.label,
                  style: TextStyle(color: c.textPrimary, fontSize: 16),
                ),
                trailing: Icon(Icons.chevron_right, color: c.textSecondary),
                onTap: () => _open(
                  context,
                  action.label == 'Cronómetro'
                      ? const StopwatchScreen()
                      : const TimerScreen(),
                ),
              ),
            Divider(height: 16, color: c.input),
            for (final action in _createActions)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(action.icon, color: c.textPrimary),
                title: Text(
                  action.label,
                  style: TextStyle(color: c.textPrimary, fontSize: 16),
                ),
                trailing: Icon(Icons.chevron_right, color: c.textSecondary),
                onTap: action.label == 'Iniciar entrenamiento vacío'
                    ? () => _open(
                        context,
                        const ActiveWorkoutScreen(exercises: []),
                      )
                    : action.label == 'Escanear comida'
                        ? () async {
                            // El context de la hoja muere al pop; el del
                            // Navigator raíz sobrevive todo el flujo.
                            final rootNav =
                                Navigator.of(context, rootNavigator: true);
                            final rootCtx = rootNav.context;
                            rootNav.pop();
                            await scanFoodFlow(rootCtx);
                          }
                        : () => _open(
                            context,
                            const CreateWorkoutScreen(),
                          ),
              ),
          ],
        ),
      ),
    );
  }
}
