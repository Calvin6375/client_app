import 'package:flutter/material.dart';
import 'package:pretium/features/home/screens/landing_page.dart';
import 'package:pretium/services/app_access_guard.dart';
import 'package:pretium/services/dashboard_session_cache.dart';
import 'package:pretium/utils/logger.dart';

/// After Firebase sign-in/register: route by `userType` claim (wrong-app guard).
Future<void> completeAuthAndRoute(BuildContext context) async {
  final guard = AppAccessGuard();
  final access = await guard.evaluate();

  if (!context.mounted) return;

  if (access == AppAccessResult.allowed) {
    DashboardSessionCache.instance.clear();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => LandingPage()),
      (route) => false,
    );
    return;
  }

  Logger.warning('Wrong-app guard triggered: $access');
  await guard.enforceDeniedAccess(context, access);
}
