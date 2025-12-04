import 'dart:convert';
import 'package:firebase_database/firebase_database.dart';
import 'package:pretium/models/wallet_model.dart';
import 'package:pretium/utils/logger.dart';
import 'package:pretium/firebase_options.dart';

/// Repository for wallet operations in Realtime Database
/// STRICT RULE: This repository is READ-ONLY
/// Client code MUST NOT write to wallet nodes
/// All wallet updates must be done via Cloud Functions
class WalletRepository {
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  /// Stream wallet balance for a user
  /// Path: wallet/{uid}/fiat/{currency}
  Stream<Wallet?> streamWalletBalance(String uid, {String currency = 'USD'}) {
    try {
      Logger.debug('Streaming wallet balance for user: $uid, currency: $currency');
      
      final ref = _database.ref('wallet/$uid/fiat/$currency');
      
      return ref.onValue.map((event) {
        if (event.snapshot.exists && event.snapshot.value != null) {
          try {
            final data = Map<String, dynamic>.from(
              event.snapshot.value as Map,
            );
            final wallet = Wallet.fromJson(data);
            Logger.debug('Wallet balance updated: ${wallet.balance} ${wallet.currencyCode}');
            return wallet;
          } catch (e) {
            Logger.error('Failed to parse wallet data', e);
            return null;
          }
        }
        Logger.warning('Wallet balance not found for user: $uid, currency: $currency');
        return null;
      });
    } catch (e) {
      Logger.error('Failed to stream wallet balance', e);
      rethrow;
    }
  }

  /// Get wallet balance once (non-streaming)
  /// Use streamWalletBalance() for real-time updates
  /// Path: wallet/{uid}/fiat/{currency}
  Future<Wallet?> getWalletBalance(String uid, {String currency = 'USD'}) async {
    try {
      // New path: wallet/{userId}/fiat/{currency}
      final dbPath = 'wallet/$uid/fiat/$currency';
      final ref = _database.ref(dbPath);
      
      // Get database URL from Firebase options
      final databaseUrl = DefaultFirebaseOptions.currentPlatform.databaseURL ?? 
                         'https://truepay-72060-default-rtdb.firebaseio.com';
      final fullEndpointUrl = '$databaseUrl/$dbPath.json';
      
      Logger.debug('Fetching wallet balance for user: $uid, currency: $currency');
      Logger.debug('═══════════════════════════════════════════════════════════');
      Logger.debug('📤 FULL RAW REQUEST:');
      Logger.debug('  HTTP Method: GET');
      Logger.debug('  Database URL: $databaseUrl');
      Logger.debug('  Reference Path: $dbPath');
      Logger.debug('  Full Reference Path: ${ref.path}');
      Logger.debug('  Full Endpoint URL: $fullEndpointUrl');
      Logger.debug('  Request Headers: {');
      Logger.debug('    "Content-Type": "application/json",');
      Logger.debug('    "Accept": "application/json"');
      Logger.debug('  }');
      Logger.debug('  Request Body: null (GET request)');
      Logger.debug('  Query Parameters: {');
      Logger.debug('    "auth": "[Firebase Auth Token]",');
      Logger.debug('    "format": "export"');
      Logger.debug('  }');
      Logger.debug('  User ID: $uid');
      Logger.debug('  Currency: $currency');
      Logger.debug('═══════════════════════════════════════════════════════════');
      
      final startTime = DateTime.now();
      final snapshot = await ref.get();
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);
      
      Logger.debug('📥 FULL RAW RESPONSE:');
      Logger.debug('  Response Time: ${duration.inMilliseconds}ms');
      Logger.debug('  Snapshot exists: ${snapshot.exists}');
      Logger.debug('  Has value: ${snapshot.value != null}');
      Logger.debug('  Snapshot key: ${snapshot.key}');
      Logger.debug('  Snapshot priority: ${snapshot.priority}');
      
      if (snapshot.value != null) {
        // Convert to JSON string for full raw response
        final rawResponseJson = jsonEncode(snapshot.value);
        Logger.debug('  Raw Response Body (JSON):');
        Logger.debug('  $rawResponseJson');
        Logger.debug('');
        Logger.debug('  Raw Response Body (Formatted):');
        Logger.debug('  ${snapshot.value}');
      } else {
        Logger.debug('  Raw Response Body: null');
      }
      
      if (snapshot.exists && snapshot.value != null) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        Logger.debug('');
        Logger.debug('  Parsed Response Data:');
        Logger.debug('  $data');
        Logger.debug('');
        final wallet = Wallet.fromJson(data);
        Logger.debug('✅ Wallet balance fetched: ${wallet.balance} ${wallet.currencyCode}');
        Logger.debug('═══════════════════════════════════════════════════════════');
        return wallet;
      }
      
