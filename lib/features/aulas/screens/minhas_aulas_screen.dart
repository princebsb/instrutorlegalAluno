import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/routes/app_router.dart';
import '../../../shared/widgets/bottom_nav_bar.dart';

class MinhasAulasScreen extends StatefulWidget {
  final int initialTab;

  const MinhasAulasScreen({super.key, this.initialTab = 0});

  @override
  State<MinhasAulasScreen> createState() => _MinhasAulasScreenState();
}

class _MinhasAulasScreenState extends State<MinhasAulasScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _api = ApiService();
  bool _isLoading = true;

  List<Map<String, dynamic>> _agendadas = [];
  List<Map<String, dynamic>> _realizadas = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 1),
    );
    _loadAulas();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAulas() async {
    setState(() => _isLoading = true);
    final user = context.read<AuthProvider>().user;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final response = await _api.get(ApiEndpoints.minhasAulas(user.id));
      if (response != null) {
        setState(() {
          _agendadas = List<Map<String, dynamic>>.from(
            response['agendadas'] ?? [],
          );
          _realizadas = List<Map<String, dynamic>>.from(
            response['realizadas'] ?? [],
          );
        });
      }
    } catch (e) {
      // Dados mock para fallback
      setState(() {
        _agendadas = [];
        _realizadas = [];
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Minhas Aulas'),
        backgroundColor: AppColors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.gray500,
          indicatorColor: AppColors.primary,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.calendar_today, size: 16),
                  const SizedBox(width: 6),
                  const Text('Agendadas'),
                  if (_agendadas.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.info,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_agendadas.length}',
                        style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_outline, size: 16),
                  const SizedBox(width: 6),
                  const Text('Realizadas'),
                  if (_realizadas.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_realizadas.length}',
                        style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildAgendadasTab(),
                _buildRealizadasTab(),
              ],
            ),
      bottomNavigationBar: const BottomNavBar(currentIndex: 1),
    );
  }

  Widget _buildAgendadasTab() {
    if (_agendadas.isEmpty) {
      return _buildEmptyState(
        icon: Icons.calendar_today_outlined,
        titulo: 'Nenhuma aula agendada',
        subtitulo: 'Agende sua próxima aula com um instrutor!',
        botaoTexto: 'Agendar Aula',
        onBotao: () => context.push(AppRoutes.agendarAula),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAulas,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _agendadas.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          return _buildAulaAgendadaCard(_agendadas[index]);
        },
      ),
    );
  }

  Widget _buildRealizadasTab() {
    if (_realizadas.isEmpty) {
      return _buildEmptyState(
        icon: Icons.history,
        titulo: 'Nenhuma aula realizada',
        subtitulo: 'Suas aulas concluídas aparecerão aqui.',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAulas,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _realizadas.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          return _buildAulaRealizadaCard(_realizadas[index]);
        },
      ),
    );
  }

  Widget _buildAulaAgendadaCard(Map<String, dynamic> aula) {
    final dataHora =
        DateTime.tryParse(aula['data_hora'] ?? '') ?? DateTime.now();
    final instrutorNome = aula['instrutor_nome'] ?? 'Instrutor';
    final local = aula['local_partida'] ?? '';
    final status = aula['status'] ?? 'Agendada';
    final categoria = aula['categoria'] ?? 'B';

    final isHoje = DateUtils.isSameDay(dataHora, DateTime.now());
    final isAmanha = DateUtils.isSameDay(
      dataHora,
      DateTime.now().add(const Duration(days: 1)),
    );

    String dataLabel;
    if (isHoje) {
      dataLabel = 'Hoje';
    } else if (isAmanha) {
      dataLabel = 'Amanhã';
    } else {
      dataLabel = DateFormat('dd/MM').format(dataHora);
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.cardShadow,
        border: Border(
          left: BorderSide(
            color: isHoje ? AppColors.warning : AppColors.info,
            width: 4,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Data box
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: isHoje ? AppColors.warningLight : AppColors.infoLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    dataLabel,
                    style: TextStyle(
                      fontSize: isHoje || isAmanha ? 13 : 15,
                      fontWeight: FontWeight.bold,
                      color: isHoje ? AppColors.warning : AppColors.info,
                    ),
                  ),
                  Text(
                    DateFormat('HH:mm').format(dataHora),
                    style: TextStyle(
                      fontSize: 12,
                      color: isHoje ? AppColors.warning : AppColors.info,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    instrutorNome,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (local.isNotEmpty)
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: AppColors.textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            local,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primarySurface,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Cat. $categoria',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(status).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(
                            fontSize: 11,
                            color: _getStatusColor(status),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AppColors.gray400,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAulaRealizadaCard(Map<String, dynamic> aula) {
    final dataHora =
        DateTime.tryParse(aula['data_hora'] ?? '') ?? DateTime.now();
    final instrutorNome = aula['instrutor_nome'] ?? 'Instrutor';
    final duracao = aula['duracao_minutos'] ?? 50;
    final nota = (aula['nota'] as num?)?.toDouble() ?? 0;
    final categoria = aula['categoria'] ?? 'B';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.cardShadow,
        border: const Border(
          left: BorderSide(
            color: AppColors.success,
            width: 4,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Check icon
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: AppColors.successLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.check,
                color: AppColors.success,
              ),
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('dd/MM/yyyy • HH:mm').format(dataHora),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$instrutorNome • ${duracao}min',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Cat. $categoria',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Nota
            if (nota > 0)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.warningLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.star, color: AppColors.warning, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      nota.toStringAsFixed(1),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String titulo,
    required String subtitulo,
    String? botaoTexto,
    VoidCallback? onBotao,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 80, color: AppColors.gray300),
            const SizedBox(height: 24),
            Text(
              titulo,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.textSecondary,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitulo,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (botaoTexto != null && onBotao != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onBotao,
                icon: const Icon(Icons.add),
                label: Text(botaoTexto),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'agendada':
      case 'confirmada':
        return AppColors.info;
      case 'realizada':
      case 'concluída':
        return AppColors.success;
      case 'cancelada':
        return AppColors.error;
      case 'pendente':
        return AppColors.warning;
      default:
        return AppColors.gray500;
    }
  }
}
