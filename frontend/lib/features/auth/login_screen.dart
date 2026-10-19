import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/api_config.dart';
import '../../core/widgets/build_footer.dart';
import '../../theme/app_theme.dart';
import 'auth_controller.dart';
import 'register_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final identifier = _identifierController.text.trim();
    final password = _passwordController.text;
    if (identifier.isEmpty || password.isEmpty) {
      return;
    }
    await ref.read(authControllerProvider.notifier).login(identifier, password);
  }

  void _goToRegister() {
    ref.read(authControllerProvider.notifier).clearError();
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const RegisterScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final c = ThemeColors.of(context);
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 48),
              Text(
                'Inicia sesión',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: c.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 28,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Bienvenido de vuelta a Macrobuddy.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: c.textSecondary,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _identifierController,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                decoration: const InputDecoration(
                  hintText: 'Correo o nombre de usuario',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  hintText: 'Contraseña',
                  suffixIcon: IconButton(
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: c.textSecondary,
                    ),
                  ),
                ),
              ),
              if (authState.error != null) ...[
                const SizedBox(height: 16),
                Text(
                  authState.error!,
                  style: const TextStyle(color: AppColors.danger, fontSize: 14),
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: isLoading ? null : _submit,
                child: isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : const Text('Iniciar sesión'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _goToRegister,
                child: const Text('¿No tienes cuenta? Regístrate'),
              ),
              // Configuración viva del servidor (útil con APK física).
              TextButton(
                onPressed: _showServerDialog,
                child: Text(
                  'Servidor: ${Uri.parse(ApiConfig.baseUrl).host}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const BuildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  /// Diálogo para cambiar la base URL del backend en runtime: clave para
  /// probar el APK en un dispositivo físico contra la IP local del PC.
  Future<void> _showServerDialog() async {
    final controller = TextEditingController(text: ApiConfig.baseUrl);
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: ThemeColors.dark.card,
        title: Text(
          'Servidor',
          style: TextStyle(
            color: ThemeColors.dark.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(signed: true),
          autocorrect: false,
          decoration: InputDecoration(
            hintText: '192.168.100.19',
            labelText: 'IP del servidor',
            labelStyle: TextStyle(color: ThemeColors.dark.textSecondary),
            fillColor: ThemeColors.dark.input,
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (saved == true) {
      await ApiConfig.setBaseUrl(controller.text);
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: ThemeColors.dark.card,
          content: Text(
            'Servidor actualizado: ${ApiConfig.baseUrl}',
            style: TextStyle(color: ThemeColors.dark.textPrimary),
          ),
        ),
      );
    }
  }
}
