import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:pretium/firebase_options.dart';
import 'package:pretium/features/splash/screens/splash_page.dart';
import 'package:pretium/features/splash/screens/splash_page_1.dart';
import 'package:pretium/features/auth/screens/login_page.dart';
import 'package:pretium/features/auth/screens/register_page.dart';
import 'package:pretium/features/home/screens/landing_page.dart';
import 'package:pretium/features/topup/screens/topup_page.dart';
import 'package:pretium/features/swap/screens/swap_page.dart';
import 'package:pretium/app/route_names.dart';
import 'package:pretium/utils/logger.dart';
import 'package:pretium/core/constants/app_colors.dart';
import 'package:pretium/core/theme/theme_provider.dart';
import 'package:pretium/features/wallet_verification/screens/wallet_verification_screen.dart';
import 'package:provider/provider.dart';

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  Logger.info('Handling background message: ${message.messageId}');
  // Handle background message here
}

/// Initialize Firebase Cloud Messaging
Future<void> _initializeFCM() async {
  try {
    final messaging = FirebaseMessaging.instance;

    // Request permission for notifications
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      Logger.success('User granted notification permission');
    } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
      Logger.info('User granted provisional notification permission');
    } else {
      Logger.warning('User declined or has not accepted notification permission');
    }

    // Get FCM token
    final token = await messaging.getToken();
    if (token != null) {
      Logger.info('FCM Token: $token');
      // TODO: Save token to Firestore or send to your backend
      // This token can be used by Cloud Functions to send push notifications
    }

    // Set up background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Handle foreground messages (optional)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      Logger.info('Received foreground message: ${message.messageId}');
      // Handle foreground message here
      // You can show a local notification or update UI
    });

    // Handle notification taps when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      Logger.info('Notification opened app: ${message.messageId}');
      // Navigate to specific screen based on message data
    });

    // Check if app was opened from a notification
    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      Logger.info('App opened from notification: ${initialMessage.messageId}');
      // Handle initial message
    }
  } catch (e) {
    Logger.error('Failed to initialize FCM', e);
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase with error handling
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    Logger.success('Firebase initialized successfully');
    
    // Initialize Firebase Cloud Messaging
    await _initializeFCM();
  } catch (e, stackTrace) {
    Logger.error('Firebase initialization failed', e, stackTrace);
    Logger.warning('App will continue but Firebase features may not work.');
  }
  
  runApp(const MyApp());
}

// Helper function to check if Firebase is initialized
bool isFirebaseInitialized() {
  try {
    return Firebase.apps.isNotEmpty;
  } catch (e) {
    return false;
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  ThemeData _buildLightTheme() {
    final colors = AppColors.light;
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: colors.background,
    );
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.brandPrimary,
      brightness: Brightness.light,
    ).copyWith(
      primary: colors.primary,
      onPrimary: Colors.white,
      secondary: colors.success,
      surface: colors.surface,
      onSurface: colors.textPrimary,
      background: colors.background,
      error: colors.error,
    );
    return base.copyWith(
      colorScheme: scheme,
      primaryColor: colors.primary,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent, // Transparent for glassmorphism
        foregroundColor: colors.textPrimary,
        elevation: 0,
        iconTheme: IconThemeData(color: colors.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: colors.surface,
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: colors.primary.withOpacity(0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.primary,
          side: BorderSide(color: colors.primary, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: colors.primary),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      dividerColor: colors.divider,
      dividerTheme: DividerThemeData(color: colors.divider),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.inputBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.inputBorderFocused, width: 2),
        ),
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    final colors = AppColors.dark;
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: colors.background,
    );
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.brandPrimary,
      brightness: Brightness.dark,
    ).copyWith(
      primary: colors.primary,
      onPrimary: colors.onPrimary,
      secondary: colors.success,
      surface: colors.surface,
      onSurface: colors.textPrimary,
      background: colors.background,
      error: colors.error,
    );
    return base.copyWith(
      colorScheme: scheme,
      primaryColor: colors.primary,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent, // Transparent for dark theme
        foregroundColor: colors.textPrimary,
        elevation: 0,
        iconTheme: IconThemeData(color: colors.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: colors.surface,
        elevation: 0,
        shadowColor: Colors.black.withOpacity(0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
          elevation: 2,
          shadowColor: colors.primary.withOpacity(0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.primary,
          side: BorderSide(color: colors.primary, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: colors.primary),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        elevation: 4,
      ),
      dividerColor: colors.divider,
      dividerTheme: DividerThemeData(color: colors.divider),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.inputBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.inputBorderFocused, width: 2),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'TruePay',
            debugShowCheckedModeBanner: false,
            theme: _buildLightTheme(), // Light theme with glassmorphism
            darkTheme: _buildDarkTheme(), // Dark fintech theme
            themeMode: themeProvider.themeMode, // Dynamic theme mode
            initialRoute: RouteNames.splash,
            routes: {
              RouteNames.splash: (context) => const SplashPage(),
              RouteNames.splashPage1: (context) => const SplashPage1(),
              RouteNames.login: (context) => const LoginPage(),
              RouteNames.register: (context) => const RegisterPage(),
              RouteNames.home: (context) => LandingPage(),
              RouteNames.topup: (context) => const TopUpPage(),
              RouteNames.swap: (context) => const SwapPage(),
              RouteNames.walletVerification: (context) =>
                  const WalletVerificationScreen(),
            },
          );
        },
      ),
    );
  }
}
