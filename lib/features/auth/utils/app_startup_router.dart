import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pretium/app/route_names.dart';
import 'package:pretium/features/home/screens/landing_page.dart';
import 'package:pretium/services/app_access_guard.dart';
import 'package:pretium/services/auth_service.dart';
import 'package:pretium/utils/logger.dart';

/// Decides where to send the user after the launch splash based on Firebase session.
class AppStartupRouter {
  AppStartupRouter._();

  static Future<void> navigateFromSplash(BuildContext context) async {
    if (!context.mounted) return;

    final user = await _resolveCurrentUser();
    if (!context.mounted) return;

    if (user == null) {
      Logger.info('Startup: no session — routing to login');
      Navigator.of(context).pushReplacementNamed(RouteNames.login);
      return;
    }

    final sessionValid = await _refreshSession(user);
    if (!sessionValid) {
      Logger.warning('Startup: stale session — routing to login');
      await AuthService().signOut();
      if (!context.mounted) return;
      Navigator.of(context).pushReplacementNamed(RouteNames.login);
      return;
    }

    final guard = AppAccessGuard();
    final access = await guard.evaluate();
    if (!context.mounted) return;

    if (access == AppAccessResult.allowed) {
      Logger.info('Startup: valid session — routing to home');
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const LandingPage()),
      );
      return;
    }

    Logger.warning('Startup: session denied ($access) — routing to login');
    await guard.enforceDeniedAccess(context, access);
  }

  /// Waits for Firebase Auth to emit its persisted session state.
  static Future<User?> _resolveCurrentUser() async {
    final auth = FirebaseAuth.instance;
    if (auth.currentUser != null) return auth.currentUser;
    return auth.authStateChanges().first;
  }

  /// Forces a token refresh so expired persisted sessions are cleared.
  static Future<bool> _refreshSession(User user) async {
    try {
      await user.getIdToken(true);
      return true;
    } on FirebaseAuthException catch (e) {
      Logger.warning('Startup: token refresh failed (${e.code})');
      return false;
    } catch (e) {
      Logger.warning('Startup: token refresh failed', e);
      return false;
    }
  }
}
