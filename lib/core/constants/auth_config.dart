import 'package:pretium/firebase_options.dart';

/// Firebase custom-claim keys and web dashboard URLs for the wrong-app guard.
final class AuthConfig {
  AuthConfig._();

  static const String userTypeClaimKey = 'userType';

  static const String customerUserType = 'customer';
  static const String partnerUserType = 'partner';
  static const String adminUserType = 'admin';

  /// Expected claim for C2B (customer) app users: `{ "userType": "customer" }`.
  static const String expectedCustomerClaim = customerUserType;

  static String get _projectId => DefaultFirebaseOptions.currentPlatform.projectId;

  /// Partner web dashboard — users with `userType: "partner"` are redirected here.
  static String get partnerDashboardUrl =>
      'https://$_projectId.web.app/partner';

  /// Admin web dashboard — users with `userType: "admin"` are redirected here.
  static String get adminDashboardUrl => 'https://$_projectId.web.app/admin';
}
