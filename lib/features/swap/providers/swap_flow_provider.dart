import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pretium/core/providers/owned_wallet_balances.dart';
import 'package:pretium/core/providers/service_providers.dart';
import 'package:pretium/core/providers/wallet_accounts_provider.dart';
import 'package:pretium/features/swap/services/exchange_quote.dart';
import 'package:pretium/utils/logger.dart';

enum SwapStep { input, confirmation, success }

class SwapFlowState {
  const SwapFlowState({
    this.step = SwapStep.input,
    this.fromCurrency = 'USD',
    this.toCurrency = 'USDT',
    this.fromBalance = 0,
    this.toBalance = 0,
    this.loadingWallets = true,
    this.ownedCurrencyCodes = const [],
    this.ownedBalances = const {},
    this.rate = 0,
    this.rateDisplay,
    this.ratesResponse,
    this.rateError,
    this.loadingRate = false,
    this.isSubmitting = false,
  });

  final SwapStep step;
  final String fromCurrency;
  final String toCurrency;
  final double fromBalance;
  final double toBalance;
  final bool loadingWallets;
  final List<String> ownedCurrencyCodes;
  final Map<String, double> ownedBalances;
  final double rate;
  final String? rateDisplay;
  final Map<String, dynamic>? ratesResponse;
  final String? rateError;
  final bool loadingRate;
  final bool isSubmitting;

  bool get hasValidQuote =>
      rate > 0 && rateError == null && !loadingRate && ratesResponse != null;

  SwapFlowState copyWith({
    SwapStep? step,
    String? fromCurrency,
    String? toCurrency,
    double? fromBalance,
    double? toBalance,
    bool? loadingWallets,
    List<String>? ownedCurrencyCodes,
    Map<String, double>? ownedBalances,
    double? rate,
    String? rateDisplay,
    bool clearRateDisplay = false,
    Map<String, dynamic>? ratesResponse,
    bool clearRatesResponse = false,
    String? rateError,
    bool clearRateError = false,
    bool? loadingRate,
    bool? isSubmitting,
  }) {
    return SwapFlowState(
      step: step ?? this.step,
      fromCurrency: fromCurrency ?? this.fromCurrency,
      toCurrency: toCurrency ?? this.toCurrency,
      fromBalance: fromBalance ?? this.fromBalance,
      toBalance: toBalance ?? this.toBalance,
      loadingWallets: loadingWallets ?? this.loadingWallets,
      ownedCurrencyCodes: ownedCurrencyCodes ?? this.ownedCurrencyCodes,
      ownedBalances: ownedBalances ?? this.ownedBalances,
      rate: rate ?? this.rate,
      rateDisplay: clearRateDisplay ? null : (rateDisplay ?? this.rateDisplay),
      ratesResponse:
          clearRatesResponse ? null : (ratesResponse ?? this.ratesResponse),
      rateError: clearRateError ? null : (rateError ?? this.rateError),
      loadingRate: loadingRate ?? this.loadingRate,
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }
}

class SwapFlowNotifier extends AutoDisposeNotifier<SwapFlowState> {
  int _rateRequestId = 0;
  String? _initialFrom;

  @override
  SwapFlowState build() {
    ref.listen(walletAccountsProvider, (prev, next) {
      applyOwnedWallets(OwnedWalletBalances.allFromSnapshot(next.valueOrNull));
    }, fireImmediately: true);
    return const SwapFlowState();
  }

  void configure({String? initialFromCurrency}) {
    _initialFrom = initialFromCurrency?.toUpperCase();
    final snap = ref.read(walletAccountsProvider).valueOrNull;
    applyOwnedWallets(OwnedWalletBalances.allFromSnapshot(snap));
  }

  bool _isCrypto(String code) {
    final upper = code.toUpperCase();
    return upper == 'USDT' || upper == 'USDC';
  }