      Logger.warning('Wallet balance not found for user: $uid, currency: $currency');
      Logger.debug('═══════════════════════════════════════════════════════════');
      return null;
    } catch (e) {
      Logger.error('Failed to get wallet balance', e);
      rethrow;
    }
  }

  /// Get crypto wallet balance for a specific currency
  /// Path: wallet/{uid}/crypto/{currencyCode}
  Future<Wallet?> getCryptoWalletBalance(String uid, String currencyCode) async {
    try {
      final dbPath = 'wallet/$uid/crypto/$currencyCode';
      final ref = _database.ref(dbPath);
      
      // Get database URL from Firebase options
      final databaseUrl = DefaultFirebaseOptions.currentPlatform.databaseURL ?? 
                         'https://truepay-72060-default-rtdb.firebaseio.com';
      final fullEndpointUrl = '$databaseUrl/$dbPath.json';
      
      Logger.debug('Fetching crypto wallet balance for user: $uid, currency: $currencyCode');
      Logger.debug('═══════════════════════════════════════════════════════════');
      Logger.debug('📤 FULL RAW REQUEST:');
      Logger.debug('  HTTP Method: GET');
      Logger.debug('  Database URL: $databaseUrl');
      Logger.debug('  Reference Path: $dbPath');
      Logger.debug('  Full Reference Path: ${ref.path}');
      Logger.debug('  Full Endpoint URL: $fullEndpointUrl');
      Logger.debug('  Request Headers: {');
      Logger.debug('    "Content-Type": "application/json",');
      Logger.debug('    "Accept": "application/json"');
      Logger.debug('  }');
      Logger.debug('  Request Body: null (GET request)');
      Logger.debug('  Query Parameters: {');
      Logger.debug('    "auth": "[Firebase Auth Token]",');
      Logger.debug('    "format": "export"');
      Logger.debug('  }');
      Logger.debug('  User ID: $uid');
      Logger.debug('  Currency Code: $currencyCode');
      Logger.debug('═══════════════════════════════════════════════════════════');
      
      final startTime = DateTime.now();
      final snapshot = await ref.get();
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);
      
      Logger.debug('📥 FULL RAW RESPONSE:');
      Logger.debug('  Response Time: ${duration.inMilliseconds}ms');
      Logger.debug('  Snapshot exists: ${snapshot.exists}');
      Logger.debug('  Has value: ${snapshot.value != null}');
      Logger.debug('  Snapshot key: ${snapshot.key}');
      Logger.debug('  Snapshot priority: ${snapshot.priority}');
      
      if (snapshot.value != null) {
        // Convert to JSON string for full raw response
        final rawResponseJson = jsonEncode(snapshot.value);
        Logger.debug('  Raw Response Body (JSON):');
        Logger.debug('  $rawResponseJson');
        Logger.debug('');
        Logger.debug('  Raw Response Body (Formatted):');
        Logger.debug('  ${snapshot.value}');
      } else {
        Logger.debug('  Raw Response Body: null');
      }
      
      if (snapshot.exists && snapshot.value != null) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        Logger.debug('');
        Logger.debug('  Parsed Response Data:');
        Logger.debug('  $data');
        Logger.debug('');
        final wallet = Wallet.fromJson(data);
        Logger.debug('✅ Crypto wallet balance fetched: ${wallet.balance} ${wallet.currencyCode}');
        Logger.debug('═══════════════════════════════════════════════════════════');
        return wallet;
      }
      
      Logger.warning('Crypto wallet balance not found for user: $uid, currency: $currencyCode');
      Logger.debug('═══════════════════════════════════════════════════════════');
      // Return default wallet with 0 balance if not found
      return Wallet(currencyCode: currencyCode, balance: 0.0);
    } catch (e) {
      Logger.error('Failed to get crypto wallet balance', e);
      // Return default wallet with 0 balance on error
      return Wallet(currencyCode: currencyCode, balance: 0.0);
    }
  }

  /// Stream crypto wallet balance for a specific currency
  /// Path: wallet/{uid}/crypto/{currencyCode}
  Stream<Wallet?> streamCryptoWalletBalance(String uid, String currencyCode) {
    try {
      Logger.debug('Streaming crypto wallet balance for user: $uid, currency: $currencyCode');
      
      final ref = _database.ref('wallet/$uid/crypto/$currencyCode');
      
      return ref.onValue.map((event) {
        if (event.snapshot.exists && event.snapshot.value != null) {
          try {
            final data = Map<String, dynamic>.from(
              event.snapshot.value as Map,
            );
            final wallet = Wallet.fromJson(data);
            Logger.debug('Crypto wallet balance updated: ${wallet.balance} ${wallet.currencyCode}');
            return wallet;
          } catch (e) {
            Logger.error('Failed to parse crypto wallet data', e);
            return Wallet(currencyCode: currencyCode, balance: 0.0);
          }
        }
        Logger.warning('Crypto wallet balance not found for user: $uid, currency: $currencyCode');
        return Wallet(currencyCode: currencyCode, balance: 0.0);
      });
    } catch (e) {
      Logger.error('Failed to stream crypto wallet balance', e);
      return Stream.value(Wallet(currencyCode: currencyCode, balance: 0.0));
    }
  }

  /// NOTE: This method is intentionally not implemented
  /// Wallet updates MUST be done via Cloud Functions only
  /// 
  /// To update wallet balance, call the Cloud Function:
  /// PaymentService.updateWalletAfterPayment()
  ///
  /// DO NOT implement updateWallet() here - it's a security risk
}

