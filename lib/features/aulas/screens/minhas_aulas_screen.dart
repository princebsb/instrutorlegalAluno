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

  Future<void> _confirmarAulaRealizada(Map<String, dynamic> aula) async {
    // Verificar se a aula está paga
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
          Navigator.pop(context); // Fecha o bottom sheet
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Aula confirmada com sucesso!'),
              backgroundColor: AppColors.success,
            ),
          );
          _loadAulas(); // Recarrega os dados
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
    // Verificar se a aula está paga
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
          Navigator.pop(context); // Fecha o bottom sheet
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Disputa aberta com sucesso. Entraremos em contato.'),
              backgroundColor: AppColors.warning,
            ),
          );
          _loadAulas(); // Recarrega os dados
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

  bool _podeConfirmarOuDisputar(Map<String, dynamic> aula) {
    final dataHora = DateTime.tryParse(aula['data_hora'] ?? '');
    if (dataHora == null) return false;

    final confirmacaoAluno = aula['confirmacao_aluno'] == true || aula['confirmacao_aluno'] == 1;
    final disputaAberta = aula['disputa_aberta'] == true || aula['disputa_aberta'] == 1;
    final passouHorario = DateTime.now().isAfter(dataHora);

    // Mostra os botões se o horário passou e não tem confirmação nem disputa
    return !confirmacaoAluno && !disputaAberta && passouHorario;
  }

  bool _aulaPaga(Map<String, dynamic> aula) {
    return aula['pago'] == true || aula['pago'] == 1;
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
          _loadAulas(); // Recarrega os dados
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
            if (valor > 0)
              _buildDetalheItem(
                icon: Icons.attach_money,
                label: 'Valor',
                value: 'R\$ ${valor.toStringAsFixed(2)}',
              ),

            const SizedBox(height: 16),

            // Botão Mensagem (só se aula paga)
            if (_aulaPaga(aula))
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
          return GestureDetector(
            onTap: () => _mostrarDetalhesAula(_agendadas[index]),
            child: _buildAulaAgendadaCard(_agendadas[index]),
          );
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
          return GestureDetector(
            onTap: () => _mostrarDetalhesAula(_realizadas[index]),
            child: _buildAulaRealizadaCard(_realizadas[index]),
          );
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
    final precisaConfirmar = _podeConfirmarOuDisputar(aula);

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
            color: precisaConfirmar
                ? AppColors.success
                : (isHoje ? AppColors.warning : AppColors.info),
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
                      if (precisaConfirmar)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle_outline,
                                size: 12,
                                color: AppColors.success,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Confirmar',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.success,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
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
            // Botão de mensagem (só se aula paga)
            if (_aulaPaga(aula) && aula['instrutor_usuario_id'] != null)
              IconButton(
                onPressed: () {
                  context.push(
                    '${AppRoutes.conversa}/${aula['instrutor_usuario_id']}',
                    extra: {
                      'nomeContato': aula['instrutor_nome'] ?? 'Instrutor',
                      'banido': false,
                      'temAulaPaga': true,
                    },
                  );
                },
                icon: const Icon(Icons.chat_bubble_outline),
                color: AppColors.primary,
                tooltip: 'Enviar mensagem',
              )
            else
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
