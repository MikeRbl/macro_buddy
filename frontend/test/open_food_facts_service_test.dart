import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:macrobuddy/core/services/open_food_facts_service.dart';

void main() {
  final service = OpenFoodFactsService();

  group('OpenFoodFacts HTTP', () {
    test('envía User-Agent al producto y no auth', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response(jsonEncode({'status': 0}), 200);
      });
      final httpService = OpenFoodFactsService(client: client);

      expect(await httpService.fetchByBarcode('12345678'), isNull);

      expect(captured.url.host, 'world.openfoodfacts.org');
      expect(captured.url.path, '/api/v2/product/12345678.json');
      expect(
        captured.headers['User-Agent'],
        'MacrobuddyApp/1.0 (maicoalf77@gmail.com)',
      );
      expect(captured.headers.containsKey('Authorization'), isFalse);
    });

    test('la búsqueda por texto usa Search-a-licious', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'hits': [
              {
                'code': '12345678',
                'product_name_es': 'Leche entera',
                'brands': ['Marca', 'Otra'],
                'quantity': '1 l',
                'image_front_url': 'https://example.com/leche.jpg',
              },
            ],
          }),
          200,
        );
      });
      final httpService = OpenFoodFactsService(client: client);

      final results = await httpService.searchProducts('leche');

      expect(results, hasLength(1));
      expect(results.first.barcode, '12345678');
      expect(results.first.name, 'Leche entera');
      expect(results.first.brand, 'Marca, Otra');
      expect(results.first.quantity, '1 l');
      expect(results.first.imageUrl, 'https://example.com/leche.jpg');
      expect(captured.url.host, 'search.openfoodfacts.org');
      expect(captured.url.path, '/search');
      expect(captured.url.queryParameters['q'], 'leche');
      expect(captured.url.queryParameters['page_size'], '10');
      expect(captured.url.queryParameters['langs'], 'es,en');
      expect(captured.url.queryParameters['fields'], contains('code'));
      expect(
        captured.headers['User-Agent'],
        'MacrobuddyApp/1.0 (maicoalf77@gmail.com)',
      );
      expect(captured.headers.containsKey('Authorization'), isFalse);
    });

    test('ignora hits sin código o nombre y deduplica', () async {
      final client = MockClient((_) async {
        return http.Response(
          jsonEncode({
            'hits': [
              {'code': '1', 'product_name': 'Uno'},
              {'code': '1', 'product_name': 'Duplicado'},
              {'code': '', 'product_name': 'Sin código'},
              {'code': '2', 'product_name': '  '},
              {'code': '3', 'generic_name': 'Tres'},
            ],
          }),
          200,
        );
      });
      final results = await OpenFoodFactsService(
        client: client,
      ).searchProducts('x');

      expect(results.map((r) => r.barcode), ['1', '3']);
      expect(results.last.name, 'Tres');
    });

    test('cachea productos por código', () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return http.Response(
          jsonEncode({'status': 1, 'product': _per100}),
          200,
        );
      });
      final httpService = OpenFoodFactsService(client: client);

      final first = await httpService.fetchByBarcode('1');
      final second = await httpService.fetchByBarcode('1');

      expect(first, isNotNull);
      expect(second, same(first));
      expect(calls, 1);
    });

    test('cachea búsquedas por texto', () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return http.Response(jsonEncode({'hits': []}), 200);
      });
      final httpService = OpenFoodFactsService(client: client);

      await httpService.searchProducts('leche');
      await httpService.searchProducts('  LECHE  ');

      expect(calls, 1);
    });

    test('mapea 503 a saturación con el mensaje para el usuario', () async {
      final client = MockClient((_) async => http.Response('', 503));
      final httpService = OpenFoodFactsService(
        client: client,
        retryDelay: Duration.zero,
      );

      await expectLater(
        httpService.fetchByBarcode('12345678'),
        throwsA(
          isA<OffException>()
              .having((e) => e.kind, 'kind', OffFailure.busy)
              .having(
                (e) => e.message,
                'message',
                contains('temporalmente saturado'),
              ),
        ),
      );
    });

    test('mapea 504 a saturación', () async {
      final client = MockClient((_) async => http.Response('', 504));
      final httpService = OpenFoodFactsService(
        client: client,
        retryDelay: Duration.zero,
      );

      await expectLater(
        httpService.fetchByBarcode('12345678'),
        throwsA(
          isA<OffException>().having((e) => e.kind, 'kind', OffFailure.busy),
        ),
      );
    });

    test('mapea 429 a límite de consultas', () async {
      final client = MockClient((_) async => http.Response('', 429));
      final httpService = OpenFoodFactsService(
        client: client,
        retryDelay: Duration.zero,
      );

      await expectLater(
        httpService.fetchByBarcode('12345678'),
        throwsA(
          isA<OffException>()
              .having((e) => e.kind, 'kind', OffFailure.rateLimited)
              .having((e) => e.message, 'message', contains('limitando')),
        ),
      );
    });
  });

  group('OpenFoodFacts parseProduct', () {
    test('prioriza los valores declarados por 100 g', () {
      final p = service.parseProduct(_per100, barcode: '3600542519104');

      expect(p, isNotNull);
      expect(p!.per100g, isTrue);
      expect(p.barcode, '3600542519104');
      expect(p.name, 'Leche entera');
      expect(p.calories, 62);
      expect(p.protein, 3.4);
      expect(p.carbs, 4.8);
      expect(p.fats, 3.6);
      expect(p.servingSizeG, 250);
    });

    test('respeta porción SOLO cuando nutrition_data_per == "serving"', () {
      final p = service.parseProduct(_perServing, barcode: '555');

      expect(p!.per100g, isFalse);
      expect(p.calories, 220);
      expect(p.protein, 12);
      expect(p.carbs, 24);
      expect(p.fats, 7);
      expect(p.servingSizeG, 60);
    });

    test('con kcal/porción ausente cae a 100 g aunque dicho sea serving', () {
      // Estilo OFF: kcal given as kJ only, per 100 g.
      final p = service.parseProduct(_perServingWithoutKcal, barcode: '556');

      expect(p!.per100g, isTrue);
      expect(p.calories, closeTo(56.6, 0.1)); // 237 kJ / 4.184
      expect(p.protein, 3.4);
    });

    test('con kcal por kJ (energy_100g) hace la conversión', () {
      final p = service.parseProduct(_kilojoulesOnly, barcode: '77');

      expect(p!.calories, closeTo(23.9, 0.1)); // 100 kJ / 4.184
    });

    test('devuelve null cuando no hay macros utilizables', () {
      expect(service.parseProduct(_noMacros, barcode: '1'), isNull);
    });

    test('descarta valores numéricos inválidos', () {
      final p = service.parseProduct(_garbled, barcode: '99');

      // kcal no parseable → se queda con kcal null pero las prote
      // declaradas en el JSON corrupto ('oops') son 0 → null.
      expect(p, isNull);
    });
  });
}

