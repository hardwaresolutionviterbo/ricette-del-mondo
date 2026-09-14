import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _notificationChannelId = 'rdm_general';
const String _notificationChannelName = 'Ricette del Mondo';
const String _notificationChannelDescription = 'Notifiche di servizio e novità di Ricette del Mondo.';
const String _serviceNotificationsKey = 'rdm_pref_service_notifications';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Le notifiche con payload "notification" vengono mostrate automaticamente
  // da FCM quando l'app è in background/terminata. Questo handler resta pronto
  // per eventuali payload dati futuri, senza duplicare la notifica di sistema.
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  String? _token;

  Future<void> initialize() async {
    if (_initialized) return;

    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_serviceNotificationsKey) ?? true;
    if (!enabled) return;

    await _initializeLocalNotifications();

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      announcement: false,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      return;
    }

    await _messaging.setAutoInitEnabled(true);
    await _syncToken();

    _messaging.onTokenRefresh.listen((token) async {
      _token = token;
      await _syncToken(token);
    });

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenedMessage);
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) _handleOpenedMessage(initialMessage);

    FirebaseAuth.instance.authStateChanges().listen((_) async {
      if (_token != null) await _syncToken(_token);
    });

    _initialized = true;
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_serviceNotificationsKey, enabled);

    if (enabled) {
      await initialize();
      return;
    }

    final oldToken = _token;
    final user = FirebaseAuth.instance.currentUser;
    if (oldToken != null && user != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'fcmTokens': FieldValue.arrayRemove([oldToken]),
          'notificationsEnabled': false,
          'notificationsUpdatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (_) {
        // La preferenza locale resta comunque valida anche se la sincronizzazione cloud fallisce.
      }
    }

    await _messaging.setAutoInitEnabled(false);
    try {
      await _messaging.deleteToken();
    } catch (_) {
      // Il token può non esistere ancora: non è un errore per l'utente.
    }
    _token = null;
    _initialized = false;
  }

  Future<void> _initializeLocalNotifications() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    const settings = InitializationSettings(android: android, iOS: ios);

    await _local.initialize(
    settings: settings,
      onDidReceiveNotificationResponse: (_) {},
    );

    final androidPlugin = _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _notificationChannelId,
        _notificationChannelName,
        description: _notificationChannelDescription,
        importance: Importance.high,
      ),
    );
  }

  Future<void> _syncToken([String? token]) async {
    final current = token ?? await _messaging.getToken();
    if (current == null || current.isEmpty) return;
    _token = current;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'fcmTokens': FieldValue.arrayUnion([current]),
      'notificationsEnabled': true,
      'notificationsUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    final title = notification.title?.trim();
    final body = notification.body?.trim();
    if ((title == null || title.isEmpty) && (body == null || body.isEmpty)) return;

    await _local.show(
        id:       DateTime.now().millisecondsSinceEpoch.remainder(1 << 31),
        title:       title?.isNotEmpty == true ? title : 'Ricette del Mondo',
        body:       body ?? '',
        notificationDetails:       const NotificationDetails(
        android: AndroidNotificationDetails(
          _notificationChannelId,
          _notificationChannelName,
          channelDescription: _notificationChannelDescription,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: jsonEncode(message.data),
    );
  }

  void _handleOpenedMessage(RemoteMessage message) {
    // Il comportamento predefinito apre l'app. I dati sono conservati nel
    // payload per permettere in seguito di aprire una ricetta specifica.
  }
}
