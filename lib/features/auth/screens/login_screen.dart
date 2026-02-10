import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/routes/app_router.dart';
import '../../../shared/widgets/app_logo.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/widgets/custom_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.login(
      _emailController.text.trim(),
      _senhaController.text,
    );

    setState(() => _isLoading = false);

    if (success && mounted) {
      context.go(AppRoutes.dashboard);
    } else if (mounted && authProvider.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.error!),
          backgroundColor: AppColors.error,
        ),
      );
      authProvider.clearError();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final compact = screenH < 700;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: 24,
                vertical: compact ? 12 : 20,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  AppLogo(size: compact ? 56 : 68)
                      .animate()
                      .fadeIn(duration: 500.ms)
                      .scale(begin: const Offset(0.8, 0.8)),

                  SizedBox(height: compact ? 12 : 20),

                  // Título
                  Text(
                    'Bem-vindo de volta!',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),

                  const SizedBox(height: 4),

                  Text(
                    'Entre com sua conta para continuar',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ).animate().fadeIn(delay: 300.ms),

                  SizedBox(height: compact ? 20 : 28),

                  // Formulário
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        CustomTextField(
                          label: 'E-mail',
                          hint: 'seu@email.com',
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          prefixIcon: const Icon(Icons.email_outlined),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Informe seu e-mail';
                            }
                            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                .hasMatch(value)) {
                              return 'E-mail inválido';
                            }
                            return null;
                          },
                        ).animate().fadeIn(delay: 400.ms).slideX(begin: -0.1),

                        const SizedBox(height: 14),

                        CustomTextField(
                          label: 'Senha',
                          hint: 'Sua senha',
                          controller: _senhaController,
                          obscureText: true,
                          textInputAction: TextInputAction.done,
                          prefixIcon: const Icon(Icons.lock_outline),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Informe sua senha';
                            }
                            return null;
                          },
                          onSubmitted: (_) => _handleLogin(),
                        ).animate().fadeIn(delay: 500.ms).slideX(begin: -0.1),

                        const SizedBox(height: 4),

                        // Esqueceu a senha
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => context.push(AppRoutes.forgotPassword),
                            child: const Text('Esqueci minha senha'),
                          ),
                        ).animate().fadeIn(delay: 600.ms),

                        SizedBox(height: compact ? 12 : 16),

                        // Botão Login
                        CustomButton(
                          text: 'Entrar',
                          onPressed: _handleLogin,
                          isLoading: _isLoading,
                          icon: Icons.login,
                        ).animate().fadeIn(delay: 700.ms).scale(begin: const Offset(0.95, 0.95)),

                        SizedBox(height: compact ? 16 : 24),

                        // Divisor
                        const Row(
                          children: [
                            Expanded(child: Divider(color: AppColors.gray300)),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                'ou',
                                style: TextStyle(color: AppColors.gray500),
                              ),
                            ),
                            Expanded(child: Divider(color: AppColors.gray300)),
                          ],
                        ).animate().fadeIn(delay: 800.ms),

                        SizedBox(height: compact ? 16 : 24),

                        // Criar conta
                        CustomButton(
                          text: 'Criar uma conta',
                          onPressed: () => context.push(AppRoutes.register),
                          variant: ButtonVariant.outline,
                          icon: Icons.person_add_outlined,
                        ).animate().fadeIn(delay: 900.ms),

                        SizedBox(height: compact ? 12 : 16),

                        // Texto informativo
                        Text(
                          'Este aplicativo é exclusivo para alunos.\nInstrutores devem usar a versão web.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.gray500,
                              ),
                        ).animate().fadeIn(delay: 1000.ms),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