  void applyOwnedWallets(OwnedWalletBalances owned) {
    if (owned.allCodes.isEmpty) {
      state = state.copyWith(loadingWallets: false);
      return;
    }
    var from = state.fromCurrency;
    var to = state.toCurrency;
    final codes = owned.allCodes;

    final preferredFrom = _initialFrom;
    if (preferredFrom != null && codes.contains(preferredFrom)) {
      from = preferredFrom;
    } else if (!codes.contains(from)) {
      from = codes.first;
    }

    final preferredTo = _isCrypto(from)
        ? codes.firstWhere(
            (c) => !_isCrypto(c),
            orElse: () => codes.firstWhere(
              (c) => c != from,
              orElse: () => from,
            ),
          )
        : codes.firstWhere(
            (c) => _isCrypto(c),
            orElse: () => codes.firstWhere(
              (c) => c != from,
              orElse: () => from,
            ),
          );
    to = preferredTo == from && codes.length > 1
        ? codes.firstWhere((c) => c != from)
        : preferredTo;

    final pairChanged = from != state.fromCurrency || to != state.toCurrency;
    state = state.copyWith(
      ownedCurrencyCodes: codes,
      ownedBalances: owned.allBalances,
      fromCurrency: from,
      toCurrency: to,
      fromBalance: owned.allBalances[from] ?? 0,
      toBalance: owned.allBalances[to] ?? 0,
      loadingWallets: false,
    );
    if (pairChanged || state.rate == 0) {
      loadRate();
    }
  }

  void swapCurrencies() {
    if (state.ownedCurrencyCodes.length < 2) return;
    state = state.copyWith(
      fromCurrency: state.toCurrency,
      toCurrency: state.fromCurrency,
      fromBalance: state.toBalance,
      toBalance: state.fromBalance,
      rate: 0,
      clearRateDisplay: true,
      clearRatesResponse: true,
      clearRateError: true,
    );
    loadRate();
  }

  void setFromCurrency(String code) {
    final upper = code.toUpperCase();
    if (upper == state.fromCurrency) return;
    state = state.copyWith(
      fromCurrency: upper,
      fromBalance: state.ownedBalances[upper] ?? 0,
    );
    loadRate();
  }

  void setToCurrency(String code) {
    final upper = code.toUpperCase();
    if (upper == state.toCurrency) return;
    state = state.copyWith(
      toCurrency: upper,
      toBalance: state.ownedBalances[upper] ?? 0,
    );
    loadRate();
  }

  void applyNewBalances(Map<String, dynamic> newBalances) {
    final fromBal = newBalances[state.fromCurrency];
    final toBal = newBalances[state.toCurrency];
    final owned = Map<String, double>.from(state.ownedBalances);
    var from = state.fromBalance;
    var to = state.toBalance;
    if (fromBal is num) {
      from = fromBal.toDouble();
      owned[state.fromCurrency] = from;
    }
    if (toBal is num) {
      to = toBal.toDouble();
      owned[state.toCurrency] = to;
    }
    state = state.copyWith(
      fromBalance: from,
      toBalance: to,
      ownedBalances: owned,
    );
  }

  void goTo(SwapStep step) {
    state = state.copyWith(step: step);
  }

  void setSubmitting(bool value) {
    state = state.copyWith(isSubmitting: value);
  }

  Future<void> loadRate() async {
    final send = state.fromCurrency;
    final get = state.toCurrency;
    final requestId = ++_rateRequestId;
    state = state.copyWith(
      loadingRate: true,
      clearRateError: true,
      rate: 0,
      clearRateDisplay: true,
      clearRatesResponse: true,
    );

    try {
      final quote = await ref
          .read(ratesServiceProvider)
          .fetchExchangeQuote(send: send, get: get);
      if (requestId != _rateRequestId) return;
      state = state.copyWith(
        rate: quote.rate,
        rateDisplay: quote.display,
        ratesResponse: Map<String, dynamic>.from(quote.raw),
        clearRateError: true,
        loadingRate: false,
      );
    } on ExchangeQuoteException catch (e) {
      if (requestId != _rateRequestId) return;
      state = state.copyWith(
        rate: 0,
        clearRateDisplay: true,
        clearRatesResponse: true,
        rateError: e.message,
        loadingRate: false,
      );
    } catch (e, st) {
      Logger.error('Unexpected exchange quote error', e, st);
      if (requestId != _rateRequestId) return;
      state = state.copyWith(
        rate: 0,
        clearRateDisplay: true,
        clearRatesResponse: true,
        rateError: 'Could not load exchange rate.',
        loadingRate: false,
      );
    }
  }
}

final swapFlowProvider =
    AutoDisposeNotifierProvider<SwapFlowNotifier, SwapFlowState>(
  SwapFlowNotifier.new,
);
