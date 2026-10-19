/// Log diario de nutrición. Contrato del backend:
/// GET/POST/PATCH devuelven camelCase, las entradas
/// POST/PATCH aceptan snake_case en `quantity_g` tal como expone la API.
///
/// El agrupado es por hora del día (`time` = "HH:mm"); `meal` fue
/// deprecado en el backend y se ignora.
class NutritionItem {
  const NutritionItem({
    required this.id,
    required this.name,
    required this.quantityG,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fats,
    this.barcode,
    this.time,
    this.label,
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

  /// Hora del registro, "HH:mm" 24h.
  final String? time;

  /// Etiqueta libre y opcional, ej. "pre-entreno".
  final String? label;
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
      time: json['time'] as String?,
      label: json['label'] as String?,
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
      'barcode': ?barcode,
      'time': ?time,
      'label': ?label,
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

/// Hora local actual como "HH:mm" 24h.
String nutritionNowTime() {
  final now = DateTime.now();
  return '${now.hour.toString().padLeft(2, '0')}:'
      '${now.minute.toString().padLeft(2, '0')}';
}

/// Hora efectiva de un ítem: `time` explícito o, en ítems legacy sin hora,
/// la hora local de `loggedAt`.
String effectiveTime(NutritionItem item) {
  final explicit = item.time;
  if (explicit != null && RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(explicit)) {
    return explicit;
  }
  final logged = DateTime.tryParse(item.loggedAt ?? '');
  if (logged != null) {
    return '${logged.hour.toString().padLeft(2, '0')}:'
        '${logged.minute.toString().padLeft(2, '0')}';
  }
  return '00:00';
}

/// "08:30" -> "8:30 AM"; "20:00" -> "8:00 PM".
String formatTime12h(String time24) {
  final parts = time24.split(':');
  final h = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 0;
  final m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
  final period = h >= 12 ? 'PM' : 'AM';
  var hour = h % 12;
  if (hour == 0) hour = 12;
  final minute = m.toString().padLeft(2, '0');
  return '$hour:$minute $period';
}

/// "8:30 PM" -> "20:30" (24h). Devuelve `null` si no se puede parsear.
String? parseTime12h(String time12) {
  final m = RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM)$', caseSensitive: false)
      .firstMatch(time12.trim());
  if (m == null) return null;
  var hour = int.tryParse(m.group(1)!) ?? 0;
  final minute = int.tryParse(m.group(2)!) ?? 0;
  final period = (m.group(3) ?? '').toUpperCase();
  if (period == 'PM' && hour != 12) hour += 12;
  if (period == 'AM' && hour == 12) hour = 0;
  return '${hour.toString().padLeft(2, '0')}:'
      '${minute.toString().padLeft(2, '0')}';
}
