import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/routes/app_router.dart';
import '../../../shared/widgets/bottom_nav_bar.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/widgets/custom_button.dart';

class AgendarAulaScreen extends StatefulWidget {
  final String? instrutorId;
  final String? instrutorNome;

  const AgendarAulaScreen({
    super.key,
    this.instrutorId,
    this.instrutorNome,
  });

  @override
  State<AgendarAulaScreen> createState() => _AgendarAulaScreenState();
}

class _AgendarAulaScreenState extends State<AgendarAulaScreen> {
  final _api = ApiService();
  final _localController = TextEditingController();
  final _observacoesController = TextEditingController();

  Map<String, dynamic>? _instrutorSelecionado;
  DateTime? _dataSelecionada;
  TimeOfDay? _horarioSelecionado;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.instrutorId != null) {
      _loadInstrutor(widget.instrutorId!);
    }
  }

  @override
  void dispose() {
    _localController.dispose();
    _observacoesController.dispose();
    super.dispose();
  }

  Future<void> _loadInstrutor(String id) async {
    try {
      final response = await _api.get(ApiEndpoints.instrutor(id), requiresAuth: false);
      setState(() {
        _instrutorSelecionado = response;
      });
    } catch (e) {
      // Fallback
      setState(() {
        _instrutorSelecionado = {
          'id': id,
          'nome': widget.instrutorNome ?? 'Instrutor',
          'valor_aula': 120.0,
        };
      });
    }
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      locale: const Locale('pt', 'BR'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: AppColors.white,
              surface: AppColors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (date != null) {
      setState(() => _dataSelecionada = date);
    }
  }

  Future<void> _selectTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: AppColors.white,
              surface: AppColors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (time != null) {
      setState(() => _horarioSelecionado = time);
    }
  }

  bool get _canSubmit =>
      _instrutorSelecionado != null &&
      _dataSelecionada != null &&
      _horarioSelecionado != null &&
      _localController.text.isNotEmpty;

  Future<void> _handleAgendar() async {
    if (!_canSubmit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preencha todos os campos obrigatórios'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final user = context.read<AuthProvider>().user;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final dataHora = DateTime(
        _dataSelecionada!.year,
        _dataSelecionada!.month,
        _dataSelecionada!.day,
        _horarioSelecionado!.hour,
        _horarioSelecionado!.minute,
      );

      await _api.post(
        ApiEndpoints.aulas,
        body: {
          'aluno_id': user.id,
          'instrutor_id': _instrutorSelecionado!['id'],
          'data_hora': dataHora.toIso8601String(),
          'duracao_minutos': 50,
          'categoria': user.categoriaPretendida ?? 'B',
          'local_partida': _localController.text.trim(),
          'observacoes': _observacoesController.text.trim().isNotEmpty
              ? _observacoesController.text.trim()
              : null,
          'valor': _instrutorSelecionado!['valor_aula'] ?? 120.0,
          'forma_pagamento': null,
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Aula agendada com sucesso!'),
            backgroundColor: AppColors.success,
          ),
        );
        context.go(AppRoutes.dashboard);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao agendar aula: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Agendar Aula'),
        backgroundColor: AppColors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tipo de aula
            _buildSectionTitle('Tipo de Aula'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildTypeCard(
                    icon: Icons.directions_car,
                    title: 'Aula Prática',
                    subtitle: 'Direção veicular',
                    isSelected: true,
                    onTap: () {},
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTypeCard(
                    icon: Icons.menu_book,
                    title: 'Aula Teórica',
                    subtitle: 'Em breve',
                    isSelected: false,
                    enabled: false,
                    onTap: () {},
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Instrutor
            _buildSectionTitle('Instrutor'),
            const SizedBox(height: 12),
            _buildInstrutorCard(),

            const SizedBox(height: 24),

            // Data e Hora
            _buildSectionTitle('Data e Horário'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildDateTimeCard(
                    icon: Icons.calendar_today,
                    label: 'Data',
                    value: _dataSelecionada != null
                        ? DateFormat('dd/MM/yyyy').format(_dataSelecionada!)
                        : 'Selecionar',
                    onTap: _selectDate,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDateTimeCard(
                    icon: Icons.access_time,
                    label: 'Horário',
                    value: _horarioSelecionado != null
                        ? '${_horarioSelecionado!.hour.toString().padLeft(2, '0')}:${_horarioSelecionado!.minute.toString().padLeft(2, '0')}'
                        : 'Selecionar',
                    onTap: _selectTime,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Local de partida
            _buildSectionTitle('Local de Partida *'),
            const SizedBox(height: 12),
            CustomTextField(
              controller: _localController,
              hint: 'Ex: Rua das Flores, 123 - Centro',
              prefixIcon: const Icon(Icons.location_on_outlined),
              maxLines: 2,
            ),

            const SizedBox(height: 24),

            // Observações
            _buildSectionTitle('Observações (opcional)'),
            const SizedBox(height: 12),
            CustomTextField(
              controller: _observacoesController,
              hint: 'Alguma informação adicional...',
              prefixIcon: const Icon(Icons.notes_outlined),
              maxLines: 3,
            ),

            const SizedBox(height: 32),

            // Resumo
            if (_instrutorSelecionado != null) _buildResumo(),

            const SizedBox(height: 24),

            // Botão Agendar
            CustomButton(
              text: 'Agendar Aula',
              onPressed: _canSubmit ? _handleAgendar : null,
              isLoading: _isLoading,
              icon: Icons.check,
            ),

            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomNavigationBar: const BottomNavBar(currentIndex: 1),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
    );
  }

  Widget _buildTypeCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isSelected,
    bool enabled = true,
    required VoidCallback onTap,
  }) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: Material(
        color: isSelected ? AppColors.primarySurface : AppColors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.gray200,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  icon,
                  size: 32,
                  color: isSelected ? AppColors.primary : AppColors.gray500,
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color:
                        isSelected ? AppColors.primary : AppColors.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInstrutorCard() {
    if (_instrutorSelecionado == null) {
      return Material(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () async {
            final result = await context.push<Map<String, dynamic>>(
              AppRoutes.buscarInstrutor,
            );
            if (result != null) {
              setState(() => _instrutorSelecionado = result);
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.gray200),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_add_outlined, color: AppColors.primary),
                SizedBox(width: 12),
                Text(
                  'Selecionar Instrutor',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: const BoxDecoration(
              color: AppColors.primarySurface,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                (_instrutorSelecionado!['nome'] ?? 'I')[0].toUpperCase(),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _instrutorSelecionado!['nome'] ?? 'Instrutor',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.star, color: AppColors.warning, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '${_instrutorSelecionado!['avaliacao'] ?? 5.0}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'R\$ ${(_instrutorSelecionado!['valor_aula'] ?? 120.0).toStringAsFixed(0)}/aula',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            onPressed: () async {
              final result = await context.push<Map<String, dynamic>>(
                AppRoutes.buscarInstrutor,
              );
              if (result != null) {
                setState(() => _instrutorSelecionado = result);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDateTimeCard({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.gray200),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      value,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.gray400),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResumo() {
    final valor = _instrutorSelecionado!['valor_aula'] ?? 120.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Resumo do Agendamento',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
          ),
          const SizedBox(height: 16),
          _buildResumoItem('Instrutor', _instrutorSelecionado!['nome'] ?? '-'),
          _buildResumoItem(
            'Data',
            _dataSelecionada != null
                ? DateFormat('dd/MM/yyyy').format(_dataSelecionada!)
                : '-',
          ),
          _buildResumoItem(
            'Horário',
            _horarioSelecionado != null
                ? '${_horarioSelecionado!.hour.toString().padLeft(2, '0')}:${_horarioSelecionado!.minute.toString().padLeft(2, '0')}'
                : '-',
          ),
          _buildResumoItem('Duração', '50 minutos'),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Valor Total',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              Text(
                'R\$ ${(valor as num).toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResumoItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
