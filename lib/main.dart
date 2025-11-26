import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:pretium/features/splash/screens/splash_page.dart';
import 'package:pretium/features/splash/screens/splash_page_1.dart';
import 'package:pretium/features/auth/screens/login_page.dart';
import 'package:pretium/features/auth/screens/register_page.dart';
import 'package:pretium/features/home/screens/landing_page.dart';
import 'package:pretium/features/topup/screens/topup_page.dart';
import 'package:pretium/features/swap/screens/swap_page.dart';
import 'package:pretium/app/route_names.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase with error handling
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
    debugPrint('');
    debugPrint('⚠️  FIREBASE SETUP REQUIRED:');
    debugPrint('For iOS: Download GoogleService-Info.plist from Firebase Console');
    debugPrint('1. Go to https://console.firebase.google.com/');
      debugPrint('2. Select project: truepay-72060');
    debugPrint('3. Add iOS app (if not added) with bundle ID: com.example.pretiumMock');
    debugPrint('4. Download GoogleService-Info.plist');
    debugPrint('5. Place it in: ios/Runner/GoogleService-Info.plist');
    debugPrint('');
    debugPrint('App will continue but Firebase features may not work.');
  }
  
  runApp(const MyApp());
}

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
