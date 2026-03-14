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
import 'package:pretium/features/notifications/screens/notifications_page.dart';
import 'package:pretium/services/notification_service.dart';
import 'package:provider/provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase with error handling
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    Logger.success('Firebase initialized successfully');
    
    // Register background message handler (must be done before runApp)
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    
    // Initialize NotificationService (will be fully initialized in MyApp)
    // We can't fully initialize here because we need the navigator key
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

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    // Initialize NotificationService after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService().initialize(navigatorKey: _navigatorKey);
    });
  }

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
            navigatorKey: _navigatorKey,
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
              RouteNames.notifications: (context) => const NotificationsPage(),
            },
          );
        },
      ),
    );
  }
}
