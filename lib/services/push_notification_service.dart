import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class PushNotificationService {
  PushNotificationService._internal();

  static final PushNotificationService instance =
      PushNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const AndroidNotificationChannel _androidChannel =
      AndroidNotificationChannel(
        'legebre_general_notifications',
        'Legebere Alerts',
        description: 'General notifications from Legebere',
        importance: Importance.high,
      );

  Future<void> initialize() async {
    if (_initialized) return;

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );

    await _notificationsPlugin.initialize(initializationSettings);

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_androidChannel);

    _initialized = true;
  }

  Future<void> handleRemoteMessage(RemoteMessage message) async {
    if (!_initialized) {
      await initialize();
    }

    try {
      final notification = message.notification;
      final title =
          notification?.title ??
          message.data['title']?.toString() ??
          'Legebere';
      final body = notification?.body ?? message.data['body']?.toString() ?? '';

      if (title.isEmpty && body.isEmpty) return;

      await _notificationsPlugin.show(
        message.hashCode,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _androidChannel.id,
            _androidChannel.name,
            channelDescription: _androidChannel.description,
            icon: notification?.android?.smallIcon ?? '@mipmap/ic_launcher',
            importance: Importance.high,
            priority: Priority.high,
            ticker: 'Legebere',
          ),
        ),
        payload: message.data.isEmpty ? null : jsonEncode(message.data),
      );
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Failed to show notification: $error');
        debugPrint(stackTrace.toString());
      }
    }
  }
}
