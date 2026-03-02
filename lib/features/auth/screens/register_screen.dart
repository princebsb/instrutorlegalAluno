import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:http/http.dart' as http;

import '../../../core/theme/app_colors.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/routes/app_router.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/widgets/custom_button.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pageController = PageController();
  int _currentStep = 0;

  // Controllers
  final _nomeController = TextEditingController();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  final _confirmarSenhaController = TextEditingController();
  final _telefoneController = TextEditingController();
  final _cpfController = TextEditingController();
  final _dataNascimentoController = TextEditingController();
  final _cepController = TextEditingController();
  final _enderecoController = TextEditingController();
  final _cidadeController = TextEditingController();

  String? _estadoSelecionado;
  bool _possuiCnh = false;
  String _categoriaPretendida = 'B';
  bool _isLoading = false;
  bool _isLoadingCep = false;

  // Formatters
  final _telefoneFormatter = MaskTextInputFormatter(
    mask: '(##) #####-####',
    filter: {'#': RegExp(r'[0-9]')},
  );

  final _cpfFormatter = MaskTextInputFormatter(
    mask: '###.###.###-##',
    filter: {'#': RegExp(r'[0-9]')},
  );

  final _dataFormatter = MaskTextInputFormatter(
    mask: '##/##/####',
    filter: {'#': RegExp(r'[0-9]')},
  );

  final _cepFormatter = MaskTextInputFormatter(
    mask: '#####-###',
    filter: {'#': RegExp(r'[0-9]')},
  );

  final List<String> _estados = [
    'AC', 'AL', 'AP', 'AM', 'BA', 'CE', 'DF', 'ES', 'GO', 'MA',
    'MT', 'MS', 'MG', 'PA', 'PB', 'PR', 'PE', 'PI', 'RJ', 'RN',
    'RS', 'RO', 'RR', 'SC', 'SP', 'SE', 'TO'
  ];

  final List<String> _categorias = ['A', 'B', 'AB', 'C', 'D', 'E'];

  @override
  void initState() {
    super.initState();
    _cepController.addListener(_onCepChanged);
  }

  void _onCepChanged() {
    final cep = _cepFormatter.getUnmaskedText();
    if (cep.length == 8) {
      _buscarCep(cep);
    }
  }

  Future<void> _buscarCep(String cep) async {
    setState(() => _isLoadingCep = true);

    try {
      final response = await http.get(
        Uri.parse('https://viacep.com.br/ws/$cep/json/'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['erro'] != true) {
          setState(() {
            _enderecoController.text = '${data['logradouro'] ?? ''}, ${data['bairro'] ?? ''}';
            _cidadeController.text = data['localidade'] ?? '';
            _estadoSelecionado = data['uf'];
          });
        }
      }
    } catch (e) {
      // Silencioso - usuário pode preencher manualmente
    }

    setState(() => _isLoadingCep = false);
  }

  bool _validarCpf(String cpf) {
    // Remove caracteres não numéricos
    cpf = cpf.replaceAll(RegExp(r'[^0-9]'), '');

    if (cpf.length != 11) return false;

    // Verifica se todos os dígitos são iguais
    if (RegExp(r'^(\d)\1{10}$').hasMatch(cpf)) return false;

    // Validação do primeiro dígito verificador
    int soma = 0;
    for (int i = 0; i < 9; i++) {
      soma += int.parse(cpf[i]) * (10 - i);
    }
    int resto = soma % 11;
    int digito1 = resto < 2 ? 0 : 11 - resto;

    if (int.parse(cpf[9]) != digito1) return false;

    // Validação do segundo dígito verificador
    soma = 0;
    for (int i = 0; i < 10; i++) {
      soma += int.parse(cpf[i]) * (11 - i);
    }
    resto = soma % 11;
    int digito2 = resto < 2 ? 0 : 11 - resto;

    if (int.parse(cpf[10]) != digito2) return false;

    return true;
  }

  @override
  void dispose() {
    _cepController.removeListener(_onCepChanged);
    _pageController.dispose();
    _nomeController.dispose();
    _emailController.dispose();
    _senhaController.dispose();
    _confirmarSenhaController.dispose();
    _telefoneController.dispose();
    _cpfController.dispose();
    _dataNascimentoController.dispose();
    _cepController.dispose();
    _enderecoController.dispose();
    _cidadeController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_validateCurrentStep()) {
      if (_currentStep < 2) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
        setState(() => _currentStep++);
      } else {
        _handleRegister();
      }
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep--);
    } else {
      context.pop();
    }
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0:
        if (_nomeController.text.isEmpty) {
          _showError('Informe seu nome completo');
          return false;
        }
        if (_emailController.text.isEmpty ||
            !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                .hasMatch(_emailController.text)) {
          _showError('Informe um e-mail válido');
          return false;
        }
        if (_senhaController.text.length < 6) {
          _showError('A senha deve ter pelo menos 6 caracteres');
          return false;
        }
        if (_senhaController.text != _confirmarSenhaController.text) {
          _showError('As senhas não coincidem');
          return false;
        }
        return true;

      case 1:
        // Telefone, CPF e data de nascimento são opcionais
        // Validar formato apenas se preenchidos
        if (_telefoneFormatter.getUnmaskedText().isNotEmpty &&
            _telefoneFormatter.getUnmaskedText().length < 11) {
          _showError('Telefone incompleto. Preencha corretamente ou deixe em branco');
          return false;
        }
        final cpf = _cpfFormatter.getUnmaskedText();
        if (cpf.isNotEmpty) {
          if (cpf.length < 11) {
            _showError('CPF incompleto. Preencha corretamente ou deixe em branco');
            return false;
          }
          if (!_validarCpf(cpf)) {
            _showError('CPF inválido. Verifique os dígitos');
            return false;
          }
        }
        if (_dataNascimentoController.text.isNotEmpty &&
            _dataNascimentoController.text.length < 10) {
          _showError('Data incompleta. Preencha corretamente ou deixe em branco');
          return false;
        }
        return true;

      case 2:
        if (_cepFormatter.getUnmaskedText().length < 8) {
          _showError('Informe um CEP válido');
          return false;
        }
        if (_cidadeController.text.isEmpty) {
          _showError('Informe sua cidade');
          return false;
        }
        if (_estadoSelecionado == null) {
          _showError('Selecione seu estado');
          return false;
        }
        return true;

      default:
        return true;
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }

  String? _formatDataNascimento() {
    if (_dataNascimentoController.text.isEmpty) {
      return null;
    }
    final parts = _dataNascimentoController.text.split('/');
    if (parts.length == 3) {
      return '${parts[2]}-${parts[1]}-${parts[0]}';
    }
    return _dataNascimentoController.text;
  }

  Future<void> _handleRegister() async {
    setState(() => _isLoading = true);

    final authProvider = context.read<AuthProvider>();
    final telefone = _telefoneFormatter.getUnmaskedText();
    final cpf = _cpfFormatter.getUnmaskedText();

    final success = await authProvider.register(
      nomeCompleto: _nomeController.text.trim(),
      email: _emailController.text.trim(),
      senha: _senhaController.text,
      telefone: telefone.isNotEmpty ? telefone : null,
      dataNascimento: _formatDataNascimento(),
      cpf: cpf.isNotEmpty ? cpf : null,
      cep: _cepFormatter.getUnmaskedText(),
      endereco: _enderecoController.text.trim(),
      cidade: _cidadeController.text.trim(),
      estado: _estadoSelecionado!,
      possuiCnh: _possuiCnh,
      categoriaPretendida: _categoriaPretendida,
    );

    setState(() => _isLoading = false);

    if (success && mounted) {
      context.go(AppRoutes.dashboard);
    } else if (mounted && authProvider.error != null) {
      _showError(authProvider.error!);
      authProvider.clearError();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: _previousStep,
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            'Criar Conta',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Passo ${_currentStep + 1} de 3',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 48), // Balance
                  ],
                ),
              ),

              // Progress indicator
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: List.generate(3, (index) {
                    return Expanded(
                      child: Container(
                        height: 4,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: index <= _currentStep
                              ? AppColors.primary
                              : AppColors.gray300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    );
                  }),
                ),
              ),

              const SizedBox(height: 24),

              // Steps
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildStep1(),
                    _buildStep2(),
                    _buildStep3(),
                  ],
                ),
              ),

              // Bottom button
              Padding(
                padding: const EdgeInsets.all(24),
                child: CustomButton(
                  text: _currentStep == 2 ? 'Criar Conta' : 'Continuar',
                  onPressed: _nextStep,
                  isLoading: _isLoading,
                  icon: _currentStep == 2 ? Icons.check : Icons.arrow_forward,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dados de Acesso',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Informe seus dados para criar sua conta',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),

          CustomTextField(
            label: 'Nome Completo',
            hint: 'Seu nome completo',
            controller: _nomeController,
            textInputAction: TextInputAction.next,
            prefixIcon: const Icon(Icons.person_outline),
          ),

          const SizedBox(height: 16),

          CustomTextField(
            label: 'E-mail',
            hint: 'seu@email.com',
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            prefixIcon: const Icon(Icons.email_outlined),
          ),

          const SizedBox(height: 16),

          CustomTextField(
            label: 'Senha',
            hint: 'Mínimo 6 caracteres',
            controller: _senhaController,
            obscureText: true,
            textInputAction: TextInputAction.next,
            prefixIcon: const Icon(Icons.lock_outline),
          ),

          const SizedBox(height: 16),

          CustomTextField(
            label: 'Confirmar Senha',
            hint: 'Digite a senha novamente',
            controller: _confirmarSenhaController,
            obscureText: true,
            textInputAction: TextInputAction.done,
            prefixIcon: const Icon(Icons.lock_outline),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dados Pessoais',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Precisamos de algumas informações pessoais',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),

          CustomTextField(
            label: 'Telefone (opcional)',
            hint: '(00) 00000-0000',
            controller: _telefoneController,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            prefixIcon: const Icon(Icons.phone_outlined),
            inputFormatters: [_telefoneFormatter],
          ),

          const SizedBox(height: 16),

          CustomTextField(
            label: 'CPF (opcional)',
            hint: '000.000.000-00',
            controller: _cpfController,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            prefixIcon: const Icon(Icons.badge_outlined),
            inputFormatters: [_cpfFormatter],
          ),

          const SizedBox(height: 16),

          CustomTextField(
            label: 'Data de Nascimento (opcional)',
            hint: 'DD/MM/AAAA',
            controller: _dataNascimentoController,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            prefixIcon: const Icon(Icons.calendar_today_outlined),
            inputFormatters: [_dataFormatter],
          ),
        ],
      ),
    );
  }

  Widget _buildStep3() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Endereço e Categoria',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Onde você mora e qual categoria pretende tirar',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),

          CustomTextField(
            label: 'CEP',
            hint: '00000-000',
            controller: _cepController,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
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
            inputFormatters: [_cepFormatter],
          ),

          const SizedBox(height: 16),

          CustomTextField(
            label: 'Endereço (opcional)',
            hint: 'Rua, número, bairro',
            controller: _enderecoController,
            textInputAction: TextInputAction.next,
            prefixIcon: const Icon(Icons.home_outlined),
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                flex: 2,
                child: CustomTextField(
                  label: 'Cidade',
                  hint: 'Sua cidade',
                  controller: _cidadeController,
                  textInputAction: TextInputAction.next,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CustomDropdownField<String>(
                  label: 'Estado',
                  hint: 'UF',
                  value: _estadoSelecionado,
                  items: _estados
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (value) {
                    setState(() => _estadoSelecionado = value);
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Possui CNH
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.gray200),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Já possui CNH?',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Marque se você já tem carteira de habilitação',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _possuiCnh,
                  onChanged: (value) {
                    setState(() => _possuiCnh = value);
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          CustomDropdownField<String>(
            label: 'Categoria Pretendida',
            hint: 'Selecione a categoria',
            value: _categoriaPretendida,
            prefixIcon: const Icon(Icons.directions_car_outlined),
            items: _categorias
                .map((e) => DropdownMenuItem(
                      value: e,
                      child: Text('Categoria $e'),
                    ))
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _categoriaPretendida = value);
              }
            },
          ),
        ],
      ),
    );
  }
}
