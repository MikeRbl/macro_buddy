import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/nutrition.dart';
import '../../core/services/open_food_facts_service.dart';
import '../../theme/app_theme.dart';
import 'nutrition_provider.dart';

Future<void> showManualEntrySheet(
  BuildContext context, {
  OffProduct? product,
  NutritionItem? existing,
  String? time,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: ThemeColors.dark.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) =>
        _EntrySheet(product: product, existing: existing, time: time),
  );
}

class _EntrySheet extends ConsumerStatefulWidget {
  const _EntrySheet({this.product, this.existing, this.time});

  final OffProduct? product;
  final NutritionItem? existing;
  final String? time;

  @override
  ConsumerState<_EntrySheet> createState() => _EntrySheetState();
}

class _EntrySheetState extends ConsumerState<_EntrySheet> {
  late final List<TextEditingController> _fields;
  late String _time;
  late final TextEditingController _labelController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(text: widget.existing?.label);
    _time = widget.existing != null
        ? effectiveTime(widget.existing!)
        : (widget.time ?? nutritionNowTime());
    // [nombre, gramos, kcal, proteína, carbohidratos, grasas]
    _fields = [
      for (final controller in [
        TextEditingController(
          text: widget.existing?.name ?? widget.product?.name,
        ),
        TextEditingController(
          text: _text(
            widget.existing?.quantityG ?? widget.product?.servingSizeG ?? 100,
          ),
        ),
        TextEditingController(
          text: _text(widget.existing?.calories ?? widget.product?.calories),
        ),
        TextEditingController(
          text: _text(widget.existing?.protein ?? widget.product?.protein),
        ),
        TextEditingController(
          text: _text(widget.existing?.carbs ?? widget.product?.carbs),
        ),
        TextEditingController(
          text: _text(widget.existing?.fats ?? widget.product?.fats),
        ),
      ])
        controller,
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
    _labelController.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final parts = _time.split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 0,
        minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
      ),
      builder: (context, child) => Theme(
        data: Theme.of(context),
        child: child ?? const SizedBox.shrink(),
      ),
    );
    if (picked == null) return;
    setState(() {
      _time =
          '${picked.hour.toString().padLeft(2, '0')}:'
          '${picked.minute.toString().padLeft(2, '0')}';
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_fields[0].text.trim().isEmpty || _parse(_fields[1]) == null) {
      return;
    }
    setState(() => _saving = true);
    final controller = ref.read(nutritionProvider.notifier);
    final time = _time;
    final label = _labelController.text.trim();
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
              time: time,
              label: label.isEmpty ? null : label,
            ).toRequest(),
          ])
        : await controller.updateItem(
            widget.existing!,
            _parse(_fields[1]) ?? widget.existing!.quantityG,
            calories: _parse(_fields[2]) ?? widget.existing!.calories,
            protein: _parse(_fields[3]) ?? widget.existing!.protein,
            carbs: _parse(_fields[4]) ?? widget.existing!.carbs,
            fats: _parse(_fields[5]) ?? widget.existing!.fats,
            time: time,
            label: label,
          );
    if (!mounted) return;
    Navigator.of(context).pop();
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: ThemeColors.dark.card,
          content: Text(
            ref.read(nutritionProvider).error ??
                'No se pudo guardar el alimento.',
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
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + safe + keyboard),
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.existing != null
                        ? 'Editar alimento'
                        : 'Registrar alimento',
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
                Expanded(child: _timeField(c)),
              ],
            ),
            _field(_labelController, 'Etiqueta', hint: 'Ej. pre-entreno'),
            Row(
              children: [
                Expanded(child: _field(_fields[2], 'Kcal', number: true)),
                const SizedBox(width: 8),
                Expanded(
                  child: _field(_fields[3], 'Proteína (g)', number: true),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: _field(_fields[4], 'Carbohidratos (g)', number: true),
                ),
                const SizedBox(width: 8),
                Expanded(child: _field(_fields[5], 'Grasas (g)', number: true)),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton(
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

  /// Píldora de hora: abre el `showTimePicker` nativo.
  Widget _timeField(ThemeColors c) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _pickTime,
        child: InputDecorator(
          decoration: InputDecoration(
            isDense: true,
            labelText: 'Hora',
            labelStyle: TextStyle(color: c.textSecondary, fontSize: 13),
            filled: true,
            fillColor: ThemeColors.dark.input,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          child: SizedBox(
            height: 24,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    formatTime12h(_time),
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 14,
                    ).merge(AppTypography.numeric),
                  ),
                ),
                Icon(Icons.access_time, size: 18, color: c.textSecondary),
              ],
            ),
          ),
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
}
