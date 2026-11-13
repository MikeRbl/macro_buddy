import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:macrobuddy/core/models/workout_plan.dart';
import 'package:macrobuddy/features/create_program/create_program_screen.dart';
import 'package:macrobuddy/features/workouts/workouts_provider.dart';
import 'package:macrobuddy/features/workouts/workouts_screen.dart';
import 'package:macrobuddy/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _press = WorkoutPlanExercise(
  exerciseId: 'e1',
  name: 'Press de banca',
  muscleGroup: 'chest',
  sets: 3,
  minReps: 8,
  maxReps: 12,
  rir: 2,
);

const _coachProgram = TrainingProgram(
  id: 'p1',
  name: 'Plan del coach',
  color: 'purple',
  icon: 'bolt',
  cycles: 6,
  isActive: true,
  currentCycle: 2,
  byCoach: true,
  coachName: 'Luis Coach',
  workouts: [
    WorkoutPlan(id: 'w1', name: 'Pecho', exercises: [_press]),
    WorkoutPlan(id: 'w2', name: 'Pierna'),
  ],
);

const _ownProgram = TrainingProgram(
  id: 'p2',
  name: 'Mi plan viejo',
  cycles: 4,
  workouts: [WorkoutPlan(id: 'w3', name: 'Full body')],
);

class _FakeWorkouts extends WorkoutController {
  _FakeWorkouts(this._initial);
  final WorkoutsState _initial;

  String? activated;
  String? savedId;
  Map<String, dynamic>? savedBody;

  @override
  WorkoutsState build() => _initial;

  @override
  Future<String?> activateProgram(String programId) async {
    activated = programId;
    return null;
  }

  @override
  Future<String?> saveProgram({
    String? programId,
    required Map<String, dynamic> body,
  }) async {
    savedId = programId;
    savedBody = body;
    return null;
  }
}

class _FakeNotices extends NotificationsController {
  _FakeNotices(this._initial);
  final List<AppNotification> _initial;
  bool dismissed = false;

  @override
  List<AppNotification> build() => _initial;

  @override
  Future<void> refresh() async {}

  @override
  Future<void> markAllRead() async {
    dismissed = true;
    state = const [];
  }
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

  Widget app(Widget home, _FakeWorkouts workouts, [_FakeNotices? notices]) {
    return ProviderScope(
      overrides: [
        workoutProvider.overrideWith(() => workouts),
        notificationsProvider.overrideWith(
          () => notices ?? _FakeNotices(const []),
        ),
      ],
      child: MaterialApp(theme: AppTheme.dark, home: home),
    );
  }

  final state = WorkoutsState(
    programs: const [_coachProgram, _ownProgram],
    workouts: _coachProgram.workouts,
    programName: _coachProgram.name,
  );

  test('TrainingProgram.fromJson lee ciclos, coach y entrenamientos', () {
    final p = TrainingProgram.fromJson({
      'id': 'p1',
      'name': 'Plan',
      'color': 'green',
      'icon': 'star',
      'cycles': 6,
      'isActive': true,
      'currentCycle': 7,
      'coach': {'id': 'c1', 'name': 'Luis'},
      'workouts': [
        {'id': 'w1', 'name': 'Pecho', 'exercises': []},
      ],
    });
    expect(p.cycles, 6);
    expect(p.byCoach, isTrue);
    expect(p.coachName, 'Luis');
    expect(p.workouts.single.name, 'Pecho');
    expect(p.isFinished, isTrue);
    expect(const TrainingProgram(id: 'x', name: 'y').byCoach, isFalse);
  });

  testWidgets('Workout muestra ciclo, programa del coach y Mis programas', (
    tester,
  ) async {
    await phone(tester);
    final workouts = _FakeWorkouts(state);
    await tester.pumpWidget(app(const WorkoutsScreen(), workouts));
    await tester.pump();

    expect(find.text('Ciclo 2 de 6'), findsOneWidget);
    expect(find.text('Plan del coach'), findsOneWidget);
    expect(find.text('De Luis Coach'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Mi plan viejo'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Mis programas'), findsOneWidget);
    expect(find.text('1 entrenamiento · 4 ciclos'), findsOneWidget);

    await tester.ensureVisible(find.text('Activar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Activar'));
    await tester.pumpAndSettle();
    expect(workouts.activated, 'p2');
  });

