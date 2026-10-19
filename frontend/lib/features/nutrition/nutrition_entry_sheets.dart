import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/nutrition.dart';
import '../../core/services/open_food_facts_service.dart';
import '../../theme/app_theme.dart';
import 'nutrition_provider.dart';

/// Comida por omisión según la hora local.
String mealForNow() {
  final h = DateTime.now().hour;
  if (h < 11) return 'breakfast';
  if (h < 15) return 'lunch';
  if (h < 21) return 'dinner';
  return 'snack';
}

void showManualEntrySheet(
  BuildContext context, {
  OffProduct? product,
  NutritionItem? existing,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: ThemeColors.dark.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _EntrySheet(product: product, existing: existing),
  );
}

class _EntrySheet extends ConsumerStatefulWidget {
  const _EntrySheet({this.product, this.existing});

  final OffProduct? product;
  final NutritionItem? existing;

  @override
  ConsumerState<_EntrySheet> createState() => _EntrySheetState();
}

class _EntrySheetState extends ConsumerState<_EntrySheet> {
  late final List<TextEditingController> _fields;
  late String _meal;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _meal = widget.existing?.meal ?? mealForNow();
    // [nombre, gramos, kcal, proteína, carbohidratos, grasas]
    _fields = [
      for (final controller in [
        TextEditingController(text: widget.existing?.name ?? widget.product?.name),
        TextEditingController(text: _text(widget.existing?.quantityG ?? widget.product?.servingSizeG ?? 100)),
        TextEditingController(text: _text(widget.existing?.calories ?? widget.product?.calories)),
        TextEditingController(text: _text(widget.existing?.protein ?? widget.product?.protein)),
        TextEditingController(text: _text(widget.existing?.carbs ?? widget.product?.carbs)),
        TextEditingController(text: _text(widget.existing?.fats ?? widget.product?.fats)),
      ])
        controller
    ];
  }

  static String _text(num? value) =>
      value == null || value == 0 ? '' : _trim(value.toDouble());

  static String _trim(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);

  double? _parse(TextEditingController c) {
    final v = double.tryParse(c.text.trim().replaceAll(',', '.'));
    return v != null && v >= 0 ? v : null;
  }

  @override
  void dispose() {
    for (final f in _fields) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_fields[0].text.trim().isEmpty || _parse(_fields[1]) == null) {
      return;
    }
    setState(() => _saving = true);
    final controller = ref.read(nutritionProvider.notifier);
    final ok = widget.existing == null
        ? await controller.addItems([
            NutritionItem(
              id: '',
              name: _fields[0].text.trim(),
              barcode: widget.product?.barcode,
              quantityG: _parse(_fields[1]) ?? 100,
              calories: _parse(_fields[2]) ?? 0,
              protein: _parse(_fields[3]) ?? 0,
              carbs: _parse(_fields[4]) ?? 0,
              fats: _parse(_fields[5]) ?? 0,
              meal: _meal,
            ).toRequest(),
          ])
        : await controller.updateQuantity(
            widget.existing!,
            _parse(_fields[1]) ?? widget.existing!.quantityG,
            calories: _parse(_fields[2]) ?? widget.existing!.calories,
            protein: _parse(_fields[3]) ?? widget.existing!.protein,
            carbs: _parse(_fields[4]) ?? widget.existing!.carbs,
            fats: _parse(_fields[5]) ?? widget.existing!.fats,
          );
    if (!mounted) return;
    Navigator.of(context).pop();
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: ThemeColors.dark.card,
          content: Text(
            ref.read(nutritionProvider).error ?? 'No se pudo guardar el alimento.',
            style: TextStyle(color: ThemeColors.dark.textPrimary),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const c = ThemeColors.dark;
    final safe = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        16 + safe,
      ).copyWith(bottom: 16 + safe),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.existing != null ? 'Editar alimento' : 'Registrar alimento',
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close, color: c.textSecondary),
                ),
              ],
            ),
            if (widget.product != null) ...[
              const SizedBox(height: 4),
              Text(
                'OpenFoodFacts · ${widget.product!.per100g ? 'por 100 g' : 'por porción (${_trim(widget.product!.servingSizeG ?? 100)} g)'}',
                style: TextStyle(color: c.textSecondary, fontSize: 12),
              ),
            ],
            _field(_fields[0], 'Nombre', hint: 'Ej. Yogur griego'),
            Row(
              children: [
                Expanded(child: _field(_fields[1], 'Gramos', number: true)),
                const SizedBox(width: 8),
                Expanded(child: _mealDropdown(c)),
              ],
            ),
            Row(
              children: [
                Expanded(child: _field(_fields[2], 'Kcal', number: true)),
                const SizedBox(width: 8),
                Expanded(child: _field(_fields[3], 'Proteína (g)', number: true)),
              ],
            ),
            Row(
              children: [
                Expanded(child: _field(_fields[4], 'Carbohidratos (g)', number: true)),
                const SizedBox(width: 8),
                Expanded(child: _field(_fields[5], 'Grasas (g)', number: true)),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: c.textPrimary),
              onPressed: _saving ? null : _save,
              child: _saving
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: c.scaffold,
                      ),
                    )
                  : Text('Guardar', style: TextStyle(color: c.scaffold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool number = false,
    String? hint,
  }) {
    const c = ThemeColors.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: controller,
        keyboardType: number
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        textCapitalization: TextCapitalization.sentences,
        inputFormatters: number
            ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*[.,]?\d*'))]
            : null,
        style: TextStyle(color: c.textPrimary).merge(AppTypography.numeric),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          hintStyle: TextStyle(color: c.textSecondary.withValues(alpha: 0.6)),
          labelStyle: TextStyle(color: c.textSecondary, fontSize: 13),
          filled: true,
          fillColor: ThemeColors.dark.input,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _mealDropdown(ThemeColors c) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: DropdownButtonFormField<String>(
        initialValue: _meal,
        items: [
          for (final m in nutritionMeals)
            DropdownMenuItem(
              value: m,
              child: Text(
                nutritionMealLabels[m]!,
                style: TextStyle(color: c.textPrimary, fontSize: 13),
              ),
            ),
        ],
        style: TextStyle(color: c.textPrimary, fontSize: 13),
        dropdownColor: ThemeColors.dark.card,
        decoration: InputDecoration(
          labelText: 'Comida',
          labelStyle: TextStyle(color: c.textSecondary, fontSize: 13),
          filled: true,
          fillColor: ThemeColors.dark.input,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: (v) => setState(() => _meal = v ?? 'snack'),
      ),
    );
  }
}
