import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../constants/app_constants.dart';

class NotificationModel {
  final String id;
  final String titulo;
  final String mensagem;
  final String tipo;
  final bool lida;
  final DateTime createdAt;
  final Map<String, dynamic>? dados;

  NotificationModel({
    required this.id,
    required this.titulo,
    required this.mensagem,
    required this.tipo,
    required this.lida,
    required this.createdAt,
    this.dados,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id']?.toString() ?? '',
      titulo: json['titulo'] ?? '',
      mensagem: json['mensagem'] ?? '',
      tipo: json['tipo'] ?? 'geral',
      lida: json['lida'] ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      dados: json['dados'],
    );
  }
}

class NotificationProvider extends ChangeNotifier {
  final _api = ApiService();

  List<NotificationModel> _notifications = [];
  int _unreadCount = 0;
  final bool _isLoading = false;
  Timer? _pollingTimer;

  List<NotificationModel> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;
  bool get hasUnread => _unreadCount > 0;

  void startPolling(String userId) {
    // Carregar imediatamente
    loadNotifications(userId);

    // Polling a cada 15 segundos
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => loadNotifications(userId),
    );
  }

  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  Future<void> loadNotifications(String userId) async {
    try {
      final response = await _api.get(ApiEndpoints.notificacoes(userId));
      final List<dynamic> data = response['notificacoes'] ?? [];

      _notifications =
          data.map((json) => NotificationModel.fromJson(json)).toList();

      _unreadCount = _notifications.where((n) => !n.lida).length;
      notifyListeners();
    } catch (e) {
      // Silencioso - mantém dados anteriores
    }
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await _api.patch(ApiEndpoints.marcarLida(notificationId));

      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1) {
        final notif = _notifications[index];
        _notifications[index] = NotificationModel(
          id: notif.id,
          titulo: notif.titulo,
          mensagem: notif.mensagem,
          tipo: notif.tipo,
          lida: true,
          createdAt: notif.createdAt,
          dados: notif.dados,
        );
        _unreadCount = _notifications.where((n) => !n.lida).length;
        notifyListeners();
      }
    } catch (e) {
      // Silencioso
    }
  }

  Future<void> markAllAsRead(String userId) async {
    for (final notif in _notifications.where((n) => !n.lida)) {
      await markAsRead(notif.id);
    }
  }

  void clearNotifications() {
    _notifications = [];
    _unreadCount = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}