  testWidgets('aviso del entrenador se muestra y se descarta', (tester) async {
    await phone(tester);
    final notices = _FakeNotices(const [
      AppNotification(
        id: 'n1',
        title: 'Luis Coach cambió tu programa',
        body: '«Plan del coach»',
        details: ['Cambió la duración de 6 a 8 ciclos'],
      ),
    ]);
    await tester.pumpWidget(
      app(const WorkoutsScreen(), _FakeWorkouts(state), notices),
    );
    await tester.pump();

    expect(
      find.text('Luis Coach cambió tu programa «Plan del coach»'),
      findsOneWidget,
    );
    expect(find.text('• Cambió la duración de 6 a 8 ciclos'), findsOneWidget);

    await tester.tap(find.text('Entendido'));
    await tester.pump();
    expect(notices.dismissed, isTrue);
    expect(find.text('Entendido'), findsNothing);
  });

  testWidgets('sin programa activo invita a activar o crear uno', (
    tester,
  ) async {
    await phone(tester);
    await tester.pumpWidget(
      app(
        const WorkoutsScreen(),
        _FakeWorkouts(const WorkoutsState(programs: [_ownProgram])),
      ),
    );
    await tester.pump();

    expect(find.text('No tienes un programa activo'), findsOneWidget);
    expect(find.textContaining('Ciclo'), findsNothing);
  });

  testWidgets('editor cambia la duración en ciclos y guarda el programa', (
    tester,
  ) async {
    await phone(tester);
    final workouts = _FakeWorkouts(state);
    await tester.pumpWidget(
      app(const ProgramEditorScreen(program: _coachProgram), workouts),
    );
    await tester.pumpAndSettle();

    expect(find.text('Editar programa'), findsOneWidget);
    expect(find.text('Duración: 6 ciclos'), findsOneWidget);
    expect(find.textContaining('tu entrenador verá'), findsOneWidget);
    expect(find.text('Press de banca'), findsOneWidget);

    await tester.tap(find.byTooltip('Ajustes del programa'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Más ciclos'));
    await tester.tap(find.byTooltip('Más ciclos'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('program-cycles')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('program-cycles'))).data,
      '8',
    );
    await tester.tap(find.text('Listo'));
    await tester.pumpAndSettle();
    expect(find.text('Duración: 8 ciclos'), findsOneWidget);

    await tester.tap(find.text('Guardar cambios'));
    await tester.pumpAndSettle();

    expect(workouts.savedId, 'p1');
    expect(workouts.savedBody?['cycles'], 8);
    expect(workouts.savedBody?['activate'], isFalse);
    final days = workouts.savedBody?['days'] as List;
    expect(days.length, 2);
    expect(days.first['id'], 'w1');
    expect((days.first['exercises'] as List).single, {
      'exercise_id': 'e1',
      'sets': 3,
      'min_reps': 8,
      'max_reps': 12,
      'rir': 2,
    });
  });

  testWidgets('programa nuevo pide nombre antes de guardar', (tester) async {
    await phone(tester);
    final workouts = _FakeWorkouts(const WorkoutsState());
    await tester.pumpWidget(app(const ProgramEditorScreen(), workouts));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('program-name')), 'Torso');
    await tester.tap(find.text('Listo'));
    await tester.pumpAndSettle();
    expect(find.text('Torso'), findsOneWidget);

    // Sin ejercicios no se guarda.
    await tester.tap(find.text('Activar programa'));
    await tester.pumpAndSettle();
    expect(find.text('Agrega al menos un ejercicio al programa.'), findsOneWidget);
    expect(workouts.savedBody, isNull);
  });
}
