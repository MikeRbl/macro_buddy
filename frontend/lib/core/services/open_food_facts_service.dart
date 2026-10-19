import 'dart:async';
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

/// Motivo por el que una consulta a OpenFoodFacts falló: permite
/// distinguir "sin red" (reintentar) de "el producto no existe" (registrar
/// manualmente).
enum OffFailure { network, server }

class OffException implements Exception {
  const OffException(this.kind, {this.statusCode});

  final OffFailure kind;
  final int? statusCode;

  String get message => kind == OffFailure.network
      ? 'No se pudo contactar OpenFoodFacts. Revisa tu conexión.'
      : 'OpenFoodFacts respondió con un error '
            '(HTTP ${statusCode ?? "desconocido"}).';
}

/// Cliente de la API v2 de OpenFoodFacts (no requiere llave).
/// Requiere un User-Agent identificativo: OFF lo pide para rastrear el
/// uso de la app (`https://world.openfoodfacts.org/`).
class OpenFoodFactsService {
  OpenFoodFactsService({http.Client? client})
    : _client = client ?? http.Client();

  /// Instancia compartida: vive toda la sesión de la app.
  static final OpenFoodFactsService shared = OpenFoodFactsService();

  final http.Client _client;

  /// Devuelve el producto o `null` si no existe. Lanza `OffException`
  /// (red / servidor) para que quien llama muestre el motivo real: el
  /// fallo de red se tragaba en silencio y parecía "producto no existe".
  ///
  /// `throws: OffException`
  Future<OffProduct?> fetchByBarcode(String barcode) async {
    final body = await _fetchBody(
      Uri.https('world.openfoodfacts.org', '/api/v2/product/$barcode.json', {
        'fields': _productFields,
      }),
    );
    final status = body['status'] as int? ?? 0;
    if (status != 1) return null;
    final product = body['product'];
    if (product is! Map<String, dynamic>) return null;
    return parseProduct(product, barcode: barcode);
  }

  /// Búsqueda libre por nombre/marca. Devuelve hasta `pageSize` productos.
  ///
  /// `throws: OffException`
  Future<List<OffProduct>> searchProducts(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return const [];
    final body = await _fetchBody(
      Uri.https('world.openfoodfacts.org', '/cgi/search.pl', {
        'search_terms': clean,
        'search_simple': '1',
        'action': 'process',
        'json': '1',
        'page_size': '20',
        'fields': 'code,$_productFields',
      }),
    );
    final products = body['products'];
    if (products is! List) return const [];
    return [
      for (final p in products)
        if (p is Map<String, dynamic>)
          parseProduct(p, barcode: p['code']?.toString() ?? ''),
    ].whereType<OffProduct>().toList();
  }

  static const _productFields =
      'product_name,product_name_es,image_front_url,serving_quantity,'
      'nutrition_data_per,energy-kcal_100g,energy-kcal_serving,energy_100g,'
      'proteins_100g,proteins_serving,carbohydrates_100g,carbohydrates_serving,'
      'fat_100g,fat_serving';

  static const _userAgent = 'Macrobuddy - Flutter App - Version 1.0';

  Future<Map<String, dynamic>> _fetchBody(Uri uri) async {
    http.Response res;
    try {
      res = await _client
          .get(uri, headers: const {'User-Agent': _userAgent})
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const OffException(OffFailure.network);
    } catch (_) {
      throw const OffException(OffFailure.network);
    }
    if (res.statusCode != 200) {
      throw OffException(OffFailure.server, statusCode: res.statusCode);
    }
    try {
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw const OffException(OffFailure.server, statusCode: 200);
    }
  }

  /// Parseo público para pruebas y flujos que ya tienen el JSON del
  /// producto a mano.
  OffProduct? parseProduct(
    Map<String, dynamic> product, {
    required String barcode,
  }) {
    final name = (product['product_name_es'] ?? product['product_name'] ?? '')
        .toString()
        .trim();
    final nutriments = product['nutriments'] is Map<String, dynamic>
        ? product['nutriments'] as Map<String, dynamic>
        : const <String, dynamic>{};

    final kcal100 =
        _num(nutriments['energy-kcal_100g']) ??
        _kilojoulesToKcal(nutriments['energy_100g']);
    final servingWeight = _num(product['serving_quantity']);

    final perServing = product['nutrition_data_per']?.toString();
    final kcalServing = _num(nutriments['energy-kcal_serving']);
    final protServing = _num(nutriments['proteins_serving']);
    final carbServing = _num(nutriments['carbohydrates_serving']);
    final fatServing = _num(nutriments['fat_serving']);
    if (perServing == 'serving' &&
        (kcalServing != null ||
            protServing != null ||
            carbServing != null ||
            fatServing != null)) {
      return OffProduct(
        barcode: barcode,
        name: name.isNotEmpty ? name : 'Producto escaneado',
        calories: kcalServing ?? 0,
        protein: protServing ?? 0,
        carbs: carbServing ?? 0,
        fats: fatServing ?? 0,
        per100g: false,
        servingSizeG: servingWeight,
        imageUrl: product['image_front_url'] is String
            ? product['image_front_url'] as String
            : null,
      );
    }

    final protein = _num(nutriments['proteins_100g']);
    final carbs = _num(nutriments['carbohydrates_100g']);
    final fats = _num(nutriments['fat_100g']);

    // Sin macros utilizables no tiene sentido registrar el producto.
    if (kcal100 == null &&
        (protein ?? 0) == 0 &&
        (carbs ?? 0) == 0 &&
        (fats ?? 0) == 0) {
      return null;
    }

    return OffProduct(
      barcode: barcode,
      name: name.isNotEmpty ? name : 'Producto escaneado',
      calories: kcal100 ?? 0,
      protein: protein ?? 0,
      carbs: carbs ?? 0,
      fats: fats ?? 0,
      per100g: true,
      servingSizeG: servingWeight,
      imageUrl: product['image_front_url'] is String
          ? product['image_front_url'] as String
          : null,
    );
  }

  double? _num(Object? value) {
    final v = value is num
        ? value.toDouble()
        : double.tryParse('$value'.trim().replaceAll(',', '.'));
    // Descarta NaN / infinitos que corrompen totales.
    if (v == null || v.isNaN || v.isInfinite || v < 0) return null;
    return v;
  }

  double? _kilojoulesToKcal(Object? kj) {
    final v = _num(kj);
    return v == null ? null : v / 4.184;
  }

  void dispose() => _client.close();
}
