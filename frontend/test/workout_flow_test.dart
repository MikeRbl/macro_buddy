import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:macrobuddy/features/workout/active_workout_screen.dart';
import 'package:macrobuddy/features/workout/workout_models.dart';
import 'package:macrobuddy/features/workout/workout_preview_screen.dart';
import 'package:macrobuddy/features/workout/workout_ui.dart';
import 'package:macrobuddy/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _bench = PreviewExercise(
  id: 'ex1',
  name: 'Press de banca',
  muscles: ['chest', 'triceps'],
  sets: 3,
  minReps: 6,
  maxReps: 8,
  rir: 1,
  isBodyweight: false,
);

const _pullup = PreviewExercise(
  id: 'ex2',
  name: 'Dominadas',
  muscles: ['lats'],
  sets: 2,
  isBodyweight: true,
);

Widget _app(Widget child) {
  return ProviderScope(
    child: MaterialApp(theme: AppTheme.dark, home: child),
  );
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> phone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  test('muscleLabel traduce y capitaliza', () {
    expect(muscleLabel('chest'), 'Pecho');
    expect(muscleLabel('Side Delts'), 'Deltoide lateral');
    expect(muscleLabel('serratus'), 'Serratus');
  });

  test('rirColor agrupa por esfuerzo', () {
    expect(rirColor(0), AppColors.danger);
    expect(rirColor(3), AppColors.warningAmber);
    expect(rirColor(5), AppColors.successGreen);
    expect(rirColor(6), AppColors.secondaryCyan);
  });

  testWidgets('detalle muestra músculos, series y botón Iniciar', (
    tester,
  ) async {
    await phone(tester);
    await tester.pumpWidget(
      _app(
        const WorkoutPreviewScreen(
          title: 'Entreno A',
          exercises: [_bench, _pullup],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Músculos objetivo'), findsOneWidget);
    expect(find.text('Pecho'), findsWidgets);
    expect(find.text('2 Ejercicios'), findsOneWidget);
    expect(find.textContaining('tiempo estimado'), findsOneWidget);
    expect(find.text('6–8 reps'), findsNWidgets(3));
    expect(find.text('Iniciar entrenamiento'), findsOneWidget);
  });

  testWidgets('registro de series con teclado propio y RIR', (tester) async {
    await phone(tester);
    await tester.pumpWidget(
      _app(
        const ActiveWorkoutScreen(
          exercises: [_bench, _pullup],
          workoutName: 'Entreno A',
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Press de banca'), findsOneWidget);
    expect(find.text('Serie 1 de 3 · Objetivo 6–8 reps'), findsOneWidget);
    expect(find.text('Terminar entrenamiento'), findsOneWidget);

    // Placeholder del objetivo en reps.
    expect(find.text('6-8'), findsNWidgets(3));

    // Toca la celda de peso de la primera serie → aparece el teclado.
    await tester.tap(find.text('6-8').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(find.text('RIR'), findsOneWidget);
    expect(find.text('Terminar entrenamiento'), findsNothing);

    // Escribe 8 reps, RIR 2 y completa con ✓.
    await tester.tap(find.text('8').last);
    await tester.pump();
    expect(find.text('8'), findsWidgets);

    await tester.tap(find.byIcon(Icons.check).last);
    await tester.pump();
    // Falta el peso: la serie no se completa.
    expect(find.text('Ingresa peso y repeticiones'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('flujo completo peso → reps → ✓', (tester) async {
    await phone(tester);
    await tester.pumpWidget(
      _app(const ActiveWorkoutScreen(exercises: [_bench])),
    );
    await tester.pump();

    // Header "Lb" existe → hay columna de peso.
    expect(find.text('Lb'), findsOneWidget);

    // Las celdas de peso vacías no tienen texto; toca la zona de la primera.
    final lbHeader = tester.getCenter(find.text('Lb'));
    final firstReps = tester.getCenter(find.text('6-8').first);
    await tester.tapAt(Offset(lbHeader.dx, firstReps.dy));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('RIR'), findsOneWidget);

    Future<void> key(String k) async {
      await tester.tap(find.text(k).last);
      await tester.pump();
    }

    await key('1');
    await key('3');
    await key('5');
    expect(find.text('135'), findsOneWidget);

    // Avanza a reps.
    await tester.tap(find.text('Reps').last);
    await tester.pump();
    await key('7');

    // RIR 2.
    await tester.tap(find.byWidgetPredicate(
      (w) => w is RirBadge && w.rir == 2 && w.size == 30,
    ));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.check).last);
    await tester.pump();

    expect(find.text('Serie 2 de 3 · Objetivo 6–8 reps'), findsOneWidget);
    // Descanso arrancó (1:30 → 1:29…).
    expect(find.textContaining('1:'), findsWidgets);

    await tester.pump(const Duration(seconds: 1));
  });
}
