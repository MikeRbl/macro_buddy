import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/nutrition.dart';
import '../../core/services/open_food_facts_service.dart';
import '../../theme/app_theme.dart';
import '../../core/widgets/mb_icon.dart';
import 'nutrition_entry_sheets.dart';
import 'nutrition_provider.dart';
import 'scan_food_flow.dart';

/// Modos de alta de alimento.
enum FoodEntryMode { scan, search }

/// Selección en curso: macros absolutos para `basisGrams` de producto,
/// escalables al confirmar.
class _Pick {
  const _Pick({
    required this.key,
    required this.name,
    required this.basisGrams,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fats,
    this.barcode,
  });

  final String key;
  final String name;
  final String? barcode;
  final double basisGrams;
  final double calories;
  final double protein;
  final double carbs;
  final double fats;

  _Pick withGrams(double grams) {
    final f = grams / basisGrams;
    return _Pick(
      key: key,
      name: name,
      barcode: barcode,
      basisGrams: grams,
      calories: calories * f,
      protein: protein * f,
      carbs: carbs * f,
      fats: fats * f,
    );
  }

  Map<String, dynamic> toRequest(String time) => NutritionItem(
    id: '',
    name: name,
    barcode: barcode,
    quantityG: basisGrams,
    calories: calories,
    protein: protein,
    carbs: carbs,
    fats: fats,
    time: time,
  ).toRequest();
}

_Pick? _pickFromProduct(OffProduct p) {
  if (p.name.trim().isEmpty) return null;
  final basis = p.per100g ? 100.0 : (p.servingSizeG ?? 100);
  return _Pick(
    key: 'off:${p.barcode.isNotEmpty ? p.barcode : p.name}',
    name: p.name.trim(),
    barcode: p.barcode.isEmpty ? null : p.barcode,
    basisGrams: basis,
    calories: p.calories,
    protein: p.protein,
    carbs: p.carbs,
    fats: p.fats,
  );
}

_Pick? _pickFromItem(NutritionItem i) {
  if (i.name.trim().isEmpty || i.quantityG <= 0) return null;
  return _Pick(
    key: 'fav:${i.name.trim()}',
    name: i.name.trim(),
    barcode: i.barcode,
    basisGrams: i.quantityG,
    calories: i.calories,
    protein: i.protein,
    carbs: i.carbs,
    fats: i.fats,
  );
}

String _fmt(double v) =>
    v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);

/// Favoritos derivados del historial de 30 días: frecuencia por nombre.
List<_Pick> _favoritesFromLogs(List<NutritionLog> logs) {
  final counts = <String, int>{};
  final latest = <String, _Pick>{};
  for (final log in logs) {
    for (final item in log.items) {
      final pick = _pickFromItem(item);
      if (pick == null) continue;
      counts[pick.key] = (counts[pick.key] ?? 0) + 1;
      latest[pick.key] = pick;
    }
  }
  final keys = counts.keys.toList()
    ..sort((a, b) => (counts[b] ?? 0).compareTo(counts[a] ?? 0));
  return [for (final k in keys.take(12)) latest[k]!];
}

/// Seleccionar e ingresar alimentos: escáner de código de barras, búsqueda
/// en OpenFoodFacts, favoritos frecuentes y registro manual. La hora del
/// registro se elige arriba y aplica a todos los alimentos del lote.
class FoodEntryScreen extends ConsumerStatefulWidget {
  const FoodEntryScreen({
    super.key,
    this.initialMode = FoodEntryMode.search,
    this.initialTime,
    this.calorieTarget,
    this.calorieConsumed,
  });

  final FoodEntryMode initialMode;

  /// Hora "HH:mm" preseleccionada (ej. la que viene del timeline).
  final String? initialTime;
  final double? calorieTarget;
  final double? calorieConsumed;

  @override
  ConsumerState<FoodEntryScreen> createState() => _FoodEntryScreenState();
}

