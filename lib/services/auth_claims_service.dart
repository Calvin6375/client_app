import 'package:firebase_auth/firebase_auth.dart';
import 'package:pretium/core/constants/auth_config.dart';
import 'package:pretium/utils/logger.dart';

/// Reads Firebase ID token custom claims (single IdP) via [User.getIdTokenResult].
///
/// Security routing must use [userTypeClaim] from the token — not institution/channel.
final class AuthClaimsService {
  AuthClaimsService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  /// Returns `userType` from ID token claims, refreshing once when missing or stale.
  Future<String?> userTypeClaim({bool forceRefresh = false}) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    var claim = await _readUserType(user, forceRefresh: forceRefresh);
    if (claim != null && claim.isNotEmpty) return claim;

    if (!forceRefresh) {
      Logger.info('userType claim missing — forcing token refresh');
      await user.getIdToken(true);
      claim = await _readUserType(user, forceRefresh: true);
    }

    return claim;
  }

  Future<String?> _readUserType(User user, {required bool forceRefresh}) async {
    final result = await user.getIdTokenResult(forceRefresh);
    final raw = result.claims?[AuthConfig.userTypeClaimKey];
    if (raw == null) return null;
    return raw.toString();
  }

  /// ID token for API calls; refreshes when [userTypeClaim] is absent (stale claims).
  Future<String> idTokenForApi({bool forceRefreshIfStale = true}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'unauthenticated',
        message: 'User must be logged in',
      );
    }

    if (forceRefreshIfStale) {
      final userType = await userTypeClaim();
      if (userType == null || userType.isEmpty) {
        await user.getIdToken(true);
      }
    }

    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw FirebaseAuthException(
        code: 'unauthenticated',
        message: 'Failed to get authentication token',
      );
    }
    return token;
  }

  bool isCustomer(String? userType) =>
      userType == AuthConfig.customerUserType;

  bool isPartner(String? userType) => userType == AuthConfig.partnerUserType;

  bool isAdmin(String? userType) => userType == AuthConfig.adminUserType;
}
