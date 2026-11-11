import 'package:flutter/material.dart';

import '../../core/services/food_repository.dart';
import '../../theme/app_theme.dart';
import 'contribute_food_flow.dart';

/// "Mis alimentos": productos que el usuario registró a mano, con el estado
/// de su solicitud de verificación. Permite editar, borrar y reenviar.
class MyFoodsScreen extends StatefulWidget {
  const MyFoodsScreen({super.key});

  @override
  State<MyFoodsScreen> createState() => _MyFoodsScreenState();
}

class _MyFoodsScreenState extends State<MyFoodsScreen> {
  final _repo = FoodRepository.shared;
  late Future<List<UserFood>> _foods = _repo.myFoods();

  @override
  void initState() {
    super.initState();
    // Trae aprobaciones y rechazos recientes; sin red se queda lo local.
    _repo.refreshContributionStatuses().then((_) => _reload());
  }

  void _reload() {
    if (!mounted) return;
    setState(() => _foods = _repo.myFoods());
  }

  Future<void> _edit(UserFood food) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _EditFoodDialog(food: food),
    );
    if (saved == true) _reload();
  }

  Future<void> _delete(UserFood food) async {
    const c = ThemeColors.dark;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.card,
        title: Text('Borrar alimento', style: TextStyle(color: c.textPrimary)),
        content: Text(
          '"${food.name}" se borrará de este equipo. Lo que ya registraste '
          'en tu diario no cambia.',
          style: TextStyle(color: c.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancelar', style: TextStyle(color: c.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Borrar', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _repo.deleteUserFood(food.localId);
    _reload();
  }

  Future<void> _send(UserFood food) async {
    await offerContribution(context, food, resend: true);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    const c = ThemeColors.dark;
    return Scaffold(
      appBar: AppBar(title: const Text('Mis alimentos')),
      body: SafeArea(
        child: FutureBuilder<List<UserFood>>(
          future: _foods,
          builder: (context, snap) {
            if (snap.hasError) {
              return Center(
                child: Text(
                  'No se pudieron cargar tus alimentos.',
                  style: TextStyle(color: c.textSecondary),
                ),
              );
            }
            final foods = snap.data;
            if (foods == null) {
              return const Center(child: CircularProgressIndicator());
            }
            if (foods.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'Aún no registras alimentos propios. Los productos que '
                    'captures a mano con "Guardar en mis alimentos" aparecerán '
                    'aquí.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: c.textSecondary, height: 1.4),
                  ),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(AppColors.screenPadding),
              itemCount: foods.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _FoodTile(
                food: foods[i],
                onEdit: () => _edit(foods[i]),
                onDelete: () => _delete(foods[i]),
                onSend: () => _send(foods[i]),
              ),
            );
          },
        ),
      ),
    );
  }
}

({String label, Color color}) _statusStyle(ContributionStatus s) => switch (s) {
  ContributionStatus.local ||
  ContributionStatus.declined => (label: 'Solo local', color: AppColors.textSecondary),
  ContributionStatus.pending => (label: 'Pendiente', color: AppColors.warningAmber),
  ContributionStatus.approved => (label: 'Aprobado', color: AppColors.successGreen),
  ContributionStatus.rejected => (label: 'Rechazado', color: AppColors.danger),
};

String _n(double v) => v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);

class _FoodTile extends StatelessWidget {
  const _FoodTile({
    required this.food,
    required this.onEdit,
    required this.onDelete,
    required this.onSend,
  });