class _FoodEntryScreenState extends ConsumerState<FoodEntryScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  List<OffProduct> _results = const [];
  bool _loading = false;
  String? _error;
  late FoodEntryMode _mode;
  late String _time;
  final _selection = <String, _Pick>{};

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    _time = widget.initialTime ?? nutritionNowTime();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  double get _remaining {
    final target = widget.calorieTarget;
    if (target == null) return 0;
    return target - (widget.calorieConsumed ?? 0);
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      final query = value.trim();
      if (query.isEmpty) {
        if (mounted) {
          setState(() {
            _results = const [];
            _error = null;
            _loading = false;
          });
        }
        return;
      }
      setState(() => _loading = true);
      try {
        final results = await OpenFoodFactsService.shared.searchProducts(query);
        if (!mounted) return;
        setState(() {
          _results = results;
          _loading = false;
          _error = results.isEmpty ? 'Sin resultados para "$query".' : null;
        });
      } on OffException catch (e) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = e.message;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'No se pudo contactar OpenFoodFacts. Revisa tu conexión.';
        });
      }
    });
  }

  void _togglePick(_Pick pick) {
    setState(() {
      final removed = _selection.remove(pick.key);
      if (removed == null) _selection[pick.key] = pick;
    });
  }

  Future<void> _pickTime() async {
    final parts = _time.split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 0,
        minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
      ),
    );
    if (picked == null) return;
    setState(() {
      _time =
          '${picked.hour.toString().padLeft(2, '0')}:'
          '${picked.minute.toString().padLeft(2, '0')}';
    });
  }

  Future<void> _confirmSelection() async {
    final picks = _selection.values.toList();
    if (picks.isEmpty) return;
    final controllers = <String, TextEditingController>{
      for (final p in picks)
        p.key: TextEditingController(text: _fmt(p.basisGrams)),
    };
    final safe = MediaQuery.paddingOf(context).bottom;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ThemeColors.dark.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + safe),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Registrar ${picks.length} '
                      '${picks.length == 1 ? 'alimento' : 'alimentos'}',
                      style: TextStyle(
                        color: ThemeColors.dark.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    formatTime12h(_time),
                    style: TextStyle(
                      color: AppColors.secondaryCyan,
                      fontSize: 13,
                    ).merge(AppTypography.numeric),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final p in picks)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text(
                                p.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: ThemeColors.dark.textPrimary,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: Text(
                                '${p.calories.round()} kcal / '
                                '${_fmt(p.basisGrams)} g',
                                style: TextStyle(
                                  color: ThemeColors.dark.textSecondary,
                                  fontSize: 11,
                                ).merge(AppTypography.numeric),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: controllers[p.key],
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'^\d*[.,]?\d*'),
                                  ),
                                ],
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: ThemeColors.dark.textPrimary,
                                ).merge(AppTypography.numeric),
                                decoration: InputDecoration(
                                  isDense: true,
                                  filled: true,
                                  fillColor: ThemeColors.dark.input,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                            ),
                            Text(
                              ' g',
                              style: TextStyle(
                                color: ThemeColors.dark.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.of(sheetCtx).pop(true),
                child: const Text('Registrar alimentos'),
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true) {
      for (final c in controllers.values) {
        c.dispose();
      }
      return;
    }
    final items = <Map<String, dynamic>>[];
    for (final p in picks) {
      final grams =
          double.tryParse(
            controllers[p.key]!.text.trim().replaceAll(',', '.'),
          ) ??
          p.basisGrams;
      items.add(
        p.withGrams(grams <= 0 ? p.basisGrams : grams).toRequest(_time),
      );
    }
    for (final c in controllers.values) {
      c.dispose();
    }
    final ok = await ref.read(nutritionProvider.notifier).addItems(items);
    if (!mounted) return;
    if (ok) {
      setState(_selection.clear);
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: ThemeColors.dark.card,
          content: Text(
            ref.read(nutritionProvider).error ??
                'No se pudieron registrar los alimentos.',
            style: TextStyle(color: ThemeColors.dark.textPrimary),
          ),
        ),
      );
    }
  }

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    const c = ThemeColors.dark;
    final favorites = _favoritesFromLogs(
      ref.watch(nutritionHistoryProvider(30)).value ?? const [],
    );

    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top bar: fila 1 = cierre + título (sin colisiones); fila
                // 2 = píldora de hora + kcal restantes.
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.of(context).maybePop(),
                            icon: Icon(Icons.close, color: c.textPrimary),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Ingresar alimento',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: c.textPrimary,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _TopPill(
                            onTap: _pickTime,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.access_time,
                                  size: 14,
                                  color: AppColors.secondaryCyan,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  formatTime12h(_time),
                                  style: TextStyle(
                                    color: c.textPrimary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ).merge(AppTypography.numeric),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (widget.calorieTarget != null)
                            _TopPill(
                              child: Text(
                                '${_remaining.round()} kcal restantes',
                                style: TextStyle(
                                  color: _remaining <= 0
                                      ? AppColors.warningAmber
                                      : AppColors.primaryCoral,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ).merge(AppTypography.numeric),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Píldoras de modo: solo Escanear y Búsqueda.
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _ModePill(
                        icon: MbIcon(
                          MbAssets.scanBarcode,
                          size: 16,
                          color: AppColors.secondaryCyan,
                        ),
                        label: 'Escanear',
                        active: _mode == FoodEntryMode.scan,
                        accent: AppColors.secondaryCyan,
                        onTap: () async {
                          setState(() => _mode = FoodEntryMode.scan);
                          await scanFoodFlow(context);
                        },
                      ),
                      const SizedBox(width: 8),
                      _ModePill(
                        icon: const Icon(
                          Icons.search,
                          size: 16,
                          color: AppColors.primaryCoral,
                        ),
                        label: 'Búsqueda',
                        active: _mode == FoodEntryMode.search,
                        accent: AppColors.primaryCoral,
                        onTap: () =>
                            setState(() => _mode = FoodEntryMode.search),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Buscador.
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onQueryChanged,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Buscar un alimento, marca o receta...',
                      filled: true,
                      fillColor: ThemeColors.dark.input,
                      border: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(14)),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (favorites.isNotEmpty) ...[
                  const _SectionLabel('TUS FRECUENTES (30 DÍAS)'),
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: favorites.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        final p = favorites[i];
                        final selected = _selection.containsKey(p.key);
                        return FilterChip(
                          label: Text(
                            '${p.name} · ${p.calories.round()} kcal',
                            style: TextStyle(
                              color: selected
                                  ? AppColors.inkOnAccent
                                  : c.textPrimary,
                              fontSize: 12,
                            ),
                          ),
                          selected: selected,
                          selectedColor: AppColors.primaryCoral,
                          backgroundColor: c.input,
                          checkmarkColor: AppColors.inkOnAccent,
                          side: BorderSide(
                            color: selected ? AppColors.primaryCoral : c.border,
                          ),
                          onSelected: (_) => _togglePick(p),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                const _SectionLabel('RESULTADOS'),
                Expanded(child: _buildResults()),
                TextButton(
                  onPressed: () => showManualEntrySheet(context, time: _time),
                  child: Text(
                    '¿No lo encuentras? Regístralo manualmente',
                    style: TextStyle(color: c.textSecondary, fontSize: 13),
                  ),
                ),
                SizedBox(height: 16),
              ],
            ),
          ),
          // Barra de multi-selección.
          if (_selection.isNotEmpty)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16 + MediaQuery.paddingOf(context).bottom,
              child: SafeArea(
                top: false,
                child: ElevatedButton.icon(
                  onPressed: _confirmSelection,
                  icon: const Icon(
                    Icons.shopping_basket_outlined,
                    color: AppColors.inkOnAccent,
                    size: 20,
                  ),
                  label: Text(
                    'Registrar alimentos (${_selection.length}) →',
                    style: const TextStyle(
                      color: AppColors.inkOnAccent,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    const c = ThemeColors.dark;
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryCoral),
      );
    }
    if (_error != null) {
      return Center(
        child: Text(
          _error!,
          textAlign: TextAlign.center,
          style: TextStyle(color: c.textSecondary, fontSize: 14),
        ),
      );
    }
    if (_results.isEmpty) {
      return Center(
        child: Text(
          'Escribe para buscar en OpenFoodFacts.',
          style: TextStyle(color: c.textSecondary, fontSize: 14),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      itemCount: _results.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final pick = _pickFromProduct(_results[i]);
        if (pick == null) return const SizedBox.shrink();
        return _ProductTile(
          product: _results[i],
          pick: pick,
          selected: _selection.containsKey(pick.key),
          onToggle: () => _togglePick(pick),
          onOpenSheet: () =>
              showManualEntrySheet(context, product: _results[i], time: _time),
        );
      },
    );
  }
}

class _TopPill extends StatelessWidget {
  const _TopPill({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ThemeColors.dark.input,
      borderRadius: BorderRadius.circular(99),
      child: InkWell(
        borderRadius: BorderRadius.circular(99),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: child,
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: TextStyle(
            color: ThemeColors.dark.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}

class _ModePill extends StatelessWidget {
  const _ModePill({
    required this.icon,
    required this.label,
    required this.active,
    required this.accent,
    required this.onTap,
  });

  final Widget icon;
  final String label;
  final bool active;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: active ? accent.withValues(alpha: 0.12) : ThemeColors.dark.input,
        borderRadius: BorderRadius.circular(99),
        child: InkWell(
          borderRadius: BorderRadius.circular(99),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(99),
              border: Border.all(
                color: active ? accent : Colors.transparent,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                icon,
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: active ? accent : ThemeColors.dark.textSecondary,
                    fontSize: 13,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({
    required this.product,
    required this.pick,
    required this.selected,
    required this.onToggle,
    required this.onOpenSheet,
  });

  final OffProduct product;
  final _Pick pick;
  final bool selected;
  final VoidCallback onToggle;
  final VoidCallback onOpenSheet;

  @override
  Widget build(BuildContext context) {
    const c = ThemeColors.dark;
    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: selected ? AppColors.primaryCoral : c.border),
      ),
      child: ListTile(
        onTap: onToggle,
        title: Text(
          product.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: c.textPrimary, fontSize: 15),
        ),
        subtitle: Text(
          '${product.calories.round()} kcal · ${product.protein.round()}P · '
          '${product.carbs.round()}C · ${product.fats.round()}F · '
          '${_fmt(pick.basisGrams)} g',
          style: TextStyle(
            color: c.textSecondary,
            fontSize: 12,
          ).merge(AppTypography.numeric),
        ),
        trailing: InkWell(
          onTap: onOpenSheet,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? AppColors.primaryCoral : c.input,
              border: Border.all(
                color: selected ? Colors.transparent : c.border,
              ),
            ),
            child: Icon(
              selected ? Icons.check : Icons.edit_outlined,
              size: 18,
              color: selected ? AppColors.inkOnAccent : c.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
