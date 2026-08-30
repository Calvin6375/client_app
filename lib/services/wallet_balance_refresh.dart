import 'package:flutter/foundation.dart';
import 'package:pretium/models/wallet_model.dart';
import 'package:pretium/repositories/wallet_repository.dart';
import 'package:pretium/services/dashboard_session_cache.dart';
import 'package:pretium/utils/logger.dart';

/// Forces a fresh `GET /api/accounts` and updates [DashboardSessionCache]
/// after a successful money-moving transaction.
///
/// [revision] notifies mounted UI (e.g. home [WalletCard]) to re-render.
class WalletBalanceRefresh {
  WalletBalanceRefresh._();

  /// Bumped after each successful refresh so listeners can reload.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static const Set<String> _alwaysVisibleFiat = {'KES', 'USD'};
  static const Set<String> _alwaysVisibleCrypto = {'USDT', 'USDC'};

  static Future<void>? _inFlight;

  /// Clears local wallet caches, fetches accounts, updates the session snapshot,
  /// and notifies listeners. Safe to call from any success path.
  static Future<void> afterSuccessfulTransaction() {
    _inFlight ??= _run().whenComplete(() => _inFlight = null);
    return _inFlight!;
  }

  static Future<void> _run() async {
    try {
      WalletRepository.clearCache();
      DashboardSessionCache.instance.invalidateTransactions();

      final accounts = await WalletRepository().fetchAccounts(forceRefresh: true);

      final fiatWallets = <String, Wallet>{
        ...accounts.fiatWallets,
        for (final e in accounts.fiatBalances.entries)
          if (!accounts.fiatWallets.containsKey(e.key))
            e.key: Wallet(currencyCode: e.key, balance: e.value),
      };
      for (final code in _alwaysVisibleFiat) {
        fiatWallets.putIfAbsent(
          code,
          () =>
              accounts.fiatWallet(code) ?? Wallet(currencyCode: code, balance: 0),
        );
      }

      final availableFiat = fiatWallets.entries
          .where((e) => _showFiat(e.key, e.value.balance))
          .map((e) => e.key)
          .toList();
      final orderedFiat = _withKesFirst(availableFiat);

      final cryptoWallets = <String, Wallet>{
        for (final code in _alwaysVisibleCrypto)
          code: accounts.cryptoWallet(code) ??
              Wallet(currencyCode: code, balance: 0),
        ...accounts.cryptoWallets,
      };
      final availableCrypto = cryptoWallets.entries
          .where((e) => _showCrypto(e.key, e.value.balance))
          .map((e) => e.key)
          .toList();
      if (!availableCrypto.contains('USDT')) availableCrypto.insert(0, 'USDT');
      if (!availableCrypto.contains('USDC')) availableCrypto.add('USDC');

      DashboardSessionCache.instance.recordWalletSnapshot(
        fiatWallets: fiatWallets,
        availableFiatCurrencies: orderedFiat,
        cryptoWallets: cryptoWallets,
        availableCryptoCurrencies: availableCrypto,
        cachedFiatWallet: fiatWallets[
                orderedFiat.isNotEmpty ? orderedFiat.first : 'USD'] ??
            Wallet(currencyCode: 'USD', balance: 0),
        cachedCryptoWallet:
            cryptoWallets['USDT'] ?? Wallet(currencyCode: 'USDT', balance: 0),
      );

      revision.value++;
      Logger.success(
        'WalletBalanceRefresh: fiat=${orderedFiat.join(',')} '
        'crypto=${availableCrypto.join(',')}',
      );
    } catch (e, st) {
      Logger.warning('WalletBalanceRefresh failed', e, st);
      // Still bump so UI can attempt its own force refresh.
      revision.value++;
    }
  }

  static bool _showFiat(String code, double balance) {
    final upper = code.trim().toUpperCase();
    if (_alwaysVisibleFiat.contains(upper)) return true;
    return balance > 0;
  }

  static bool _showCrypto(String code, double balance) {
    final upper = code.trim().toUpperCase();
    if (_alwaysVisibleCrypto.contains(upper)) return true;
    return balance > 0;
  }

  static List<String> _withKesFirst(List<String> currencies) {
    if (!currencies.contains('KES')) return List<String>.from(currencies);
    return ['KES', ...currencies.where((c) => c != 'KES')];
  }
}
