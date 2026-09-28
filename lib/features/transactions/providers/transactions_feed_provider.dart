import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pretium/core/providers/auth_providers.dart';
import 'package:pretium/core/providers/service_providers.dart';
import 'package:pretium/models/transaction_model.dart';

class TransactionsFeedState {
  const TransactionsFeedState({
    this.response,
    this.chartTransactions = const [],
    this.loading = true,
    this.loadingMore = false,
    this.error,
    this.filter = 'all',
  });

  final TransactionsResponse? response;
  final List<Transaction> chartTransactions;
  final bool loading;
  final bool loadingMore;
  final String? error;
  final String filter;

  TransactionsFeedState copyWith({
    TransactionsResponse? response,
    List<Transaction>? chartTransactions,
    bool? loading,
    bool? loadingMore,
    String? error,
    bool clearError = false,
    String? filter,
  }) {
    return TransactionsFeedState(
      response: response ?? this.response,
      chartTransactions: chartTransactions ?? this.chartTransactions,
      loading: loading ?? this.loading,
      loadingMore: loadingMore ?? this.loadingMore,
      error: clearError ? null : (error ?? this.error),
      filter: filter ?? this.filter,
    );
  }
}

class TransactionsFeedNotifier extends AutoDisposeNotifier<TransactionsFeedState> {
  @override
  TransactionsFeedState build() {
    Future<void>(load);
    return const TransactionsFeedState();
  }

  Future<TransactionsResponse> _fetchFiltered({
    int limit = 50,
    String? startAfter,
    String? filter,
  }) {
    final service = ref.read(transactionsServiceProvider);
    switch (filter ?? state.filter) {
      case 'income':
        return service.getCreditTransactions(limit: limit, startAfter: startAfter);
      case 'expenses':
        return service.getDebitTransactions(limit: limit, startAfter: startAfter);
      case 'pending':
        return service.getPendingTransactions(limit: limit, startAfter: startAfter);
      default:
        return service.getTransactions(limit: limit, startAfter: startAfter);
    }
  }

  Future<void> load() async {
    if (ref.read(currentUserProvider) == null) {
      state = state.copyWith(
        loading: false,
        response: TransactionsResponse(transactions: []),
        chartTransactions: const [],
      );
      return;
    }
    state = state.copyWith(loading: true, clearError: true);
    try {
      final service = ref.read(transactionsServiceProvider);
      final chartRes = await service.getTransactions(limit: 50);
      final res = await _fetchFiltered(limit: 50);
      state = state.copyWith(
        chartTransactions: chartRes.transactions,
        response: res,
        loading: false,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString(), loading: false);
    }
  }

  Future<void> setFilter(String filter) async {
    if (state.filter == filter) return;
    state = state.copyWith(filter: filter);
    await load();
  }

  Future<void> loadMore() async {
    final current = state.response;
    if (state.loadingMore || current == null || !current.hasMore) return;
    final startAfter = current.nextPageToken;
    if (startAfter == null || startAfter.isEmpty) return;

    state = state.copyWith(loadingMore: true);
    try {
      final nextPage = await _fetchFiltered(limit: 50, startAfter: startAfter);
      state = state.copyWith(
        response: TransactionsResponse(
          transactions: [...current.transactions, ...nextPage.transactions],
          nextPageToken: nextPage.nextPageToken,
          totalCount: nextPage.totalCount,
          hasMore: nextPage.hasMore,
          sources: nextPage.sources,
        ),
        loadingMore: false,
      );
    } catch (_) {
      state = state.copyWith(loadingMore: false);
    }
  }
}

final transactionsFeedProvider =
    AutoDisposeNotifierProvider<TransactionsFeedNotifier, TransactionsFeedState>(
  TransactionsFeedNotifier.new,
);
