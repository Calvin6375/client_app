import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pretium/core/providers/service_providers.dart';
import 'package:pretium/core/providers/wallet_accounts_provider.dart';
import 'package:pretium/features/topup/models/topup_deposit_country.dart';
import 'package:pretium/features/topup/models/topup_quote.dart';
import 'package:pretium/features/topup/services/topup_quote_api_service.dart';
import 'package:pretium/services/countries_api_service.dart';

enum TopUpPaymentMethod {
  cardMobileMoney,
  directFiatDeposit,
  cryptoDeposit,
}

enum TopUpStep { form, review }

List<String> topupFiatCurrencyCodes({
  List<String>? apiCodes,
  String? includeCode,
  bool excludeAfrican = false,
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
  if (extra != null && extra.isNotEmpty) {
    final extraAllowed = excludeAfrican
        ? !TopupDepositCountry.isAfricanCurrency(extra)
        : TopupDepositCountry.isAllowedOnDepositSelector(extra);
    if (extraAllowed) codes.add(extra);
  }

  final list = codes.toList()..sort();
  if (excludeAfrican) {
    return list
        .where((c) => !TopupDepositCountry.isAfricanCurrency(c))
        .toList();
  }
  return list.where(TopupDepositCountry.isAllowedOnDepositSelector).toList();
}

String coerceTopupFiatCurrency(String? code) {
  final u = code?.trim().toUpperCase() ?? '';
  if (u.isEmpty) return 'USD';
  return TopupDepositCountry.resolve(u).code;
}

class TopUpFlowState {
  const TopUpFlowState({
    this.method = TopUpPaymentMethod.directFiatDeposit,
    this.step = TopUpStep.form,
    this.selectedCurrency = 'USD',
    this.fiatBalances = const {},
    this.apiFiatCurrencies = const [],
    this.loadingCountries = true,
    this.quote,
    this.isLoadingQuote = false,
    this.quoteError,
    this.isProcessingPayment = false,
  });

  final TopUpPaymentMethod method;
  final TopUpStep step;
  final String selectedCurrency;
  final Map<String, double> fiatBalances;
  final List<String> apiFiatCurrencies;
  final bool loadingCountries;
  final TopupQuote? quote;
  final bool isLoadingQuote;
  final String? quoteError;
  final bool isProcessingPayment;

  bool get isInternational => method == TopUpPaymentMethod.cardMobileMoney;

  double get availableBalance => fiatBalances[selectedCurrency] ?? 0;

  List<String> get depositPickerCurrencies => topupFiatCurrencyCodes(
        apiCodes: apiFiatCurrencies,
        includeCode: selectedCurrency,
        excludeAfrican: isInternational,
      );

  String get cardMobileMoneyProvider =>
      TopupDepositCountry.cardMobileMoneyProviderFor(selectedCurrency);

  String get providerDisplayLabel {
    switch (cardMobileMoneyProvider) {
      case 'paystack':
        return 'Paystack';
      case 'transak':
        return 'Transak';
      default:
        return cardMobileMoneyProvider;
    }
  }

  TopUpFlowState copyWith({
    TopUpPaymentMethod? method,
    TopUpStep? step,
    String? selectedCurrency,
    Map<String, double>? fiatBalances,
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
      method: method ?? this.method,
      step: step ?? this.step,
      selectedCurrency: selectedCurrency ?? this.selectedCurrency,
      fiatBalances: fiatBalances ?? this.fiatBalances,
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
      applyFiatBalances({
        for (final e in snap.fiatWallets.entries) e.key: e.value.balance,
      });
    }, fireImmediately: true);
    Future<void>(_loadCountries);
    return const TopUpFlowState();
  }

  void configureInitialCurrency(String? code) {
    if (code == null || code.trim().isEmpty) return;
    state = state.copyWith(selectedCurrency: coerceTopupFiatCurrency(code));
  }

  void applyFiatBalances(Map<String, double> balances) {
    if (balances.isEmpty) return;
    var currency = state.selectedCurrency;
    if (!balances.containsKey(currency) && balances.isNotEmpty) {
      // Keep explicit selection even if missing; only seed when still USD default
      // and we have a KES wallet.
      if (currency == 'USD' && balances.containsKey('KES')) {
        currency = 'KES';
      }
    }
    state = state.copyWith(
      fiatBalances: balances,
      selectedCurrency: currency,
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
    final allowed = topupFiatCurrencyCodes(
      apiCodes: fiatCodes,
      includeCode: selected,
    );
    if (!allowed.contains(selected) && allowed.isNotEmpty) {
      selected = allowed.first;
    }
    state = state.copyWith(
      apiFiatCurrencies: List<String>.from(fiatCodes),
      loadingCountries: false,
      selectedCurrency: selected,
    );
  }

  void selectMethod(TopUpPaymentMethod method) {
    var currency = state.selectedCurrency;
    if (method == TopUpPaymentMethod.cardMobileMoney &&
        TopupDepositCountry.isAfricanCurrency(currency)) {
      final international = topupFiatCurrencyCodes(
        apiCodes: state.apiFiatCurrencies,
        excludeAfrican: true,
      );
      currency = international.contains('USD')
          ? 'USD'
          : (international.isNotEmpty ? international.first : 'USD');
    }
    state = state.copyWith(method: method, selectedCurrency: currency);
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
