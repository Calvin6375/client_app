import 'dart:convert';

import 'package:encrypt/encrypt.dart' as enc;
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pretium/utils/logger.dart';

/// Remote Config + secure storage for the C2B payload encryption key.
final class C2bEncryptionContext {
  const C2bEncryptionContext({required this.key, required this.keyId});

  final enc.Key key;
  final String keyId;
}

final class C2bEncryptionService {
  C2bEncryptionService._();

  static final C2bEncryptionService instance = C2bEncryptionService._();

  static const _storageKeyMaterial = 'c2b_payload_key';
  static const _storageKeyId = 'c2b_payload_key_id';

  static const _rcEnabled = 'c2b_payload_encryption_enabled';
  static const _rcKeyMaterial = 'mwanya';
  static const _rcKeyId = 'c2b_payload_encryption_key_id';

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  bool _initialized = false;
  bool _enabled = false;
  C2bEncryptionContext? _context;

  bool get isInitialized => _initialized;

  /// Loads Remote Config, caches key material in secure storage, prepares context.
  Future<void> initialize() async {
    if (_initialized) return;
    if (kIsWeb) {
      _initialized = true;
      return;
    }

    try {
      final remoteConfig = FirebaseRemoteConfig.instance;
      await remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          // Debug: always fetch latest after publishing RC changes.
          minimumFetchInterval: kDebugMode ? Duration.zero : const Duration(hours: 1),
        ),
      );
      await remoteConfig.setDefaults({
        _rcEnabled: false,
        _rcKeyMaterial: '',
        _rcKeyId: 'default',
      });

      try {
        await remoteConfig.fetchAndActivate();
        Logger.debug(
          'C2B Remote Config fetch — status=${remoteConfig.lastFetchStatus.name}, '
          'time=${remoteConfig.lastFetchTime.toIso8601String()}',
        );
      } catch (e) {
        Logger.warning('C2B encryption Remote Config fetch failed — using cache', e);
      }

      await _syncFromRemoteConfig(remoteConfig);
    } catch (e, stackTrace) {
      Logger.warning('C2B encryption init failed — plaintext fallback', e, stackTrace);
      await _loadFromSecureStorage();
    }

    _initialized = true;
    Logger.info(
      'C2B payload encryption ${_enabled ? "enabled (kid=${_context?.keyId})" : "disabled"}',
    );
  }

  Future<void> _syncFromRemoteConfig(FirebaseRemoteConfig remoteConfig) async {
    final enabled = remoteConfig.getBool(_rcEnabled);
    final material = remoteConfig.getString(_rcKeyMaterial).trim();
    final keyId = remoteConfig.getString(_rcKeyId).trim().isNotEmpty
        ? remoteConfig.getString(_rcKeyId).trim()
        : 'default';

    Logger.debug(
      'C2B Remote Config — enabled=$enabled, '
      'keyParam=$_rcKeyMaterial present=${material.isNotEmpty}, '
      'keyId=$keyId',
    );

    if (!enabled) {
      _enabled = false;
      _context = null;
      return;
    }

    if (material.isNotEmpty) {
      await _storage.write(key: _storageKeyMaterial, value: material);
      await _storage.write(key: _storageKeyId, value: keyId);
      _applyKeyMaterial(material, keyId);
      return;
    }

    await _loadFromSecureStorage();
  }

  Future<void> _loadFromSecureStorage() async {
    final material = (await _storage.read(key: _storageKeyMaterial))?.trim();
    final keyId = (await _storage.read(key: _storageKeyId))?.trim();
    if (material == null || material.isEmpty) {
      _enabled = false;
      _context = null;
      return;
    }
    _applyKeyMaterial(material, keyId?.isNotEmpty == true ? keyId! : 'default');
  }

  void _applyKeyMaterial(String material, String keyId) {
    try {
      final keyBytes = base64Decode(material);
      if (keyBytes.length != 32) {
        throw FormatException('Expected 32-byte key, got ${keyBytes.length}');
      }
      _context = C2bEncryptionContext(key: enc.Key(keyBytes), keyId: keyId);
      _enabled = true;
    } catch (e) {
      Logger.error('Invalid C2B encryption key material', e);
      _enabled = false;
      _context = null;
    }
  }

  bool get isEnabled => _enabled;

  /// Active encryption context, or `null` when encryption is disabled.
  C2bEncryptionContext? activeContext() => _enabled ? _context : null;
}
