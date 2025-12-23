import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Notification service for handling FCM notifications
/// - Subscribes to 'general' topic on app start
/// - Shows local notifications when app is in foreground
/// - Background/terminated notifications are handled automatically by FCM
class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  /// Initialize notification service
  /// Call this in main() before runApp()
  static Future<void> initialize() async {
    // Initialize local notifications for foreground display first (doesn't require FCM)
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _local.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create Android notification channel
    const androidChannel = AndroidNotificationChannel(
      'general_channel',
      'General Notifications',
      description: 'Notifications for announcements and events',
      importance: Importance.high,
      playSound: true,
    );

    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    // Handle foreground messages - show local notification
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    debugPrint('✅ Local notification service initialized');

    // FCM operations in background - don't block app startup
    _initializeFCM();
  }

  /// Initialize FCM in background (non-blocking)
  static Future<void> _initializeFCM() async {
    try {
      // Request notification permissions with timeout
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('⚠️ Notification permission request timed out');
          return const NotificationSettings(
            authorizationStatus: AuthorizationStatus.notDetermined,
            alert: AppleNotificationSetting.notSupported,
            badge: AppleNotificationSetting.notSupported,
            sound: AppleNotificationSetting.notSupported,
            announcement: AppleNotificationSetting.notSupported,
            carPlay: AppleNotificationSetting.notSupported,
            criticalAlert: AppleNotificationSetting.notSupported,
            lockScreen: AppleNotificationSetting.notSupported,
            notificationCenter: AppleNotificationSetting.notSupported,
            showPreviews: AppleShowPreviewSetting.never,
            timeSensitive: AppleNotificationSetting.notSupported,
            providesAppNotificationSettings: AppleNotificationSetting.notSupported,
          );
        },
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('✅ Notification permissions granted');
      } else {
        debugPrint('⚠️ Notification permissions denied or not determined');
      }

      // Subscribe to global 'general' topic with timeout
      await _messaging.subscribeToTopic('general').timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('⚠️ FCM topic subscription timed out, will retry later');
        },
      );
      debugPrint('✅ Subscribed to general notification topic');
    } catch (e) {
      debugPrint('⚠️ FCM initialization failed (will retry automatically): $e');
      // FCM will retry automatically, don't block the app
    }
  }

  /// Handle notification tap
  static void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
    // TODO: Navigate to relevant screen based on notification type
  }

  /// Handle foreground messages by showing local notification
  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('Foreground message received: ${message.notification?.title}');

    if (message.notification != null) {
      await _local.show(
        message.hashCode,
        message.notification!.title,
        message.notification!.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'general_channel',
            'General Notifications',
            channelDescription: 'Notifications for announcements and events',
            importance: Importance.high,
            priority: Priority.high,
            showWhen: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: message.data['type'],
      );
    }
  }

  /// Unsubscribe from general topic (optional, for testing)
  static Future<void> unsubscribe() async {
    await _messaging.unsubscribeFromTopic('general');
    debugPrint('❌ Unsubscribed from general topic');
  }
}