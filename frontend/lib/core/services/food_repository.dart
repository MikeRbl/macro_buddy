import 'dart:async';

import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'food_catalog/food_api.dart';
import 'food_catalog/food_models.dart';
import 'food_catalog/food_text.dart';
import 'food_catalog/local_food_db.dart';
import 'open_food_facts_service.dart';

export 'food_catalog/food_models.dart';
export 'food_catalog/food_text.dart' show MacroCheck, checkMacros;

/// Punto único para buscar alimentos. Reemplaza las llamadas directas a
/// `OpenFoodFactsService.shared` en las pantallas.
///
/// Orden al escanear un código:
///   1. productos del usuario (este teléfono)
///   2. catálogo local (SQLite, funciona sin internet)
///   3. servidor de MacroBuddy (aprobados después del último sync)
///   4. OpenFoodFacts como último recurso (desactivable)
///   5. `null` → la app ofrece registrarlo
class FoodRepository {
  FoodRepository({
    LocalFoodDb? db,
    FoodApi? api,
    OpenFoodFactsService? off,
  }) : _db = db ?? LocalFoodDb(),
       _api = api ?? FoodApi(),
       _off = off ?? OpenFoodFactsService.shared;

  static final FoodRepository shared = FoodRepository();

  final LocalFoodDb _db;
  final FoodApi _api;
  final OpenFoodFactsService _off;

  /// Token JWT del usuario; lo fija `foodCatalogBootstrapProvider`.
  String? token;

  /// Consultar OFF cuando nada más tiene el producto. Apágalo cuando el
  /// catálogo propio cubra lo suficiente.
  bool useOpenFoodFactsFallback = true;

  static const _lastSyncKey = 'food_catalog_last_sync';
  Future<int>? _syncing;

  // ── Lectura ───────────────────────────────────────────────────────────

  Future<OffProduct?> fetchByBarcode(String raw) async {
    final code = normalizeBarcode(raw);
    if (code == null) return null;

    final mine = await _db.userByBarcode(code);
    if (mine != null && mine.status != ContributionStatus.approved) {
      return mine.toProduct();
    }

    final local = await _db.catalogByBarcode(code);
    if (local != null) return local.toProduct();

    final t = token;
    if (t != null) {
      try {
        final remote = await _api.byBarcode(token: t, barcode: code);
        if (remote != null) {
          await _db.cacheFood(remote);
          final cached = await _db.catalogByBarcode(code);
          if (cached != null) return cached.toProduct();
        }
      } on FoodApiException {
        // Sin conexión: seguimos con lo que haya.
      }
    }

    // Una copia aprobada que aún no llegó por sync sigue siendo útil.
    if (mine != null) return mine.toProduct();

    if (useOpenFoodFactsFallback) {
      try {
        return await _off.fetchByBarcode(code);
      } on OffException {
        return null;
      }
    }
    return null;
  }

  /// Búsqueda por texto: primero lo del usuario, luego el catálogo local.
  /// Si hay pocos resultados y hay conexión, completa con el servidor.
  Future<List<FoodSearchHit>> search(String query, {int limit = 30}) async {
    final hits = <FoodSearchHit>[];
    final seen = <String>{};

    void add(String key, OffProduct product) {
      if (!seen.add(key)) return;
      final quantity = product.servingLabel ??
          (product.servingSizeG != null
              ? '${product.servingSizeG!.round()} g'
              : null);
      hits.add((
        result: OffSearchResult(
          barcode: key,
          name: product.name,
          brand: product.brand,
          quantity: quantity,
        ),
        product: product,
      ));
    }

    for (final f in await _db.searchUser(query)) {
      if (f.status == ContributionStatus.approved) continue;
      add('usr:${f.localId}', f.toProduct());
    }
    final local = await _db.searchCatalog(query, limit: limit);
    for (final f in local) {
      add('cat:${f.id}', f.toProduct());
    }

    final t = token;
    if (t != null && local.length < 5) {
      try {
        final remote = await _api.search(token: t, query: query);
        for (final item in remote) {
          final barcodes = ((item['barcodes'] as List?) ?? const []).cast<String>();
          final food = CatalogFood(
            id: item['id'] as String,
            name: item['name'] as String,
            brand: item['brand'] as String?,
            barcode: barcodes.isEmpty ? null : barcodes.first,
            kcal: (item['kcal'] as num).toDouble(),
            protein: (item['protein'] as num).toDouble(),
            carbs: (item['carbs'] as num).toDouble(),
            fat: (item['fat'] as num).toDouble(),
            baseUnit: item['baseUnit'] as String? ?? 'g',
            servings: FoodServing.listFromJson(item['servings']),
            source: item['source'] as String? ?? 'off',
          );
          add('cat:${food.id}', food.toProduct());
          // La próxima vez aparece sin red.
          unawaited(_db.cacheFood(item));
        }
      } on FoodApiException {
        // Sin conexión: se muestran solo los resultados locales.
      }
    }
    return hits.take(limit).toList();
  }

  Future<List<UserFood>> myFoods() => _db.allUserFoods();

  // ── Productos del usuario ─────────────────────────────────────────────

