import 'dart:convert';

import 'package:http/http.dart' as http;

/// Resultado de una consulta a OpenFoodFacts con los macros por producto.
class OffProduct {
  const OffProduct({
    required this.barcode,
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fats,
    required this.per100g,
    this.servingSizeG,
    this.imageUrl,
  });

  final String barcode;
  final String name;
  final double calories;
  final double protein;
  final double carbs;
  final double fats;

  /// true si los valores corresponden a 100 g, false si a una porción.
  final bool per100g;
  final double? servingSizeG;
  final String? imageUrl;

  /// Macros escalados a `grams` de producto.
  ({double calories, double protein, double carbs, double fats}) forGrams(
    double grams,
  ) {
    final base = per100g ? grams / 100 : grams / (servingSizeG ?? 100);
    return (
      calories: calories * base,
      protein: protein * base,
      carbs: carbs * base,
      fats: fats * base,
    );
  }
}

/// Cliente de la API v2 de OpenFoodFacts (no requiere llave).
class OpenFoodFactsService {
  OpenFoodFactsService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<OffProduct?> fetchByBarcode(String barcode) async {
    try {
      final res = await _client
          .get(
            Uri.https(
              'world.openfoodfacts.org',
              '/api/v2/product/$barcode.json',
              {'fields': _fields},
            ),
          )
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final status = body['status'] as int? ?? 0;
      final product = body['product'] as Map<String, dynamic>?;
      if (status != 1 || product == null) return null;

      final name =
          (product['product_name_es'] ?? product['product_name'] ?? '')
              .toString()
              .trim();
      final nutriments = product['nutriments'] as Map<String, dynamic>? ?? {};

      final kcal100 =
          _num(nutriments['energy-kcal_100g']) ??
          _kilojoulesToKcal(nutriments['energy_100g']);
      final weight = _num(product['serving_quantity']);
      final psi = product['nutrition_data_per']?.toString();

      if (psi?.endsWith('serving') == true) {
        // Macros declarados por porción, no por 100 g.
        return OffProduct(
          barcode: barcode,
          name: name.isNotEmpty ? name : 'Producto escaneado',
          calories: _num(nutriments['energy-kcal_serving']) ?? kcal100 ?? 0,
          protein: _num(nutriments['proteins_serving']) ?? 0,
          carbs: _num(nutriments['carbohydrates_serving']) ?? 0,
          fats: _num(nutriments['fat_serving']) ?? 0,
          per100g: false,
          servingSizeG: weight,
          imageUrl: product['image_front_url'] as String?,
        );
      }

      final kcal = kcal100;
      final protein = _num(nutriments['proteins_100g']);
      final carbs = _num(nutriments['carbohydrates_100g']);
      final fats = _num(nutriments['fat_100g']);

      // Sin macros utilizables no tiene sentido registrar el producto.
      if ((kcal ?? 0) == 0 && (protein ?? 0) == 0 && (carbs ?? 0) == 0 && (fats ?? 0) == 0) {
        return null;
      }

      return OffProduct(
        barcode: barcode,
        name: name.isNotEmpty ? name : 'Producto escaneado',
        calories: kcal ?? 0,
        protein: protein ?? 0,
        carbs: carbs ?? 0,
        fats: fats ?? 0,
        per100g: true,
        servingSizeG: weight,
        imageUrl: product['image_front_url'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  static const _fields =
      'product_name,product_name_es,image_front_url,serving_quantity,'
      'nutrition_data_per,energy-kcal_100g,energy-kcal_serving,energy_100g,'
      'proteins_100g,proteins_serving,carbohydrates_100g,carbohydrates_serving,'
      'fat_100g,fat_serving';

  double? _num(Object? value) =>
      value is num ? value.toDouble() : double.tryParse('$value');

  double? _kilojoulesToKcal(Object? kj) {
    final v = _num(kj);
    return v == null ? null : v / 4.184;
  }

  void dispose() => _client.close();
}
