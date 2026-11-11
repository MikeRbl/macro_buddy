// Normalización compartida con el backend (backend/lib/foods.ts). Si cambia
// una, debe cambiar la otra: los códigos y el texto de búsqueda tienen que
// coincidir en el teléfono y en el servidor.

/// Deja solo dígitos; UPC-A (12) → EAN-13 con 0 inicial. Acepta EAN-8,
/// EAN-13 y GTIN-14. `null` si no es un código de producto válido.
String? normalizeBarcode(String raw) {
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.length == 12) return '0$digits';
  if (digits.length == 8 || digits.length == 13 || digits.length == 14) {
    return digits;
  }
  if (digits.length > 14) {
    final trimmed = digits.replaceFirst(RegExp(r'^0+'), '');
    return trimmed.length >= 8 ? normalizeBarcode(trimmed) : null;
  }
  return null;
}

const _accents = {
  'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a', 'ã': 'a',
  'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e',
  'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i',
  'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o', 'õ': 'o',
  'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u',
  'ç': 'c',
};

/// Minúsculas, sin acentos ni signos, espacios simples. La ñ se conserva
/// (igual que en el backend).
String normalizeSearch(String text) {
  final lower = text.toLowerCase();
  final buffer = StringBuffer();
  for (final rune in lower.runes) {
    final ch = String.fromCharCode(rune);
    buffer.write(_accents[ch] ?? ch);
  }
  return buffer
      .toString()
      .replaceAll(RegExp(r'[^a-z0-9ñ ]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// Resultado de validar macros por 100 g.
class MacroCheck {
  const MacroCheck._(this.ok, this.needsReview, this.reason);
  const MacroCheck.valid({bool needsReview = false})
    : this._(true, needsReview, null);
  const MacroCheck.invalid(String reason) : this._(false, false, reason);

  final bool ok;
  final bool needsReview;
  final String? reason;
}

/// Misma regla que el servidor: rangos físicos + Atwater
/// (kcal ≈ 4·P + 4·C + 9·G). >35 % de diferencia se rechaza.
MacroCheck checkMacros({
  required double kcal,
  required double protein,
  required double carbs,
  required double fat,
}) {
  if ([kcal, protein, carbs, fat].any((v) => v.isNaN || v < 0)) {
    return const MacroCheck.invalid('Hay valores inválidos.');
  }
  if (protein > 100 || carbs > 100 || fat > 100 ||
      protein + carbs + fat > 105) {
    return const MacroCheck.invalid(
      'Los macros suman más que el peso del producto.',
    );
  }
  if (kcal > 950) {
    return const MacroCheck.invalid('Más de 950 kcal por 100 g no es posible.');
  }
  final computed = 4 * protein + 4 * carbs + 9 * fat;
  final diff = (kcal - computed).abs();
  if (diff <= 10) return const MacroCheck.valid();
  final deviation = diff / (kcal > computed ? kcal : computed);
  if (deviation > 0.35) {
    return MacroCheck.invalid(
      'Las calorías no cuadran con los macros '
      '(${kcal.round()} declaradas, ${computed.round()} calculadas).',
    );
  }
  return MacroCheck.valid(needsReview: deviation > 0.15);
}
