import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:percent_indicator/percent_indicator.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/bottom_nav_bar.dart';

class ProgressoScreen extends StatefulWidget {
  const ProgressoScreen({super.key});

  @override
  State<ProgressoScreen> createState() => _ProgressoScreenState();
}

class _ProgressoScreenState extends State<ProgressoScreen> {
  final _api = ApiService();
  bool _isLoading = true;

  Map<String, dynamic> _estatisticas = {
    'aulasRealizadas': 0,
    'totalAulas': 30,
    'horasPraticas': 0,
    'mediaAvaliacoes': 0.0,
    'progresso': 0,
  };

  List<Map<String, dynamic>> _evolucaoSemanal = [];
  List<Map<String, dynamic>> _ultimasAulas = [];

  @override
  void initState() {
    super.initState();
    _loadProgresso();
  }

  Future<void> _loadProgresso() async {
    setState(() => _isLoading = true);

    final user = context.read<AuthProvider>().user;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final response = await _api.get(ApiEndpoints.progresso(user.id));

      if (response != null) {
        setState(() {
          if (response['estatisticas'] != null) {
            _estatisticas = Map<String, dynamic>.from(response['estatisticas']);
          }
          if (response['evolucaoSemanal'] != null) {
            _evolucaoSemanal = List<Map<String, dynamic>>.from(
              response['evolucaoSemanal']
                  .map((a) => Map<String, dynamic>.from(a)),
            );
          }
          if (response['ultimasAulas'] != null) {
            _ultimasAulas = List<Map<String, dynamic>>.from(
              response['ultimasAulas'].map((a) => Map<String, dynamic>.from(a)),
            );
          }
        });
      }
    } catch (e) {
      // Usar dados mock
      setState(() {
        _evolucaoSemanal = [
          {'semana': 'Sem 1', 'aulas': 2},
          {'semana': 'Sem 2', 'aulas': 3},
          {'semana': 'Sem 3', 'aulas': 1},
          {'semana': 'Sem 4', 'aulas': 4},
        ];
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
        title: const Text('Meu Progresso'),
        backgroundColor: AppColors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: RefreshIndicator(
        onRefresh: _loadProgresso,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stats Cards
                    _buildStatsGrid(),

                    const SizedBox(height: 24),

                    // Progresso Circular
                    _buildProgressCard(),

                    const SizedBox(height: 24),

                    // Evolução Semanal
                    _buildEvolucaoSemanal(),

                    const SizedBox(height: 24),

                    // Últimas Aulas
                    _buildUltimasAulas(),

                    const SizedBox(height: 24),

                    // Metas
                    _buildMetasCard(),

                    const SizedBox(height: 100),
                  ],
                ),
              ),
      ),
      bottomNavigationBar: const BottomNavBar(currentIndex: 2),
    );
  }

  Widget _buildStatsGrid() {
    final realizadas = _estatisticas['aulasRealizadas'] ?? 0;
    final total = _estatisticas['totalAulas'] ?? 30;
    final horas = _estatisticas['horasPraticas'] ?? 0;
    final media = (_estatisticas['mediaAvaliacoes'] ?? 0.0) as num;

    final stats = [
      {
        'icon': Icons.check_circle_outline,
        'label': 'Realizadas',
        'value': '$realizadas/$total',
        'color': AppColors.success,
      },
      {
        'icon': Icons.timer_outlined,
        'label': 'Horas',
        'value': '${horas}h',
        'color': AppColors.info,
      },
      {
        'icon': Icons.star_outline,
        'label': 'Média',
        'value': media.toStringAsFixed(1),
        'color': AppColors.warning,
      },
      {
        'icon': Icons.trending_up,
        'label': 'Progresso',
        'value': '${_estatisticas['progresso'] ?? 0}%',
        'color': AppColors.primary,
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.5,
      ),
      itemCount: stats.length,
      itemBuilder: (context, index) {
        final stat = stats[index];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppColors.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (stat['color'] as Color).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  stat['icon'] as IconData,
                  color: stat['color'] as Color,
                  size: 20,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stat['value'] as String,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    stat['label'] as String,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProgressCard() {
    final progresso = (_estatisticas['progresso'] ?? 0) as num;
    final realizadas = _estatisticas['aulasRealizadas'] ?? 0;
    final total = _estatisticas['totalAulas'] ?? 30;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        children: [
          Text(
            'Progresso Geral',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 24),
          CircularPercentIndicator(
            radius: 80,
            lineWidth: 12,
            percent: (progresso / 100).clamp(0.0, 1.0).toDouble(),
            center: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${progresso.toInt()}%',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  'Completo',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            progressColor: AppColors.primary,
            backgroundColor: AppColors.gray200,
            circularStrokeCap: CircularStrokeCap.round,
            animation: true,
            animationDuration: 1000,
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildProgressStat(
                label: 'Realizadas',
                value: realizadas.toString(),
                color: AppColors.success,
              ),
              Container(
                width: 1,
                height: 40,
                color: AppColors.gray200,
              ),
              _buildProgressStat(
                label: 'Restantes',
                value: '${total - realizadas}',
                color: AppColors.warning,
              ),
              Container(
                width: 1,
                height: 40,
                color: AppColors.gray200,
              ),
              _buildProgressStat(
                label: 'Meta',
                value: total.toString(),
                color: AppColors.info,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressStat({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildEvolucaoSemanal() {
    if (_evolucaoSemanal.isEmpty) return const SizedBox.shrink();

    final maxAulas = _evolucaoSemanal
        .map((e) => (e['aulas'] as num?) ?? 0)
        .reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Evolução Semanal',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 20),
          ...List.generate(_evolucaoSemanal.length, (index) {
            final item = _evolucaoSemanal[index];
            final aulas = (item['aulas'] as num?) ?? 0;
            final percent = maxAulas > 0 ? aulas / maxAulas : 0.0;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 60,
                    child: Text(
                      item['semana'] ?? '',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  Expanded(
                    child: Container(
                      height: 24,
                      decoration: BoxDecoration(
                        color: AppColors.gray100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: percent.toDouble(),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 40,
                    child: Text(
                      '$aulas aulas',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.info_outline, size: 14, color: AppColors.gray400),
              const SizedBox(width: 4),
              Text(
                'Média: ${(_evolucaoSemanal.map((e) => (e['aulas'] as num?) ?? 0).reduce((a, b) => a + b) / _evolucaoSemanal.length).toStringAsFixed(1)} aulas/semana',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUltimasAulas() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Últimas Aulas Realizadas',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        if (_ultimasAulas.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Column(
                children: [
                  const Icon(
                    Icons.history,
                    size: 48,
                    color: AppColors.gray400,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Nenhuma aula realizada ainda',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _ultimasAulas.length.clamp(0, 5),
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final aula = _ultimasAulas[index];
              return _buildAulaCard(aula);
            },
          ),
      ],
    );
  }

  Widget _buildAulaCard(Map<String, dynamic> aula) {
    final dataHora =
        DateTime.tryParse(aula['data_hora'] ?? '') ?? DateTime.now();
    final duracao = aula['duracao_minutos'] ?? 50;
    final instrutorNome = aula['instrutor_nome'] ?? 'Instrutor';
    final nota = (aula['nota'] as num?) ?? 0;

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
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('dd/MM/yyyy • HH:mm').format(dataHora),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$instrutorNome • ${duracao}min',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (nota > 0)
            Row(
              children: [
                const Icon(Icons.star, color: AppColors.warning, size: 18),
                const SizedBox(width: 4),
                Text(
                  nota.toStringAsFixed(1),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildMetasCard() {
    final realizadas = _estatisticas['aulasRealizadas'] ?? 0;
    final total = _estatisticas['totalAulas'] ?? 30;
    final horas = _estatisticas['horasPraticas'] ?? 0;
    final progresso = _estatisticas['progresso'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.flag_outlined, color: AppColors.white),
              SizedBox(width: 8),
              Text(
                'Próximas Metas',
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildMetaItem(
            'Aulas restantes para a meta',
            '${total - realizadas} aulas',
            Icons.calendar_today,
          ),
          const SizedBox(height: 12),
          _buildMetaItem(
            'Total de horas práticas',
            '${horas}h de 25h',
            Icons.timer,
          ),
          const SizedBox(height: 12),
          _buildMetaItem(
            'Faltam para 100%',
            '${100 - progresso}%',
            Icons.trending_up,
          ),
        ],
      ),
    );
  }

  Widget _buildMetaItem(String label, String value, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.white, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: AppColors.white.withOpacity(0.9),
              fontSize: 14,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}
