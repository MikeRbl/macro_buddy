import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import 'auth_controller.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _pageController = PageController();
  int _step = 0;

  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  static const _genders = [
    (label: 'Masculino', value: 'male'),
    (label: 'Femenino', value: 'female'),
    (label: 'Otro', value: 'other'),
  ];
  String? _gender;

  String? _formError;

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  bool _validateStep1() {
    final name = _nameController.text.trim();
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    String? error;
    if (name.isEmpty ||
        username.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      error = 'Completa todos los campos para continuar.';
    } else if (password != confirmPassword) {
      error = 'Las contraseñas no coinciden.';
    }

    setState(() => _formError = error);
    return error == null;
  }

  void _goToStep2() {
    if (!_validateStep1()) return;
    _formError = null;
    _pageController.animateToPage(
      1,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  void _goBack() {
    if (_step == 1) {
      setState(() => _step = 0);
      _pageController.animateToPage(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    } else {
      ref.read(authControllerProvider.notifier).clearError();
      Navigator.of(context).maybePop();
    }
  }

  Future<void> _submitRegistration() async {
    FocusScope.of(context).unfocus();
    final weight = double.tryParse(
      _weightController.text.trim().replaceAll(',', '.'),
    );
    final height = double.tryParse(
      _heightController.text.trim().replaceAll(',', '.'),
    );

    await ref
        .read(authControllerProvider.notifier)
        .register(
          fullName: _nameController.text.trim(),
          username: _usernameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
          weight: weight,
          height: height,
          gender: _gender,
        );

    if (ref.read(authControllerProvider).isAuthenticated) {
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = ThemeColors.of(context);
    final authState = ref.watch(authControllerProvider);
    final error = _formError ?? authState.error;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 8),
              SizedBox(
                height: 40,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        onPressed: _goBack,
                        icon: Icon(
                          Icons.arrow_back_ios_new,
                          color: c.textSecondary,
                        ),
                      ),
                    ),
                    Text(
                      'Paso ${_step + 1} de 2',
                      style: TextStyle(color: c.textSecondary, fontSize: 14),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (page) => setState(() => _step = page),
                  children: [
                    _buildStep1(context, error),
                    _buildStep2(context, error),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep1(BuildContext context, String? error) {
    final c = ThemeColors.of(context);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 40),
          Text(
            'Crea tu cuenta',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: c.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Únete a Macrobuddy para registrar tu progreso.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: c.textSecondary,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _nameController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(hintText: 'Nombre'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _usernameController,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            decoration: const InputDecoration(hintText: 'Nombre de usuario'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            decoration: const InputDecoration(hintText: 'Correo electrónico'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              hintText: 'Contraseña',
              suffixIcon: IconButton(
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
                icon: Icon(
                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
                  color: c.textSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirmPassword,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _goToStep2(),
            decoration: InputDecoration(
              hintText: 'Confirmar contraseña',
              suffixIcon: IconButton(
                onPressed: () => setState(
                  () => _obscureConfirmPassword = !_obscureConfirmPassword,
                ),
                icon: Icon(
                  _obscureConfirmPassword
                      ? Icons.visibility
                      : Icons.visibility_off,
                  color: c.textSecondary,
                ),
              ),
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 16),
            Text(
              error,
              style: const TextStyle(color: AppColors.danger, fontSize: 14),
            ),
          ],
          const SizedBox(height: 32),
          ElevatedButton(onPressed: _goToStep2, child: const Text('Siguiente')),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildStep2(BuildContext context, String? error) {
    final c = ThemeColors.of(context);
    final isLoading = ref.watch(authControllerProvider).isLoading;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 40),
          Text(
            'Conozcámonos un poco',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: c.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Estos datos nos ayudan a personalizar tu perfil.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: c.textSecondary,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Género',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: c.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _genders.map((gender) {
              final selected = _gender == gender.value;
              return GestureDetector(
                onTap: () => setState(() => _gender = gender.value),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: c.input,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: selected ? c.textPrimary : c.input,
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    gender.label,
                    style: TextStyle(
                      color: selected ? c.textPrimary : c.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _weightController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
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
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
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
          if (error != null) ...[
            const SizedBox(height: 16),
            Text(
              error,
              style: const TextStyle(color: AppColors.danger, fontSize: 14),
            ),
          ],
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: isLoading ? null : _submitRegistration,
            child: isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : const Text('Crear Cuenta y Comenzar'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
