import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/routes/app_router.dart';
import '../../../shared/widgets/bottom_nav_bar.dart';
import '../../../shared/widgets/custom_text_field.dart';

class MensagensScreen extends StatefulWidget {
  const MensagensScreen({super.key});

  @override
  State<MensagensScreen> createState() => _MensagensScreenState();
}

class _MensagensScreenState extends State<MensagensScreen> {
  final _api = ApiService();
  final _searchController = TextEditingController();

  List<Map<String, dynamic>> _conversas = [];
  List<Map<String, dynamic>> _conversasFiltradas = [];
  bool _isLoading = true;
  bool _showRulesModal = false;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _checkRulesModal();
    _loadConversas();
    _startPolling();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkRulesModal() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenRules = prefs.getBool('aluno_viu_regras_mensagens') ?? false;
    if (!hasSeenRules && mounted) {
      setState(() => _showRulesModal = true);
    }
  }

  Future<void> _acceptRules() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('aluno_viu_regras_mensagens', true);
    if (mounted) {
      setState(() => _showRulesModal = false);
    }
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _loadConversas(silent: true),
    );
  }

  Future<void> _loadConversas({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);

    final user = context.read<AuthProvider>().user;
    if (user == null) {
      if (!silent) setState(() => _isLoading = false);
      return;
    }

    try {
      final response = await _api.get(ApiEndpoints.conversas(user.id));
      final List<dynamic> data = response is List ? response : (response['conversas'] ?? []);

      setState(() {
        _conversas = data.map((c) => Map<String, dynamic>.from(c)).toList();
        _filterConversas(_searchController.text);
      });
    } catch (e) {
      // Mock data
      if (!silent) {
        setState(() {
          _conversas = [];
          _conversasFiltradas = [];
        });
      }
    } finally {
      if (!silent) setState(() => _isLoading = false);
    }
  }

  void _filterConversas(String query) {
    setState(() {
      if (query.isEmpty) {
        _conversasFiltradas = _conversas;
      } else {
        _conversasFiltradas = _conversas.where((c) {
          final nome = (c['outro_usuario_nome'] ?? '').toString().toLowerCase();
          return nome.contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  int get _totalNaoLidas {
    return _conversas.fold<int>(
      0,
      (sum, c) => sum + (int.tryParse(c['nao_lidas']?.toString() ?? '0') ?? 0),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: Row(
              children: [
                const Text('Mensagens'),
                if (_totalNaoLidas > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _totalNaoLidas.toString(),
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            backgroundColor: AppColors.white,
            elevation: 0,
            automaticallyImplyLeading: false,
          ),
          body: Column(
            children: [
              // Search
              Container(
                padding: const EdgeInsets.all(16),
                color: AppColors.white,
                child: CustomTextField(
                  controller: _searchController,
                  hint: 'Buscar conversa...',
                  prefixIcon: const Icon(Icons.search),
                  onChanged: _filterConversas,
                ),
              ),

              // Lista
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _conversasFiltradas.isEmpty
                        ? _buildEmptyState()
                        : RefreshIndicator(
                            onRefresh: _loadConversas,
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: _conversasFiltradas.length,
                              separatorBuilder: (_, __) => const Divider(
                                height: 1,
                                indent: 88,
                              ),
                              itemBuilder: (context, index) {
                                return _buildConversaItem(_conversasFiltradas[index]);
                              },
                            ),
                          ),
              ),
            ],
          ),
          bottomNavigationBar: BottomNavBar(
            currentIndex: 3,
            unreadMessages: _totalNaoLidas,
          ),
        ),
        // Modal de Regras
        if (_showRulesModal) _buildRulesModal(),
      ],
    );
  }

  Widget _buildRulesModal() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          constraints: const BoxConstraints(maxWidth: 320),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header compacto
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.shield, color: Colors.white, size: 24),
                    SizedBox(width: 10),
                    Text(
                      'Regras do Chat',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Regra Principal compacta
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.block, color: Colors.red.shade600, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Proibido compartilhar telefone, e-mail ou redes sociais',
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Consequências compactas
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          _buildWarningRow('1ª vez: Aviso', Colors.amber),
                          const SizedBox(height: 6),
                          _buildWarningRow('2ª vez: Último aviso', Colors.orange),
                          const SizedBox(height: 6),
                          _buildWarningRow('3ª vez: Banimento', Colors.red),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Botão
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _acceptRules,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Entendi',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWarningRow(String text, MaterialColor color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color.shade600,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(text, style: TextStyle(color: color.shade700, fontSize: 12)),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.chat_bubble_outline,
              size: 80,
              color: AppColors.gray300,
            ),
            const SizedBox(height: 24),
            Text(
              'Nenhuma conversa ainda',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Suas conversas com instrutores aparecerão aqui',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversaItem(Map<String, dynamic> conversa) {
    final nome = conversa['outro_usuario_nome'] ?? 'Usuário';
    final tipo = conversa['outro_usuario_tipo'] ?? 'instrutor';
    final ultimaMensagem = conversa['ultima_mensagem'] ?? '';
    final dataStr = conversa['ultima_mensagem_data'];
    final naoLidas = int.tryParse(conversa['nao_lidas']?.toString() ?? '0') ?? 0;
    final banido = conversa['banido'] == true;
    final temAulaPaga = conversa['temAulaPaga'] == true;
    final chatBloqueado = !temAulaPaga && tipo != 'admin';

    final data = dataStr != null ? DateTime.tryParse(dataStr) : null;
    final timeAgo = data != null ? _formatTimeAgo(data) : '';

    return Material(
      color: banido
          ? Colors.red.shade50
          : chatBloqueado
              ? Colors.orange.shade50
              : naoLidas > 0
                  ? AppColors.primarySurface.withOpacity(0.3)
                  : AppColors.white,
      child: InkWell(
        onTap: () {
          // Bloquear acesso se não pagou aula (exceto admin)
          if (chatBloqueado) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.lock, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Pague uma aula com este instrutor para liberar o chat.',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
                backgroundColor: Colors.orange.shade700,
                duration: const Duration(seconds: 4),
                behavior: SnackBarBehavior.floating,
                action: SnackBarAction(
                  label: 'IR PARA PAGAMENTO',
                  textColor: Colors.white,
                  onPressed: () => context.go(AppRoutes.pagamentos),
                ),
              ),
            );
            return;
          }

          context.push(
            '${AppRoutes.conversa}/${conversa['outro_usuario_id']}',
            extra: {
              'nomeContato': nome,
              'banido': banido,
              'temAulaPaga': temAulaPaga,
            },
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Avatar
              Stack(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: banido
                          ? Colors.red
                          : chatBloqueado
                              ? Colors.orange
                              : tipo == 'admin'
                                  ? AppColors.primarySurface
                                  : AppColors.gray100,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: tipo == 'admin'
                          ? const Icon(
                              Icons.support_agent,
                              color: AppColors.primary,
                              size: 28,
                            )
                          : Text(
                              nome[0].toUpperCase(),
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: (banido || chatBloqueado) ? Colors.white : AppColors.gray600,
                              ),
                            ),
                    ),
                  ),
                  if (banido)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: Colors.red.shade700,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Center(
                          child: Icon(Icons.block, color: Colors.white, size: 12),
                        ),
                      ),
                    ),
                  if (chatBloqueado && !banido)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: Colors.orange.shade700,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Center(
                          child: Icon(Icons.lock, color: Colors.white, size: 10),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  nome,
                                  style: TextStyle(
                                    fontWeight: naoLidas > 0 ? FontWeight.bold : FontWeight.w600,
                                    fontSize: 16,
                                    color: banido ? Colors.red.shade700 : null,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (banido) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'BANIDO',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red.shade700,
                                    ),
                                  ),
                                ),
                              ] else if (chatBloqueado) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'PAGUE PARA CONVERSAR',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Text(
                          timeAgo,
                          style: TextStyle(
                            fontSize: 12,
                            color: naoLidas > 0 ? AppColors.primary : AppColors.gray500,
                            fontWeight: naoLidas > 0 ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            banido
                                ? 'Este instrutor foi banido por violar as regras'
                                : chatBloqueado
                                    ? 'Pague a aula para liberar o chat'
                                    : ultimaMensagem,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: banido
                                  ? Colors.red.shade400
                                  : chatBloqueado
                                      ? Colors.orange.shade600
                                      : naoLidas > 0
                                          ? AppColors.textPrimary
                                          : AppColors.textSecondary,
                              fontWeight: naoLidas > 0 ? FontWeight.w500 : FontWeight.normal,
                            ),
                          ),
                        ),
                        if (naoLidas > 0 && !banido && !chatBloqueado) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              naoLidas.toString(),
                              style: const TextStyle(
                                color: AppColors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) {
      return 'Agora';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes} min';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d';
    } else {
      return DateFormat('dd/MM').format(date);
    }
  }
}
