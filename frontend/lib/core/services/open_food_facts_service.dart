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

/// Resultado de la búsqueda de texto (Search-a-licious). Solo trae los
/// datos de listado; los macros se consultan al seleccionar el producto.
class OffSearchResult {
  const OffSearchResult({
    required this.barcode,
    required this.name,
    this.brand,
    this.quantity,
    this.imageUrl,
  });

  final String barcode;
  final String name;
  final String? brand;
  final String? quantity;
  final String? imageUrl;
}

/// Motivo por el que una consulta a OpenFoodFacts falló: permite
/// distinguir "sin red" (reintentar), "servidor saturado" (esperar o
/// registrar manualmente) de "el producto no existe".
enum OffFailure { network, server, busy, rateLimited }

class OffException implements Exception {
  const OffException(this.kind, {this.statusCode});

  final OffFailure kind;
  final int? statusCode;

  String get message => switch (kind) {
    OffFailure.network =>
      'No se pudo contactar OpenFoodFacts. Revisa tu conexión.',
    OffFailure.busy =>
      'El servidor de OpenFoodFacts está temporalmente saturado. '
          'Intenta de nuevo en unos momentos o usa el registro manual.',
    OffFailure.rateLimited =>
      'OpenFoodFacts está limitando las consultas. '
          'Espera un minuto o usa el registro manual.',
    OffFailure.server =>
      'OpenFoodFacts respondió con un error '
          '(HTTP ${statusCode ?? "desconocido"}).',
  };
}

/// Cliente de la API v2 de OpenFoodFacts (no requiere llave).
/// Requiere un User-Agent identificativo: OFF lo pide para rastrear el
/// uso de la app (`https://world.openfoodfacts.org/`).
class OpenFoodFactsService {
  OpenFoodFactsService({
    http.Client? client,
    this.retryDelay = const Duration(milliseconds: 1500),
  }) : _client = client ?? http.Client();

  /// Instancia compartida: vive toda la sesión de la app.
  static final OpenFoodFactsService shared = OpenFoodFactsService();

  final http.Client _client;
  final Duration retryDelay;

  /// Cachés de sesión: evitan repetir consultas y ayudar a respetar los
  /// límites de OpenFoodFacts (15 productos/min y 10 búsquedas/min).
  final Map<String, OffProduct?> _productCache = {};
  final Map<String, List<OffSearchResult>> _searchCache = {};

  /// Devuelve el producto o `null` si no existe. Lanza `OffException`
  /// (red / servidor) para que quien llama muestre el motivo real: el
  /// fallo de red se tragaba en silencio y parecía "producto no existe".
  ///
  /// `throws: OffException`
  Future<OffProduct?> fetchByBarcode(String barcode) async {
    if (_productCache.containsKey(barcode)) return _productCache[barcode];
    final body = await _fetchBody(
      Uri.https('world.openfoodfacts.org', '/api/v2/product/$barcode.json', {
        'fields': _productFields,
      }),
    );
    final status = body['status'] as int? ?? 0;
    if (status != 1) {
      _productCache[barcode] = null;
      return null;
    }
    final product = body['product'];
    if (product is! Map<String, dynamic>) {
      _productCache[barcode] = null;
      return null;
    }
    final parsed = parseProduct(product, barcode: barcode);
    _productCache[barcode] = parsed;
    return parsed;
  }

  /// Búsqueda libre por nombre/marca usando Search-a-licious.
  ///
  /// Devuelve hasta 10 resultados con nombre, marca e imagen. Los macros se
  /// consultan después con [fetchByBarcode] al seleccionar un resultado.
  ///
  /// `throws: OffException`
  Future<List<OffSearchResult>> searchProducts(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return const [];
    final cacheKey = clean.toLowerCase();
    final cached = _searchCache[cacheKey];
    if (cached != null) return cached;

    final body = await _fetchBody(
      Uri.https('search.openfoodfacts.org', '/search', {
        'q': clean,
        'page_size': '10',
        'langs': 'es,en',
        'fields':
            'code,product_name,product_name_es,generic_name,'
            'generic_name_es,brands,quantity,image_front_url,'
            'image_front_small_url',
      }),
    );
    final hits = body['hits'];
    if (hits is! List) return const [];

    final results = <OffSearchResult>[];
    final seen = <String>{};
    for (final hit in hits) {
      if (hit is! Map<String, dynamic>) continue;
      final barcode = hit['code']?.toString().trim() ?? '';
      if (barcode.isEmpty || !seen.add(barcode)) continue;
      final name = _cleanText(
        hit['product_name_es'] ??
            hit['product_name'] ??
            hit['generic_name_es'] ??
            hit['generic_name'],
      );
      if (name.isEmpty) continue;
      final quantity = _cleanText(hit['quantity']);
      final image = hit['image_front_url'] ?? hit['image_front_small_url'];
      results.add(
        OffSearchResult(
          barcode: barcode,
          name: name,
          brand: _brandName(hit['brands']),
          quantity: quantity.isEmpty ? null : quantity,
          imageUrl: image is String && image.trim().isNotEmpty
              ? image.trim()
              : null,
        ),
      );
      if (results.length >= 10) break;
    }
    _searchCache[cacheKey] = results;
    return results;
  }

  static String _cleanText(Object? value) =>
      (value ?? '').toString().replaceAll(RegExp(r'\s+'), ' ').trim();

  static String? _brandName(Object? value) {
    if (value is List) {
      final brands = value.map(_cleanText).where((b) => b.isNotEmpty);
      final joined = brands.join(', ');
      return joined.isEmpty ? null : joined;
    }
    final brand = _cleanText(value);
    return brand.isEmpty ? null : brand;
  }

  static const _productFields =
      'product_name,product_name_es,image_front_url,serving_quantity,'
      'nutrition_data_per,energy-kcal_100g,energy-kcal_serving,energy_100g,'
      'proteins_100g,proteins_serving,carbohydrates_100g,carbohydrates_serving,'
      'fat_100g,fat_serving';

  static const _userAgent = 'MacrobuddyApp/1.0 (maicoalf77@gmail.com)';
  static const _requestHeaders = {
    'User-Agent': _userAgent,
    'Accept': 'application/json',
  };
  static const _maxRetries = 1;

  Future<Map<String, dynamic>> _fetchBody(Uri uri) async {
    http.Response res;
    var attempt = 0;
    while (true) {
      res = await _get(uri);
      if (!_isRetryable(res.statusCode) || attempt >= _maxRetries) break;
      attempt++;
      await Future<void>.delayed(retryDelay);
    }
    if (res.statusCode == 429) {
      throw OffException(OffFailure.rateLimited, statusCode: 429);
    }
    if (res.statusCode == 503 || res.statusCode == 504) {
      throw OffException(OffFailure.busy, statusCode: res.statusCode);
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

  Future<http.Response> _get(Uri uri) async {
    try {
      return await _client
          .get(uri, headers: _requestHeaders)
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const OffException(OffFailure.network);
    } catch (_) {
      throw const OffException(OffFailure.network);
    }
  }

  static bool _isRetryable(int statusCode) =>
      statusCode == 429 || statusCode == 503 || statusCode == 504;

  /// Limpia las cachés en memoria (útil al cambiar de red o en pruebas).
  void clearCache() {
    _productCache.clear();
    _searchCache.clear();
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
