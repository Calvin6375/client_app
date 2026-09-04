// Top-up screen: fiat (Paystack / Transak card checkout) and crypto.
// Local and International topup: PaymentService.createPayment → hosted checkout in-app WebView.
// African currencies → Paystack; USD, GBP, EUR, and other non-African → Transak.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pretium/repositories/wallet_repository.dart';
import 'package:pretium/repositories/user_repository.dart';
import 'package:pretium/services/payment_service.dart';
import 'package:pretium/services/dashboard_session_cache.dart';
import 'package:pretium/services/wallet_balance_refresh.dart';
import 'package:pretium/services/countries_api_service.dart';
import 'package:pretium/models/wallet_model.dart';
import 'package:pretium/utils/firebase_utils.dart';
import 'package:pretium/core/constants/app_colors.dart';
import 'package:pretium/features/topup/models/topup_deposit_country.dart';
import 'package:pretium/features/topup/models/topup_quote.dart';
import 'package:pretium/features/topup/screens/deposit_review_screen.dart';
import 'package:pretium/features/topup/screens/payment_checkout_webview_page.dart';
import 'package:pretium/features/topup/services/topup_quote_api_service.dart';
import 'package:pretium/widgets/currency_logo.dart';
import 'package:pretium/widgets/app_shimmer.dart';
import 'package:pretium/widgets/bottom_safe_action_bar.dart';

