import 'dart:convert';

import '../open_food_facts_service.dart';

class FoodServing {
  const FoodServing(this.label, this.grams);

  final String label;
  final double grams;

  static List<FoodServing> listFromJson(Object? raw) {
    final list = raw is String ? _decode(raw) : raw;
    if (list is! List) return const [];
    return [
      for (final s in list)
        if (s is Map && s['label'] is String && s['grams'] is num)
          FoodServing(s['label'] as String, (s['grams'] as num).toDouble()),
    ];
  }

  static Object? _decode(String raw) {
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }
}

/// Alimento del catálogo verificado (SQLite local, sincronizado).
/// Macros por 100 g (o 100 ml).
class CatalogFood {
  const CatalogFood({
    required this.id,
    required this.name,
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.brand,
    this.barcode,
    this.baseUnit = 'g',
    this.servings = const [],
    this.source = 'off',
  });

  final String id;
  final String name;
  final String? brand;

  /// Código con el que se encontró (si aplica).
  final String? barcode;
  final double kcal;
  final double protein;
  final double carbs;
  final double fat;
  final String baseUnit;
  final List<FoodServing> servings;
  final String source;

  factory CatalogFood.fromRow(Map<String, Object?> row, {String? barcode}) {
    double n(String k) => (row[k] as num?)?.toDouble() ?? 0;
    return CatalogFood(
      id: row['id'] as String,
      name: row['name'] as String,
      brand: row['brand'] as String?,
      barcode: barcode,
      kcal: n('kcal'),
      protein: n('protein'),
      carbs: n('carbs'),
      fat: n('fat'),
      baseUnit: row['base_unit'] as String? ?? 'g',
      servings: FoodServing.listFromJson(row['servings']),
      source: row['source'] as String? ?? 'off',
    );
  }

  /// El resto de la app trabaja con `OffProduct`; este adaptador evita
  /// tocar todas las pantallas.
  OffProduct toProduct() => OffProduct(
    barcode: barcode ?? '',
    name: name,
    brand: brand,
    calories: kcal,
    protein: protein,
    carbs: carbs,
    fats: fat,
    per100g: true,
    servingSizeG: servings.isEmpty ? null : servings.first.grams,
    servingLabel: servings.isEmpty ? null : servings.first.label,
    source: FoodSource.catalog,
  );
}

/// Estado de un producto creado por el usuario.
enum ContributionStatus {
  /// Solo vive en este teléfono; aún no se le preguntó si quiere enviarlo.
  local,

  /// El usuario eligió dejarlo solo en su equipo. No se vuelve a preguntar
  /// salvo que cambie los datos.
  declined,

  /// Enviado a verificación.
  pending,

  /// Ya está en el catálogo de MacroBuddy.
  approved,

  /// Un revisor lo rechazó (ver `reviewerNote`). Sigue disponible localmente.
  rejected;

  static ContributionStatus parse(Object? raw) => ContributionStatus.values
      .firstWhere((s) => s.name == raw, orElse: () => ContributionStatus.local);
}

/// Producto que el usuario registró a mano. Macros por 100 g.
class UserFood {
  const UserFood({
    required this.localId,
    required this.name,
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.barcode,
    this.brand,
    this.baseUnit = 'g',
    this.servingG,
    this.servingLabel,
    this.status = ContributionStatus.local,
    this.contributionId,
    this.reviewerNote,
  });

  final String localId;
  final String? barcode;
  final String name;
  final String? brand;
  final double kcal;
  final double protein;
  final double carbs;
  final double fat;
  final String baseUnit;
  final double? servingG;
  final String? servingLabel;
  final ContributionStatus status;
  final String? contributionId;
  final String? reviewerNote;

  factory UserFood.fromRow(Map<String, Object?> row) {
    double n(String k) => (row[k] as num?)?.toDouble() ?? 0;
    return UserFood(
      localId: row['local_id'] as String,
      barcode: row['barcode'] as String?,
      name: row['name'] as String,
      brand: row['brand'] as String?,
      kcal: n('kcal'),
      protein: n('protein'),
      carbs: n('carbs'),
      fat: n('fat'),
      baseUnit: row['base_unit'] as String? ?? 'g',
      servingG: (row['serving_g'] as num?)?.toDouble(),
      servingLabel: row['serving_label'] as String?,
      status: ContributionStatus.parse(row['contribution_status']),
      contributionId: row['contribution_id'] as String?,
      reviewerNote: row['reviewer_note'] as String?,
    );
  }

  OffProduct toProduct() => OffProduct(
    barcode: barcode ?? '',
    name: name,
    brand: brand,
    calories: kcal,
    protein: protein,
    carbs: carbs,
    fats: fat,
    per100g: true,
    servingSizeG: servingG,
    servingLabel: servingLabel,
    source: FoodSource.user,
    userFoodId: localId,
  );
}

/// Un resultado de búsqueda con sus macros ya resueltos.
typedef FoodSearchHit = ({OffSearchResult result, OffProduct product});
