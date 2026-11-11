import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macrobuddy/core/models/coach_link.dart';
import 'package:macrobuddy/features/auth/auth_controller.dart';
import 'package:macrobuddy/features/profile/coach_card.dart';
import 'package:macrobuddy/features/profile/link_coach_screen.dart';

void main() {
  test('extractLinkCode lee el QR y el código escrito a mano', () {
    expect(extractLinkCode('macrobuddy://link?code=MB-7K4Q-29'), 'MB-7K4Q-29');
    expect(extractLinkCode(' mb 7k4q 29 '), 'MB-7K4Q-29');
    expect(extractLinkCode('mb7k4q29'), 'MB-7K4Q-29');
    expect(extractLinkCode('7501000111111'), isNull);
    expect(extractLinkCode('MB-7K4Q-2'), isNull);
  });

  CoachLink link({bool active = true, bool macros = false, bool routines = false}) =>
      CoachLink.fromJson({
        'id': 'l1',
        'status': active ? 'active' : 'pending',
        'role': 'nutritionist',
        'permissions': {'setMacros': macros, 'manageRoutines': routines},
        'professional': {'displayName': 'Profesional de prueba'},
      });

  ProviderContainer container(List<CoachLink> links) {
    final c = ProviderContainer(
      overrides: [coachLinksProvider.overrideWith((ref) async => links)],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('los bloqueos salen de los permisos del vínculo activo', () async {
    final c = container([link(macros: true)]);
    await c.read(coachLinksProvider.future);
    expect(c.read(macrosLockedProvider), isTrue);
    expect(c.read(isGuidedModeProvider), isFalse);

    // Una solicitud pendiente todavía no bloquea nada.
    final pending = container([link(active: false, macros: true, routines: true)]);
    await pending.read(coachLinksProvider.future);
    expect(pending.read(macrosLockedProvider), isFalse);
    expect(pending.read(isGuidedModeProvider), isFalse);
  });

  testWidgets('CoachCard muestra al profesional y permite desvincular', (tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container([link(macros: true)]),
        child: const MaterialApp(home: Scaffold(body: CoachCard())),
      ),
    );
    await tester.pump();

    expect(find.text('Profesional de prueba'), findsOneWidget);
    expect(find.text('Nutriólogo'), findsOneWidget);
    expect(find.text('Activo'), findsOneWidget);
    expect(find.text('Desvincular'), findsOneWidget);
    expect(find.text('Vincular otro profesional'), findsOneWidget);
  });

  testWidgets('CoachCard sin vínculo ofrece vincular', (tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container(const []),
        child: const MaterialApp(home: Scaffold(body: CoachCard())),
      ),
    );
    await tester.pump();

    expect(find.text('Sin vínculo'), findsOneWidget);
    expect(find.text('Vincular entrenador'), findsOneWidget);
  });
}
