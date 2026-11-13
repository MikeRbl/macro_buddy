import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:macrobuddy/features/onboarding/onboarding_content.dart';
import 'package:macrobuddy/features/onboarding/onboarding_widgets.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Bienvenida: avanza por las páginas y termina', (tester) async {
    var done = false;
    await tester.pumpWidget(
      MaterialApp(home: WelcomeOnboardingScreen(onDone: () => done = true)),
    );
    expect(find.text('Bienvenido a MacroBuddy'), findsOneWidget);

    for (var i = 0; i < welcomeSteps.length - 1; i++) {
      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();
    }
    expect(find.text(welcomeSteps.last.title), findsOneWidget);
    await tester.tap(find.text('Empezar'));
    expect(done, isTrue);
  });

  testWidgets('Bienvenida: Omitir termina de inmediato', (tester) async {
    var done = false;
    await tester.pumpWidget(
      MaterialApp(home: WelcomeOnboardingScreen(onDone: () => done = true)),
    );
    await tester.tap(find.text('Omitir'));
    expect(done, isTrue);
  });

  for (final section in AppSection.values) {
    testWidgets('Botón ? de ${section.name}: ayuda y repetir recorrido', (
      tester,
    ) async {
      final guide = sectionGuides[section]!;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Center(child: SectionHelpButton(section: section)),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(SectionHelpButton));
      await tester.pumpAndSettle();
      expect(find.text('Ayuda · ${guide.name}'), findsOneWidget);
      expect(find.text(guide.steps.first.title), findsOneWidget);

      await tester.tap(find.text('Repetir recorrido de la sección'));
      await tester.pumpAndSettle();
      expect(find.text('Así funciona ${guide.name}'), findsOneWidget);

      for (var i = 0; i < guide.steps.length - 1; i++) {
        await tester.tap(find.text('Siguiente'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Entendido'));
      await tester.pumpAndSettle();
      expect(find.text('Así funciona ${guide.name}'), findsNothing);
    });
  }
}
