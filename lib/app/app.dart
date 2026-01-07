import 'package:flutter/material.dart';
import 'package:pretium/app/route_names.dart';
import 'package:pretium/features/splash/screens/splash_page.dart';
import 'package:pretium/features/auth/screens/login_page.dart';
import 'package:pretium/features/auth/screens/register_page.dart';
import 'package:pretium/features/home/screens/landing_page.dart';
import 'package:pretium/features/topup/screens/topup_page.dart';
import 'package:pretium/features/wallet_verification/screens/wallet_verification_screen.dart';

class PretiumApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TruePay',
      debugShowCheckedModeBanner: false,
      initialRoute: RouteNames.splash,
      routes: {
        RouteNames.splash: (_) => const SplashPage(),
        RouteNames.login: (_) => const LoginPage(),
        RouteNames.register: (_) => const RegisterPage(),
        RouteNames.home: (_) => LandingPage(),
        RouteNames.topup: (_) => const TopUpPage(),
        RouteNames.walletVerification: (_) => const WalletVerificationScreen(),
      },
    );
  }
}
// This is the main entry point of the TruePay application.