/// Fiat codes for the Deposit currency picker.
/// Prefers [apiCodes] from `GET /api/countries`; falls back to the static catalog.
/// When [excludeAfrican] is true (International Topup), African fiat is omitted.
/// Otherwise African fiat is dropped except KES and ETB; AED is never shown.
List<String> _topupFiatCurrencyCodes({
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
  return list
      .where(TopupDepositCountry.isAllowedOnDepositSelector)
      .toList();
}

String _coerceTopupFiatCurrency(String? code) {
  final u = code?.trim().toUpperCase() ?? '';
  if (u.isEmpty) return 'USD';
  return TopupDepositCountry.resolve(u).code;
}

enum _TopUpPaymentMethod {
  cardMobileMoney,
  directFiatDeposit,
  cryptoDeposit,
}

enum _TopUpStep { form, review }

// Top Up main screen composed of smaller widgets
class TopUpPage extends StatefulWidget {
  const TopUpPage({super.key, this.initialDepositCountry});

  /// When set, pre-selects that currency in Set amount and is passed to direct fiat deposit.
  final TopupDepositCountry? initialDepositCountry;

  @override
  State<TopUpPage> createState() => _TopUpPageState();
}

class _TopUpPageState extends State<TopUpPage> {
  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _firstNameCtrl = TextEditingController();
  final TextEditingController _lastNameCtrl = TextEditingController();

  final WalletRepository _walletRepository = WalletRepository();
  final UserRepository _userRepository = UserRepository();
  final CountriesApiService _countriesApi = CountriesApiService();
  final TopupQuoteApiService _quoteApi = TopupQuoteApiService();

  bool _hideBalance = false;
  /// Per-currency fiat balances so Available matches the selected currency.
  final Map<String, double> _fiatBalances = {};
  String _selectedCurrency = 'USD';
  bool _isProcessingPayment = false;
  bool _isLoadingBalance = false;
  bool _hasBalanceData = false;
  bool _loadingCountries = true;
  List<String> _apiFiatCurrencies = const [];
  _TopUpPaymentMethod _selectedMethod = _TopUpPaymentMethod.directFiatDeposit;
  _TopUpStep _step = _TopUpStep.form;

  TopupQuote? _quote;
  bool _isLoadingQuote = false;
  String? _quoteError;
  int _quoteRequestId = 0;

  /// Minimum Set amount for Fiat Option actions when currency is KES.
  static const double _kesFiatOptionMinimumAmount = 150;

  double get _availableBalanceForSelected =>
      _fiatBalances[_selectedCurrency] ?? 0.0;

  bool get _isInternationalTopup =>
      _selectedMethod == _TopUpPaymentMethod.cardMobileMoney;

  List<String> get _depositPickerCurrencies => _topupFiatCurrencyCodes(
        apiCodes: _apiFiatCurrencies,
        includeCode: _selectedCurrency,
        excludeAfrican: _isInternationalTopup,
      );

  void _selectPaymentMethod(_TopUpPaymentMethod method) {
    setState(() {
      _selectedMethod = method;
      if (method == _TopUpPaymentMethod.cardMobileMoney &&
          TopupDepositCountry.isAfricanCurrency(_selectedCurrency)) {
        final international = _topupFiatCurrencyCodes(
          apiCodes: _apiFiatCurrencies,
          excludeAfrican: true,
        );
        _selectedCurrency = international.contains('USD')
            ? 'USD'
            : (international.isNotEmpty ? international.first : 'USD');
      }
    });
  }

  @override
  void initState() {
    super.initState();
    final country = widget.initialDepositCountry;
    if (country != null) {
      _selectedCurrency = _coerceTopupFiatCurrency(country.code);
    }
    _hydrateBalancesFromCache();
    _loadWalletBalance(silent: _hasBalanceData);
    _loadUserProfile();
    _loadDepositCurrencies();
  }

  Future<void> _loadDepositCurrencies() async {
    final cached = CountriesApiService.cached;
    if (cached != null && cached.fiatCodes.isNotEmpty) {
      _applyDepositCurrencies(cached.fiatCodes);
    }

    try {
      final catalog = await _countriesApi.fetchCountries();
      if (!mounted) return;
      _applyDepositCurrencies(catalog.fiatCodes);
    } catch (e) {
      debugPrint('TopUpPage - Failed to load /api/countries: $e');
      if (!mounted) return;
      setState(() => _loadingCountries = false);
    }
  }

  void _applyDepositCurrencies(List<String> fiatCodes) {
    setState(() {
      _apiFiatCurrencies = List<String>.from(fiatCodes);
      _loadingCountries = false;
      final allowed = _topupFiatCurrencyCodes(
        apiCodes: _apiFiatCurrencies,
        includeCode: _selectedCurrency,
      );
      if (!allowed.contains(_selectedCurrency) && allowed.isNotEmpty) {
        _selectedCurrency = allowed.first;
      }
    });
  }

  void _hydrateBalancesFromCache() {
    final snap = DashboardSessionCache.instance.readWalletLastKnown();
    if (snap == null) return;

    for (final entry in snap.fiatWallets.entries) {
      _fiatBalances[entry.key] = entry.value.balance;
    }
    _hasBalanceData = _fiatBalances.isNotEmpty;

    // Only pick a default currency from cache when the caller did not preset one.
    if (widget.initialDepositCountry == null &&
        snap.availableFiatCurrencies.isNotEmpty) {
      _selectedCurrency =
          _coerceTopupFiatCurrency(snap.availableFiatCurrencies.first);
    }
  }

  Future<void> _loadUserProfile() async {
    if (!isFirebaseInitialized()) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userProfile = await _userRepository.getUserProfile(user.uid);
      if (userProfile != null && mounted) {
        // Auto-fill user data from Firestore
        _emailCtrl.text = userProfile.email;
        _firstNameCtrl.text = userProfile.firstName;
        _lastNameCtrl.text = userProfile.lastName;
      }
    } catch (e) {
      debugPrint('Failed to load user profile on TopUpPage: $e');
      // Continue without auto-filling if profile load fails
    }
  }

  Future<void> _loadWalletBalance({bool silent = false}) async {
    if (_isLoadingBalance || !isFirebaseInitialized()) return;

    if (!silent) {
      setState(() {
        _isLoadingBalance = true;
      });
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final accounts = await _walletRepository.fetchAccounts(forceRefresh: true);
      final fiatWallets = <String, Wallet>{
        ...accounts.fiatWallets,
        for (final e in accounts.fiatBalances.entries)
          if (!accounts.fiatWallets.containsKey(e.key))
            e.key: Wallet(currencyCode: e.key, balance: e.value),
      };
      // Ensure USD is present so the dropdown always has a balance entry.
      fiatWallets.putIfAbsent(
        'USD',
        () => accounts.fiatWallet('USD') ?? Wallet(currencyCode: 'USD', balance: 0),
      );

      final availableCurrencies = accounts.fiatWallets.keys.toList();
      if (availableCurrencies.isEmpty) {
        availableCurrencies.addAll(fiatWallets.keys);
      }
      if (!availableCurrencies.contains('USD')) {
        availableCurrencies.insert(0, 'USD');
      }

      final cryptoWallet = accounts.cryptoWallet('USDT') ??
          Wallet(currencyCode: 'USDT', balance: 0);

      final existing = DashboardSessionCache.instance.readWalletLastKnown();
      final cryptoWallets = <String, Wallet>{
        ...?existing?.cryptoWallets,
        ...accounts.cryptoWallets,
        'USDT': cryptoWallet,
      };

      DashboardSessionCache.instance.recordWalletSnapshot(
        fiatWallets: {
          ...?existing?.fiatWallets,
          ...fiatWallets,
        },
        availableFiatCurrencies: availableCurrencies.isNotEmpty
            ? availableCurrencies
            : (existing?.availableFiatCurrencies ?? ['USD']),
        cryptoWallets: cryptoWallets,
        availableCryptoCurrencies: existing?.availableCryptoCurrencies.isNotEmpty == true
            ? existing!.availableCryptoCurrencies
            : const ['USDT', 'USDC'],
        cachedFiatWallet: fiatWallets[_selectedCurrency] ??
            fiatWallets[availableCurrencies.isNotEmpty
                ? availableCurrencies.first
                : 'USD'] ??
            existing?.cachedFiatWallet,
        cachedCryptoWallet: cryptoWallets['USDT'] ?? existing?.cachedCryptoWallet,
      );

      if (!mounted) return;

      setState(() {
        _fiatBalances
          ..clear()
          ..addEntries(
            fiatWallets.entries.map((e) => MapEntry(e.key, e.value.balance)),
          );
        _hasBalanceData = true;
        // Keep the user's selected currency; do not overwrite after init.
      });
    } catch (e) {
      debugPrint('Failed to load wallet balances on TopUpPage: $e');
      if (!mounted || silent) return;
      setState(() {
        if (!_hasBalanceData) {
          _fiatBalances.clear();
        }
      });
    } finally {
      if (mounted && !silent) {
        setState(() {
          _isLoadingBalance = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _emailCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    super.dispose();
  }

  double _parsedSetAmount() {
    final text = _amountCtrl.text.replaceAll(',', '').trim();
    return double.tryParse(text) ?? 0.0;
  }

  /// Fiat Option (Paystack, Transak, direct fiat): KES requires at least [_kesFiatOptionMinimumAmount].
  bool _meetsKesFiatOptionMinimum() {
    if (_selectedCurrency != 'KES') return true;
    return _parsedSetAmount() >= _kesFiatOptionMinimumAmount;
  }

  String get _cardMobileMoneyProvider =>
      TopupDepositCountry.cardMobileMoneyProviderFor(_selectedCurrency);

  String get _providerDisplayLabel {
    switch (_cardMobileMoneyProvider) {
      case 'paystack':
        return 'Paystack';
      case 'transak':
        return 'Transak';
      default:
        return _cardMobileMoneyProvider;
    }
  }

  String get _paymentMethodTitle {
    switch (_selectedMethod) {
      case _TopUpPaymentMethod.directFiatDeposit:
        return 'Local Topup';
      case _TopUpPaymentMethod.cardMobileMoney:
        return 'International Topup';
      case _TopUpPaymentMethod.cryptoDeposit:
        return 'Crypto Deposit';
    }
  }

  String get _paymentMethodSubtitle {
    switch (_selectedMethod) {
      case _TopUpPaymentMethod.directFiatDeposit:
        return 'Local bank or card or mobile money';
      case _TopUpPaymentMethod.cardMobileMoney:
        return 'International bank or card, Apple Pay or Google Pay';
      case _TopUpPaymentMethod.cryptoDeposit:
        return 'Crypto or stablecoin to a wallet address';
    }
  }

  /// Returns false (and shows an error) when the form is not ready for review/checkout.
  bool _validateFiatDepositForm() {
    if (_amountCtrl.text.isEmpty) {
      _showError('Please enter an amount');
      return false;
    }

    final amount = _parsedSetAmount();
    if (amount <= 0) {
      _showError('Please enter a valid amount');
      return false;
    }
    if (!_meetsKesFiatOptionMinimum()) {
      _showError(
        'For KES, the minimum amount for fiat top-up options is KSh ${_kesFiatOptionMinimumAmount.toStringAsFixed(0)}.',
      );
      return false;
    }

    final user = FirebaseAuth.instance.currentUser;
    final email = _emailCtrl.text.trim().isNotEmpty
        ? _emailCtrl.text.trim()
        : user?.email;
    if (email == null || email.isEmpty) {
      _showError('An email address is required for payment.');
      return false;
    }
    return true;
  }

  void _goToReview() {
    setState(() {
      _step = _TopUpStep.review;
      _quote = null;
      _quoteError = null;
      _isLoadingQuote = true;
    });
    _loadTopupQuote();
  }

  void _goToForm() {
    if (_isProcessingPayment) return;
    _quoteRequestId++;
    setState(() {
      _step = _TopUpStep.form;
      _isLoadingQuote = false;
      _quoteError = null;
    });
  }

  Future<void> _loadTopupQuote() async {
    final requestId = ++_quoteRequestId;
    final amount = _parsedSetAmount();
    final currency = _selectedCurrency;

    setState(() {
      _isLoadingQuote = true;
      _quoteError = null;
    });

    try {
      final quote = await _quoteApi.fetchQuote(
        amount: amount,
        currency: currency,
      );
      if (!mounted || requestId != _quoteRequestId) return;
      setState(() {
        _quote = quote;
        _isLoadingQuote = false;
        _quoteError = null;
      });
    } catch (e) {
      if (!mounted || requestId != _quoteRequestId) return;
      final message = e is TopupQuoteApiException
          ? e.message
          : 'Unable to load deposit quote. Please try again.';
      setState(() {
        _isLoadingQuote = false;
        _quoteError = message;
        // Keep Confirm disabled until a successful quote; show Free/amount fallback
        // values only as placeholders while the user retries.
        _quote = TopupQuote.fallback(
          amount: amount,
          currency: currency,
          checkoutProvider: _providerDisplayLabel,
        );
      });
    }
  }

  void _onBackPressed() {
    if (_step == _TopUpStep.review) {
      _goToForm();
      return;
    }
    Navigator.of(context).pop();
  }

  /// Card checkout: createPayment (Cloud Function) → open hosted checkout in-app.
  Future<void> _processFiatTopUp() async {
    if (!_validateFiatDepositForm()) return;
    if (_isProcessingPayment) return;

    final amount = _parsedSetAmount();
    final user = FirebaseAuth.instance.currentUser;
    final email = _emailCtrl.text.trim().isNotEmpty
        ? _emailCtrl.text.trim()
        : user?.email;

    setState(() {
      _isProcessingPayment = true;
    });

    try {
      String? userPhoneNumber;
      try {
        if (user != null) {
          final userProfile = await _userRepository.getUserProfile(user.uid);
          userPhoneNumber = userProfile?.phoneNumber;
        }
      } catch (_) {}

      final paymentService = PaymentService();
      final result = await paymentService.createPayment(
        amount: amount,
        currency: _selectedCurrency,
        provider: _cardMobileMoneyProvider,
        email: email!,
        firstName: _firstNameCtrl.text.trim().isNotEmpty
            ? _firstNameCtrl.text.trim()
            : null,
        lastName: _lastNameCtrl.text.trim().isNotEmpty
            ? _lastNameCtrl.text.trim()
            : null,
        phoneNumber: userPhoneNumber,
      );

      if (result['success'] != true) {
        _showError(result['error']?.toString() ?? 'Payment failed');
        return;
      }

      final checkoutUrl = result['checkoutUrl'] as String?;
      final invoiceId = result['invoiceId'] as String? ?? result['paymentId'] as String?;
      if (checkoutUrl == null ||
          checkoutUrl.isEmpty ||
          invoiceId == null ||
          invoiceId.isEmpty) {
        _showError('No checkout URL returned from server');
        return;
      }

      if (!mounted) return;

      await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => PaymentCheckoutWebViewPage(
            checkoutUrl: checkoutUrl,
            paymentId: invoiceId,
            title: 'Secure checkout',
          ),
        ),
      );
      // Checkout may have settled while the WebView was open — refresh ledger.
      await WalletBalanceRefresh.afterSuccessfulTransaction();
      if (mounted) await _loadWalletBalance(silent: true);
    } catch (e) {
      _showError('Error processing payment: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingPayment = false;
        });
      }
    }
  }

  void _onNextPressed() {
    if (_isProcessingPayment) return;
    switch (_selectedMethod) {
      case _TopUpPaymentMethod.cardMobileMoney:
      case _TopUpPaymentMethod.directFiatDeposit:
        if (_validateFiatDepositForm()) {
          _goToReview();
        }
      case _TopUpPaymentMethod.cryptoDeposit:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Copy a crypto address below and send your deposit.'),
          ),
        );
    }
  }

  void _showError(String message) {
    debugPrint('Showing error dialog: $message');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              debugPrint('User acknowledged error dialog');
              Navigator.of(context).pop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final isReview = _step == _TopUpStep.review;

    return PopScope(
      canPop: !isReview,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && isReview) {
          _goToForm();
        }
      },
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: isReview
              ? Text(
                  'Deposit',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                  ),
                )
              : null,
          centerTitle: true,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: colors.textPrimary),
            onPressed: _onBackPressed,
          ),
          actions: [
            if (!isReview)
              IconButton(
                icon: Icon(
                  _hideBalance ? Icons.visibility_off : Icons.visibility,
                  color: colors.textSecondary,
                ),
                onPressed: () => setState(() => _hideBalance = !_hideBalance),
              ),
          ],
        ),
        body: isReview ? _buildReviewStep() : _buildFormStep(colors),
      ),
    );
  }

  Widget _buildReviewStep() {
    final amount = _parsedSetAmount();
    final fallbackAmount =
        '${amount.toStringAsFixed(2)} $_selectedCurrency';

    return DepositReviewScreen(
      quote: _quote,
      isLoadingQuote: _isLoadingQuote,
      quoteError: _quoteError,
      onRetryQuote: _isLoadingQuote ? null : _loadTopupQuote,
      fallbackAmountLabel: fallbackAmount,
      paymentMethodTitle: _paymentMethodTitle,
      paymentMethodSubtitle: _paymentMethodSubtitle,
      isSubmitting: _isProcessingPayment,
      onEditDepositDetails: _goToForm,
      onEditPaymentMethod: _goToForm,
      onConfirm: _processFiatTopUp,
    );
  }

  Widget _buildFormStep(AppThemeColors colors) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final availableLabel = _hideBalance
        ? 'Available: •••• $_selectedCurrency'
        : 'Available: ${_availableBalanceForSelected.toStringAsFixed(2)} $_selectedCurrency';
    final nextEnabled = _selectedMethod != _TopUpPaymentMethod.cryptoDeposit;
    final nextLabel = nextEnabled ? 'Next' : 'Copy address below';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Deposit',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Deposit',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                _DepositAmountField(
                  controller: _amountCtrl,
                  selectedCurrency: _selectedCurrency,
                  currencies: _depositPickerCurrencies,
                  loadingCurrencies: _loadingCountries,
                  onCurrencyChanged: (currency) {
                    setState(() => _selectedCurrency = currency);
                  },
                ),
                const SizedBox(height: 8),
                if (_isLoadingBalance && !_hasBalanceData)
                  const ShimmerBusyIndicator(width: 96, height: 12)
                else
                  Text(
                    availableLabel,
                    style: TextStyle(
                      fontSize: 13,
                      color: colors.textSecondary,
                    ),
                  ),
                const SizedBox(height: 32),
                Text(
                  'Select a payment method',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                _PaymentMethodTile(
                  title: 'Local Topup',
                  subtitle: 'Local bank or card or mobile money',
                  brandIcon: Icons.account_balance_outlined,
                  selected:
                      _selectedMethod == _TopUpPaymentMethod.directFiatDeposit,
                  onTap: () =>
                      _selectPaymentMethod(_TopUpPaymentMethod.directFiatDeposit),
                ),
                const SizedBox(height: 12),
                _PaymentMethodTile(
                  title: 'International Topup',
                  subtitle:
                      'International bank or card, Apple Pay or Google Pay.',
                  brandIcon: Icons.payment,
                  selected:
                      _selectedMethod == _TopUpPaymentMethod.cardMobileMoney,
                  onTap: () =>
                      _selectPaymentMethod(_TopUpPaymentMethod.cardMobileMoney),
                ),
                const SizedBox(height: 12),
                _PaymentMethodTile(
                  title: 'Crypto Deposit',
                  subtitle:
                      'Send any crypto or stablecoin from any network to a wallet address',
                  brandIcon: Icons.currency_bitcoin,
                  selected:
                      _selectedMethod == _TopUpPaymentMethod.cryptoDeposit,
                  onTap: () =>
                      _selectPaymentMethod(_TopUpPaymentMethod.cryptoDeposit),
                ),
                if (_selectedMethod == _TopUpPaymentMethod.cryptoDeposit) ...[
                  const SizedBox(height: 16),
                  const _CryptoDepositDetails(),
                ],
              ],
            ),
          ),
        ),
        BottomSafeActionBar(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: SizedBox(
            height: 52,
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: isDark ? colors.onPrimary : Colors.white,
                disabledBackgroundColor: colors.surfaceVariant,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              onPressed: _isProcessingPayment ? null : _onNextPressed,
              child: _isProcessingPayment
                  ? const ShimmerBusyIndicator(onPrimary: true)
                  : Text(
                      nextLabel,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

// Argo-style deposit layout widgets
class _DepositAmountField extends StatelessWidget {
  const _DepositAmountField({
    required this.controller,
    required this.selectedCurrency,
    required this.currencies,
    required this.onCurrencyChanged,
    this.loadingCurrencies = false,
  });

  final TextEditingController controller;
  final String selectedCurrency;
  final List<String> currencies;
  final ValueChanged<String> onCurrencyChanged;
  final bool loadingCurrencies;

  Future<void> _openCurrencyPicker(BuildContext context) async {
    if (loadingCurrencies && currencies.isEmpty) return;
    final colors = AppColors.getThemeColors(context);

    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.55,
          child: _CurrencyPickerSheet(
            currencies: currencies,
            selectedCurrency: selectedCurrency,
          ),
        );
      },
    );

    if (picked != null) onCurrencyChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? colors.surface : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.surfaceVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: colors.textPrimary,
              ),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                border: InputBorder.none,
                hintText: '0.00',
                hintStyle: TextStyle(color: colors.textSecondary),
              ),
            ),
          ),
          Container(
            width: 1,
            height: 44,
            color: colors.surfaceVariant,
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _openCurrencyPicker(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      TopupDepositCountry.flagEmojiForCode(selectedCurrency),
                      style: const TextStyle(fontSize: 18),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      selectedCurrency,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: primary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.keyboard_arrow_down, color: colors.textSecondary, size: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrencyPickerSheet extends StatefulWidget {
  const _CurrencyPickerSheet({
    required this.currencies,
    required this.selectedCurrency,
  });

  final List<String> currencies;
  final String selectedCurrency;

  @override
  State<_CurrencyPickerSheet> createState() => _CurrencyPickerSheetState();
}

class _CurrencyPickerSheetState extends State<_CurrencyPickerSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<String> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.currencies;
    return widget.currencies.where((code) {
      final country = TopupDepositCountry.resolve(code);
      return code.toLowerCase().contains(q) ||
          country.name.toLowerCase().contains(q) ||
          country.currencyName.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final primary = Theme.of(context).colorScheme.primary;
    final filtered = _filtered;

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Text(
              'Select currency',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (value) => setState(() => _query = value),
              style: TextStyle(color: colors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search currency',
                hintStyle: TextStyle(color: colors.textSecondary),
                prefixIcon: Icon(Icons.search, color: colors.textSecondary),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: colors.textSecondary),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: colors.background,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: colors.surfaceVariant),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: colors.surfaceVariant),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: primary, width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      'No currencies found',
                      style: TextStyle(color: colors.textSecondary),
                    ),
                  )
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (_, index) {
                      final currency = filtered[index];
                      final country = TopupDepositCountry.resolve(currency);
                      final isSelected = currency == widget.selectedCurrency;
                      return ListTile(
                        leading: Text(
                          country.flagEmoji,
                          style: const TextStyle(fontSize: 26),
                        ),
                        title: Text(
                          currency,
                          style: TextStyle(
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: colors.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          '${country.name} · ${country.currencyName}',
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.textSecondary,
                          ),
                        ),
                        trailing: isSelected
                            ? Icon(Icons.check, color: primary)
                            : null,
                        onTap: () => Navigator.of(context).pop(currency),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _PaymentMethodTile extends StatelessWidget {
  const _PaymentMethodTile({
    required this.title,
    required this.subtitle,
    required this.brandIcon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData brandIcon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final primary = Theme.of(context).colorScheme.primary;

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? primary : colors.surfaceVariant,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  size: 22,
                  color: selected ? primary : colors.textSecondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(brandIcon, color: colors.textSecondary, size: 28),
            ],
          ),
        ),
      ),
    );
  }
}

