import 'package:firebase_auth/firebase_auth.dart';
import 'package:pretium/firebase_options.dart';
import 'package:pretium/services/dashboard_session_cache.dart';
import 'package:pretium/utils/logger.dart';

/// Android `applicationId` in `android/app/build.gradle` (password-reset app links).
const _androidPackageForPasswordReset = 'com.example.pretium_mock';

/// iOS `BUNDLE_ID` in `ios/Runner/GoogleService-Info.plist` (password-reset universal links).
const _iosBundleIdForPasswordReset = 'com.example.pretiumMock';

/// Authentication service
/// Handles all Firebase Authentication operations
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get current user
  User? get currentUser => _auth.currentUser;

  /// Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  /// Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Stream of user changes
  Stream<User?> get userChanges => _auth.userChanges();

  /// Sign in with email and password
  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    try {
      Logger.info('Signing in user: $email');
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      Logger.success('User signed in successfully: ${credential.user?.uid}');
      return credential;
    } on FirebaseAuthException catch (e) {
      Logger.error('Sign in failed', e);
      rethrow;
    } catch (e) {
      Logger.error('Unexpected sign in error', e);
      rethrow;
    }
  }

  /// Sign up with email and password
  Future<UserCredential> signUp({
    required String email,
    required String password,
  }) async {
    try {
      // Log request body (mask password for security)
      final requestBody = {
        'email': email.trim(),
        'password': '***${password.length > 0 ? '*' * (password.length > 3 ? password.length - 3 : 0) : ''}***', // Mask password
        'passwordLength': password.length,
      };
      Logger.info('📤 Firebase Auth - Create User Request:');
      Logger.info('   Request Body: $requestBody');
      
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      
      // Log response body
      // Get provider data from user (list of providers)
      final providerData = credential.user?.providerData
          .map((info) => {
                'providerId': info.providerId,
                'uid': info.uid,
                'email': info.email,
                'displayName': info.displayName,
                'photoURL': info.photoURL,
              })
          .toList();
      
      final responseBody = {
        'uid': credential.user?.uid,
        'email': credential.user?.email,
        'emailVerified': credential.user?.emailVerified,
        'displayName': credential.user?.displayName,
        'photoURL': credential.user?.photoURL,
        'phoneNumber': credential.user?.phoneNumber,
        'creationTime': credential.user?.metadata.creationTime?.toIso8601String(),
        'lastSignInTime': credential.user?.metadata.lastSignInTime?.toIso8601String(),
        'isAnonymous': credential.user?.isAnonymous,
        'providerData': providerData,
        'additionalUserInfo': {
          'isNewUser': credential.additionalUserInfo?.isNewUser,
          'providerId': credential.additionalUserInfo?.providerId,
          'username': credential.additionalUserInfo?.username,
          'profile': credential.additionalUserInfo?.profile,
        },
      };
      Logger.info('📥 Firebase Auth - Create User Response:');
      Logger.info('   Response Body: $responseBody');
      Logger.success('User signed up successfully: ${credential.user?.uid}');
      return credential;
    } on FirebaseAuthException catch (e) {
      Logger.error('📥 Firebase Auth - Create User Error Response:');
      Logger.error('   Error Code: ${e.code}');
      Logger.error('   Error Message: ${e.message}');
      Logger.error('   Error Details: ${e.toString()}');
      rethrow;
    } catch (e) {
      Logger.error('📥 Firebase Auth - Create User Unexpected Error:');
      Logger.error('   Error: $e');
      rethrow;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      Logger.info('Signing out user: ${currentUserId}');
      await _auth.signOut();
      DashboardSessionCache.instance.clear();
      Logger.success('User signed out successfully');
    } catch (e) {
      Logger.error('Sign out failed', e);
      rethrow;
    }
  }

  /// Send password reset email using Firebase Auth (client SDK).
  ///
  /// Uses [ActionCodeSettings] so the link can open in-app when supported
  /// (`handleCodeInApp`, iOS bundle id, Android package name). Continue URL
  /// uses the project default host (`https://<projectId>.firebaseapp.com/`),
  /// which is on Firebase Auth authorized domains by default.
  Future<void> sendPasswordResetEmail(
    String email, {
    ActionCodeSettings? actionCodeSettings,
  }) async {
    try {
      Logger.info('Sending password reset email to: $email');
      await _auth.sendPasswordResetEmail(
        email: email.trim(),
        actionCodeSettings:
            actionCodeSettings ?? _defaultPasswordResetActionCodeSettings(),
      );
      Logger.success('Password reset email sent');
    } on FirebaseAuthException catch (e) {
      Logger.error('Password reset email failed', e);
      rethrow;
    } catch (e) {
      Logger.error('Unexpected password reset error', e);
      rethrow;
    }
  }

  static ActionCodeSettings _defaultPasswordResetActionCodeSettings() {
    final projectId = DefaultFirebaseOptions.currentPlatform.projectId;
    final url = 'https://$projectId.firebaseapp.com/';
    return ActionCodeSettings(
      url: url,
      handleCodeInApp: true,
      iOSBundleId: _iosBundleIdForPasswordReset,
      androidPackageName: _androidPackageForPasswordReset,
      androidInstallApp: true,
      androidMinimumVersion: '1',
    );
  }

  /// User-facing copy for [FirebaseAuthException]. Never surfaces raw native traces.
  static String getErrorMessage(FirebaseAuthException e) {
    final code = e.code.toLowerCase().replaceAll('_', '-');
    switch (code) {
      // Email/password (Firebase may use invalid-credential or invalid-login-credentials on newer SDKs)
      case 'invalid-credential':
      case 'invalid-login-credentials':
        return 'Incorrect email or password. Please try again.';
      case 'wrong-password':
        return 'Incorrect email or password. Please try again.';
      case 'user-not-found':
        return 'No account found for that email.';
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'invalid-email':
        return 'The email address is invalid.';
      case 'weak-password':
        return 'The password is too weak.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'operation-not-allowed':
        return 'This operation is not allowed.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      default:
        return _fallbackMessageForAuthException(e);
    }
  }

  /// User-facing copy for password reset failures (continue URI, rate limits, etc.).
  static String getPasswordResetErrorMessage(FirebaseAuthException e) {
    final code = e.code.toLowerCase().replaceAll('_', '-');
    switch (code) {
      case 'invalid-email':
      case 'too-many-requests':
      case 'network-request-failed':
      case 'user-disabled':
      case 'operation-not-allowed':
        return getErrorMessage(e);
      case 'unauthorized-continue-uri':
      case 'invalid-continue-uri':
      case 'missing-continue-uri':
      case 'missing-android-pkg-name':
      case 'missing-ios-bundle-id':
        return 'Password reset is temporarily unavailable. Please try again later.';
      default:
        return 'Unable to send reset email. Please try again.';
    }
  }

  /// When [code] is unknown, infer from [message] or use a safe generic line (no stack traces).
  static String _fallbackMessageForAuthException(FirebaseAuthException e) {
    final m = (e.message ?? '').toUpperCase();
    if (m.contains('INVALID_LOGIN_CREDENTIALS') ||
        m.contains('INVALID_CREDENTIAL')) {
      return 'Incorrect email or password. Please try again.';
    }
    return 'Unable to sign in. Please check your details and try again.';
  }
}

