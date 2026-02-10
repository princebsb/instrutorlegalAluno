import 'dart:async';
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
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _loadConversas();
    _startPolling();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _pollingTimer?.cancel();
    super.dispose();
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
          _conversas = [
            {
              'outro_usuario_id': '1',
              'outro_usuario_nome': 'João Silva',
              'outro_usuario_tipo': 'instrutor',
              'ultima_mensagem': 'Perfeito! Te vejo amanhã às 9h então.',
              'ultima_mensagem_data': DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String(),
              'nao_lidas': 2,
            },
            {
              'outro_usuario_id': '2',
              'outro_usuario_nome': 'Maria Santos',
              'outro_usuario_tipo': 'instrutor',
              'ultima_mensagem': 'Bom dia! Como posso ajudar?',
              'ultima_mensagem_data': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
              'nao_lidas': 0,
            },
            {
              'outro_usuario_id': '3',
              'outro_usuario_nome': 'Suporte Instrutor Legal',
              'outro_usuario_tipo': 'admin',
              'ultima_mensagem': 'Olá! Bem-vindo ao Instrutor Legal!',
              'ultima_mensagem_data': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
              'nao_lidas': 1,
            },
          ];
          _conversasFiltradas = _conversas;
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
    return Scaffold(
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

    final data = dataStr != null ? DateTime.tryParse(dataStr) : null;
    final timeAgo = data != null ? _formatTimeAgo(data) : '';

    return Material(
      color: naoLidas > 0 ? AppColors.primarySurface.withOpacity(0.3) : AppColors.white,
      child: InkWell(
        onTap: () {
          context.push(
            '${AppRoutes.conversa}/${conversa['outro_usuario_id']}',
            extra: {'nomeContato': nome},
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: tipo == 'admin'
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
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.gray600,
                          ),
                        ),
                ),
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
                          child: Text(
                            nome,
                            style: TextStyle(
                              fontWeight: naoLidas > 0
                                  ? FontWeight.bold
                                  : FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Text(
                          timeAgo,
                          style: TextStyle(
                            fontSize: 12,
                            color: naoLidas > 0
                                ? AppColors.primary
                                : AppColors.gray500,
                            fontWeight: naoLidas > 0
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            ultimaMensagem,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: naoLidas > 0
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                              fontWeight: naoLidas > 0
                                  ? FontWeight.w500
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                        if (naoLidas > 0) ...[
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
