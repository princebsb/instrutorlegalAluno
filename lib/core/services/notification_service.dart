import 'dart:ui' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static final FirebaseMessaging _firebaseMessaging =
      FirebaseMessaging.instance;

  static Future<void> initialize() async {
    // Configuração Android
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // Configuração iOS
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Canal de notificação Android
    const androidChannel = AndroidNotificationChannel(
      'instrutor_legal_channel',
      'Instrutor Legal',
      description: 'Notificações do Instrutor Legal',
      importance: Importance.high,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    // Configurar Firebase Messaging
    await _setupFirebaseMessaging();
  }

  static Future<void> _setupFirebaseMessaging() async {
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true, badge: true, sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      String? token = await _firebaseMessaging.getToken();
      print('FCM Token: $token');

      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        print('FCM Token atualizado: $newToken');
      });
    }

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
  }

  static void _handleForegroundMessage(RemoteMessage message) {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null && android != null) {
      showNotification(
        title: notification.title ?? 'Instrutor Legal',
        body: notification.body ?? '',
        payload: message.data.toString(),
      );
    }
  }

  static void _handleMessageOpenedApp(RemoteMessage message) {
    print('Mensagem aberta: ${message.data}');
  }

  static void _onNotificationTapped(NotificationResponse response) {
    // Tratar clique na notificação
    print('Notificação clicada: ${response.payload}');
  }

  static Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'instrutor_legal_channel',
      'Instrutor Legal',
      channelDescription: 'Notificações do Instrutor Legal',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFF00A859),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      details,
      payload: payload,
    );
  }

  static Future<void> showAulaNotification({
    required String titulo,
    required String mensagem,
    required String aulaId,
  }) async {
    await showNotification(
      title: titulo,
      body: mensagem,
      payload: 'aula:$aulaId',
    );
  }

  static Future<void> showMensagemNotification({
    required String remetente,
    required String mensagem,
    required String conversaId,
  }) async {
    await showNotification(
      title: 'Nova mensagem de $remetente',
      body: mensagem,
      payload: 'mensagem:$conversaId',
    );
  }

  static Future<bool> requestPermission() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  static Future<String?> getToken() async {
    return await _firebaseMessaging.getToken();
  }

  static Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }

  static Future<void> cancel(int id) async {
    await _notifications.cancel(id);
  }
}
