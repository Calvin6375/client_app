import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pretium/core/providers/service_providers.dart';
import 'package:pretium/core/providers/wallet_accounts_provider.dart';
import 'package:pretium/features/topup/models/topup_deposit_country.dart';
import 'package:pretium/features/topup/models/topup_quote.dart';
import 'package:pretium/features/topup/services/topup_quote_api_service.dart';
import 'package:pretium/services/countries_api_service.dart';
import 'package:pretium/services/dashboard_session_cache.dart';

enum TopUpStep { form, review }

List<String> topupFiatCurrencyCodes({
  List<String>? apiCodes,
  String? includeCode,
}) {
  final codes = <String>{
    if (apiCodes != null && apiCodes.isNotEmpty)
      ...apiCodes
    else ...[
      ...TopupDepositCountry.depositCurrencyCodes,
      'EUR',
      'GBP',
    ],
  };

  final extra = includeCode?.trim().toUpperCase();
  if (extra != null &&
      extra.isNotEmpty &&
      TopupDepositCountry.isAllowedOnDepositSelector(extra)) {
    codes.add(extra);
  }

  final list = codes.toList()..sort();
  return list.where(TopupDepositCountry.isAllowedOnDepositSelector).toList();
}

/// Fiat codes first, then USDC / USDT / BNB for the deposit currency picker.
List<String> topupDepositPickerCodes({
  List<String>? apiCodes,
  String? includeCode,
}) {
  final fiat = topupFiatCurrencyCodes(
    apiCodes: apiCodes,
    includeCode: includeCode,
  );
  final crypto = List<String>.from(TopupDepositCountry.cryptoDepositAssets);
  final extra = includeCode?.trim().toUpperCase();
  if (extra != null &&
      TopupDepositCountry.isCryptoDepositAsset(extra) &&
      !crypto.contains(extra)) {
    crypto.add(extra);
  }
  return [...fiat, ...crypto];
}

class TopUpFlowState {
  const TopUpFlowState({
    this.step = TopUpStep.form,
    this.selectedCurrency = '',
    this.fiatBalances = const {},
    this.cryptoBalances = const {},
    this.apiFiatCurrencies = const [],
    this.loadingCountries = true,
    this.quote,
    this.isLoadingQuote = false,
    this.quoteError,
    this.isProcessingPayment = false,
  });

  final TopUpStep step;
  final String selectedCurrency;
  final Map<String, double> fiatBalances;
  final Map<String, double> cryptoBalances;
  final List<String> apiFiatCurrencies;
  final bool loadingCountries;
  final TopupQuote? quote;
  final bool isLoadingQuote;
  final String? quoteError;
  final bool isProcessingPayment;

  bool get hasSelectedCurrency => selectedCurrency.trim().isNotEmpty;

  bool get isCryptoDeposit =>
      hasSelectedCurrency &&
      TopupDepositCountry.isCryptoDepositAsset(selectedCurrency);

  double get availableBalance {
    if (!hasSelectedCurrency) return 0;
    return fiatBalances[selectedCurrency] ??
        cryptoBalances[selectedCurrency] ??
        0;
  }

  List<String> get depositPickerCurrencies => topupDepositPickerCodes(
        apiCodes: apiFiatCurrencies,
        includeCode: selectedCurrency,
      );

  String get cardMobileMoneyProvider =>
      TopupDepositCountry.cardMobileMoneyProviderFor(selectedCurrency);

  String get providerDisplayLabel {
    switch (cardMobileMoneyProvider) {
      case 'paystack':
        return 'Paystack';
      case 'transak':
        return 'Transak';
      case 'crossmint':
        return 'Card';
      default:
        return cardMobileMoneyProvider;
    }
  }

  TopUpFlowState copyWith({
    TopUpStep? step,
    String? selectedCurrency,
    Map<String, double>? fiatBalances,
    Map<String, double>? cryptoBalances,
    List<String>? apiFiatCurrencies,
    bool? loadingCountries,
    TopupQuote? quote,
    bool clearQuote = false,
    bool? isLoadingQuote,
    String? quoteError,
    bool clearQuoteError = false,
    bool? isProcessingPayment,
  }) {
    return TopUpFlowState(
      step: step ?? this.step,
      selectedCurrency: selectedCurrency ?? this.selectedCurrency,
      fiatBalances: fiatBalances ?? this.fiatBalances,
      cryptoBalances: cryptoBalances ?? this.cryptoBalances,
      apiFiatCurrencies: apiFiatCurrencies ?? this.apiFiatCurrencies,
      loadingCountries: loadingCountries ?? this.loadingCountries,
      quote: clearQuote ? null : (quote ?? this.quote),
      isLoadingQuote: isLoadingQuote ?? this.isLoadingQuote,
      quoteError: clearQuoteError ? null : (quoteError ?? this.quoteError),
      isProcessingPayment: isProcessingPayment ?? this.isProcessingPayment,
    );
  }
}

