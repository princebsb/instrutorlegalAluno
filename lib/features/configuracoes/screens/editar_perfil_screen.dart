import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/widgets/custom_button.dart';

class EditarPerfilScreen extends StatefulWidget {
  const EditarPerfilScreen({super.key});

  @override
  State<EditarPerfilScreen> createState() => _EditarPerfilScreenState();
}

class _EditarPerfilScreenState extends State<EditarPerfilScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nomeController;
  late TextEditingController _emailController;
  late TextEditingController _telefoneController;
  late TextEditingController _cpfController;
  late TextEditingController _dataNascimentoController;
  late TextEditingController _cepController;
  late TextEditingController _enderecoController;
  late TextEditingController _numeroController;
  late TextEditingController _complementoController;
  late TextEditingController _bairroController;
  late TextEditingController _cidadeController;
  late TextEditingController _estadoController;

  bool _isLoading = false;
  bool _hasChanges = false;

  final _phoneMask = MaskTextInputFormatter(
    mask: '(##) #####-####',
    filter: {"#": RegExp(r'[0-9]')},
  );

  final _cpfMask = MaskTextInputFormatter(
    mask: '###.###.###-##',
    filter: {"#": RegExp(r'[0-9]')},
  );

  final _dateMask = MaskTextInputFormatter(
    mask: '##/##/####',
    filter: {"#": RegExp(r'[0-9]')},
  );

  final _cepMask = MaskTextInputFormatter(
    mask: '#####-###',
    filter: {"#": RegExp(r'[0-9]')},
  );

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;

    _nomeController = TextEditingController(text: user?.nomeCompleto ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _telefoneController = TextEditingController(text: user?.telefone ?? '');
    _cpfController = TextEditingController(text: user?.cpf ?? '');
    _dataNascimentoController =
        TextEditingController(text: user?.dataNascimento ?? '');
    _cepController = TextEditingController(text: user?.cep ?? '');
    _enderecoController = TextEditingController(text: user?.endereco ?? '');
    _numeroController = TextEditingController(text: user?.numero ?? '');
    _complementoController =
        TextEditingController(text: user?.complemento ?? '');
    _bairroController = TextEditingController(text: user?.bairro ?? '');
    _cidadeController = TextEditingController(text: user?.cidade ?? '');
    _estadoController = TextEditingController(text: user?.estado ?? '');

    // Listen for changes
    for (var controller in [
      _nomeController,
      _telefoneController,
      _cpfController,
      _dataNascimentoController,
      _cepController,
      _enderecoController,
      _numeroController,
      _complementoController,
      _bairroController,
      _cidadeController,
      _estadoController,
    ]) {
      controller.addListener(_onFieldChanged);
    }
  }

  void _onFieldChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _emailController.dispose();
    _telefoneController.dispose();
    _cpfController.dispose();
    _dataNascimentoController.dispose();
    _cepController.dispose();
    _enderecoController.dispose();
    _numeroController.dispose();
    _complementoController.dispose();
    _bairroController.dispose();
    _cidadeController.dispose();
    _estadoController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.updateProfile({
      'nome_completo': _nomeController.text.trim(),
      'telefone': _phoneMask.getUnmaskedText(),
      'cpf': _cpfMask.getUnmaskedText(),
      'data_nascimento': _dataNascimentoController.text.trim(),
      'cep': _cepMask.getUnmaskedText(),
      'endereco': _enderecoController.text.trim(),
      'numero': _numeroController.text.trim(),
      'complemento': _complementoController.text.trim(),
      'bairro': _bairroController.text.trim(),
      'cidade': _cidadeController.text.trim(),
      'estado': _estadoController.text.trim(),
    });

    setState(() => _isLoading = false);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Perfil atualizado com sucesso!'),
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

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Descartar alterações?'),
        content: const Text(
          'Você tem alterações não salvas. Deseja descartá-las?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          context.pop();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Editar Perfil'),
          backgroundColor: AppColors.white,
          elevation: 0,
          actions: [
            if (_hasChanges)
              TextButton(
                onPressed: _isLoading ? null : _handleSave,
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Salvar'),
              ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar section
                Center(
                  child: Stack(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: AppColors.primarySurface,
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: AppColors.primary, width: 3),
                        ),
                        child: Center(
                          child: Text(
                            context.watch<AuthProvider>().user?.iniciais ?? 'U',
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: GestureDetector(
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Alterar foto em breve!')),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              color: AppColors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 400.ms),

                const SizedBox(height: 32),

                // Personal Data Section
                _buildSectionTitle('Dados Pessoais'),
                const SizedBox(height: 16),

                CustomTextField(
                  label: 'Nome Completo',
                  controller: _nomeController,
                  prefixIcon: const Icon(Icons.person_outline),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Informe seu nome';
                    }
                    if (value.trim().split(' ').length < 2) {
                      return 'Informe nome e sobrenome';
                    }
                    return null;
                  },
                ).animate().fadeIn(delay: 100.ms),

                const SizedBox(height: 16),

                CustomTextField(
                  label: 'E-mail',
                  controller: _emailController,
                  prefixIcon: const Icon(Icons.email_outlined),
                  enabled: false,
                  hint: 'O e-mail não pode ser alterado',
                ).animate().fadeIn(delay: 150.ms),

                const SizedBox(height: 16),

                CustomTextField(
                  label: 'Telefone',
                  controller: _telefoneController,
                  prefixIcon: const Icon(Icons.phone_outlined),
                  keyboardType: TextInputType.phone,
                  inputFormatters: [_phoneMask],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Informe seu telefone';
                    }
                    if (_phoneMask.getUnmaskedText().length < 11) {
                      return 'Telefone inválido';
                    }
                    return null;
                  },
                ).animate().fadeIn(delay: 200.ms),

                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        label: 'CPF',
                        controller: _cpfController,
                        prefixIcon: const Icon(Icons.badge_outlined),
                        keyboardType: TextInputType.number,
                        inputFormatters: [_cpfMask],
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Informe o CPF';
                          }
                          if (_cpfMask.getUnmaskedText().length < 11) {
                            return 'CPF inválido';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: CustomTextField(
                        label: 'Data de Nascimento',
                        controller: _dataNascimentoController,
                        prefixIcon: const Icon(Icons.cake_outlined),
                        keyboardType: TextInputType.number,
                        inputFormatters: [_dateMask],
                        hint: 'DD/MM/AAAA',
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Informe a data';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ).animate().fadeIn(delay: 250.ms),

                const SizedBox(height: 32),

                // Address Section
                _buildSectionTitle('Endereço'),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: CustomTextField(
                        label: 'CEP',
                        controller: _cepController,
                        prefixIcon: const Icon(Icons.location_on_outlined),
                        keyboardType: TextInputType.number,
                        inputFormatters: [_cepMask],
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Informe o CEP';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 3,
                      child: CustomTextField(
                        label: 'Estado',
                        controller: _estadoController,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Informe o estado';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ).animate().fadeIn(delay: 300.ms),

                const SizedBox(height: 16),

                CustomTextField(
                  label: 'Cidade',
                  controller: _cidadeController,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Informe a cidade';
                    }
                    return null;
                  },
                ).animate().fadeIn(delay: 350.ms),

                const SizedBox(height: 16),

                CustomTextField(
                  label: 'Bairro',
                  controller: _bairroController,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Informe o bairro';
                    }
                    return null;
                  },
                ).animate().fadeIn(delay: 400.ms),

                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: CustomTextField(
                        label: 'Endereço',
                        controller: _enderecoController,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Informe o endereço';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: CustomTextField(
                        label: 'Nº',
                        controller: _numeroController,
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Nº';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ).animate().fadeIn(delay: 450.ms),

                const SizedBox(height: 16),

                CustomTextField(
                  label: 'Complemento',
                  controller: _complementoController,
                  hint: 'Apartamento, bloco, etc. (opcional)',
                ).animate().fadeIn(delay: 500.ms),

                const SizedBox(height: 32),

                // Save button
                CustomButton(
                  text: 'Salvar Alterações',
                  onPressed: _handleSave,
                  isLoading: _isLoading,
                  icon: Icons.save_outlined,
                ).animate().fadeIn(delay: 550.ms),

                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
    );
  }
}
