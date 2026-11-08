import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/services/user_notification_service.dart';
import '../models/user_notification.dart';

// Top-level function for background messages
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("Handling a background message: ${message.messageId}");
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  FirebaseMessaging? get _firebaseMessaging {
    try {
      return FirebaseMessaging.instance;
    } catch (_) {
      return null;
    }
  }

  final FlutterLocalNotificationsPlugin _localNotificationsPlugin = FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    final messaging = _firebaseMessaging;
    if (messaging == null) return;

    // 1. Request permissions (shows prompt on iOS)
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    debugPrint('User granted permission: ${settings.authorizationStatus}');

    // 2. Configure Local Notifications for foreground display
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings();
    const InitializationSettings initSettings = InitializationSettings(android: androidSettings, iOS: iosSettings);
    
    await _localNotificationsPlugin.initialize(initSettings);

    // Create a high importance channel for Android
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel', // id
      'High Importance Notifications', // title
      description: 'This channel is used for important notifications.', // description
      importance: Importance.high,
    );

    if (Platform.isAndroid) {
      await _localNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }

    // 3. Listen to foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Got a message whilst in the foreground!');
      debugPrint('Message data: ${message.data}');

      if (message.notification != null) {
        debugPrint('Message also contained a notification: ${message.notification}');
        _showForegroundNotification(message, channel);
        _recordIncomingFcmNotification(message);
      }
    });

    // 4. Listen to notification opened events (background -> foreground)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('Notification opened from background: ${message.messageId}');
      _recordIncomingFcmNotification(message);
    });

    // 5. Check if app was launched by tapping a notification (terminated -> foreground)
    messaging.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        debugPrint('Notification launched app from terminated: ${message.messageId}');
        _recordIncomingFcmNotification(message);
      }
    });

    // 6. Setup background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    _isInitialized = true;
  }

  Future<bool> areNotificationsEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pref = prefs.getBool('notifications_enabled');
      if (pref != null) return pref;
    } catch (_) {}

    try {
      final messaging = _firebaseMessaging;
      if (messaging != null) {
        final settings = await messaging.getNotificationSettings();
        return settings.authorizationStatus == AuthorizationStatus.authorized ||
               settings.authorizationStatus == AuthorizationStatus.provisional;
      }
    } catch (_) {}
    return true;
  }

  Future<bool> setNotificationsEnabled(bool enable) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notifications_enabled', enable);
    } catch (_) {}

    if (enable) {
      try {
        final messaging = _firebaseMessaging;
        if (messaging != null) {
          final settings = await messaging.requestPermission(
            alert: true,
            badge: true,
            sound: true,
          );
          final granted = settings.authorizationStatus == AuthorizationStatus.authorized ||
                          settings.authorizationStatus == AuthorizationStatus.provisional;
          if (!granted) {
            try {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('notifications_enabled', false);
            } catch (_) {}
            return false;
          }
        }
      } catch (_) {}
    }
    return enable;
  }

  void _recordIncomingFcmNotification(RemoteMessage message) async {
    if (message.notification == null) return;
    final enabled = await areNotificationsEnabled();
    if (!enabled) return;
    try {
      final notif = UserNotification(
        id: message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
        title: message.notification?.title ?? '',
        body: message.notification?.body ?? '',
        timestamp: message.sentTime ?? DateTime.now(),
        isRead: false,
        type: message.data['type'] ?? 'general',
        bookId: message.data['bookId'] is String ? message.data['bookId'] as String : null,
      );
      UserNotificationService().addNotification(notif);
    } catch (e) {
      debugPrint('Error recording incoming FCM notification: $e');
    }
  }

  void _showForegroundNotification(RemoteMessage message, AndroidNotificationChannel channel) async {
    final enabled = await areNotificationsEnabled();
    if (!enabled) return;
    _localNotificationsPlugin.show(
      message.notification.hashCode,
      message.notification?.title,
      message.notification?.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  Future<String?> getToken() async {
    if (const bool.fromEnvironment('USE_FIREBASE_EMULATORS')) return null;
    final messaging = _firebaseMessaging;
    if (messaging == null) return null;
    // For iOS, ensure APNs token is available before getting FCM token
    if (Platform.isIOS) {
      final apnsToken = await messaging.getAPNSToken();
      if (apnsToken == null) {
        debugPrint('APNS token not available yet. FCM token might fail.');
      }
    }
    return await messaging.getToken();
  }

  Future<void> deleteToken() async {
    try {
      final messaging = _firebaseMessaging;
      if (messaging != null) {
        await messaging.deleteToken();
      }
    } catch (e) {
      debugPrint('Error deleting FCM token: $e');
    }
  }
}