class TopUpFlowNotifier extends AutoDisposeNotifier<TopUpFlowState> {
  int _quoteRequestId = 0;

  @override
  TopUpFlowState build() {
    ref.listen(walletAccountsProvider, (prev, next) {
      final snap = next.valueOrNull;
      if (snap == null) return;
      applyWalletBalances(snap);
    });
    Future<void>(_loadCountries);
    return _initialState(ref.read(walletAccountsProvider).valueOrNull);
  }

  static Map<String, double> _fiatBalancesFrom(WalletSessionSnapshot snap) {
    return {
      for (final e in snap.fiatWallets.entries) e.key: e.value.balance,
    };
  }

  static Map<String, double> _cryptoBalancesFrom(WalletSessionSnapshot snap) {
    return {
      for (final e in snap.cryptoWallets.entries) e.key: e.value.balance,
    };
  }

  static TopUpFlowState _initialState(WalletSessionSnapshot? snap) {
    if (snap == null) return const TopUpFlowState();
    final fiat = _fiatBalancesFrom(snap);
    final crypto = _cryptoBalancesFrom(snap);
    if (fiat.isEmpty && crypto.isEmpty) return const TopUpFlowState();
    return TopUpFlowState(
      fiatBalances: fiat,
      cryptoBalances: crypto,
    );
  }

  void applyWalletBalances(WalletSessionSnapshot snap) {
    final fiat = _fiatBalancesFrom(snap);
    final crypto = _cryptoBalancesFrom(snap);
    if (fiat.isEmpty && crypto.isEmpty) return;
    state = state.copyWith(
      fiatBalances: fiat,
      cryptoBalances: crypto,
    );
  }

  Future<void> _loadCountries() async {
    final cached = CountriesApiService.cached;
    if (cached != null && cached.fiatCodes.isNotEmpty) {
      _applyDepositCurrencies(cached.fiatCodes);
    }
    try {
      final catalog = await ref.read(countriesApiProvider).fetchCountries();
      _applyDepositCurrencies(catalog.fiatCodes);
    } catch (_) {
      state = state.copyWith(loadingCountries: false);
    }
  }

  void _applyDepositCurrencies(List<String> fiatCodes) {
    var selected = state.selectedCurrency;
    final allowed = topupDepositPickerCodes(
      apiCodes: fiatCodes,
      includeCode: selected,
    );
    if (selected.isNotEmpty && !allowed.contains(selected)) {
      selected = '';
    }
    state = state.copyWith(
      apiFiatCurrencies: List<String>.from(fiatCodes),
      loadingCountries: false,
      selectedCurrency: selected,
    );
  }

  void selectCurrency(String currency) {
    state = state.copyWith(selectedCurrency: currency.toUpperCase());
  }

  void goToReview() {
    state = state.copyWith(
      step: TopUpStep.review,
      clearQuote: true,
      clearQuoteError: true,
      isLoadingQuote: true,
    );
  }

  void goToForm() {
    _quoteRequestId++;
    state = state.copyWith(
      step: TopUpStep.form,
      isLoadingQuote: false,
      clearQuoteError: true,
    );
  }

  void setProcessing(bool value) {
    state = state.copyWith(isProcessingPayment: value);
  }

  Future<void> loadQuote({required double amount}) async {
    final requestId = ++_quoteRequestId;
    final currency = state.selectedCurrency;
    state = state.copyWith(isLoadingQuote: true, clearQuoteError: true);
    try {
      final quote = await ref.read(topupQuoteApiProvider).fetchQuote(
            amount: amount,
            currency: currency,
          );
      if (requestId != _quoteRequestId) return;
      state = state.copyWith(
        quote: quote,
        isLoadingQuote: false,
        clearQuoteError: true,
      );
    } catch (e) {
      if (requestId != _quoteRequestId) return;
      final message = e is TopupQuoteApiException
          ? e.message
          : 'Unable to load deposit quote. Please try again.';
      state = state.copyWith(
        isLoadingQuote: false,
        quoteError: message,
        quote: TopupQuote.fallback(
          amount: amount,
          currency: currency,
          checkoutProvider: state.providerDisplayLabel,
        ),
      );
    }
  }
}

final topUpFlowProvider =
    AutoDisposeNotifierProvider<TopUpFlowNotifier, TopUpFlowState>(
  TopUpFlowNotifier.new,
);
