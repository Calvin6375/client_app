import 'package:flutter/material.dart';
import 'package:pretium/app/route_names.dart';
import 'package:pretium/core/constants/auth_config.dart';
import 'package:pretium/repositories/user_repository.dart';
import 'package:pretium/services/auth_claims_service.dart';
import 'package:pretium/services/auth_service.dart';
import 'package:pretium/utils/logger.dart';
import 'package:url_launcher/url_launcher.dart';

/// Result of checking whether the signed-in user belongs in the C2B customer app.
enum AppAccessResult {
  /// `userType === "customer"` — stay in app.
  allowed,

  /// `userType === "partner"` — redirect to partner web dashboard.
  redirectPartner,

  /// `userType === "admin"` — redirect to admin web dashboard.
  redirectAdmin,

  /// Claim missing or unrecognized after refresh.
  unknownUserType,
}

/// Wrong-app guard: partner/admin accounts must use their web dashboards, not C2B.
final class AppAccessGuard {
  AppAccessGuard({
    AuthClaimsService? claimsService,
    AuthService? authService,
    UserRepository? userRepository,
  })  : _claims = claimsService ?? AuthClaimsService(),
        _auth = authService ?? AuthService(),
        _users = userRepository ?? UserRepository();

  final AuthClaimsService _claims;
  final AuthService _auth;
  final UserRepository _users;

  Future<AppAccessResult> evaluate() async {
    final userType = await _claims.userTypeClaim();
    Logger.info('Auth routing: userType=${userType ?? "(missing)"}');

    if (_claims.isCustomer(userType)) {
      return AppAccessResult.allowed;
    }
    if (_claims.isPartner(userType)) {
      return AppAccessResult.redirectPartner;
    }
    if (_claims.isAdmin(userType)) {
      return AppAccessResult.redirectAdmin;
    }

    if (userType == null || userType.isEmpty) {
      return _evaluateLegacyRouting();
    }

    return AppAccessResult.unknownUserType;
  }

  Future<AppAccessResult> _evaluateLegacyRouting() async {
    final legacy = await _claims.legacyRoutingHint();

    if (legacy.partnerId != null) {
      Logger.info('Auth routing: legacy partnerId=${legacy.partnerId}');
      return AppAccessResult.redirectPartner;
    }
    if (legacy.admin || _claims.isSuperAdminEmail(legacy.email)) {
      Logger.info('Auth routing: legacy admin');
      return AppAccessResult.redirectAdmin;
    }

    final uid = _auth.currentUserId;
    if (uid != null && await _users.profileExists(uid)) {
      Logger.info('Auth routing: legacy customer (users/$uid exists)');
      return AppAccessResult.allowed;
    }

    return AppAccessResult.unknownUserType;
  }

  /// Signs out and opens the correct web dashboard when access is denied.
  Future<void> enforceDeniedAccess(
    BuildContext context,
    AppAccessResult result,
  ) async {
    final (url, message) = switch (result) {
      AppAccessResult.redirectPartner => (
          AuthConfig.partnerDashboardUrl,
          'Partner accounts use the partner dashboard. Opening it now.',
        ),
      AppAccessResult.redirectAdmin => (
          AuthConfig.adminDashboardUrl,
          'Admin accounts use the admin dashboard. Opening it now.',
        ),
      AppAccessResult.unknownUserType => (
          null as String?,
          'This account is not authorized for the customer app.',
        ),
      AppAccessResult.allowed => (null as String?, ''),
    };

    await _auth.signOut();

    if (url != null) {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        Logger.warning('Could not launch dashboard URL: $url');
      }
    }

    if (!context.mounted) return;

    if (message.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 5)),
      );
    }

    Navigator.of(context).pushNamedAndRemoveUntil(
      RouteNames.login,
      (route) => false,
    );
  }
}
