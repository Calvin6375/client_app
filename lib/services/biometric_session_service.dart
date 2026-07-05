import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// Stores login credentials in platform secure storage and gates access with biometrics.
class BiometricSessionService {
  BiometricSessionService._();

  static final BiometricSessionService instance = BiometricSessionService._();

  static const _keyEnabled = 'biometric_login_enabled';
  static const _keyEmail = 'biometric_login_email';
  static const _keyPassword = 'biometric_login_password';

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  final LocalAuthentication _localAuth = LocalAuthentication();

  Future<bool> isDeviceSupported() async {
    if (kIsWeb) return false;
    try {
      return await _localAuth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  Future<bool> isBiometricLoginEnabled() async {
    final value = await _storage.read(key: _keyEnabled);
    return value == 'true';
  }

  Future<bool> canUseBiometricLogin() async {
    if (!await isBiometricLoginEnabled()) return false;
    final email = await _storage.read(key: _keyEmail);
    final password = await _storage.read(key: _keyPassword);
    return email != null &&
        email.isNotEmpty &&
        password != null &&
        password.isNotEmpty;
  }

  Future<bool> authenticate({
    required String reason,
    bool biometricOnly = true,
  }) async {
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
        biometricOnly: biometricOnly,
      );
    } on LocalAuthException {
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> enableBiometricLogin({
    required String email,
    required String password,
  }) async {
    await _storage.write(key: _keyEmail, value: email.trim());
    await _storage.write(key: _keyPassword, value: password);
    await _storage.write(key: _keyEnabled, value: 'true');
  }

  Future<void> disableBiometricLogin() async {
    await _storage.delete(key: _keyEmail);
    await _storage.delete(key: _keyPassword);
    await _storage.write(key: _keyEnabled, value: 'false');
  }

  Future<({String email, String password})?> readStoredCredentials() async {
    final email = await _storage.read(key: _keyEmail);
    final password = await _storage.read(key: _keyPassword);
    if (email == null || password == null) return null;
    return (email: email, password: password);
  }

  /// Prompts the user to enable biometric login after a successful password sign-in.
  Future<void> maybePromptEnableAfterLogin(
    BuildContext context, {
    required String email,
    required String password,
  }) async {
    if (!await isDeviceSupported()) return;
    if (await isBiometricLoginEnabled()) return;
    if (!context.mounted) return;

    final enable = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enable biometric login?'),
        content: const Text(
          'Use fingerprint or Face ID to sign in quickly. Your email and password '
          'are stored securely on this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Enable'),
          ),
        ],
      ),
    );

    if (enable != true || !context.mounted) return;

    final verified = await authenticate(
      reason: 'Verify your identity to enable biometric login',
    );
    if (!verified) return;

    await enableBiometricLogin(email: email, password: password);
  }
}