  /// Guarda en el teléfono un producto capturado a mano. Los valores que
  /// recibe son los de la porción registrada (`grams`), como los escribe
  /// el usuario; aquí se convierten a 100 g.
  Future<UserFood?> saveUserFood({
    String? localId,
    String? barcode,
    required String name,
    String? brand,
    required double grams,
    required double calories,
    required double protein,
    required double carbs,
    required double fats,
  }) async {
    if (grams <= 0 || name.trim().isEmpty) return null;
    final f = 100 / grams;
    double r(double v) => (v * f * 10).roundToDouble() / 10;
    return _db.upsertUser(
      localId: localId,
      barcode: barcode == null ? null : normalizeBarcode(barcode),
      name: name.trim(),
      brand: brand,
      kcal: r(calories),
      protein: r(protein),
      carbs: r(carbs),
      fat: r(fats),
      servingG: grams,
      servingLabel: '${grams.round()} g',
    );
  }

  /// Edita un producto propio desde "Mis alimentos". Valores por 100 g/ml;
  /// la porción y el código se conservan. Si algo cambió, vuelve a "solo local".
  Future<UserFood> updateUserFood(
    UserFood food, {
    required String name,
    String? brand,
    required double kcal,
    required double protein,
    required double carbs,
    required double fat,
  }) => _db.upsertUser(
    localId: food.localId,
    barcode: food.barcode,
    name: name,
    brand: brand,
    kcal: kcal,
    protein: protein,
    carbs: carbs,
    fat: fat,
    baseUnit: food.baseUnit,
    servingG: food.servingG,
    servingLabel: food.servingLabel,
  );

  Future<void> deleteUserFood(String localId) => _db.deleteUserFood(localId);

  /// "Solo en mi equipo": no se vuelve a preguntar hasta que cambien los datos.
  Future<void> markDeclined(String localId) =>
      _db.setContribution(localId, status: ContributionStatus.declined);

  /// Envía el producto a verificación. Devuelve el estado resultante
  /// (`approved` si se aprobó al instante por consenso).
  /// `throws: FoodApiException`
  Future<ContributionStatus> contribute(
    UserFood food, {
    List<XFile> photos = const [],
  }) async {
    final t = token;
    if (t == null) {
      throw const FoodApiException('Inicia sesión para enviar productos.');
    }
    final res = await _api.contribute(
      token: t,
      clientId: food.localId,
      name: food.name,
      brand: food.brand,
      barcode: food.barcode,
      kcal: food.kcal,
      protein: food.protein,
      carbs: food.carbs,
      fat: food.fat,
      baseUnit: food.baseUnit,
      servingG: food.servingG,
      servingLabel: food.servingLabel,
      photos: photos,
    );
    final status = ContributionStatus.parse(res['status']);
    await _db.setContribution(
      food.localId,
      status: status == ContributionStatus.local
          ? ContributionStatus.pending
          : status,
      contributionId: res['id'] as String?,
    );
    if (status == ContributionStatus.approved) unawaited(sync());
    return status;
  }

  /// Trae del servidor el estado de mis solicitudes (aprobadas/rechazadas).
  Future<void> refreshContributionStatuses() async {
    final t = token;
    if (t == null) return;
    try {
      final list = await _api.myContributions(token: t);
      for (final c in list) {
        final localId = c['clientId'] as String?;
        if (localId == null) continue;
        final current = await _db.userById(localId);
        if (current == null || current.contributionId != c['id']) continue;
        await _db.setContribution(
          localId,
          status: ContributionStatus.parse(c['status']),
          contributionId: c['id'] as String?,
          reviewerNote: c['reviewerNote'] as String?,
        );
      }
    } on FoodApiException {
      // Se reintenta en el próximo arranque.
    }
  }

  // ── Sincronización ────────────────────────────────────────────────────

  /// Sincroniza si pasó más de [maxAge] desde la última vez.
  Future<void> syncIfStale({Duration maxAge = const Duration(hours: 12)}) async {
    await _db.open();
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getInt(_lastSyncKey) ?? 0;
    final age = DateTime.now().millisecondsSinceEpoch - last;
    if (age < maxAge.inMilliseconds) return;
    try {
      await sync();
      await refreshContributionStatuses();
    } on FoodApiException {
      // Offline: se intenta de nuevo en el próximo arranque.
    }
  }

  /// Baja todos los cambios desde la versión local. Devuelve cuántos
  /// alimentos se aplicaron. Llamadas simultáneas comparten la misma.
  Future<int> sync() => _syncing ??= _sync().whenComplete(() => _syncing = null);

  Future<int> _sync() async {
    final t = token;
    if (t == null) return 0;
    var applied = 0;
    // Se piden 100 versiones de traslape: si dos escrituras del servidor
    // terminaron fuera de orden, la segunda pasada las recoge. Reaplicar
    // es idempotente.
    var since = await _db.catalogVersion();
    since = since > 100 ? since - 100 : 0;
    while (true) {
      final page = await _api.sync(token: t, since: since);
      final codes = await _db.applySyncPage(page.items, page.nextSince);
      await _db.markApprovedByBarcodes(codes);
      applied += page.items.length;
      if (!page.hasMore || page.nextSince <= since) break;
      since = page.nextSince;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastSyncKey, DateTime.now().millisecondsSinceEpoch);
    return applied;
  }
}
