import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Service for handling Firebase Cloud Messaging (FCM) notifications
class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  
  /// Initialize FCM with proper APNS token handling for iOS
  static Future<void> initialize() async {
    try {
      // Request notification permissions
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
        debugPrint('✅ SUCCESS: User granted notification permission');
        
        // On iOS, we MUST get the APNS token before initializing FCM
        bool apnsTokenAvailable = true;
        if (Platform.isIOS) {
          try {
            // Request APNS token - this is required before FCM can work on iOS
            final apnsToken = await _messaging.getAPNSToken();
            if (apnsToken != null) {
              debugPrint('✅ SUCCESS: APNS token obtained: ${apnsToken.substring(0, 20)}...');
              apnsTokenAvailable = true;
            } else {
              debugPrint('⚠️  WARNING: APNS token is null. This may happen in simulator.');
              debugPrint('   Skipping FCM token retrieval (will work on real device)');
              apnsTokenAvailable = false;
              
              // Set up listener for when APNS token becomes available (on real device)
              _setupAPNSTokenListener();
            }
          } catch (e) {
            debugPrint('⚠️  WARNING: Could not get APNS token: $e');
            debugPrint('   This is normal in simulator. Will work on real device.');
            apnsTokenAvailable = false;
            _setupAPNSTokenListener();
          }
        }
        
        // Now initialize FCM and get the FCM token (only if APNS token is available on iOS)
        if (!Platform.isIOS || apnsTokenAvailable) {
          try {
            final fcmToken = await _messaging.getToken();
            if (fcmToken != null) {
              debugPrint('✅ SUCCESS: FCM initialized successfully');
              debugPrint('   FCM Token: ${fcmToken.substring(0, 20)}...');
              
              // Listen for token refresh
              _messaging.onTokenRefresh.listen((newToken) {
                debugPrint('🔄 FCM token refreshed: ${newToken.substring(0, 20)}...');
                // TODO: Update token on your backend
              });
            } else {
              debugPrint('⚠️  WARNING: FCM token is null');
            }
          } catch (e) {
            debugPrint('🚨 ERROR: Failed to initialize FCM');
            debugPrint('   Error: $e');
            if (e.toString().contains('apns-token-not-set')) {
              debugPrint('');
              debugPrint('💡 SOLUTION: APNS token not set. This usually happens when:');
              debugPrint('   1. Running on iOS Simulator (APNS tokens not available)');
              debugPrint('   2. App not properly configured for push notifications');
              debugPrint('   3. Need to test on a real iOS device');
              debugPrint('');
              debugPrint('   To fix:');
              debugPrint('   - Test on a real iOS device (not simulator)');
              debugPrint('   - Ensure push notification capability is enabled in Xcode');
              debugPrint('   - Check that GoogleService-Info.plist is properly configured');
            }
          }
        }
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        debugPrint('✅ SUCCESS: User granted provisional notification permission');
      } else {
        debugPrint('⚠️  WARNING: User denied notification permission');
      }
    } catch (e, stackTrace) {
      debugPrint('🚨 ERROR: Failed to request notification permission');
      debugPrint('   Error: $e');
      debugPrint('   Stack trace: $stackTrace');
    }
  }
  
  /// Get the current FCM token
  static Future<String?> getToken() async {
    try {
      return await _messaging.getToken();
    } catch (e) {
      debugPrint('🚨 ERROR: Failed to get FCM token: $e');
      return null;
    }
  }
  
  /// Setup foreground message handler
  static void setupForegroundHandler() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('📨 Received foreground message: ${message.messageId}');
      debugPrint('   Title: ${message.notification?.title}');
      debugPrint('   Body: ${message.notification?.body}');
      // TODO: Show local notification or update UI
    });
  }
  
  /// Setup listener for when APNS token becomes available (on real device)
  static void _setupAPNSTokenListener() {
    if (!Platform.isIOS) return;
    
    // Poll for APNS token (will be available on real device)
    Future.delayed(const Duration(seconds: 2), () async {
      try {
        final apnsToken = await _messaging.getAPNSToken();
        if (apnsToken != null) {
          debugPrint('✅ SUCCESS: APNS token now available: ${apnsToken.substring(0, 20)}...');
          // Now try to get FCM token
          try {
            final fcmToken = await _messaging.getToken();
            if (fcmToken != null) {
              debugPrint('✅ SUCCESS: FCM token obtained: ${fcmToken.substring(0, 20)}...');
            }
          } catch (e) {
            debugPrint('⚠️  WARNING: Could not get FCM token even with APNS token: $e');
          }
        }
      } catch (e) {
        // Silently fail - this is expected in simulator
      }
    });
  }
  
  /// Setup background message handler
  /// This must be a top-level function
  @pragma('vm:entry-point')
  static Future<void> backgroundMessageHandler(RemoteMessage message) async {
    debugPrint('📨 Received background message: ${message.messageId}');
    // TODO: Handle background message
  }
}
