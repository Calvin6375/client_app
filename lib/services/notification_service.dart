import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:pretium/models/notification_model.dart';
import 'package:pretium/utils/logger.dart';
import 'package:pretium/app/route_names.dart';
import 'package:http/http.dart' as http;

/// Service for handling Firebase Cloud Messaging (FCM) notifications
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  
  bool _isInitialized = false;
  String? _currentUserId;
  GlobalKey<NavigatorState>? _navigatorKey;

  /// Initialize the notification service
  /// Should be called once at app startup
  Future<void> initialize({
    GlobalKey<NavigatorState>? navigatorKey,
  }) async {
    if (_isInitialized) {
      Logger.info('NotificationService already initialized');
      return;
    }

    _navigatorKey = navigatorKey;

    try {
      // 1. Initialize local notifications (for Android foreground notifications)
      await _initializeLocalNotifications();

      // 2. Request notification permissions
      await _requestPermission();

      // 3. Set up message handlers
      _setupMessageHandlers();

      // 4. Set up token refresh listener
      _setupTokenRefreshListener();

      _isInitialized = true;
      Logger.success('NotificationService initialized successfully');
    } catch (e, stackTrace) {
      Logger.error('Failed to initialize NotificationService', e, stackTrace);
    }
  }

  /// Initialize local notifications for Android foreground notifications
  Future<void> _initializeLocalNotifications() async {
    if (!Platform.isAndroid) return;

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    await _localNotifications.initialize(
      const InitializationSettings(
        android: initializationSettingsAndroid,
      ),
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channel for Android 8.0+
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      description: 'This channel is used for important notifications.',
      importance: Importance.high,
      playSound: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    Logger.info('Local notifications initialized for Android');
  }

  /// Request notification permissions
  Future<bool> _requestPermission() async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        Logger.success('User granted notification permission');
        return true;
      } else if (settings.authorizationStatus ==
          AuthorizationStatus.provisional) {
        Logger.info('User granted provisional notification permission');
        return true;
      } else {
        Logger.warning('User denied notification permission');
        return false;
      }
    } catch (e) {
      Logger.error('Failed to request notification permission', e);
      return false;
    }
  }

  /// Set up message handlers for foreground, background, and app launch
  void _setupMessageHandlers() {
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      Logger.info('📨 Received foreground message: ${message.messageId}');
      Logger.info('   Title: ${message.notification?.title}');
      Logger.info('   Body: ${message.notification?.body}');
      Logger.info('   Data: ${message.data}');

      // Show local notification for foreground messages
      _showLocalNotification(message);
    });

    // Handle notification taps when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      Logger.info('📱 Notification opened app from background');
      _handleNotificationTap(message);
    });

    // Check if app was opened from terminated state via notification
    _messaging.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        Logger.info('📱 App opened from terminated state via notification');
        _handleNotificationTap(message);
      }
    });
  }

  /// Set up token refresh listener
  void _setupTokenRefreshListener() {
    _messaging.onTokenRefresh.listen((newToken) {
      Logger.info('🔄 FCM token refreshed: ${newToken.substring(0, 20)}...');
      if (_currentUserId != null) {
        saveFCMToken(_currentUserId!, newToken);
      }
    });
  }

  /// Show local notification (for Android foreground messages)
  Future<void> _showLocalNotification(RemoteMessage message) async {
    if (!Platform.isAndroid) return;

    final notification = message.notification;
    if (notification == null) return;

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'high_importance_channel',
      'High Importance Notifications',
      channelDescription: 'This channel is used for important notifications.',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      message.hashCode,
      notification.title,
      notification.body,
      notificationDetails,
      payload: message.data.toString(),
    );
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    Logger.info('Notification tapped: ${response.payload}');
    // Navigation will be handled by _handleNotificationTap
  }

  /// Handle notification tap and navigate to appropriate screen
  void _handleNotificationTap(RemoteMessage message) {
    final notificationType = message.data['type'];
    // actionUrl is available in message.data['actionUrl'] for future use

    Logger.info('Handling notification tap - Type: $notificationType');

    if (_navigatorKey?.currentState == null) {
      Logger.warning('Navigator not available, cannot handle notification tap');
      return;
    }

    final navigator = _navigatorKey!.currentState!;

    // Navigate based on notification type
    switch (notificationType) {
      case 'payment_completed':
        // Navigate to transactions or home screen
        navigator.pushNamedAndRemoveUntil(
          RouteNames.home,
          (route) => false,
        );
        break;
      case 'wallet_credited':
      case 'wallet_debited':
        // Navigate to wallet/home screen
        navigator.pushNamedAndRemoveUntil(
          RouteNames.home,
          (route) => false,
        );
        break;
      case 'transaction_completed':
        // Navigate to transactions screen
        navigator.pushNamedAndRemoveUntil(
          RouteNames.home,
          (route) => false,
        );
        break;
      default:
        // Navigate to home screen
        navigator.pushNamedAndRemoveUntil(
          RouteNames.home,
          (route) => false,
        );
        break;
    }
  }

  /// Setup notifications for a user (call after login/registration)
  Future<void> setupNotifications(String userId) async {
    _currentUserId = userId;

    try {
      // 1. Request permission (if not already granted)
      await _requestPermission();

      // 2. Get FCM token
      String? token = await getFCMToken();

      if (token != null) {
        // 3. Save to Firestore
        await saveFCMToken(userId, token);
        Logger.success('FCM token saved for user: $userId');
      } else {
        Logger.warning('FCM token is null, cannot save to Firestore');
      }

      // 4. Token refresh listener is already set up in initialize()
    } catch (e, stackTrace) {
      Logger.error('Failed to setup notifications for user', e, stackTrace);
    }
  }

  /// Get FCM token
  Future<String?> getFCMToken() async {
    try {
      // On iOS, ensure APNS token is available first
      if (Platform.isIOS) {
        try {
          final apnsToken = await _messaging.getAPNSToken();
          if (apnsToken == null) {
            Logger.warning(
                'APNS token is null. This may happen in simulator. Will work on real device.');
            // Set up listener for when APNS token becomes available
            _setupAPNSTokenListener();
            return null;
          }
        } catch (e) {
          Logger.warning('Could not get APNS token: $e');
          Logger.warning('This is normal in simulator. Will work on real device.');
          _setupAPNSTokenListener();
          return null;
        }
      }

      final token = await _messaging.getToken();
      if (token != null) {
        Logger.info('FCM Token obtained: ${token.substring(0, 20)}...');
      }
      return token;
    } catch (e) {
      Logger.error('Failed to get FCM token', e);
      if (e.toString().contains('apns-token-not-set')) {
        Logger.warning(
            'APNS token not set. This usually happens when running on iOS Simulator.');
        Logger.warning('Test on a real iOS device for push notifications to work.');
      }
      return null;
    }
  }

  /// Setup listener for when APNS token becomes available (iOS)
  void _setupAPNSTokenListener() {
    if (!Platform.isIOS) return;

    // Poll for APNS token (will be available on real device)
    Future.delayed(const Duration(seconds: 2), () async {
      try {
        final apnsToken = await _messaging.getAPNSToken();
        if (apnsToken != null) {
          Logger.info('APNS token now available: ${apnsToken.substring(0, 20)}...');
          // Now try to get FCM token
          try {
            final fcmToken = await _messaging.getToken();
            if (fcmToken != null && _currentUserId != null) {
              Logger.info('FCM token obtained: ${fcmToken.substring(0, 20)}...');
              await saveFCMToken(_currentUserId!, fcmToken);
            }
          } catch (e) {
            Logger.warning('Could not get FCM token even with APNS token: $e');
          }
        }
      } catch (e) {
        // Silently fail - this is expected in simulator
      }
    });
  }

  /// Save FCM token to Firestore
  Future<void> saveFCMToken(String userId, String token) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      });
      Logger.success('FCM token saved successfully for user: $userId');
    } catch (e) {
      Logger.error('Error saving FCM token', e);
      rethrow;
    }
  }

  /// Get notifications stream from Firestore
  Stream<List<NotificationModel>> getNotificationsStream(String userId) {
    return FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return NotificationModel.fromFirestore(doc);
      }).toList();
    });
  }

  /// Mark notification as read using REST API
  Future<void> markNotificationAsRead(
    String notificationId, {
    String? authToken,
  }) async {
    try {
      final url = Uri.parse(
          'https://us-central1-truepay-72060.cloudfunctions.net/notificationsApi/notifications/$notificationId/read');

      final headers = <String, String>{
        'Content-Type': 'application/json',
      };

      if (authToken != null) {
        headers['Authorization'] = 'Bearer $authToken';
      }

      final response = await http.patch(url, headers: headers);

      if (response.statusCode == 200) {
        Logger.success('Notification marked as read: $notificationId');
      } else {
        Logger.warning(
            'Failed to mark notification as read. Status: ${response.statusCode}');
      }
    } catch (e) {
      Logger.error('Error marking notification as read', e);
      // Fallback to direct Firestore update if API fails
      try {
        await FirebaseFirestore.instance
            .collection('notifications')
            .doc(notificationId)
            .update({'read': true});
        Logger.info('Notification marked as read via Firestore fallback');
      } catch (firestoreError) {
        Logger.error('Firestore fallback also failed', firestoreError);
      }
    }
  }

  /// Marks notifications for [userId] as read (up to [limit] most recent, same window as the list stream).
  Future<void> markAllNotificationsAsRead(String userId, {int limit = 100}) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      final unread = snap.docs.where((d) {
        final data = d.data();
        return data['read'] != true;
      }).toList();

      if (unread.isEmpty) {
        Logger.info('markAllNotificationsAsRead: nothing unread in window');
        return;
      }

      WriteBatch batch = FirebaseFirestore.instance.batch();
      var pending = 0;
      for (final doc in unread) {
        batch.update(doc.reference, {
          'read': true,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        pending++;
        if (pending >= 450) {
          await batch.commit();
          batch = FirebaseFirestore.instance.batch();
          pending = 0;
        }
      }
      if (pending > 0) {
        await batch.commit();
      }
      Logger.success('Marked ${unread.length} notification(s) as read');
    } catch (e, st) {
      Logger.error('markAllNotificationsAsRead failed', e, st);
      rethrow;
    }
  }

  /// Mark notification as read directly via Firestore (if rules allow)
  Future<void> markNotificationAsReadDirect(String notificationId) async {
    try {
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(notificationId)
          .update({'read': true});
      Logger.success('Notification marked as read: $notificationId');
    } catch (e) {
      Logger.error('Error marking notification as read', e);
      rethrow;
    }
  }

  /// Clear current user (call on logout)
  void clearCurrentUser() {
    _currentUserId = null;
  }
}

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  Logger.info('Handling background message: ${message.messageId}');
  Logger.info('Title: ${message.notification?.title}');
  Logger.info('Body: ${message.notification?.body}');
  Logger.info('Data: ${message.data}');
  // Background message handling is done here
  // You can show local notifications if needed
}