  final UserFood food;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    const c = ThemeColors.dark;
    final status = _statusStyle(food.status);
    // Solo se verifican productos con código; lo pendiente o aprobado ya se envió.
    final canSend = food.barcode != null &&
        food.status != ContributionStatus.pending &&
        food.status != ContributionStatus.approved;
    final brand = food.brand;
    final note = food.reviewerNote;

    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(AppColors.radiusCard),
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 4, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  food.name,
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (brand != null && brand.isNotEmpty)
                  Text(brand, style: TextStyle(color: c.textSecondary, fontSize: 13)),
                const SizedBox(height: 4),
                Text(
                  '${_n(food.kcal)} kcal · P ${_n(food.protein)} · '
                  'C ${_n(food.carbs)} · G ${_n(food.fat)} por 100 ${food.baseUnit}',
                  style: TextStyle(color: c.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: status.color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    status.label,
                    style: TextStyle(
                      color: status.color,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (food.status == ContributionStatus.rejected &&
                    note != null &&
                    note.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Nota del revisor: $note',
                    style: TextStyle(color: c.textSecondary, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          PopupMenuButton<VoidCallback>(
            tooltip: 'Opciones',
            icon: Icon(Icons.more_vert, color: c.textSecondary),
            onSelected: (action) => action(),
            itemBuilder: (_) => [
              PopupMenuItem(value: onEdit, child: const Text('Editar')),
              if (canSend)
                PopupMenuItem(
                  value: onSend,
                  child: Text(
                    food.status == ContributionStatus.rejected
                        ? 'Reenviar a verificación'
                        : 'Enviar a verificación',
                  ),
                ),
              PopupMenuItem(value: onDelete, child: const Text('Borrar')),
            ],
          ),
        ],
      ),
    );
  }
}

/// Edita nombre, marca y macros por 100 g/ml. Guardar cambios regresa el
/// producto a "solo local": lo verificado eran los datos anteriores.
class _EditFoodDialog extends StatefulWidget {
  const _EditFoodDialog({required this.food});

  final UserFood food;

  @override
  State<_EditFoodDialog> createState() => _EditFoodDialogState();
}

class _EditFoodDialogState extends State<_EditFoodDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.food.name);
  late final _brand = TextEditingController(text: widget.food.brand ?? '');
  late final _kcal = TextEditingController(text: _n(widget.food.kcal));
  late final _protein = TextEditingController(text: _n(widget.food.protein));
  late final _carbs = TextEditingController(text: _n(widget.food.carbs));
  late final _fat = TextEditingController(text: _n(widget.food.fat));

  @override
  void dispose() {
    for (final t in [_name, _brand, _kcal, _protein, _carbs, _fat]) {
      t.dispose();
    }
    super.dispose();
  }

  static double? _parse(String raw) {
    final v = double.tryParse(raw.trim().replaceAll(',', '.'));
    return v == null || v < 0 || !v.isFinite ? null : v;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final brand = _brand.text.trim();
    await FoodRepository.shared.updateUserFood(
      widget.food,
      name: _name.text.trim(),
      brand: brand.isEmpty ? null : brand,
      kcal: _parse(_kcal.text)!,
      protein: _parse(_protein.text)!,
      carbs: _parse(_carbs.text)!,
      fat: _parse(_fat.text)!,
    );
    if (mounted) Navigator.of(context).pop(true);
  }

  Widget _number(String label, TextEditingController controller) => TextFormField(
    controller: controller,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(labelText: label),
    validator: (v) => _parse(v ?? '') == null ? 'Número inválido' : null,
  );

  @override
  Widget build(BuildContext context) {
    const c = ThemeColors.dark;
    final unit = widget.food.baseUnit;
    return AlertDialog(
      backgroundColor: c.card,
      title: Text('Editar alimento', style: TextStyle(color: c.textPrimary)),
      content: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                maxLength: 120,
                decoration: const InputDecoration(labelText: 'Nombre', counterText: ''),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'El nombre es obligatorio' : null,
              ),
              TextFormField(
                controller: _brand,
                maxLength: 80,
                decoration: const InputDecoration(labelText: 'Marca', counterText: ''),
              ),
              _number('Calorías (kcal) por 100 $unit', _kcal),
              _number('Proteína (g) por 100 $unit', _protein),
              _number('Carbohidratos (g) por 100 $unit', _carbs),
              _number('Grasa (g) por 100 $unit', _fat),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text('Cancelar', style: TextStyle(color: c.textSecondary)),
        ),
        ElevatedButton(
          onPressed: _save,
          child: Text('Guardar', style: TextStyle(color: c.scaffold)),
        ),
      ],
    );
  }
}
