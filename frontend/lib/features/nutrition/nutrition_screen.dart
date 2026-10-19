import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/nutrition.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/mb_icon.dart';
import '../../theme/app_theme.dart';
import '../auth/auth_controller.dart';
import 'food_entry_screen.dart';
import 'nutrition_entry_sheets.dart';
import 'nutrition_provider.dart';

const _monthsEs = [
  'Enero',
  'Febrero',
  'Marzo',
  'Abril',
  'Mayo',
  'Junio',
  'Julio',
  'Agosto',
  'Septiembre',
  'Octubre',
  'Noviembre',
  'Diciembre',
];
const _weekdaysEs = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

/// Formato con separador de miles para kcal (sin dependencias).
String _formatNum(int v) {
  final s = v.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    final idx = s.length - i;
    if (i > 0 && idx % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

String _dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Tab de Nutrición: bitácora por horas del día ("HH:mm"). El registro
/// guarda `time` y `label` (contrato del backend); no hay comidas fijas.
class NutritionScreen extends ConsumerStatefulWidget {
  const NutritionScreen({super.key});

  @override
  ConsumerState<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends ConsumerState<NutritionScreen> {
  String _selectedDate = '';

  String get _date {
    if (_selectedDate.isEmpty) {
      _selectedDate = ref.read(nutritionProvider).date ?? nutritionToday();
    }
    return _selectedDate;
  }

  DateTime get _dateObj {
    final parts = _date.split('-');
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  Future<void> _select(DateTime day) async {
    setState(() => _selectedDate = _dateKey(day));
    await ref.read(nutritionProvider.notifier).loadDay(_date);
  }

  Future<void> _pickCalendarDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateObj,
      firstDate: DateTime(_today.year - 5),
      lastDate: DateTime(_today.year + 5),
    );
    if (picked == null) return;
    await _select(picked);
  }

  void _openFoodEntry({String? time}) {
    final state = ref.read(nutritionProvider);
    final user = ref.read(authControllerProvider).user;
    final target = user?.targetCalories;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FoodEntryScreen(
          initialTime: time ?? nutritionNowTime(),
          calorieTarget: target,
          calorieConsumed: state.log?.totalCalories ?? 0,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(nutritionProvider);
    final user = ref.watch(authControllerProvider.select((s) => s.user));
    final safe = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: RefreshIndicator(
              onRefresh: () async =>
                  ref.read(nutritionProvider.notifier).loadDay(_date),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.all(AppColors.screenPadding),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _Header(
                          date: _dateObj,
                          today: _today,
                          onPrev: () => _select(
                            _dateObj.subtract(const Duration(days: 1)),
                          ),
                          onNext: () =>
                              _select(_dateObj.add(const Duration(days: 1))),
                          onCalendar: _pickCalendarDate,
                        ),
                        const SizedBox(height: 16),
                        _WeekStrip(
                          focused: _dateObj,
                          selected: _date,
                          today: _today,
                          onSelect: _select,
                        ),
                        const SizedBox(height: 16),
                        _MiniMacroRow(
                          log: state.log,
                          targets: (
                            kcal: user?.targetCalories,
                            protein: user?.targetProtein,
                            carbs: user?.targetCarbs,
                            fats: user?.targetFats,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (state.loading)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: CircularProgressIndicator(
                                color: AppColors.primaryCoral,
                              ),
                            ),
                          )
                        else
                          ..._timeline(state),
                        if (state.error != null)
                          _ErrorBanner(message: state.error!),
                        // Zona inferior para no quedar bajo el navbar
                        // flotante ni el FAB.
                        SizedBox(height: 170.0 + safe),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _timeline(NutritionState state) {
    final log = state.log;
    if (log == null) return const [];
    // 24 bloques fijos (00:00 → 23:00): la hoja completa del día. Los ítems
    // caen en el bloque de su hora (los :30 van con XX:00).
    final byHour = <int, List<NutritionItem>>{};
    for (final item in log.items) {
      final h = int.tryParse(effectiveTime(item).split(':')[0]) ?? 0;
      byHour.putIfAbsent(h.clamp(0, 23), () => []).add(item);
    }
    return [
      for (var h = 0; h < 24; h++)
        _TimelineBlock(
          key: ValueKey('hour-$h'),
          hour: '${h.toString().padLeft(2, '0')}:00',
          items: byHour[h] ?? const [],
          onAdd: () =>
              _openFoodEntry(time: '${h.toString().padLeft(2, '0')}:00'),
        ),
    ];
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.date,
    required this.today,
    required this.onPrev,
    required this.onNext,
    required this.onCalendar,
  });

  final DateTime date;
  final DateTime today;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onCalendar;

  String get _label {
    final isToday =
        date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;
    final isYesterday =
        date.year == today.year &&
        date.month == today.month &&
        date.day == today.day - 1;
    if (isToday) return 'Hoy, ${date.day} de ${_monthsEs[date.month - 1]}';
    if (isYesterday) {
      return 'Ayer, ${date.day} de ${_monthsEs[date.month - 1]}';
    }
    return '${_weekdaysEs[date.weekday - 1]}, ${date.day} de '
        '${_monthsEs[date.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    const c = ThemeColors.dark;
    return Row(
      children: [
        IconButton(
          onPressed: onPrev,
          icon: Icon(Icons.chevron_left, color: c.textPrimary),
        ),
        Expanded(
          child: Text(
            _label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        IconButton(
          onPressed: onNext,
          icon: Icon(Icons.chevron_right, color: c.textPrimary),
        ),
        IconButton(
          onPressed: onCalendar,
          icon: MbIcon(MbAssets.calendar, size: 22, color: c.textPrimary),
        ),
      ],
    );
  }
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({
    required this.focused,
    required this.selected,
    required this.today,
    required this.onSelect,
  });

  final DateTime focused;
  final String selected;
  final DateTime today;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    const c = ThemeColors.dark;
    final start = focused.subtract(const Duration(days: 3));
    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: 7,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final day = start.add(Duration(days: i));
          final code = _dateKey(day);
          final isSelected = code == selected;
          return GestureDetector(
            onTap: () => onSelect(day),
            child: Container(
              width: 44,
              height: 62,
              decoration: BoxDecoration(
                color: isSelected ? c.card : Colors.transparent,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isSelected ? AppColors.primaryCoral : c.border,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _weekdaysEs[day.weekday - 1][0],
                    style: TextStyle(
                      color: isSelected ? c.textPrimary : c.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${day.day}',
                    style: TextStyle(
                      color: isSelected ? c.textPrimary : c.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? AppColors.primaryCoral
                          : Colors.transparent,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MiniMacroRow extends StatelessWidget {
  const _MiniMacroRow({required this.log, required this.targets});

  final NutritionLog? log;
  final ({double? kcal, double? protein, double? carbs, double? fats}) targets;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MiniMacroCard(
            label: 'CAL',
            value: log?.totalCalories.round() ?? 0,
            target: (targets.kcal ?? 0).round(),
            color: AppColors.primaryCoral,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MiniMacroCard(
            label: 'P',
            value: log?.totalProtein.round() ?? 0,
            target: (targets.protein ?? 0).round(),
            color: AppColors.secondaryCyan,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MiniMacroCard(
            label: 'F',
            value: log?.totalFats.round() ?? 0,
            target: (targets.fats ?? 0).round(),
            color: AppColors.warningAmber,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MiniMacroCard(
            label: 'C',
            value: log?.totalCarbs.round() ?? 0,
            target: (targets.carbs ?? 0).round(),
            color: AppColors.successGreen,
          ),
        ),
      ],
    );
  }
}

class _MiniMacroCard extends StatelessWidget {
  const _MiniMacroCard({
    required this.label,
    required this.value,
    required this.target,
    required this.color,
  });

  final String label;
  final int value;
  final int target;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final progress = target > 0 ? (value / target).clamp(0.0, 1.0) : 0.0;
    const c = ThemeColors.dark;
    return GlassCard(
      padding: const EdgeInsets.all(10),
      color: c.input,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${_formatNum(value)}${target > 0 ? '/${_formatNum(target)}' : ''}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 12,
            ).merge(AppTypography.numeric),
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: progress,
            minHeight: 3,
            borderRadius: BorderRadius.circular(2),
            color: color,
            backgroundColor: c.border,
          ),
        ],
      ),
    );
  }
}

class _TimelineBlock extends ConsumerWidget {
  const _TimelineBlock({
    required this.hour,
    required this.items,
    required this.onAdd,
    super.key,
  });

  final String hour;
  final List<NutritionItem> items;
  final VoidCallback onAdd;

  double get _kcal => items.fold(0, (s, i) => s + i.calories);
  double get _protein => items.fold(0, (s, i) => s + i.protein);
  double get _fats => items.fold(0, (s, i) => s + i.fats);
  double get _carbs => items.fold(0, (s, i) => s + i.carbs);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const c = ThemeColors.dark;
    final isEmpty = items.isEmpty;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Riel izquierdo: etiqueta vigente + mini botón + solo en horas con
        // registros o en la franja desayuno para no saturar el riel.
        SizedBox(
          width: 56,
          child: Column(
            children: [
              Text(
                formatTime12h(hour),
                style: TextStyle(
                  color: isEmpty ? c.textSecondary : c.textPrimary,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ).merge(AppTypography.numeric),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: onAdd,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: c.input,
                    border: Border.all(color: c.border),
                  ),
                  child: Icon(
                    Icons.add,
                    size: 14,
                    color: isEmpty ? c.textSecondary : AppColors.primaryCoral,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Expanded(child: Container(width: 1, color: c.border)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // Franja derecha: solo contenido si hay registros en esta hora
        // (los bloques vacíos quedan compactos para no inflar la lista).
        Expanded(
          child: Container(
            padding: EdgeInsets.only(bottom: isEmpty ? 12 : 16),
            child: isEmpty
                ? null
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Text(
                            formatTime12h(hour),
                            style: TextStyle(
                              color: c.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${_formatNum(_kcal.round())} kcal • '
                            '${_protein.round()}P • ${_fats.round()}F • '
                            '${_carbs.round()}C',
                            style: TextStyle(
                              color: c.textSecondary,
                              fontSize: 10,
                            ).merge(AppTypography.numeric),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ...items.map((item) => _TimeItemTile(item: item)),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

class _TimeItemTile extends ConsumerWidget {
  const _TimeItemTile({required this.item});

  final NutritionItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const c = ThemeColors.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(AppColors.radiusCard),
        border: Border.all(color: c.border),
      ),
      child: Dismissible(
        key: ValueKey('item-${item.id}'),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: AppColors.danger,
            borderRadius: BorderRadius.circular(AppColors.radiusCard),
          ),
          child: const Icon(Icons.delete_outline, color: Colors.white),
        ),
        onDismissed: (_) =>
            ref.read(nutritionProvider.notifier).deleteItem(item),
        child: ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppColors.radiusCard),
          ),
          onTap: () => showManualEntrySheet(context, existing: item),
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color:
                  (item.barcode != null
                          ? AppColors.secondaryCyan
                          : AppColors.primaryCoral)
                      .withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: MbIcon(
                item.barcode != null ? MbAssets.scanBarcode : MbAssets.fruit,
                size: 20,
                color: item.barcode != null
                    ? AppColors.secondaryCyan
                    : AppColors.primaryCoral,
              ),
            ),
          ),
          title: Text(
            item.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: c.textPrimary, fontSize: 15),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${item.calories.round()} kcal • ${item.protein.round()}P • '
                '${item.fats.round()}F • ${item.carbs.round()}C',
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 11,
                ).merge(AppTypography.numeric),
              ),
              if (item.quantityG > 0)
                Text(
                  '${item.quantityG.round()} g',
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 10,
                  ).merge(AppTypography.numeric),
                ),
            ],
          ),
          trailing: IconButton(
            onPressed: () => showManualEntrySheet(context, existing: item),
            icon: Icon(Icons.edit_outlined, size: 20, color: c.textSecondary),
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    const c = ThemeColors.dark;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: TextStyle(color: c.textPrimary, fontSize: 13),
      ),
    );
  }
}