// ── Fixtures tipo OpenFoodFacts ──────────────────────────────────────────
const _per100 = {
  'product_name': 'Whole milk',
  'product_name_es': 'Leche entera',
  'serving_quantity': 250,
  'nutrition_data_per': '100g',
  'nutriments': {
    'energy-kcal_100g': 62,
    'proteins_100g': 3.4,
    'carbohydrates_100g': 4.8,
    'fat_100g': 3.6,
  },
};

const _perServing = {
  'product_name': 'Protein bar',
  'serving_quantity': 60,
  'nutrition_data_per': 'serving',
  'nutriments': {
    'energy-kcal_serving': 220,
    'proteins_serving': 12,
    'carbohydrates_serving': 24,
    'fat_serving': 7,
  },
};

const _perServingWithoutKcal = {
  'product_name': 'Sin kcal de porción declarada',
  'nutrition_data_per': 'serving',
  'nutriments': {'energy_100g': 237, 'proteins_100g': 3.4},
};

const _kilojoulesOnly = {
  'product_name': 'Bebida energética',
  'nutrition_data_per': '100g',
  'nutriments': {'energy_100g': 100},
};

const _noMacros = {
  'product_name': 'Vacío total',
  'nutrition_data_per': '100g',
  'nutriments': <String, dynamic>{},
};

const _garbled = {
  'product_name': 'Valores corruptos',
  'nutrition_data_per': '100g',
  'nutriments': {'energy-kcal_100g': 'NaN', 'proteins_100g': 'oops'},
};
