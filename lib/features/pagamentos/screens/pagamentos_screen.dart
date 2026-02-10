import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/bottom_nav_bar.dart';

class PagamentosScreen extends StatefulWidget {
  const PagamentosScreen({super.key});

  @override
  State<PagamentosScreen> createState() => _PagamentosScreenState();
}

class _PagamentosScreenState extends State<PagamentosScreen> {
  final _api = ApiService();
  bool _isLoading = true;
  String _filtroSelecionado = 'todos';

  Map<String, dynamic> _resumo = {
    'totalPago': 0.0,
    'totalPendente': 0.0,
    'totalAtrasado': 0.0,
  };

  List<Map<String, dynamic>> _pagamentos = [];

  @override
  void initState() {
    super.initState();
    _loadPagamentos();
  }

  Future<void> _loadPagamentos() async {
    setState(() => _isLoading = true);

    final user = context.read<AuthProvider>().user;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final response = await _api.get(ApiEndpoints.pagamentos(user.id));

      if (response != null) {
        setState(() {
          if (response['resumo'] != null) {
            _resumo = Map<String, dynamic>.from(response['resumo']);
          }
          if (response['pagamentos'] != null) {
            _pagamentos = List<Map<String, dynamic>>.from(
              response['pagamentos'].map((p) => Map<String, dynamic>.from(p)),
            );
          }
        });
      }
    } catch (e) {
      // Mock data
      setState(() {
        _pagamentos = [
          {
            'id': '1',
            'data': DateTime.now().subtract(const Duration(days: 5)).toIso8601String(),
            'descricao': 'Aula prática - João Silva',
            'valor': 130.0,
            'status': 'pago',
            'metodoPagamento': 'pix',
          },
          {
            'id': '2',
            'data': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
            'descricao': 'Aula prática - Maria Santos',
            'valor': 120.0,
            'status': 'pendente',
            'metodoPagamento': null,
          },
          {
            'id': '3',
            'data': DateTime.now().subtract(const Duration(days: 10)).toIso8601String(),
            'descricao': 'Aula prática - Carlos Oliveira',
            'valor': 125.0,
            'status': 'atrasado',
            'metodoPagamento': null,
          },
        ];
        _resumo = {
          'totalPago': 130.0,
          'totalPendente': 120.0,
          'totalAtrasado': 125.0,
        };
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _pagamentosFiltrados {
    if (_filtroSelecionado == 'todos') return _pagamentos;
    return _pagamentos
        .where((p) => p['status'] == _filtroSelecionado)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Pagamentos'),
        backgroundColor: AppColors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: RefreshIndicator(
        onRefresh: _loadPagamentos,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Resumo Cards
                    _buildResumoCards(),

                    const SizedBox(height: 16),

                    // Alerta pendentes
                    if ((_resumo['totalPendente'] ?? 0) > 0 ||
                        (_resumo['totalAtrasado'] ?? 0) > 0)
                      _buildAlertaPendentes(),

                    const SizedBox(height: 24),

                    // Filtros
                    _buildFiltros(),

                    const SizedBox(height: 16),

                    // Lista de pagamentos
                    _buildListaPagamentos(),

                    const SizedBox(height: 100),
                  ],
                ),
              ),
      ),
      bottomNavigationBar: const BottomNavBar(currentIndex: 0),
    );
  }

  Widget _buildResumoCards() {
    final cards = [
      {
        'label': 'Total Pago',
        'valor': _resumo['totalPago'] ?? 0.0,
        'color': AppColors.success,
        'bgColor': AppColors.successLight,
        'icon': Icons.check_circle,
      },
      {
        'label': 'Pendente',
        'valor': _resumo['totalPendente'] ?? 0.0,
        'color': AppColors.warning,
        'bgColor': AppColors.warningLight,
        'icon': Icons.pending,
      },
      {
        'label': 'Atrasado',
        'valor': _resumo['totalAtrasado'] ?? 0.0,
        'color': AppColors.error,
        'bgColor': AppColors.errorLight,
        'icon': Icons.error,
      },
    ];

    return Row(
      children: cards.map((card) {
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(
              right: card != cards.last ? 8 : 0,
            ),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: card['bgColor'] as Color,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: (card['color'] as Color).withOpacity(0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  card['icon'] as IconData,
                  color: card['color'] as Color,
                  size: 20,
                ),
                const SizedBox(height: 8),
                Text(
                  'R\$ ${(card['valor'] as num).toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: card['color'] as Color,
                  ),
                ),
                Text(
                  card['label'] as String,
                  style: TextStyle(
                    fontSize: 11,
                    color: (card['color'] as Color).withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAlertaPendentes() {
    final pendente = _resumo['totalPendente'] ?? 0.0;
    final atrasado = _resumo['totalAtrasado'] ?? 0.0;
    final total = pendente + atrasado;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warning.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: AppColors.warning,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Você tem pagamentos pendentes',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'Total: R\$ ${total.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltros() {
    final filtros = [
      {'id': 'todos', 'label': 'Todos'},
      {'id': 'pago', 'label': 'Pagos'},
      {'id': 'pendente', 'label': 'Pendentes'},
      {'id': 'atrasado', 'label': 'Atrasados'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filtros.map((filtro) {
          final isSelected = _filtroSelecionado == filtro['id'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(filtro['label']!),
              selected: isSelected,
              onSelected: (selected) {
                setState(() => _filtroSelecionado = filtro['id']!);
              },
              selectedColor: AppColors.primarySurface,
              checkmarkColor: AppColors.primary,
              labelStyle: TextStyle(
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildListaPagamentos() {
    if (_pagamentosFiltrados.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            children: [
              const Icon(
                Icons.receipt_long,
                size: 64,
                color: AppColors.gray400,
              ),
              const SizedBox(height: 16),
              Text(
                'Nenhum pagamento encontrado',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _pagamentosFiltrados.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return _buildPagamentoCard(_pagamentosFiltrados[index]);
      },
    );
  }

  Widget _buildPagamentoCard(Map<String, dynamic> pagamento) {
    final data = DateTime.tryParse(pagamento['data'] ?? '') ?? DateTime.now();
    final status = pagamento['status'] ?? 'pendente';
    final valor = (pagamento['valor'] as num?) ?? 0;
    final metodo = pagamento['metodoPagamento'];

    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    switch (status) {
      case 'pago':
        statusColor = AppColors.success;
        statusLabel = 'Pago';
        statusIcon = Icons.check_circle;
        break;
      case 'atrasado':
        statusColor = AppColors.error;
        statusLabel = 'Atrasado';
        statusIcon = Icons.error;
        break;
      default:
        statusColor = AppColors.warning;
        statusLabel = 'Pendente';
        statusIcon = Icons.pending;
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.cardShadow,
        border: Border(
          left: BorderSide(color: statusColor, width: 4),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: status != 'pago'
              ? () => _showPaymentOptions(pagamento)
              : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pagamento['descricao'] ?? 'Pagamento',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            size: 14,
                            color: AppColors.gray500,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('dd/MM/yyyy').format(data),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          if (metodo != null) ...[
                            const SizedBox(width: 12),
                            Icon(
                              _getMetodoIcon(metodo),
                              size: 14,
                              color: AppColors.gray500,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _getMetodoLabel(metodo),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'R\$ ${valor.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 12, color: statusColor),
                          const SizedBox(width: 4),
                          Text(
                            statusLabel,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getMetodoIcon(String metodo) {
    switch (metodo.toLowerCase()) {
      case 'pix':
        return Icons.qr_code;
      case 'cartao':
        return Icons.credit_card;
      case 'dinheiro':
        return Icons.money;
      case 'boleto':
        return Icons.receipt;
      default:
        return Icons.payment;
    }
  }

  String _getMetodoLabel(String metodo) {
    switch (metodo.toLowerCase()) {
      case 'pix':
        return 'PIX';
      case 'cartao':
        return 'Cartão';
      case 'dinheiro':
        return 'Dinheiro';
      case 'boleto':
        return 'Boleto';
      default:
        return metodo;
    }
  }

  void _showPaymentOptions(Map<String, dynamic> pagamento) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            Text(
              'Escolha a forma de pagamento',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            _buildPaymentOption(
              icon: Icons.qr_code,
              title: 'PIX',
              subtitle: 'Pagamento instantâneo',
              color: AppColors.primary,
              onTap: () {
                Navigator.pop(context);
                _showPixPayment(pagamento);
              },
            ),
            _buildPaymentOption(
              icon: Icons.credit_card,
              title: 'Cartão de Crédito',
              subtitle: 'Parcele em até 12x',
              color: AppColors.info,
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Pagamento com cartão em breve!'),
                  ),
                );
              },
            ),
            _buildPaymentOption(
              icon: Icons.receipt_long,
              title: 'Boleto Bancário',
              subtitle: 'Vencimento em 3 dias',
              color: AppColors.secondary,
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Boleto em breve!'),
                  ),
                );
              },
            ),
            _buildPaymentOption(
              icon: Icons.money,
              title: 'Dinheiro',
              subtitle: 'Pagar ao instrutor',
              color: AppColors.success,
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Combine com o instrutor!'),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  void _showPixPayment(Map<String, dynamic> pagamento) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pagamento PIX'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.gray100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.qr_code,
                size: 120,
                color: AppColors.gray500,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Valor: R\$ ${((pagamento['valor'] as num?) ?? 0).toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Escaneie o QR Code ou copie o código PIX',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Código PIX copiado!'),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copiar código'),
          ),
        ],
      ),
    );
  }
}
