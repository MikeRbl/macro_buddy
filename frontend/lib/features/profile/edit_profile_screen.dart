import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import '../auth/auth_controller.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  static const _genders = [
    (label: 'Masculino', value: 'male'),
    (label: 'Femenino', value: 'female'),
    (label: 'Otro', value: 'other'),
    (label: 'Prefiero no decirlo', value: 'prefer_not_to_say'),
  ];

  late final TextEditingController _fullNameController;
  late final TextEditingController _usernameController;
  late final TextEditingController _currentPasswordController;
  late final TextEditingController _newPasswordController;
  late final TextEditingController _weightController;
  late final TextEditingController _bodyFatController;
  late final TextEditingController _heightController;
  late final List<TextEditingController> _macroControllers;
  late String _gender;

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authControllerProvider).user;
    _fullNameController = TextEditingController(text: user?.fullName ?? '');
    _usernameController = TextEditingController(text: user?.username ?? '');
    _currentPasswordController = TextEditingController();
    _newPasswordController = TextEditingController();
    _weightController = TextEditingController(
      text: user?.weight?.toStringAsFixed(0) ?? '',
    );
    _bodyFatController = TextEditingController(
      text: user?.bodyFat?.toStringAsFixed(1) ?? '',
    );
    _heightController = TextEditingController(
      text: user?.height?.toStringAsFixed(0) ?? '',
    );
    _gender = user?.gender ?? 'prefer_not_to_say';
    _macroControllers = [
      for (final v in [
        user?.targetCalories,
        user?.targetProtein,
        user?.targetCarbs,
        user?.targetFats,
      ])
        TextEditingController(text: v?.toString() ?? ''),
    ];
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _weightController.dispose();
    _bodyFatController.dispose();
    _heightController.dispose();
    for (final c in _macroControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final guided = ref.read(authControllerProvider).user?.isGuidedMode ?? false;
    final name = _fullNameController.text.trim();
    final weightStr = _weightController.text.trim().replaceAll(',', '.');
    final heightStr = _heightController.text.trim().replaceAll(',', '.');
    final bodyFatStr = _bodyFatController.text.trim().replaceAll(',', '.');
    final weight = double.tryParse(weightStr);
    final height = double.tryParse(heightStr);
    final bodyFat = double.tryParse(bodyFatStr);

    double? parseMacro(int i) =>
        double.tryParse(_macroControllers[i].text.trim().replaceAll(',', '.'));
    final targetCalories = parseMacro(0);
    final targetProtein = parseMacro(1);
    final targetCarbs = parseMacro(2);
    final targetFats = parseMacro(3);

    if (name.isEmpty ||
        weight == null ||
        height == null ||
        weight <= 0 ||
        height <= 0) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor completa tu nombre, peso y altura.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final error = await ref
        .read(authControllerProvider.notifier)
        .updateProfile(
          fullName: name,
          username: _usernameController.text.trim(),
          weight: weight,
          height: height,
          bodyFat: bodyFat,
          gender: _gender,
          currentPassword: _currentPasswordController.text.isEmpty
              ? null
              : _currentPasswordController.text,
          newPassword: _newPasswordController.text.isEmpty
              ? null
              : _newPasswordController.text,
          // El backend ignora los targets (y devuelve 403) en modo guiado.
          targetCalories: guided ? null : targetCalories,
          targetProtein: guided ? null : targetProtein,
          targetCarbs: guided ? null : targetCarbs,
          targetFats: guided ? null : targetFats,
        );

    if (!mounted) return;
    setState(() => _saving = false);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Cambios guardados')));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = ThemeColors.of(context);
    final user = ref.watch(authControllerProvider).user;
    final bool isProfileIncomplete = user == null ||
        (user.fullName == null || user.fullName!.trim().isEmpty) ||
        user.weight == null ||
        user.height == null;

    return PopScope(
      canPop: !isProfileIncomplete,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Debes completar tu perfil para continuar.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Editar Perfil'),
          automaticallyImplyLeading: !isProfileIncomplete,
        ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppColors.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _fullNameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(hintText: 'Nombre completo'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _usernameController,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                decoration: const InputDecoration(
                  hintText: 'Nombre de usuario',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _currentPasswordController,
                obscureText: _obscureCurrent,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  hintText: 'Contraseña actual',
                  suffixIcon: IconButton(
                    onPressed: () =>
                        setState(() => _obscureCurrent = !_obscureCurrent),
                    icon: Icon(
                      _obscureCurrent
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: c.textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _newPasswordController,
                obscureText: _obscureNew,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  hintText: 'Nueva contraseña',
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscureNew = !_obscureNew),
                    icon: Icon(
                      _obscureNew
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: c.textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _weightController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                      ],
                      decoration: const InputDecoration(
                        hintText: 'Peso',
                        suffixText: 'kg',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _heightController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                      ],
                      decoration: const InputDecoration(
                        hintText: 'Altura',
                        suffixText: 'cm',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Grasa corporal estimada; es opcional.
              TextField(
                controller: _bodyFatController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                decoration: const InputDecoration(
                  hintText: 'Grasa corporal (opcional)',
                  suffixText: '%',
                ),
              ),
              const SizedBox(height: 16),
              _MacrosSection(guided: user?.isGuidedMode ?? false, controllers: _macroControllers),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: c.input,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _gender,
                    isExpanded: true,
                    dropdownColor: c.card,
                    style: TextStyle(color: c.textPrimary, fontSize: 16),
                    items: _genders
                        .map(
                          (gender) => DropdownMenuItem(
                            value: gender.value,
                            child: Text(gender.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _gender = value ?? _gender),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: const TextStyle(color: AppColors.danger, fontSize: 14),
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : const Text('Guardar Cambios'),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

/// Objetivos de macros asignados por el profesional. En modo guiado los
/// campos se ven pero no se pueden editar (403 del backend como cinturón
/// de seguridad; la UI ya los deshabilita).
class _MacrosSection extends StatelessWidget {
  const _MacrosSection({required this.guided, required this.controllers});

  final bool guided;
  final List<TextEditingController> controllers;

  static const _labels = ['Kcal', 'Proteína (g)', 'Carb. (g)', 'Grasa (g)'];

  @override
  Widget build(BuildContext context) {
    final c = ThemeColors.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(AppColors.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Objetivos de macros',
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (guided)
                Icon(Icons.lock, color: AppColors.coral, size: 16),
            ],
          ),
          if (guided) ...[
            const SizedBox(height: 4),
            Text(
              'Los gestiona tu profesional (modo guiado).',
              style: TextStyle(color: c.textSecondary, fontSize: 11),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 0; i < 4; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: controllers[i],
                    enabled: !guided,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    style: TextStyle(color: c.textPrimary)
                        .merge(AppTypography.numeric),
                    decoration: InputDecoration(
                      hintText: _labels[i],
                      filled: true,
                      fillColor: ThemeColors.dark.input,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
