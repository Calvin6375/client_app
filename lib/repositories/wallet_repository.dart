import 'package:firebase_database/firebase_database.dart';
import 'package:pretium/models/wallet_model.dart';
import 'package:pretium/utils/logger.dart';

/// Repository for wallet operations in Realtime Database
/// STRICT RULE: This repository is READ-ONLY
/// Client code MUST NOT write to wallet nodes
/// All wallet updates must be done via Cloud Functions
class WalletRepository {
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  /// Stream wallet balance for a user
  /// Path: wallet/{uid}/balance
  Stream<Wallet?> streamWalletBalance(String uid) {
    try {
      Logger.debug('Streaming wallet balance for user: $uid');
      
      final ref = _database.ref('wallet/$uid/balance');
      
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
        Logger.warning('Wallet balance not found for user: $uid');
        return null;
      });
    } catch (e) {
      Logger.error('Failed to stream wallet balance', e);
      rethrow;
    }
  }

  /// Get wallet balance once (non-streaming)
  /// Use streamWalletBalance() for real-time updates
  Future<Wallet?> getWalletBalance(String uid) async {
    try {
      Logger.debug('Fetching wallet balance for user: $uid');
      
      final ref = _database.ref('wallet/$uid/balance');
      final snapshot = await ref.get();
      
      if (snapshot.exists && snapshot.value != null) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        final wallet = Wallet.fromJson(data);
        Logger.debug('Wallet balance fetched: ${wallet.balance} ${wallet.currencyCode}');
        return wallet;
      }
      
      Logger.warning('Wallet balance not found for user: $uid');
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
      Logger.debug('Fetching crypto wallet balance for user: $uid, currency: $currencyCode');
      
      final ref = _database.ref('wallet/$uid/crypto/$currencyCode');
      final snapshot = await ref.get();
      
      if (snapshot.exists && snapshot.value != null) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        final wallet = Wallet.fromJson(data);
        Logger.debug('Crypto wallet balance fetched: ${wallet.balance} ${wallet.currencyCode}');
        return wallet;
      }
      
      Logger.warning('Crypto wallet balance not found for user: $uid, currency: $currencyCode');
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

