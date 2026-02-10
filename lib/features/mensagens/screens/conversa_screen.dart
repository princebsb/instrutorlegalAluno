import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/app_constants.dart';

class ConversaScreen extends StatefulWidget {
  final String conversaId;
  final String nomeContato;

  const ConversaScreen({
    super.key,
    required this.conversaId,
    required this.nomeContato,
  });

  @override
  State<ConversaScreen> createState() => _ConversaScreenState();
}

class _ConversaScreenState extends State<ConversaScreen> {
  final _api = ApiService();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();

  List<Map<String, dynamic>> _mensagens = [];
  bool _isLoading = true;
  bool _isSending = false;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _loadMensagens();
    _startPolling();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _loadMensagens(silent: true),
    );
  }

  Future<void> _loadMensagens({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);

    final user = context.read<AuthProvider>().user;
    if (user == null) {
      if (!silent) setState(() => _isLoading = false);
      return;
    }

    try {
      final response = await _api.get(
        ApiEndpoints.mensagens(user.id, widget.conversaId),
      );
      final List<dynamic> data =
          response is List ? response : (response['mensagens'] ?? []);

      final newMessages = data.map((m) => Map<String, dynamic>.from(m)).toList();

      // Verificar se há novas mensagens
      if (newMessages.length != _mensagens.length) {
        setState(() {
          _mensagens = newMessages;
        });
        _scrollToBottom();
      }
    } catch (e) {
      // Mock data
      if (!silent) {
        setState(() {
          _mensagens = [
            {
              'id': '1',
              'remetente_id': widget.conversaId,
              'mensagem': 'Olá! Tudo bem?',
              'data_envio': DateTime.now()
                  .subtract(const Duration(hours: 2))
                  .toIso8601String(),
              'lida': true,
            },
            {
              'id': '2',
              'remetente_id': context.read<AuthProvider>().user?.id ?? '',
              'mensagem': 'Tudo ótimo! Quero agendar uma aula.',
              'data_envio': DateTime.now()
                  .subtract(const Duration(hours: 1, minutes: 50))
                  .toIso8601String(),
              'lida': true,
            },
            {
              'id': '3',
              'remetente_id': widget.conversaId,
              'mensagem': 'Perfeito! Que dia e horário seria melhor para você?',
              'data_envio': DateTime.now()
                  .subtract(const Duration(hours: 1, minutes: 45))
                  .toIso8601String(),
              'lida': true,
            },
          ];
        });
      }
    } finally {
      if (!silent) {
        setState(() => _isLoading = false);
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    setState(() => _isSending = true);
    _messageController.clear();

    // Adicionar mensagem localmente
    final tempMessage = {
      'id': 'temp_${DateTime.now().millisecondsSinceEpoch}',
      'remetente_id': user.id,
      'mensagem': text,
      'data_envio': DateTime.now().toIso8601String(),
      'lida': false,
    };

    setState(() {
      _mensagens.add(tempMessage);
    });
    _scrollToBottom();

    try {
      await _api.post(
        ApiEndpoints.enviarMensagem,
        body: {
          'remetente_id': user.id,
          'destinatario_id': widget.conversaId,
          'mensagem': text,
        },
      );
    } catch (e) {
      // Mensagem enviada localmente, erro silencioso
    } finally {
      setState(() => _isSending = false);
    }
  }

  Future<void> _sendLocation() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    try {
      // Verificar permissão
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Permissão de localização negada'),
            ),
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permissão de localização negada permanentemente'),
          ),
        );
        return;
      }

      // Obter localização
      final position = await Geolocator.getCurrentPosition();
      final locationMessage =
          '📍 Localização: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';

      setState(() => _isSending = true);

      // Adicionar mensagem localmente
      final tempMessage = {
        'id': 'temp_${DateTime.now().millisecondsSinceEpoch}',
        'remetente_id': user.id,
        'mensagem': locationMessage,
        'data_envio': DateTime.now().toIso8601String(),
        'lida': false,
      };

      setState(() {
        _mensagens.add(tempMessage);
      });
      _scrollToBottom();

      await _api.post(
        ApiEndpoints.enviarMensagem,
        body: {
          'remetente_id': user.id,
          'destinatario_id': widget.conversaId,
          'mensagem': locationMessage,
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao enviar localização: $e')),
      );
    } finally {
      setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      backgroundColor: AppColors.gray100,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: AppColors.primarySurface,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  widget.nomeContato[0].toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.nomeContato,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _mensagens.length,
                    itemBuilder: (context, index) {
                      final mensagem = _mensagens[index];
                      final isMe = mensagem['remetente_id'] == user?.id;
                      return _buildMessage(mensagem, isMe);
                    },
                  ),
          ),

          // Input area
          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: MediaQuery.of(context).padding.bottom + 12,
            ),
            decoration: BoxDecoration(
              color: AppColors.white,
              boxShadow: [
                BoxShadow(
                  color: AppColors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Location button
                IconButton(
                  icon: const Icon(Icons.location_on_outlined),
                  color: AppColors.primary,
                  onPressed: _sendLocation,
                  tooltip: 'Enviar localização',
                ),

                // Text field
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.gray100,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: _messageController,
                      focusNode: _focusNode,
                      decoration: const InputDecoration(
                        hintText: 'Digite sua mensagem...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Send button
                Container(
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: _isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation(AppColors.white),
                            ),
                          )
                        : const Icon(Icons.send),
                    color: AppColors.white,
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(Map<String, dynamic> mensagem, bool isMe) {
    final text = mensagem['mensagem'] ?? '';
    final dataStr = mensagem['data_envio'];
    final data = dataStr != null ? DateTime.tryParse(dataStr) : null;
    final lida = mensagem['lida'] ?? false;

    // Detectar mensagem de localização
    final isLocation = text.startsWith('📍 Localização:');

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isMe ? AppColors.primary : AppColors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (isLocation)
              _buildLocationMessage(text, isMe)
            else
              Text(
                text,
                style: TextStyle(
                  color: isMe ? AppColors.white : AppColors.textPrimary,
                  fontSize: 15,
                ),
              ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (data != null)
                  Text(
                    DateFormat('HH:mm').format(data),
                    style: TextStyle(
                      fontSize: 11,
                      color: isMe
                          ? AppColors.white.withOpacity(0.7)
                          : AppColors.gray500,
                    ),
                  ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    lida ? Icons.done_all : Icons.done,
                    size: 14,
                    color: lida
                        ? AppColors.white
                        : AppColors.white.withOpacity(0.7),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationMessage(String text, bool isMe) {
    // Extrair coordenadas
    final match = RegExp(r'(-?\d+\.?\d*),\s*(-?\d+\.?\d*)').firstMatch(text);
    final lat = match?.group(1) ?? '';
    final lng = match?.group(2) ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.location_on,
              color: isMe ? AppColors.white : AppColors.primary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Localização compartilhada',
              style: TextStyle(
                color: isMe ? AppColors.white : AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'LAT: $lat\nLNG: $lng',
          style: TextStyle(
            fontSize: 12,
            color: isMe
                ? AppColors.white.withOpacity(0.8)
                : AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildMapButton(
              'Google Maps',
              Icons.map,
              isMe,
              () => _openGoogleMaps(lat, lng),
            ),
            const SizedBox(width: 8),
            _buildMapButton(
              'Waze',
              Icons.navigation,
              isMe,
              () => _openWaze(lat, lng),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMapButton(
    String label,
    IconData icon,
    bool isMe,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isMe
              ? AppColors.white.withOpacity(0.2)
              : AppColors.primarySurface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isMe ? AppColors.white : AppColors.primary,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isMe ? AppColors.white : AppColors.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openGoogleMaps(String lat, String lng) async {
    final url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void _openWaze(String lat, String lng) async {
    final url = Uri.parse('https://waze.com/ul?ll=$lat,$lng&navigate=yes');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }
}
