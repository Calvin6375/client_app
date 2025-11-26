import 'package:firebase_auth/firebase_auth.dart';
import 'package:pretium/utils/logger.dart';

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
      Logger.info('Signing up user: $email');
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      Logger.success('User signed up successfully: ${credential.user?.uid}');
      return credential;
    } on FirebaseAuthException catch (e) {
      Logger.error('Sign up failed', e);
      rethrow;
    } catch (e) {
      Logger.error('Unexpected sign up error', e);
      rethrow;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      Logger.info('Signing out user: ${currentUserId}');
      await _auth.signOut();
      Logger.success('User signed out successfully');
    } catch (e) {
      Logger.error('Sign out failed', e);
      rethrow;
    }
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      Logger.info('Sending password reset email to: $email');
      await _auth.sendPasswordResetEmail(email: email.trim());
      Logger.success('Password reset email sent');
    } on FirebaseAuthException catch (e) {
      Logger.error('Password reset email failed', e);
      rethrow;
    } catch (e) {
      Logger.error('Unexpected password reset error', e);
      rethrow;
    }
  }

  /// Get user-friendly error message
  static String getErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found for that email.';
      case 'wrong-password':
        return 'Wrong password provided.';
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'invalid-email':
        return 'The email address is invalid.';
      case 'weak-password':
        return 'The password is too weak.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many requests. Please try again later.';
      case 'operation-not-allowed':
        return 'This operation is not allowed.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      default:
        return 'An error occurred: ${e.message ?? e.code}';
    }
  }
}

