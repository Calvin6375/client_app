import 'package:flutter/foundation.dart';
import 'package:pretium/repositories/wallet_repository.dart';
import 'package:pretium/services/dashboard_session_cache.dart';
import 'package:pretium/services/wallet_session_mapper.dart';
import 'package:pretium/utils/logger.dart';

/// Forces a fresh `GET /api/accounts` and updates [DashboardSessionCache]
/// after a successful money-moving transaction.
///
/// [revision] notifies Riverpod ([walletRefreshTickProvider]) and any leftover
/// listeners to re-render.
class WalletBalanceRefresh {
  WalletBalanceRefresh._();

  /// Bumped after each successful refresh so listeners can reload.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

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
      final snap = WalletSessionMapper.fromAccounts(accounts);

      DashboardSessionCache.instance.recordWalletSnapshot(
        fiatWallets: snap.fiatWallets,
        availableFiatCurrencies: snap.availableFiatCurrencies,
        cryptoWallets: snap.cryptoWallets,
        availableCryptoCurrencies: snap.availableCryptoCurrencies,
        cachedFiatWallet: snap.cachedFiatWallet,
        cachedCryptoWallet: snap.cachedCryptoWallet,
      );

      revision.value++;
      Logger.success(
        'WalletBalanceRefresh: fiat=${snap.availableFiatCurrencies.join(',')} '
        'crypto=${snap.availableCryptoCurrencies.join(',')}',
      );
    } catch (e, st) {
      Logger.warning('WalletBalanceRefresh failed', e, st);
      revision.value++;
    }
  }
}
