/// Log diario de nutrición. Contrato del backend:
/// GET/POST/PATCH devuelven camelCase (`quantityG`), las entradas
/// POST/PATCH aceptan `quantity_g` (snake_case) tal como expone la API.
class NutritionItem {
  const NutritionItem({
    required this.id,
    required this.name,
    required this.quantityG,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fats,
    required this.meal,
    this.barcode,
    this.loggedAt,
  });

  final String id;
  final String name;
  final String? barcode;
  final double quantityG;
  final double calories;
  final double protein;
  final double carbs;
  final double fats;
  final String meal;
  final String? loggedAt;

  factory NutritionItem.fromJson(Map<String, dynamic> json) {
    return NutritionItem(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      barcode: json['barcode'] as String?,
      quantityG: (json['quantityG'] as num?)?.toDouble() ?? 0,
      calories: (json['calories'] as num?)?.toDouble() ?? 0,
      protein: (json['protein'] as num?)?.toDouble() ?? 0,
      carbs: (json['carbs'] as num?)?.toDouble() ?? 0,
      fats: (json['fats'] as num?)?.toDouble() ?? 0,
      meal: json['meal'] as String? ?? 'snack',
      loggedAt: json['loggedAt'] as String?,
    );
  }

  /// Cuerpo para POST/PATCH (entradas en snake_case).
  Map<String, dynamic> toRequest({String? itemId}) {
    final body = <String, dynamic>{
      'name': name,
      'quantity_g': quantityG,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fats': fats,
      'meal': meal,
      'barcode': ?barcode,
    };
    if (itemId != null) body['itemId'] = itemId;
    return body;
  }
}

class NutritionLog {
  const NutritionLog({
    required this.id,
    required this.date,
    required this.totalCalories,
    required this.totalProtein,
    required this.totalCarbs,
    required this.totalFats,
    required this.items,
  });

  final String? id;
  final String date;
  final double totalCalories;
  final double totalProtein;
  final double totalCarbs;
  final double totalFats;
  final List<NutritionItem> items;

  factory NutritionLog.fromJson(Map<String, dynamic> json) {
    return NutritionLog(
      id: json['id'] as String?,
      date: json['date'] as String,
      totalCalories: (json['totalCalories'] as num?)?.toDouble() ?? 0,
      totalProtein: (json['totalProtein'] as num?)?.toDouble() ?? 0,
      totalCarbs: (json['totalCarbs'] as num?)?.toDouble() ?? 0,
      totalFats: (json['totalFats'] as num?)?.toDouble() ?? 0,
      items: ((json['consumedItems'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(NutritionItem.fromJson)
          .toList(),
    );
  }
}

/// `YYYY-MM-DD` local, el mismo formato que valida el backend.
String nutritionToday() {
  final now = DateTime.now();
  return '${now.year.toString().padLeft(4, '0')}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';
}

const nutritionMeals = ['breakfast', 'lunch', 'dinner', 'snack'];

const nutritionMealLabels = {
  'breakfast': 'Desayuno',
  'lunch': 'Almuerzo',
  'dinner': 'Cena',
  'snack': 'Snack',
};
