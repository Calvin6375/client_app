import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:pretium/features/splash/screens/splash_page.dart';
import 'package:pretium/features/splash/screens/splash_page_1.dart';
import 'package:pretium/features/auth/screens/login_page.dart';
import 'package:pretium/features/auth/screens/register_page.dart';
import 'package:pretium/features/home/screens/landing_page.dart';
import 'package:pretium/features/topup/screens/topup_page.dart';
import 'package:pretium/features/swap/screens/swap_page.dart';
import 'package:pretium/app/route_names.dart';
import 'package:pretium/services/notification_service.dart';

// Global flag to track Firebase initialization status
bool _firebaseInitialized = false;

// Background message handler - must be top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await NotificationService.backgroundMessageHandler(message);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase with error handling
  await _initializeFirebase();
  
  // Register background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  
  // Initialize FCM notifications (after Firebase is initialized)
  await NotificationService.initialize();
  
  // Setup foreground message handler
  NotificationService.setupForegroundHandler();
  
  runApp(const MyApp());
}

Future<void> _initializeFirebase() async {
  try {
    // Check if Firebase is already initialized
    if (Firebase.apps.isNotEmpty) {
      debugPrint('✅ Firebase already initialized');
      _firebaseInitialized = true;
      return;
    }
    
    // Initialize Firebase
    await Firebase.initializeApp();
    _firebaseInitialized = true;
    debugPrint('✅ Firebase initialized successfully');
    
    // Verify initialization by checking if we can access Firebase app
    final app = Firebase.app();
    debugPrint('✅ Firebase app verified: ${app.name}');
    
  } catch (e, stackTrace) {
    _firebaseInitialized = false;
    debugPrint('❌ Firebase initialization error: $e');
    debugPrint('Stack trace: $stackTrace');
    debugPrint('');
    
    // Platform-specific error messages
    if (Platform.isIOS) {
      debugPrint('⚠️  FIREBASE SETUP REQUIRED FOR iOS:');
      debugPrint('1. Ensure GoogleService-Info.plist exists at: ios/Runner/GoogleService-Info.plist');
      debugPrint('2. Open ios/Runner.xcworkspace (NOT .xcodeproj) in Xcode');
      debugPrint('3. Verify GoogleService-Info.plist is in the Runner folder in Xcode');
      debugPrint('4. Select the file and check "Target Membership" → "Runner" is checked');
      debugPrint('5. Clean build: flutter clean && cd ios && rm -rf Pods Podfile.lock && pod install && cd ..');
      debugPrint('6. Rebuild: flutter run');
    } else if (Platform.isAndroid) {
      debugPrint('⚠️  FIREBASE SETUP REQUIRED FOR ANDROID:');
      debugPrint('1. Ensure google-services.json exists at: android/app/google-services.json');
      debugPrint('2. Verify the file is properly configured in build.gradle');
    }
    
    debugPrint('');
    debugPrint('App will continue but Firebase features may not work.');
  }
}

// Helper function to check if Firebase is initialized
bool isFirebaseInitialized() => _firebaseInitialized;

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  static const Color brandPrimary = Color(0xFF0097A7); // Teal-blue from logo

  ThemeData _buildLightTheme() {
    final base = ThemeData(useMaterial3: true, brightness: Brightness.light);
    final scheme = ColorScheme.fromSeed(
      seedColor: brandPrimary,
      brightness: Brightness.light,
    ).copyWith(primary: brandPrimary, onPrimary: Colors.white);
    return base.copyWith(
      colorScheme: scheme,
      primaryColor: brandPrimary,
      appBarTheme: const AppBarTheme(
        backgroundColor: brandPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: brandPrimary,
          foregroundColor: Colors.white,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: brandPrimary,
          side: const BorderSide(color: brandPrimary, width: 1.5),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: brandPrimary),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: brandPrimary,
        foregroundColor: Colors.white,
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    final base = ThemeData(useMaterial3: true, brightness: Brightness.dark);
    final scheme = ColorScheme.fromSeed(
      seedColor: brandPrimary,
      brightness: Brightness.dark,
    ).copyWith(primary: brandPrimary, onPrimary: Colors.white);
    return base.copyWith(
      colorScheme: scheme,
      primaryColor: brandPrimary,
      appBarTheme: const AppBarTheme(
        backgroundColor: brandPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: brandPrimary,
          foregroundColor: Colors.white,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: brandPrimary,
          side: const BorderSide(color: brandPrimary, width: 1.5),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: brandPrimary),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: brandPrimary,
        foregroundColor: Colors.white,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TruePay',
      debugShowCheckedModeBanner: false,
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      themeMode: ThemeMode.system,
      initialRoute: RouteNames.splash,
      routes: {
        RouteNames.splash: (context) => const SplashPage(),
        RouteNames.splashPage1: (context) => const SplashPage1(),
        RouteNames.login: (context) => const LoginPage(),
        RouteNames.register: (context) => const RegisterPage(),
        RouteNames.home: (context) => LandingPage(),
        RouteNames.topup: (context) => const TopUpPage(),
        RouteNames.swap: (context) => const SwapPage(),
      },
    );
  }
}
