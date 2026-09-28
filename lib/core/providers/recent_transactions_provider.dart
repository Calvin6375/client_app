import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pretium/core/providers/auth_providers.dart';
import 'package:pretium/core/providers/service_providers.dart';
import 'package:pretium/core/providers/wallet_accounts_provider.dart';
import 'package:pretium/models/transaction_model.dart';

class RecentTransactionsNotifier extends AsyncNotifier<TransactionsResponse?> {
  @override
  Future<TransactionsResponse?> build() async {
    ref.watch(walletRefreshTickProvider);
    final user = ref.watch(currentUserProvider);
    if (user == null) return null;

    final cache = ref.read(dashboardSessionCacheProvider);
    final cached = cache.copyRecentTransactionsIfFresh();
    if (cached != null) return cached;
    return _fetch();
  }

  Future<void> refresh() async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      state = const AsyncData(null);
      return;
    }
    try {
      state = AsyncData(await _fetch());
    } catch (e, st) {
      if (state.hasValue) return;
      state = AsyncError(e, st);
    }
  }

  Future<TransactionsResponse> _fetch() async {
    final response =
        await ref.read(transactionsServiceProvider).getTransactions(limit: 5);
    ref.read(dashboardSessionCacheProvider).recordTransactions(response);
    return response;
  }
}

final recentTransactionsProvider =
    AsyncNotifierProvider<RecentTransactionsNotifier, TransactionsResponse?>(
  RecentTransactionsNotifier.new,
);
