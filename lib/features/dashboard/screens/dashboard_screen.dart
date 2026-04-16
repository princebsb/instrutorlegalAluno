import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/notification_provider.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/routes/app_router.dart';
import '../../../shared/widgets/app_logo.dart';
import '../../../shared/widgets/bottom_nav_bar.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with WidgetsBindingObserver {
  final _api = ApiService();
  bool _isLoading = true;
  bool _hasLoadedOnce = false;

  // Dashboard data
  Map<String, dynamic> _estatisticas = {
    'aulasRealizadas': 0,
    'aulasAgendadas': 0,
    'mensagensNaoLidas': 0,
    'instrutoresFavoritos': 0,
    'progressoPercentual': 0,
    'metaAulas': 30,
  };
  List<Map<String, dynamic>> _proximasAulas = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadDashboard();
    _startNotificationPolling();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Recarrega quando o app volta ao foco
    if (state == AppLifecycleState.resumed && _hasLoadedOnce) {
      _loadDashboard();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Recarrega quando a tela é exibida novamente (apenas após primeira carga)
    if (_hasLoadedOnce) {
      _loadDashboard();
    }
  }

  void _startNotificationPolling() {
    final user = context.read<AuthProvider>().user;
    if (user != null) {
      context.read<NotificationProvider>().startPolling(user.id);
    }
  }

  Future<void> _loadDashboard() async {
    setState(() => _isLoading = true);

    final user = context.read<AuthProvider>().user;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final response = await _api.get(ApiEndpoints.dashboard(user.id));

      if (response != null) {
        setState(() {
          if (response['estatisticas'] != null) {
            _estatisticas = Map<String, dynamic>.from(response['estatisticas']);
          }
          if (response['proximasAulas'] != null) {
            _proximasAulas = List<Map<String, dynamic>>.from(
              response['proximasAulas'].map((a) => Map<String, dynamic>.from(a)),
            );
          }
        });
      }
    } catch (e) {
      // Usar dados mock
    } finally {
      setState(() {
        _isLoading = false;
        _hasLoadedOnce = true;
      });
    }
  }

  bool _podeConfirmarOuDisputar(Map<String, dynamic> aula) {
    final dataHora = DateTime.tryParse(aula['data_hora'] ?? '');
    if (dataHora == null) return false;

    final confirmacaoAluno = aula['confirmacao_aluno'] == true || aula['confirmacao_aluno'] == 1;
    final disputaAberta = aula['disputa_aberta'] == true || aula['disputa_aberta'] == 1;
    final passouHorario = DateTime.now().isAfter(dataHora);

    return !confirmacaoAluno && !disputaAberta && passouHorario;
  }

  bool _aulaPaga(Map<String, dynamic> aula) {
    return aula['pago'] == true || aula['pago'] == 1;
  }

  Future<void> _confirmarAulaRealizada(Map<String, dynamic> aula) async {
    if (!_aulaPaga(aula)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Você precisa pagar a aula antes de confirmar.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Aula'),
        content: const Text(
          'Você confirma que esta aula foi realizada?\n\n'
          'Ao confirmar, o pagamento será liberado para o instrutor.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
            ),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        await _api.post(
          ApiEndpoints.confirmarAulaRealizada(aula['id'].toString()),
          body: {},
        );

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Aula confirmada com sucesso!'),
              backgroundColor: AppColors.success,
            ),
          );
          _loadDashboard();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao confirmar aula: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _abrirDisputa(Map<String, dynamic> aula) async {
    if (!_aulaPaga(aula)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Você precisa pagar a aula antes de abrir uma disputa.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    String? motivoSelecionado;
    final descricaoController = TextEditingController();

    final motivos = [
      'Aula não foi realizada',
      'Instrutor não compareceu',
      'Aula incompleta',
      'Problema com veículo',
      'Outro',
    ];

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Abrir Disputa'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Selecione o motivo da disputa:',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: motivoSelecionado,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  hint: const Text('Selecione o motivo'),
                  items: motivos.map((motivo) {
                    return DropdownMenuItem(
                      value: motivo,
                      child: Text(motivo),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      motivoSelecionado = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                const Text(
                  'Descreva o problema:',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descricaoController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Descreva o que aconteceu...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: motivoSelecionado != null
                  ? () => Navigator.pop(context, true)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warning,
              ),
              child: const Text('Abrir Disputa'),
            ),
          ],
        ),
      ),
    );

    if (confirmar == true && motivoSelecionado != null) {
      try {
        await _api.post(
          ApiEndpoints.abrirDisputa(aula['id'].toString()),
          body: {
            'motivo': motivoSelecionado,
            'descricao': descricaoController.text.trim(),
          },
        );

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Disputa aberta com sucesso. Entraremos em contato.'),
              backgroundColor: AppColors.warning,
            ),
          );
          _loadDashboard();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao abrir disputa: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }

    descricaoController.dispose();
  }

  Future<void> _confirmarCancelamento(Map<String, dynamic> aula) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar Aula'),
        content: const Text('Tem certeza que deseja cancelar esta aula?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Não'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Sim, cancelar'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        await _api.patch(
          '${ApiEndpoints.aula(aula['id'].toString())}/cancelar',
          body: {'motivo': 'Cancelado pelo aluno'},
        );

        if (mounted) {
          Navigator.pop(context); // Fecha o bottom sheet
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Aula cancelada com sucesso'),
              backgroundColor: AppColors.success,
            ),
          );
          _loadDashboard(); // Recarrega os dados
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao cancelar aula: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  void _mostrarDetalhesAula(Map<String, dynamic> aula) {
    final dataHora = DateTime.tryParse(aula['data_hora'] ?? '') ?? DateTime.now();
    final status = aula['status']?.toString() ?? 'agendada';
    final valor = double.tryParse(aula['valor']?.toString() ?? '') ?? 0.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.gray300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Título
            const Text(
              'Detalhes da Aula',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),

            // Status
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: status == 'confirmada'
                    ? AppColors.success.withOpacity(0.1)
                    : AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                status == 'confirmada' ? 'Confirmada' : 'Aguardando confirmação',
                style: TextStyle(
                  color: status == 'confirmada' ? AppColors.success : AppColors.warning,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Instrutor
            _buildDetalheItem(
              icon: Icons.person,
              label: 'Instrutor',
              value: aula['instrutor_nome']?.toString() ?? 'Não informado',
            ),

            // Data e Hora
            _buildDetalheItem(
              icon: Icons.calendar_today,
              label: 'Data',
              value: DateFormat('EEEE, dd/MM/yyyy', 'pt_BR').format(dataHora),
            ),
            _buildDetalheItem(
              icon: Icons.access_time,
              label: 'Horário',
              value: DateFormat('HH:mm').format(dataHora),
            ),

            // Local
            if (aula['local_partida'] != null)
              _buildDetalheItem(
                icon: Icons.location_on,
                label: 'Local de partida',
                value: aula['local_partida'].toString(),
              ),

            // Valor
            _buildDetalheItem(
              icon: Icons.attach_money,
              label: 'Valor',
              value: 'R\$ ${valor.toStringAsFixed(2)}',
            ),

            const SizedBox(height: 16),

            // Botão Mensagem (só se aula paga)
            if (aula['pago'] == true || aula['pago'] == 1)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: aula['instrutor_usuario_id'] != null
                      ? () {
                          Navigator.pop(context);
                          context.push(
                            '${AppRoutes.conversa}/${aula['instrutor_usuario_id']}',
                            extra: {
                              'nomeContato': aula['instrutor_nome'] ?? 'Instrutor',
                              'banido': false,
                              'temAulaPaga': true,
                            },
                          );
                        }
                      : null,
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('Enviar Mensagem'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // Status de confirmação/disputa
            if (aula['confirmacao_aluno'] == true || aula['confirmacao_aluno'] == 1)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.success.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle, color: AppColors.success, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Aula confirmada pelo aluno',
                        style: TextStyle(
                          color: AppColors.success,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            if (aula['disputa_aberta'] == true || aula['disputa_aberta'] == 1)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber, color: AppColors.warning, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Disputa em análise',
                        style: TextStyle(
                          color: AppColors.warning,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 24),

            // Botões de confirmação/disputa (se aplicável)
            if (_podeConfirmarOuDisputar(aula)) ...[
              // Aviso se a aula não foi paga
              if (!_aulaPaga(aula))
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.info.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.info.withOpacity(0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: AppColors.info, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Pague a aula para confirmar ou abrir disputa',
                          style: TextStyle(
                            color: AppColors.info,
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _confirmarAulaRealizada(aula),
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Confirmar Aula'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: AppColors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _abrirDisputa(aula),
                      icon: const Icon(Icons.warning_amber),
                      label: const Text('Tive Problema'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.warning,
                        side: const BorderSide(color: AppColors.warning),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // Botões padrão
            Row(
              children: [
                // Botão cancelar (apenas se a aula ainda não passou)
                if (DateTime.tryParse(aula['data_hora'] ?? '')?.isAfter(DateTime.now()) ?? false) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _confirmarCancelamento(aula),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Cancelar Aula'),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                // Botão fechar
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Fechar'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildDetalheItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
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
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.gray500,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final notificationProvider = context.watch<NotificationProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadDashboard,
          color: AppColors.primary,
          child: CustomScrollView(
            slivers: [
              // App Bar
              SliverAppBar(
                floating: true,
                backgroundColor: AppColors.white,
                elevation: 0,
                automaticallyImplyLeading: false,
                title: const AppLogoHorizontal(height: 36),
                actions: [
                  // Notificações
                  Stack(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.notifications_outlined),
                        onPressed: () {
                          _showNotificationsSheet(context);
                        },
                      ),
                      if (notificationProvider.hasUnread)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: AppColors.error,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),

              // Content
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Greeting
                    _buildGreeting(user?.primeiroNome ?? 'Aluno'),

                    const SizedBox(height: 24),

                    // Stats Cards
                    _buildStatsCards(),

                    const SizedBox(height: 24),

                    // Progress Card
                    _buildProgressCard(),

                    const SizedBox(height: 24),

                    // Próximas Aulas
                    _buildProximasAulas(),

                    const SizedBox(height: 24),

                    // Quick Actions
                    _buildQuickActions(),

                    const SizedBox(height: 100), // Space for bottom nav
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: 0,
        unreadMessages: _estatisticas['mensagensNaoLidas'] ?? 0,
      ),
    );
  }

  Widget _buildGreeting(String nome) {
    final hora = DateTime.now().hour;
    String saudacao;
    IconData icon;

    if (hora < 12) {
      saudacao = 'Bom dia';
      icon = Icons.wb_sunny_outlined;
    } else if (hora < 18) {
      saudacao = 'Boa tarde';
      icon = Icons.wb_sunny;
    } else {
      saudacao = 'Boa noite';
      icon = Icons.nightlight_outlined;
    }

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '$saudacao,',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                nome,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
        ),
        // Avatar
        GestureDetector(
          onTap: () => context.push(AppRoutes.configuracoes),
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary, width: 2),
            ),
            child: Center(
              child: Text(
                context.read<AuthProvider>().user?.iniciais ?? 'U',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 500.ms);
  }

  Widget _buildStatsCards() {
    final stats = [
      {
        'icon': Icons.calendar_today,
        'label': 'Agendadas',
        'value': _estatisticas['aulasAgendadas']?.toString() ?? '0',
        'color': AppColors.info,
        'route': AppRoutes.minhasAulas,
        'extra': {'initialTab': 0},
      },
      {
        'icon': Icons.check_circle_outline,
        'label': 'Realizadas',
        'value': _estatisticas['aulasRealizadas']?.toString() ?? '0',
        'color': AppColors.success,
        'route': AppRoutes.minhasAulas,
        'extra': {'initialTab': 1},
      },
      {
        'icon': Icons.chat_bubble_outline,
        'label': 'Mensagens',
        'value': _estatisticas['mensagensNaoLidas']?.toString() ?? '0',
        'color': AppColors.warning,
        'route': AppRoutes.mensagens,
      },
      {
        'icon': Icons.star_outline,
        'label': 'Favoritos',
        'value': _estatisticas['instrutoresFavoritos']?.toString() ?? '0',
        'color': AppColors.error,
        'route': AppRoutes.buscarInstrutor,
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.8,
      ),
      itemCount: stats.length,
      itemBuilder: (context, index) {
        final stat = stats[index];
        return Material(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: () => context.push(
              stat['route'] as String,
              extra: stat['extra'],
            ),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppColors.cardShadow,
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (stat['color'] as Color).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      stat['icon'] as IconData,
                      color: stat['color'] as Color,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stat['value'] as String,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          stat['label'] as String,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: AppColors.gray400,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ).animate(delay: (100 * index).ms).fadeIn().slideY(begin: 0.2);
      },
    );
  }

  Widget _buildProgressCard() {
    final progresso = _estatisticas['progressoPercentual'] ?? 0;
    final realizadas = _estatisticas['aulasRealizadas'] ?? 0;
    final meta = _estatisticas['metaAulas'] ?? 30;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.buttonShadow,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Seu Progresso',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$realizadas de $meta aulas realizadas',
                  style: TextStyle(
                    color: AppColors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                // Progress bar
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: (progresso / 100).clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          // Circular progress
          SizedBox(
            width: 80,
            height: 80,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: (progresso / 100).clamp(0.0, 1.0),
                  strokeWidth: 8,
                  backgroundColor: AppColors.white.withOpacity(0.3),
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppColors.white),
                ),
                Center(
                  child: Text(
                    '$progresso%',
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2);
  }

  Widget _buildProximasAulas() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Próximas Aulas',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            TextButton(
              onPressed: () => context.push(
                AppRoutes.minhasAulas,
                extra: {'initialTab': 0},
              ),
              child: const Text('Ver todas'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_proximasAulas.isEmpty)
          Material(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: () => context.push(AppRoutes.agendarAula),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.gray200),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 48,
                      color: AppColors.gray400,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Nenhuma aula agendada',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Agende sua primeira aula!',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _proximasAulas.length.clamp(0, 3),
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final aula = _proximasAulas[index];
              return GestureDetector(
                onTap: () => _mostrarDetalhesAula(aula),
                child: _buildAulaCard(aula),
              );
            },
          ),
      ],
    ).animate().fadeIn(delay: 500.ms);
  }

  Widget _buildAulaCard(Map<String, dynamic> aula) {
    final dataHora = DateTime.tryParse(aula['data_hora'] ?? '') ?? DateTime.now();
    final precisaConfirmar = _podeConfirmarOuDisputar(aula);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.cardShadow,
        border: precisaConfirmar
            ? Border.all(color: AppColors.success, width: 2)
            : null,
      ),
      child: Row(
        children: [
          // Data
          Container(
            width: 60,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: precisaConfirmar
                  ? AppColors.success.withOpacity(0.1)
                  : AppColors.primarySurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  DateFormat('dd').format(dataHora),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: precisaConfirmar ? AppColors.success : AppColors.primary,
                  ),
                ),
                Text(
                  DateFormat('MMM', 'pt_BR').format(dataHora).toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: precisaConfirmar ? AppColors.success : AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  aula['instrutor_nome'] ?? 'Instrutor',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 14, color: AppColors.gray500),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('HH:mm').format(dataHora),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.location_on_outlined,
                        size: 14, color: AppColors.gray500),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        aula['local_partida'] ?? 'Local a definir',
                        style: Theme.of(context).textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: precisaConfirmar
                  ? AppColors.success.withOpacity(0.1)
                  : AppColors.successLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (precisaConfirmar) ...[
                  const Icon(Icons.check_circle_outline, size: 14, color: AppColors.success),
                  const SizedBox(width: 4),
                ],
                Text(
                  precisaConfirmar ? 'Confirmar' : (aula['status'] ?? 'Agendada'),
                  style: const TextStyle(
                    color: AppColors.success,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ações Rápidas',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                icon: Icons.add_circle_outline,
                label: 'Agendar Aula',
                color: AppColors.primary,
                onTap: () => context.push(AppRoutes.agendarAula),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                icon: Icons.chat_bubble_outline,
                label: 'Mensagens',
                color: AppColors.info,
                onTap: () => context.push(AppRoutes.mensagens),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                icon: Icons.payment_outlined,
                label: 'Pagamentos',
                color: AppColors.warning,
                onTap: () => context.push(AppRoutes.pagamentos),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                icon: Icons.search,
                label: 'Buscar Instrutor',
                color: AppColors.secondary,
                onTap: () => context.push(AppRoutes.buscarInstrutor),
              ),
            ),
          ],
        ),
      ],
    ).animate().fadeIn(delay: 600.ms);
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.gray200),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showNotificationsSheet(BuildContext context) {
    final notificationProvider = context.read<NotificationProvider>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.gray300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Notificações',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (notificationProvider.hasUnread)
                      TextButton(
                        onPressed: () {
                          final user = context.read<AuthProvider>().user;
                          if (user != null) {
                            notificationProvider.markAllAsRead(user.id);
                          }
                        },
                        child: const Text('Marcar todas como lidas'),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: notificationProvider.notifications.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.notifications_none,
                              size: 64,
                              color: AppColors.gray400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Nenhuma notificação',
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: notificationProvider.notifications.length,
                        separatorBuilder: (_, __) => const Divider(),
                        itemBuilder: (context, index) {
                          final notif = notificationProvider.notifications[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: notif.lida
                                    ? AppColors.gray100
                                    : AppColors.primarySurface,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _getNotificationIcon(notif.tipo),
                                color: notif.lida
                                    ? AppColors.gray500
                                    : AppColors.primary,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              notif.titulo,
                              style: TextStyle(
                                fontWeight:
                                    notif.lida ? FontWeight.normal : FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              notif.mensagem,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Text(
                              _formatNotificationDate(notif.createdAt),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            onTap: () {
                              notificationProvider.markAsRead(notif.id);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getNotificationIcon(String tipo) {
    switch (tipo) {
      case 'aula':
        return Icons.calendar_today;
      case 'mensagem':
        return Icons.chat_bubble;
      case 'pagamento':
        return Icons.payment;
      default:
        return Icons.notifications;
    }
  }

  String _formatNotificationDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}min';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d';
    } else {
      return DateFormat('dd/MM').format(date);
    }
  }
}
