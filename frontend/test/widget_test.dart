import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:macrobuddy/main.dart';

import 'package:macrobuddy/core/models/user.dart';
import 'package:macrobuddy/core/models/workout_session.dart';
import 'package:macrobuddy/features/auth/auth_controller.dart';
import 'package:macrobuddy/features/auth/login_screen.dart';
import 'package:macrobuddy/features/auth/register_screen.dart';
import 'package:macrobuddy/features/community/community_provider.dart';
import 'package:macrobuddy/features/community/community_screen.dart';
import 'package:macrobuddy/features/create_program/create_program_screen.dart';
import 'package:macrobuddy/features/dashboard/dashboard_provider.dart';
import 'package:macrobuddy/features/dashboard/dashboard_screen.dart';
import 'package:macrobuddy/features/navigation/main_scaffold.dart';
import 'package:macrobuddy/features/navigation/shortcuts_sheet.dart';
import 'package:macrobuddy/features/profile/edit_profile_screen.dart';
import 'package:macrobuddy/features/profile/more_screen.dart';
import 'package:macrobuddy/features/tools/stopwatch_screen.dart';
import 'package:macrobuddy/features/tools/timer_screen.dart';
import 'package:macrobuddy/features/workout/active_workout_screen.dart';
import 'package:macrobuddy/features/workout/exercise_info_sheet.dart';
import 'package:macrobuddy/features/workout/workout_models.dart';
import 'package:macrobuddy/features/workout/workout_preview_screen.dart';
import 'package:macrobuddy/core/models/workout_plan.dart';
import 'package:macrobuddy/features/workouts/create_workout_screen.dart';
import 'package:macrobuddy/features/workouts/workouts_provider.dart';
import 'package:macrobuddy/features/workouts/workouts_screen.dart';

