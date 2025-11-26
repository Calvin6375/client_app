import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase with error handling
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    Logger.success('Firebase initialized successfully');
  } catch (e, stackTrace) {
    Logger.error('Firebase initialization failed', e, stackTrace);
    Logger.warning('App will continue but Firebase features may not work.');
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
