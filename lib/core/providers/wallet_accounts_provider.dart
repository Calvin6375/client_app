import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pretium/core/providers/auth_providers.dart';
import 'package:pretium/core/providers/service_providers.dart';
import 'package:pretium/services/dashboard_session_cache.dart';
import 'package:pretium/services/wallet_balance_refresh.dart';
import 'package:pretium/services/wallet_session_mapper.dart';

/// Mirrors [WalletBalanceRefresh.revision] so Riverpod can rebuild on money moves.
class WalletRefreshTick extends Notifier<int> {
  @override
  int build() {
    final revision = WalletBalanceRefresh.revision;
    void listener() => state = revision.value;
    revision.addListener(listener);
    ref.onDispose(() => revision.removeListener(listener));
    return revision.value;
  }
}

final walletRefreshTickProvider =
    NotifierProvider<WalletRefreshTick, int>(WalletRefreshTick.new);

class WalletAccountsNotifier extends AsyncNotifier<WalletSessionSnapshot?> {
  @override
  Future<WalletSessionSnapshot?> build() async {
    ref.watch(walletRefreshTickProvider);
    final user = ref.watch(currentUserProvider);
    if (user == null) return null;

    final cache = ref.read(dashboardSessionCacheProvider);
    final lastKnown = cache.readWalletLastKnown();
    if (lastKnown != null) {
      Future<void>(() async {
        try {
          final snap = await _fetchAndRecord(force: false);
          state = AsyncData(snap);
        } catch (_) {}
      });
      return lastKnown;
    }

    return _fetchAndRecord(force: false);
  }

  Future<void> refresh({bool force = true}) async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      state = const AsyncData(null);
      return;
    }
    try {
      final snap = await _fetchAndRecord(force: force);
      state = AsyncData(snap);
    } catch (e, st) {
      if (state.hasValue && state.value != null) return;
      state = AsyncError(e, st);
    }
  }

  Future<WalletSessionSnapshot> _fetchAndRecord({required bool force}) async {
    final accounts = await ref
        .read(walletRepositoryProvider)
        .fetchAccounts(forceRefresh: force);
    final snap = WalletSessionMapper.fromAccounts(accounts);
    ref.read(dashboardSessionCacheProvider).recordWalletSnapshot(
          fiatWallets: snap.fiatWallets,
          availableFiatCurrencies: snap.availableFiatCurrencies,
          cryptoWallets: snap.cryptoWallets,
          availableCryptoCurrencies: snap.availableCryptoCurrencies,
          cachedFiatWallet: snap.cachedFiatWallet,
          cachedCryptoWallet: snap.cachedCryptoWallet,
        );
    return snap;
  }
}

final walletAccountsProvider =
    AsyncNotifierProvider<WalletAccountsNotifier, WalletSessionSnapshot?>(
  WalletAccountsNotifier.new,
);