final _fixtureExercises = [
  PreviewExercise(
    name: 'Bench Press',
    muscles: const ['Chest'],
    sets: 3,
    minReps: 8,
    maxReps: 10,
    rir: 1,
    isBodyweight: false,
  ),
  PreviewExercise(
    name: 'Pull Up',
    muscles: const ['Back'],
    sets: 3,
    minReps: 8,
    maxReps: 12,
    rir: 0,
    isBodyweight: true,
  ),
];

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Login screen renders its fields and button', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: LoginScreen())),
    );

    expect(find.text('Inicia sesión'), findsOneWidget);
    expect(find.text('Correo o nombre de usuario'), findsOneWidget);
    expect(find.text('Contraseña'), findsOneWidget);
    expect(
      find.widgetWithText(ElevatedButton, 'Iniciar sesión'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.visibility), findsOneWidget);
  });

  testWidgets('Register wizard shows step 1 credentials', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: RegisterScreen())),
    );

    expect(find.text('Paso 1 de 2'), findsOneWidget);
    expect(find.text('Crea tu cuenta'), findsOneWidget);
    expect(find.text('Nombre'), findsOneWidget);
    expect(find.text('Nombre de usuario'), findsOneWidget);
    expect(find.text('Correo electrónico'), findsOneWidget);
    expect(find.text('Contraseña'), findsOneWidget);
    expect(find.text('Confirmar contraseña'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Siguiente'), findsOneWidget);
  });

  testWidgets('Register step 1 rejects mismatched passwords', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: RegisterScreen())),
    );

    await tester.enterText(find.byType(TextField).at(0), 'Miguel');
    await tester.enterText(find.byType(TextField).at(1), 'bigmike');
    await tester.enterText(find.byType(TextField).at(2), 'mike@test.com');
    await tester.enterText(find.byType(TextField).at(3), 'secret123');
    await tester.enterText(find.byType(TextField).at(4), 'distinto123');

    await tester.tap(find.widgetWithText(ElevatedButton, 'Siguiente'));
    await tester.pump();

    expect(find.text('Las contraseñas no coinciden.'), findsOneWidget);
    expect(find.text('Paso 1 de 2'), findsOneWidget);
  });

  testWidgets('Register step 1 advances when passwords match', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: RegisterScreen())),
    );

    await tester.enterText(find.byType(TextField).at(0), 'Miguel');
    await tester.enterText(find.byType(TextField).at(1), 'bigmike');
    await tester.enterText(find.byType(TextField).at(2), 'mike@test.com');
    await tester.enterText(find.byType(TextField).at(3), 'secret123');
    await tester.enterText(find.byType(TextField).at(4), 'secret123');

    await tester.tap(find.widgetWithText(ElevatedButton, 'Siguiente'));
    await tester.pumpAndSettle();

    expect(find.text('Paso 2 de 2'), findsOneWidget);
  });

  testWidgets('Dashboard renders its sections', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: DashboardScreen())),
    );

    expect(find.text('DASHBOARD'), findsOneWidget);
    expect(find.text('Hoy'), findsOneWidget);
    expect(find.text('Insights y análisis'), findsOneWidget);
    expect(find.text('Hábitos'), findsOneWidget);
    // Anillos nuevos del dashboard.
    expect(find.text('Calorías'), findsOneWidget);
    expect(find.text('Entrenamiento'), findsOneWidget);
    expect(find.text('Pasos'), findsOneWidget);
  });

  testWidgets('Main scaffold shows liquid glass nav and quick action', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: MainScaffold())),
    );
    await tester.pump();

    // Barra flotante: 4 pestañas + acción rápida central. Sin FAB.
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byIcon(Icons.person_outline), findsOneWidget);
    expect(find.byIcon(Icons.fitness_center_outlined), findsOneWidget);
    expect(find.byIcon(Icons.apple_outlined), findsOneWidget);
    // Dashboard arranca seleccionado: icono filled.
    expect(find.byIcon(Icons.grid_view), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
  });

  testWidgets('Navigation switches tabs and quick action opens the sheet', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: MainScaffold())),
    );
    await tester.pump();

    // Tab de Nutrición muestra su placeholder.
    await tester.tap(find.byIcon(Icons.apple_outlined));
    await tester.pump();
    expect(find.text('Sin registros para hoy.'), findsOneWidget);

    // La acción rápida abre la hoja de atajos.
    await tester.tap(find.bySemanticsLabel('Acción rápida'));
    await tester.pumpAndSettle();
    expect(find.text('Atajos'), findsOneWidget);

    // Vuelta a Dashboard: la hoja ofrece su propio botón de cerrar (X).
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    // Ahora Nutrición está activa y Dashboard se muestra outlined.
    await tester.tap(find.byIcon(Icons.grid_view_outlined));
    await tester.pump();
    expect(find.text('DASHBOARD'), findsOneWidget);
  });

  testWidgets('Workouts screen shows empty state and More section', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: WorkoutsScreen())),
    );

    expect(find.text('Entrenos'), findsOneWidget);
    expect(find.text('Biblioteca de entrenos'), findsOneWidget);
    expect(find.text('Programa activo'), findsNothing);
    expect(find.textContaining('La biblioteca está vacía'), findsOneWidget);
    expect(find.text('Más'), findsOneWidget);
    expect(find.text('Historial de entrenos'), findsOneWidget);
  });

  testWidgets('Days cycle dialog asks for the cycle length', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDaysCycleDialog(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(
      find.text('¿Cuántos días tiene tu ciclo de entrenamiento?'),
      findsOneWidget,
    );
  });

  testWidgets('Create program screen shows tabs, empty state and footer', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: CreateProgramScreen(days: 3))),
    );

    expect(find.text('Crear programa'), findsOneWidget);
    expect(find.text('Entreno A'), findsWidgets);
    expect(find.text('Entreno B'), findsWidgets);
    expect(find.text('Entreno C'), findsWidgets);
    expect(find.text('Guardar en biblioteca'), findsOneWidget);
    expect(find.text('Activar programa'), findsOneWidget);
    expect(find.textContaining('día de descanso'), findsOneWidget);
  });

  testWidgets('Workout preview renders exercises and footer', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: WorkoutPreviewScreen(
          title: 'Entreno A',
          exercises: _fixtureExercises,
        ),
      ),
    );

    expect(find.text('Entreno A'), findsOneWidget);
    expect(find.text('2 Ejercicios'), findsOneWidget);
    expect(find.text('Bench Press'), findsOneWidget);
    expect(find.text('Iniciar entrenamiento'), findsOneWidget);
    expect(find.text('Activar programa'), findsNothing);
    expect(find.text('Actualizar plan'), findsNothing);
  });

  testWidgets('Workout preview shows empty state without exercises', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: WorkoutPreviewScreen(title: 'Entreno A')),
    );

    expect(
      find.text('Este entrenamiento no tiene ejercicios.'),
      findsOneWidget,
    );
  });

  testWidgets('Active workout shows timer and set table', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: ActiveWorkoutScreen(exercises: _fixtureExercises)),
      ),
    );
    await tester.pump();

    expect(find.text('0:00:00'), findsOneWidget);
    expect(find.text('Bench Press'), findsOneWidget);
    expect(find.text('Serie'), findsOneWidget);
    expect(find.text('Anterior'), findsOneWidget);
    expect(find.text('Reps'), findsOneWidget);
    expect(find.text('RIR'), findsOneWidget);
    expect(find.text('Lb'), findsOneWidget);
    expect(find.text('Agregar serie de calentamiento (W)'), findsOneWidget);
    await tester.drag(find.byType(ListView).last, const Offset(0, -300));
    await tester.pump();
    expect(find.text('Finalizar Entrenamiento'), findsOneWidget);
  });

  testWidgets('Exercise info sheet renders details without video controls', (
    tester,
  ) async {
    const exercise = PreviewExercise(
      name: 'Bench Press',
      muscles: ['Chest'],
      isBodyweight: false,
      target: 'Pectoralis',
      equipment: 'Barbell',
      instructions: 'Press the bar from your chest.',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ExerciseInfoSheet(exercise: exercise)),
      ),
    );

    expect(find.text('Bench Press'), findsOneWidget);
    expect(find.text('Objetivo'), findsOneWidget);
    expect(find.text('Pectoralis'), findsOneWidget);
    expect(find.text('Equipo'), findsOneWidget);
    expect(find.text('Barbell'), findsOneWidget);
    expect(find.text('Instrucciones'), findsOneWidget);
    expect(find.byIcon(Icons.speed), findsNothing);
  });

  testWidgets('More screen shows profile, dark toggle and logout', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: MoreScreen())),
    );
    await tester.pump();

    expect(find.text('PERFIL'), findsOneWidget);
    expect(find.text('Perfil'), findsOneWidget);
    expect(find.text('Comunidad'), findsOneWidget);
    expect(find.text('Cerrar sesión'), findsOneWidget);
  });

  testWidgets(
    'Edit profile screen shows all fields and locks navigation when incomplete',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(
            () => _TestAuthController(
              const AuthState(
                user: AuthUser(
                  id: 'u1',
                  username: 'bigmike',
                  email: 'mike@test.com',
                  fullName: null,
                  weight: null,
                  height: null,
                ),
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: EditProfileScreen()),
        ),
      );
      await tester.pump();

      expect(find.text('Editar Perfil'), findsOneWidget);
      expect(find.text('Nombre completo'), findsOneWidget);
      expect(find.text('Nombre de usuario'), findsOneWidget);
      expect(find.text('Guardar Cambios'), findsOneWidget);

      final popScope =
          tester.widget(find.byWidgetPredicate((w) => w is PopScope))
              as PopScope;
      expect(popScope.canPop, isFalse);

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.automaticallyImplyLeading, isFalse);

      // Pressing Guardar Cambios with empty fields shows error SnackBar
      await tester.tap(find.text('Guardar Cambios'));
      await tester.pump();

      expect(
        find.text('Por favor completa tu nombre, peso y altura.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Edit profile screen allows pop when profile is complete',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(
            () => _TestAuthController(
              const AuthState(
                user: AuthUser(
                  id: 'u1',
                  username: 'bigmike',
                  email: 'mike@test.com',
                  fullName: 'Big Mike',
                  weight: 85.0,
                  height: 182.0,
                ),
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: EditProfileScreen()),
        ),
      );
      await tester.pump();

      final popScope =
          tester.widget(find.byWidgetPredicate((w) => w is PopScope))
              as PopScope;
      expect(popScope.canPop, isTrue);

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.automaticallyImplyLeading, isTrue);
    },
  );

  testWidgets('Shortcuts sheet shows tools and create actions', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ShortcutsSheet())),
    );

    expect(find.text('Atajos'), findsOneWidget);
    expect(find.text('Cronómetro'), findsOneWidget);
    expect(find.text('Temporizador'), findsOneWidget);
    expect(find.text('Iniciar entrenamiento vacío'), findsOneWidget);
    expect(find.text('Crear entrenamiento'), findsOneWidget);
    expect(find.text('Nuevo programa'), findsNothing);
    expect(find.text('Peso'), findsNothing);
    expect(find.text('New Workout'), findsNothing);
  });

  testWidgets('Create workout screen renders empty state and actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: CreateWorkoutScreen())),
    );

    expect(find.text('Crear entrenamiento'), findsOneWidget);
    expect(find.text('Nombre del entrenamiento'), findsOneWidget);
    expect(find.text('Sin ejercicios todavía'), findsOneWidget);
    expect(find.text('Agregar ejercicios'), findsOneWidget);
    expect(find.text('Guardar en biblioteca'), findsOneWidget);
  });

  testWidgets('Workouts screen + button opens simplified add sheet', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: WorkoutsScreen())),
    );
    await tester.pump();

    // Tap + button in AppBar
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(find.text('Agregar'), findsOneWidget);
    expect(find.text('Iniciar entrenamiento vacío'), findsOneWidget);
    expect(find.text('Crear entrenamiento'), findsOneWidget);
    expect(find.text('Nuevo programa'), findsNothing);
  });

  testWidgets('Stopwatch screen renders its controls', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: StopwatchScreen()));

    expect(find.text('Cronómetro'), findsOneWidget);
    expect(find.text('Inicio'), findsOneWidget);
    expect(find.text('Reiniciar'), findsOneWidget);
  });

  testWidgets('Timer screen renders presets and create button', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: TimerScreen()));

    expect(find.text('Temporizador'), findsOneWidget);
    expect(find.text('Mis temporizadores'), findsOneWidget);
    expect(find.text('Crear nuevo'), findsOneWidget);
  });

  testWidgets('Empty active workout shows free workout state', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: ActiveWorkoutScreen(exercises: []))),
    );
    await tester.pump();

    expect(
      find.text('Entrenamiento libre. Agrega ejercicios para comenzar.'),
      findsOneWidget,
    );
    expect(find.text('Agregar ejercicio'), findsOneWidget);
    expect(find.text('Finalizar Entrenamiento'), findsOneWidget);
  });

  testWidgets('App is permanently dark with no appearance setting', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MacrobuddyApp(),
      ),
    );
    await tester.pump();

    expect(
      Theme.of(tester.element(find.text('Inicia sesión'))).brightness,
      Brightness.dark,
    );
    expect(find.byType(SwitchListTile), findsNothing);
  });

  testWidgets('Community screen shows title and empty states', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: CommunityScreen())),
    );
    await tester.pump();

    expect(find.text('Comunidad'), findsOneWidget);
    expect(find.text('Entrenando ahora'), findsOneWidget);
    expect(find.text('El gimnasio está vacío en este momento'), findsOneWidget);
    expect(find.text('Actividad global'), findsOneWidget);
  });

  testWidgets(
    'Community screen renders training vs online border and enables tap only for training',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          communityProvider.overrideWith(
            () => _TestCommunityController(
              const CommunityState(
                activeUsers: [
                  ActiveUser(
                    userId: 'u1',
                    username: 'IronMike',
                    status: 'training',
                  ),
                  ActiveUser(
                    userId: 'u2',
                    username: 'LazyBob',
                    status: 'online',
                  ),
                ],
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: CommunityScreen()),
        ),
      );
      await tester.pump();

      expect(find.text('IronMike'), findsOneWidget);
      expect(find.text('LazyBob'), findsOneWidget);

      // Verify containers decoration border
      final containers = tester.widgetList<Container>(
        find.descendant(
          of: find.byType(ListView),
          matching: find.byType(Container),
        ),
      );
      final trainingContainer = containers.firstWhere(
        (c) =>
            c.decoration is BoxDecoration &&
            (c.decoration as BoxDecoration).border != null &&
            ((c.decoration as BoxDecoration).border as Border).top.color ==
                Colors.greenAccent,
      );
      expect(trainingContainer, isNotNull);

      // Tap on training user opens sheet
      await tester.tap(find.text('IronMike'));
      await tester.pumpAndSettle();
      expect(find.text('Fuego'), findsOneWidget);
      expect(find.text('Fuerza'), findsOneWidget);
      expect(find.text('Pesas'), findsOneWidget);

      // Close bottom sheet
      await tester.tap(find.text('Fuego'));
      await tester.pumpAndSettle();

      // Tap on online user does not open bottom sheet
      await tester.tap(find.text('LazyBob'));
      await tester.pumpAndSettle();
      expect(find.text('Fuego'), findsNothing);
    },
  );

  testWidgets(
    'Dashboard renders bar chart and TableCalendar when user has workouts',
    (tester) async {
      final now = DateTime.now();
      final mockSessions = [
        WorkoutSession(
          id: 's1',
          date: now,
          sets: const [
            WorkoutSessionSet(
              setNumber: 1,
              weight: 100,
              reps: 10,
              isWarmup: false,
            ),
            WorkoutSessionSet(
              setNumber: 2,
              weight: 120,
              reps: 8,
              isWarmup: false,
            ),
          ],
        ),
      ];

      final container = ProviderContainer(
        overrides: [
          dashboardProvider.overrideWith((ref) => mockSessions),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: DashboardScreen()),
        ),
      );
      await tester.pump();

      expect(find.text('DASHBOARD'), findsOneWidget);
      expect(find.text('Insights y análisis'), findsOneWidget);
      expect(find.text('Volumen total (Lb)'), findsOneWidget);
      expect(find.text('Total: 1960 lb'), findsOneWidget);
      expect(find.text('Actividad mensual'), findsOneWidget);
      expect(find.text('1 entreno registrado'), findsOneWidget);
      expect(find.text('Entrenado'), findsOneWidget);
      expect(
        find.text('Sin datos todavía. Completa tu primer entrenamiento para ver tus métricas.'),
        findsNothing,
      );
    },
  );

  testWidgets(
    'Active workout warmup set (W) hides RIR input and keeps row in view when done',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: ActiveWorkoutScreen(exercises: _fixtureExercises),
          ),
        ),
      );
      await tester.pump();

      // Add a warmup set
      await tester.tap(find.text('Agregar serie de calentamiento (W)'));
      await tester.pump();

      expect(find.text('W'), findsOneWidget);

      // Verify the RIR input is hidden for warmup row and shows placeholder '—'
      expect(find.text('—'), findsWidgets);

      // Enter weight and reps on the warmup row
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), '50');
      await tester.enterText(textFields.at(1), '10');
      await tester.pump();

      // Mark the warmup set as done
      final checkboxes = find.byType(Checkbox);
      await tester.tap(checkboxes.at(0));
      await tester.pump();

      // Warmup set is still in the widget tree (dimmed, not removed from state)
      expect(find.text('W'), findsOneWidget);
    },
  );

  testWidgets(
    'Active workout set validation prevents checking and shows SnackBar when fields empty',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: ActiveWorkoutScreen(exercises: _fixtureExercises),
          ),
        ),
      );
      await tester.pump();

      // Checkbox at index 0 has empty weight and reps
      final checkboxes = find.byType(Checkbox);
      await tester.tap(checkboxes.first);
      await tester.pump();

      expect(find.text('Ingresa peso y repeticiones'), findsOneWidget);
    },
  );

  testWidgets(
    'Active workout delete button removes exercise from active workout',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: ActiveWorkoutScreen(exercises: _fixtureExercises),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Bench Press'), findsOneWidget);
      final deleteBtn = find.byIcon(Icons.delete_outline);
      expect(deleteBtn, findsOneWidget);

      await tester.tap(deleteBtn);
      await tester.pump();

      expect(find.text('Bench Press'), findsNothing);
      expect(find.text('Pull Up'), findsOneWidget);
    },
  );

  testWidgets(
    'Workouts screen renders library items in ReorderableListView',
    (tester) async {
      final plans = [
        const WorkoutPlan(id: 'p1', name: 'Upper 1'),
        const WorkoutPlan(id: 'p2', name: 'Lower 1'),
      ];

      final container = ProviderContainer(
        overrides: [
          workoutProvider.overrideWith(
            () => _TestWorkoutController(
              WorkoutsState(workouts: plans),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: WorkoutsScreen()),
        ),
      );
      await tester.pump();

      expect(find.byType(ReorderableListView), findsOneWidget);
      expect(find.text('Upper 1'), findsOneWidget);
      expect(find.text('Lower 1'), findsOneWidget);
    },
  );

  testWidgets(
    'Dashboard dynamic goals calculate targets from library workouts',
    (tester) async {
      final plans = [
        const WorkoutPlan(
          id: 'p1',
          name: 'Upper 1',
          exercises: [
            WorkoutPlanExercise(
              exerciseId: 'e1',
              name: 'Bench Press',
              muscleGroup: 'Chest',
              sets: 4,
            ),
            WorkoutPlanExercise(
              exerciseId: 'e2',
              name: 'Incline Press',
              muscleGroup: 'Chest',
              sets: 3,
            ),
          ],
        ),
        const WorkoutPlan(
          id: 'p2',
          name: 'Lower 1',
          exercises: [
            WorkoutPlanExercise(
              exerciseId: 'e3',
              name: 'Squat',
              muscleGroup: 'Legs',
              sets: 5,
            ),
          ],
        ),
      ];

      final container = ProviderContainer(
        overrides: [
          workoutProvider.overrideWith(
            () => _TestWorkoutController(
              WorkoutsState(workouts: plans),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: DashboardScreen()),
        ),
      );
      await tester.pump();

      // Anillo Entrenamiento: objetivo del ciclo = nº de entrenos del
      // programa (Upper 1 + Lower 1 = 2 sesiones objetivo).
      expect(find.text('2 objetivo'), findsOneWidget);
      // Anillos de Calorías y Pasos con sus textos de contexto.
      expect(find.text('kcal hoy'), findsOneWidget);
      expect(find.text('pasos hoy'), findsOneWidget);
      expect(find.text('8000 objetivo'), findsOneWidget);
    },
  );
}

class _TestWorkoutController extends WorkoutController {
  _TestWorkoutController(this._initialState);
  final WorkoutsState _initialState;

  @override
  WorkoutsState build() => _initialState;
}

class _TestCommunityController extends CommunityController {
  _TestCommunityController(this._initialState);
  final CommunityState _initialState;

  @override
  CommunityState build() => _initialState;

  @override
  void cheer(
    String targetUserId, {
    String? workoutId,
    String reactionType = 'fire',
  }) {}

  @override
  void updatePresence(String status) {}
}

class _TestAuthController extends AuthController {
  _TestAuthController(this._initialState);
  final AuthState _initialState;

  @override
  AuthState build() => _initialState;

  @override
  Future<String?> updateProfile({
    required String fullName,
    required String username,
    double? weight,
    double? height,
    String? gender,
    String? currentPassword,
    String? newPassword,
    double? targetCalories,
    double? targetProtein,
    double? targetCarbs,
    double? targetFats,
  }) async {
    return null;
  }
}
