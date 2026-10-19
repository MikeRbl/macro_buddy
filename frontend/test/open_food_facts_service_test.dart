import 'package:flutter_test/flutter_test.dart';

import 'package:macrobuddy/core/services/open_food_facts_service.dart';

void main() {
  final service = OpenFoodFactsService();

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
  'nutriments': {
    'energy_100g': 237,
    'proteins_100g': 3.4,
  },
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
  'nutriments': {
    'energy-kcal_100g': 'NaN',
    'proteins_100g': 'oops',
  },
};
