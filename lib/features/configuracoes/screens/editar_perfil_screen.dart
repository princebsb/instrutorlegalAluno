import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

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
  late TextEditingController _bairroController;
  late TextEditingController _cidadeController;
  late TextEditingController _estadoController;

  bool _isLoading = false;
  bool _hasChanges = false;
  bool _isLoadingCep = false;
  File? _selectedImage;
  final ImagePicker _imagePicker = ImagePicker();

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

    // Inicializa controllers vazios
    _nomeController = TextEditingController();
    _emailController = TextEditingController();
    _telefoneController = TextEditingController();
    _cpfController = TextEditingController();
    _dataNascimentoController = TextEditingController();
    _cepController = TextEditingController();
    _enderecoController = TextEditingController();
    _bairroController = TextEditingController();
    _cidadeController = TextEditingController();
    _estadoController = TextEditingController();

    // Listen for changes
    for (var controller in [
      _nomeController,
      _telefoneController,
      _cpfController,
      _dataNascimentoController,
      _cepController,
      _enderecoController,
      _bairroController,
      _cidadeController,
      _estadoController,
    ]) {
      controller.addListener(_onFieldChanged);
    }

    // Listener específico para buscar CEP
    _cepController.addListener(_onCepChanged);

    // Carrega dados atualizados do servidor
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);

    try {
      // Busca dados atualizados do servidor
      await context.read<AuthProvider>().refreshUser();
    } catch (e) {
      // Ignora erro, usa dados locais
    }

    final user = context.read<AuthProvider>().user;
    if (user != null) {
      _nomeController.text = user.nomeCompleto;
      _emailController.text = user.email;
      // Usar valores sem formatação para que as máscaras processem corretamente
      final telefoneRaw = user.telefone?.replaceAll(RegExp(r'\D'), '') ?? '';
      final cpfRaw = user.cpf?.replaceAll(RegExp(r'\D'), '') ?? '';
      final cepRaw = user.cep?.replaceAll(RegExp(r'\D'), '') ?? '';
      _telefoneController.text = _phoneMask.maskText(telefoneRaw);
      _cpfController.text = _cpfMask.maskText(cpfRaw);
      // Data já vem formatada como DD/MM/YYYY do backend
      final dataRaw = user.dataNascimento?.replaceAll(RegExp(r'\D'), '') ?? '';
      _dataNascimentoController.text = _dateMask.maskText(dataRaw);
      _cepController.text = _cepMask.maskText(cepRaw);
      _enderecoController.text = user.endereco ?? '';
      _bairroController.text = user.bairro ?? '';
      _cidadeController.text = user.cidade ?? '';
      _estadoController.text = user.estado ?? '';
    }

    setState(() {
      _isLoading = false;
      _hasChanges = false; // Reset após carregar
    });
  }

  void _onFieldChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }

  void _onCepChanged() {
    final cep = _cepController.text.replaceAll(RegExp(r'\D'), '');
    if (cep.length == 8) {
      _buscarCep(cep);
    }
  }

  bool _validarCpf(String cpf) {
    // Remove caracteres não numéricos
    cpf = cpf.replaceAll(RegExp(r'[^0-9]'), '');

    // Verifica se tem 11 dígitos
    if (cpf.length != 11) return false;

    // Verifica se todos os dígitos são iguais
    if (RegExp(r'^(\d)\1*$').hasMatch(cpf)) return false;

    // Calcula o primeiro dígito verificador
    int soma = 0;
    for (int i = 0; i < 9; i++) {
      soma += int.parse(cpf[i]) * (10 - i);
    }
    int resto = soma % 11;
    int digito1 = resto < 2 ? 0 : 11 - resto;

    // Verifica o primeiro dígito
    if (int.parse(cpf[9]) != digito1) return false;

    // Calcula o segundo dígito verificador
    soma = 0;
    for (int i = 0; i < 10; i++) {
      soma += int.parse(cpf[i]) * (11 - i);
    }
    resto = soma % 11;
    int digito2 = resto < 2 ? 0 : 11 - resto;

    // Verifica o segundo dígito
    if (int.parse(cpf[10]) != digito2) return false;

    return true;
  }

  Future<void> _buscarCep(String cep) async {
    if (_isLoadingCep) return;

    setState(() => _isLoadingCep = true);

    try {
      final response = await http.get(
        Uri.parse('https://brasilapi.com.br/api/cep/v1/$cep'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _enderecoController.text = data['street'] ?? '';
          _bairroController.text = data['neighborhood'] ?? '';
          _cidadeController.text = data['city'] ?? '';
          _estadoController.text = data['state'] ?? '';
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('CEP não encontrado'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao buscar CEP'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      setState(() => _isLoadingCep = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
          _hasChanges = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao selecionar imagem'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _cepController.removeListener(_onCepChanged);
    _nomeController.dispose();
    _emailController.dispose();
    _telefoneController.dispose();
    _cpfController.dispose();
    _dataNascimentoController.dispose();
    _cepController.dispose();
    _enderecoController.dispose();
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
      'telefone': _telefoneController.text.replaceAll(RegExp(r'\D'), ''),
      'cpf': _cpfController.text.replaceAll(RegExp(r'\D'), ''),
      'data_nascimento': _dataNascimentoController.text.trim(),
      'cep': _cepController.text.replaceAll(RegExp(r'\D'), ''),
      'endereco': _enderecoController.text.trim(),
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
                        child: ClipOval(
                          child: _selectedImage != null
                              ? Image.file(
                                  _selectedImage!,
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                )
                              : Center(
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
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: GestureDetector(
                          onTap: _pickImage,
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
                    final digits = value.replaceAll(RegExp(r'\D'), '');
                    if (digits.length < 11) {
                      return 'Telefone inválido';
                    }
                    return null;
                  },
                ).animate().fadeIn(delay: 200.ms),

                const SizedBox(height: 16),

                CustomTextField(
                  label: 'CPF',
                  controller: _cpfController,
                  prefixIcon: const Icon(Icons.badge_outlined),
                  keyboardType: TextInputType.number,
                  inputFormatters: [_cpfMask],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Informe o CPF';
                    }
                    final cpf = value.replaceAll(RegExp(r'\D'), '');
                    if (cpf.length < 11) {
                      return 'CPF incompleto';
                    }
                    if (!_validarCpf(cpf)) {
                      return 'CPF inválido';
                    }
                    return null;
                  },
                ).animate().fadeIn(delay: 250.ms),

                const SizedBox(height: 16),

                CustomTextField(
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
                ).animate().fadeIn(delay: 300.ms),

                const SizedBox(height: 32),

                // Address Section
                _buildSectionTitle('Endereço'),
                const SizedBox(height: 16),

                CustomTextField(
                  label: 'CEP (opcional)',
                  controller: _cepController,
                  prefixIcon: const Icon(Icons.location_on_outlined),
                  suffixIcon: _isLoadingCep
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                  keyboardType: TextInputType.number,
                  inputFormatters: [_cepMask],
                ).animate().fadeIn(delay: 300.ms),

                const SizedBox(height: 16),

                CustomTextField(
                  label: 'Estado (opcional)',
                  controller: _estadoController,
                ).animate().fadeIn(delay: 320.ms),

                const SizedBox(height: 16),

                CustomTextField(
                  label: 'Cidade (opcional)',
                  controller: _cidadeController,
                ).animate().fadeIn(delay: 350.ms),

                const SizedBox(height: 16),

                CustomTextField(
                  label: 'Bairro (opcional)',
                  controller: _bairroController,
                ).animate().fadeIn(delay: 400.ms),

                const SizedBox(height: 16),

                CustomTextField(
                  label: 'Endereço (opcional)',
                  controller: _enderecoController,
                ).animate().fadeIn(delay: 450.ms),

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
