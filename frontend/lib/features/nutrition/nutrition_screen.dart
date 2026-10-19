import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/nutrition.dart';
import '../../theme/app_theme.dart';
import '../auth/auth_controller.dart';
import 'nutrition_entry_sheets.dart';
import 'nutrition_provider.dart';
import 'scan_food_flow.dart';

/// Tab de Nutrición: resumen de macros del día + registro de alimentos.
/// El botón del escáner consulta OpenFoodFacts y guarda en el
/// DailyNutritionLog vía el backend.
class NutritionScreen extends ConsumerStatefulWidget {
  const NutritionScreen({super.key});

  @override
  ConsumerState<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends ConsumerState<NutritionScreen> {
  bool _checkingBarcode = false;

  Future<void> _scan() async {
    if (_checkingBarcode) return;
    setState(() => _checkingBarcode = true);
    try {
      await scanFoodFlow(context);
    } finally {
      if (mounted) setState(() => _checkingBarcode = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(nutritionProvider);
    final user = ref.watch(authControllerProvider.select((s) => s.user));
    final targets = (
      kcal: user?.targetCalories,
      protein: user?.targetProtein,
      carbs: user?.targetCarbs,
      fats: user?.targetFats,
    );

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async =>
              ref.read(nutritionProvider.notifier).loadDay(state.date ?? nutritionToday()),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(AppColors.screenPadding),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const _Header(),
                    const SizedBox(height: 16),
                    _MacroCards(state: state, targets: targets),
                    const SizedBox(height: 16),
                    if (state.log != null) ..._mealSections(state),
                    if (state.loading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(
                            color: AppColors.coral,
                          ),
                        ),
                      )
                    else if (state.log == null || state.log!.items.isEmpty)
                      _EmptyState(
                        onScan: _scan,
                        onManual: () => showManualEntrySheet(context),
                      ),
                    if (state.error != null) _ErrorBanner(message: state.error!),
                    // Zona inferior para que el listado no choque con la barra.
                    const SizedBox(height: 96),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.coral,
        foregroundColor: AppColors.inkOnAccent,
        shape: const CircleBorder(),
        onPressed: _scan,
        child: _checkingBarcode
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: AppColors.inkOnAccent,
                ),
              )
            : const Icon(Icons.qr_code_scanner, size: 26),
      ),
    );
  }

  List<Widget> _mealSections(NutritionState state) {
    final c = ThemeColors.dark;
    final log = state.log;
    if (log == null || log.items.isEmpty) return const [];
    return [
      for (final meal in nutritionMeals)
        if (log.items.any((i) => i.meal == meal)) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              nutritionMealLabels[meal]!,
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
          ...log.items
              .where((i) => i.meal == meal)
              .map((item) => _ItemTile(item: item)),
          const SizedBox(height: 12),
        ],
    ];
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    const c = ThemeColors.dark;
    return Text(
      'NUTRICIÓN',
      style: TextStyle(
        color: c.textPrimary,
        fontSize: 32,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _MacroCards extends StatelessWidget {
  const _MacroCards({required this.state, required this.targets});

  final NutritionState state;
  final ({
    double? kcal,
    double? protein,
    double? carbs,
    double? fats,
  }) targets;

  @override
  Widget build(BuildContext context) {
    final log = state.log;
    final kcal = log?.totalCalories ?? 0.0;
    final protein = log?.totalProtein ?? 0.0;
    final carbs = log?.totalCarbs ?? 0.0;
    final fats = log?.totalFats ?? 0.0;

    return Column(
      children: [
        _RingCard(
          label: 'Calorías',
          value: kcal,
          target: targets.kcal,
          gradient: AppColors.caloriesGradient,
          unit: 'kcal',
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _MacroTile(
                label: 'Proteína',
                value: protein,
                target: targets.protein,
                color: AppColors.accentTeal,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MacroTile(
                label: 'Carb.',
                value: carbs,
                target: targets.carbs,
                color: AppColors.accentBlue,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MacroTile(
                label: 'Grasa',
                value: fats,
                target: targets.fats,
                color: AppColors.accentPurple,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RingCard extends StatelessWidget {
  const _RingCard({
    required this.label,
    required this.value,
    required this.target,
    required this.gradient,
    required this.unit,
  });

  final String label;
  final String unit;
  final double value;
  final double? target;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    const c = ThemeColors.dark;
    final t = target ?? 0;
    final progress = t > 0 ? (value / t).clamp(0.0, 1.0) : 0.0;
    final over = t > 0 && value > t;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(AppColors.radiusCard),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 84,
            height: 84,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 8,
                  strokeCap: StrokeCap.round,
                  color: over ? AppColors.coral : AppColors.accentTeal,
                  backgroundColor: ThemeColors.dark.input,
                ),
                Center(
                  child: Text(
                    '${(progress * 100).round()}%',
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ).merge(AppTypography.numeric),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(color: c.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      value.round().toString(),
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ).merge(AppTypography.numeric),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '/ ${t.round()} $unit',
                      style: TextStyle(
                        color: c.textSecondary,
                        fontSize: 13,
                      ).merge(AppTypography.numeric),
                    ),
                  ],
                ),
                if (target == null)
                  Text(
                    'Sin objetivo: asígnalo en Perfil o con tu profesional.',
                    style: TextStyle(color: c.textSecondary, fontSize: 11),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MacroTile extends StatelessWidget {
  const _MacroTile({
    required this.label,
    required this.value,
    required this.target,
    required this.color,
  });

  final String label;
  final double value;
  final double? target;
  final Color color;

  @override
  Widget build(BuildContext context) {
    const c = ThemeColors.dark;
    final t = target ?? 0;
    final progress = t > 0 ? (value / t).clamp(0.0, 1.0) : 0.0;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(AppColors.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: c.textSecondary, fontSize: 11)),
          const SizedBox(height: 2),
          Text(
            '${value.round()}${target != null ? '/${t.round()}' : ''} g',
            maxLines: 1,
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              overflow: TextOverflow.ellipsis,
            ).merge(AppTypography.numeric),
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: progress,
            minHeight: 4,
            borderRadius: BorderRadius.circular(2),
            color: color,
            backgroundColor: ThemeColors.dark.input,
          ),
        ],
      ),
    );
  }
}

class _ItemTile extends ConsumerWidget {
  const _ItemTile({required this.item});

  final NutritionItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const c = ThemeColors.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(AppColors.radiusCard),
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
          title: Text(
            item.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: c.textPrimary, fontSize: 15),
          ),
          subtitle: Text(
            '${item.quantityG.round()} g',
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 12,
            ).merge(AppTypography.numeric),
          ),
          trailing: Text(
            '${item.calories.round()} kcal',
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ).merge(AppTypography.numeric),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onScan, required this.onManual});

  final VoidCallback onScan;
  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) {
    const c = ThemeColors.dark;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(AppColors.radiusCard),
      ),
      child: Column(
        children: [
          Icon(Icons.apple_outlined, size: 48, color: c.textSecondary),
          const SizedBox(height: 12),
          Text(
            'Sin registros para hoy.',
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Escanea el código de barras de un producto o registra un alimento manualmente.',
            textAlign: TextAlign.center,
            style: TextStyle(color: c.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: Icon(Icons.edit_outlined, color: c.textPrimary, size: 18),
                  label: Text('Manual', style: TextStyle(color: c.textPrimary)),
                  onPressed: onManual,
                ),
              ),
            ],
          ),
        ],
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
      child: Text(message, style: TextStyle(color: c.textPrimary, fontSize: 13)),
    );
  }
}