class _CryptoDepositDetails extends StatelessWidget {
  const _CryptoDepositDetails();

  static const Map<String, Map<String, String>> _cryptoAddresses = {
    'USDT': {
      'address': 'TGkPQsmAhRVh51bEj961EUavP3BjZqEnBb',
      'network': 'Tron Network',
    },
    'USDC': {
      'address': 'FPJoay8fh2FpBBUM2pSmSdTrqpKepZPagGZfU6pwF2qo',
      'network': 'Solana Network',
    },
    'BNB': {
      'address': '0xe421b816e5664a4ecd514956db132762b4e82e8d',
      'network': 'BNB Smart Chain',
      'icon': '🟡',
    },
  };

  void _copy(BuildContext context, String address, String currency) {
    Clipboard.setData(ClipboardData(text: address));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$currency address copied to clipboard'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Deposit from a crypto wallet below:',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ..._cryptoAddresses.entries.map((entry) {
            final currency = entry.key;
            final data = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CurrencyLogo(
                        code: currency,
                        size: 20,
                        fallbackEmoji: data['icon'],
                      ),
                      const SizedBox(width: 8),
                      Text(
                        currency,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        data['network']!,
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colors.surfaceVariant),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            data['address']!,
                            style: TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () => _copy(context, data['address']!, currency),
                          child: Icon(Icons.copy, size: 18, color: primary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
