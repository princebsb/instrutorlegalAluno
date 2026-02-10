import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/widgets/custom_button.dart';

class AlterarSenhaScreen extends StatefulWidget {
  const AlterarSenhaScreen({super.key});

  @override
  State<AlterarSenhaScreen> createState() => _AlterarSenhaScreenState();
}

class _AlterarSenhaScreenState extends State<AlterarSenhaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _senhaAtualController = TextEditingController();
  final _novaSenhaController = TextEditingController();
  final _confirmarSenhaController = TextEditingController();

  bool _isLoading = false;
  bool _obscureSenhaAtual = true;
  bool _obscureNovaSenha = true;
  bool _obscureConfirmarSenha = true;

  // Password strength
  double _passwordStrength = 0;
  String _passwordStrengthText = '';
  Color _passwordStrengthColor = AppColors.gray400;

  @override
  void initState() {
    super.initState();
    _novaSenhaController.addListener(_checkPasswordStrength);
  }

  @override
  void dispose() {
    _senhaAtualController.dispose();
    _novaSenhaController.dispose();
    _confirmarSenhaController.dispose();
    super.dispose();
  }

  void _checkPasswordStrength() {
    final password = _novaSenhaController.text;
    double strength = 0;

    if (password.isEmpty) {
      setState(() {
        _passwordStrength = 0;
        _passwordStrengthText = '';
        _passwordStrengthColor = AppColors.gray400;
      });
      return;
    }

    // Length check
    if (password.length >= 8) strength += 0.25;
    if (password.length >= 12) strength += 0.15;

    // Contains lowercase
    if (password.contains(RegExp(r'[a-z]'))) strength += 0.15;

    // Contains uppercase
    if (password.contains(RegExp(r'[A-Z]'))) strength += 0.15;

    // Contains numbers
    if (password.contains(RegExp(r'[0-9]'))) strength += 0.15;

    // Contains special characters
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) strength += 0.15;

    String text;
    Color color;

    if (strength < 0.3) {
      text = 'Muito fraca';
      color = AppColors.error;
    } else if (strength < 0.5) {
      text = 'Fraca';
      color = AppColors.warning;
    } else if (strength < 0.7) {
      text = 'Média';
      color = AppColors.secondary;
    } else if (strength < 0.9) {
      text = 'Forte';
      color = AppColors.success;
    } else {
      text = 'Muito forte';
      color = AppColors.success;
    }

    setState(() {
      _passwordStrength = strength.clamp(0, 1);
      _passwordStrengthText = text;
      _passwordStrengthColor = color;
    });
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.changePassword(
      _senhaAtualController.text,
      _novaSenhaController.text,
    );

    setState(() => _isLoading = false);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Senha alterada com sucesso!'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      } else if (authProvider.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authProvider.error!),
            backgroundColor: AppColors.error,
          ),
        );
        authProvider.clearError();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Alterar Senha'),
        backgroundColor: AppColors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header icon
              Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: AppColors.primarySurface,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_outline,
                    size: 48,
                    color: AppColors.primary,
                  ),
                ),
              ).animate().fadeIn(duration: 400.ms).scale(
                    begin: const Offset(0.8, 0.8),
                    end: const Offset(1, 1),
                  ),

              const SizedBox(height: 24),

              // Description
              Center(
                child: Text(
                  'Para sua segurança, crie uma senha forte com no mínimo 8 caracteres.',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ).animate().fadeIn(delay: 100.ms),

              const SizedBox(height: 32),

              // Current password
              CustomTextField(
                label: 'Senha Atual',
                controller: _senhaAtualController,
                obscureText: _obscureSenhaAtual,
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureSenhaAtual
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () {
                    setState(() => _obscureSenhaAtual = !_obscureSenhaAtual);
                  },
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Informe sua senha atual';
                  }
                  return null;
                },
              ).animate().fadeIn(delay: 200.ms),

              const SizedBox(height: 24),

              // New password
              CustomTextField(
                label: 'Nova Senha',
                controller: _novaSenhaController,
                obscureText: _obscureNovaSenha,
                prefixIcon: const Icon(Icons.lock_reset),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureNovaSenha
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () {
                    setState(() => _obscureNovaSenha = !_obscureNovaSenha);
                  },
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Informe a nova senha';
                  }
                  if (value.length < 8) {
                    return 'A senha deve ter no mínimo 8 caracteres';
                  }
                  if (value == _senhaAtualController.text) {
                    return 'A nova senha deve ser diferente da atual';
                  }
                  return null;
                },
              ).animate().fadeIn(delay: 300.ms),

              // Password strength indicator
              if (_novaSenhaController.text.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _passwordStrength,
                          backgroundColor: AppColors.gray200,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(_passwordStrengthColor),
                          minHeight: 6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _passwordStrengthText,
                      style: TextStyle(
                        color: _passwordStrengthColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ).animate().fadeIn(),
              ],

              const SizedBox(height: 24),

              // Confirm password
              CustomTextField(
                label: 'Confirmar Nova Senha',
                controller: _confirmarSenhaController,
                obscureText: _obscureConfirmarSenha,
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirmarSenha
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () {
                    setState(
                        () => _obscureConfirmarSenha = !_obscureConfirmarSenha);
                  },
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Confirme a nova senha';
                  }
                  if (value != _novaSenhaController.text) {
                    return 'As senhas não coincidem';
                  }
                  return null;
                },
              ).animate().fadeIn(delay: 400.ms),

              const SizedBox(height: 32),

              // Password tips
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.infoLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.info.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.tips_and_updates,
                            color: AppColors.info, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Dicas para uma senha forte:',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.info,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildPasswordTip('Mínimo de 8 caracteres'),
                    _buildPasswordTip('Letras maiúsculas e minúsculas'),
                    _buildPasswordTip('Números'),
                    _buildPasswordTip('Caracteres especiais (!@#\$%)'),
                  ],
                ),
              ).animate().fadeIn(delay: 500.ms),

              const SizedBox(height: 32),

              // Submit button
              CustomButton(
                text: 'Alterar Senha',
                onPressed: _handleSubmit,
                isLoading: _isLoading,
                icon: Icons.check,
              ).animate().fadeIn(delay: 600.ms),

              const SizedBox(height: 16),

              // Forgot password link
              Center(
                child: TextButton(
                  onPressed: () {
                    context.pop();
                    // Navigate to forgot password
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Se esqueceu sua senha atual, faça logout e use a opção "Esqueci minha senha"',
                        ),
                      ),
                    );
                  },
                  child: const Text('Esqueci minha senha atual'),
                ),
              ).animate().fadeIn(delay: 700.ms),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordTip(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline,
              size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
