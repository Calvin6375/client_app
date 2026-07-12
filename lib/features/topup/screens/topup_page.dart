// Top-up screen: fiat (Paystack / Transak card checkout, direct fiat, crypto).
// Card/mobile money: PaymentService.createPayment → hosted checkout in browser.
// African currencies → Paystack; USD, GBP, EUR, and other non-African → Transak.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:pretium/repositories/wallet_repository.dart';
import 'package:pretium/repositories/user_repository.dart';
import 'package:pretium/services/payment_service.dart';
import 'package:pretium/services/dashboard_session_cache.dart';
import 'package:pretium/models/wallet_model.dart';
import 'package:pretium/utils/firebase_utils.dart';
import 'package:pretium/core/constants/app_colors.dart';
import 'package:pretium/features/topup/models/topup_deposit_country.dart';
import 'package:pretium/features/topup/screens/direct_fiat_deposit_flow.dart';

/// Fiat codes in the Set amount dropdown; includes every [TopupDepositCountry] code plus extras.
List<String> _topupFiatCurrencyCodes({String? includeCode}) {
  final codes = <String>{
    ...TopupDepositCountry.depositCurrencyCodes,
    'EUR',
    'GBP',
    if (includeCode != null && includeCode.trim().isNotEmpty)
      includeCode.trim().toUpperCase(),
  };
  return codes.toList()..sort();
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

  bool _hideBalance = false;
  /// Per-currency fiat balances so Available matches the selected currency.
  final Map<String, double> _fiatBalances = {};
  String _selectedCurrency = 'USD';
  bool _isProcessingPayment = false;
  bool _isLoadingBalance = false;
  bool _hasBalanceData = false;
  _TopUpPaymentMethod _selectedMethod = _TopUpPaymentMethod.cardMobileMoney;

  static const List<String> _supportedFiatCurrencies = [
    'USD',
    'KES',
    'NGN',
    'GHS',
    'UGX',
    'GBP',
    'EUR',
  ];

  /// Minimum Set amount for Fiat Option actions when currency is KES.
  static const double _kesFiatOptionMinimumAmount = 150;

  double get _availableBalanceForSelected =>
      _fiatBalances[_selectedCurrency] ?? 0.0;

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

      final fiatWallets = <String, Wallet>{};
      final availableCurrencies = <String>[];

      for (final currency in _supportedFiatCurrencies) {
        try {
          final wallet =
              await _walletRepository.getWalletBalance(user.uid, currency: currency);
          if (wallet != null) {
            fiatWallets[currency] = wallet;
            availableCurrencies.add(currency);
          }
        } catch (_) {
          continue;
        }
      }

      // Ensure USD is present so the dropdown always has a balance entry.
      if (!fiatWallets.containsKey('USD')) {
        final usd =
            await _walletRepository.getWalletBalance(user.uid, currency: 'USD');
        fiatWallets['USD'] =
            usd ?? Wallet(currencyCode: 'USD', balance: 0.0);
        if (!availableCurrencies.contains('USD')) {
          availableCurrencies.insert(0, 'USD');
        }
      }

      var cryptoWallet =
          await _walletRepository.getCryptoWalletBalance(user.uid, 'USDT');

      // Create default USDT wallet if it doesn't exist (as a holding place)
      final cryptoWalletRef =
          FirebaseDatabase.instance.ref('wallet/${user.uid}/crypto/USDT');
      final cryptoSnapshot = await cryptoWalletRef.get();

      if (!cryptoSnapshot.exists) {
        try {
          final timestamp = DateTime.now().toIso8601String();
          await cryptoWalletRef.set({
            'balance': 0,
            'currency': 'USDT',
            'updatedAt': timestamp,
            'createdAt': timestamp,
          });
          cryptoWallet =
              await _walletRepository.getCryptoWalletBalance(user.uid, 'USDT');
        } catch (e) {
          debugPrint('TopUpPage - Failed to create default USDT wallet: $e');
        }
      }

      final existing = DashboardSessionCache.instance.readWalletLastKnown();
      final cryptoWallets = <String, Wallet>{
        ...?existing?.cryptoWallets,
        'USDT': cryptoWallet ?? Wallet(currencyCode: 'USDT', balance: 0.0),
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
      if (!mounted) return;
      if (!silent) {
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

  String get _cardMobileMoneyProviderLabel =>
      TopupDepositCountry.cardMobileMoneyProviderLabelFor(_selectedCurrency);

  String get _cardMobileMoneySubtitle {
    if (_cardMobileMoneyProvider == 'transak') {
      return 'Pay with card via Transak';
    }
    return 'Pay with card or M-Pesa via Paystack';
  }

  /// Card checkout: createPayment (Cloud Function) → open hosted checkout in browser.
  Future<void> _processFiatTopUp() async {
    if (_amountCtrl.text.isEmpty) {
      _showError('Please enter an amount');
      return;
    }

    final amount = _parsedSetAmount();
    if (amount <= 0) {
      _showError('Please enter a valid amount');
      return;
    }
    if (!_meetsKesFiatOptionMinimum()) {
      _showError(
        'For KES, the minimum amount for fiat top-up options is KSh ${_kesFiatOptionMinimumAmount.toStringAsFixed(0)}.',
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    final email = _emailCtrl.text.trim().isNotEmpty
        ? _emailCtrl.text.trim()
        : user?.email;
    if (email == null || email.isEmpty) {
      _showError('An email address is required for payment.');
      return;
    }

    if (_isProcessingPayment) return;

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
        email: email,
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

      final paystackAmount = result['paystackAmount'];
      final paystackCurrency = result['paystackCurrency']?.toString();
      final providerLabel = _cardMobileMoneyProviderLabel;
      var message = 'Complete payment in your browser.';
      if (_cardMobileMoneyProvider == 'paystack' &&
          paystackAmount != null &&
          paystackCurrency != null &&
          _selectedCurrency.toUpperCase() != paystackCurrency.toUpperCase()) {
        message =
            'You will be charged $paystackCurrency $paystackAmount on Paystack.';
      } else if (_cardMobileMoneyProvider == 'transak') {
        final chargeAmount = result['amount'];
        final chargeCurrency = result['currency']?.toString() ?? _selectedCurrency;
        if (chargeAmount != null) {
          message =
              'You will pay $chargeCurrency $chargeAmount on Transak.';
        }
      }

      final launched = await launchUrl(
        Uri.parse(checkoutUrl),
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        _showPaymentLaunchedDialog(
          checkoutUrl,
          invoiceId,
          '$message (automatic launch failed — use options below)',
          providerLabel: providerLabel,
        );
      }
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

  bool _validateAmountForPayment() {
    if (_amountCtrl.text.trim().isEmpty) {
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
    return true;
  }

  void _openDirectFiatDepositFlow() {
    if (_selectedCurrency == 'KES' && !_validateAmountForPayment()) return;
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => DirectFiatDepositScreen(
          fiatBalance: _availableBalanceForSelected,
          walletCurrencyCode: _selectedCurrency,
          initialDepositCountry: widget.initialDepositCountry,
        ),
      ),
    );
  }

  void _onNextPressed() {
    if (_isProcessingPayment) return;
    switch (_selectedMethod) {
      case _TopUpPaymentMethod.cardMobileMoney:
        _processFiatTopUp();
      case _TopUpPaymentMethod.directFiatDeposit:
        _openDirectFiatDepositFlow();
      case _TopUpPaymentMethod.cryptoDeposit:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Copy a crypto address below and send your deposit.'),
          ),
        );
    }
  }

  void _showError(String message) {
    print('❌ Showing error dialog: $message');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              print('👍 User acknowledged error dialog');
              Navigator.of(context).pop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showPaymentLaunchedDialog(
    String checkoutUrl,
    String paymentId,
    String? message, {
    required String providerLabel,
  }) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Payment Ready'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.payment,
                    size: 32,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '$providerLabel checkout is ready!',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (message != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text(message, style: TextStyle(color: Colors.green[700]))),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Text(
                'Complete payment in your browser. When finished, return to the app — '
                'confirmation happens automatically via the app link.',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              
              // Payment URL section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.link, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Text('Payment URL:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.grey[600])),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      checkoutUrl,
                      style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                            onPressed: () async {
                              final launched = await launchUrl(
                                Uri.parse(checkoutUrl),
                                mode: LaunchMode.externalApplication,
                              );
                              if (!launched) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Could not open payment page automatically. Please copy the URL above.'),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Payment page opened successfully!'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.open_in_browser, size: 16),
                            label: const Text('Open Page', style: TextStyle(fontSize: 12)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: checkoutUrl));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Payment URL copied to clipboard!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            },
                            icon: const Icon(Icons.copy, size: 16),
                            label: const Text('Copy URL', style: TextStyle(fontSize: 12)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final availableLabel = _hideBalance
        ? 'Available: •••• $_selectedCurrency'
        : 'Available: ${_availableBalanceForSelected.toStringAsFixed(2)} $_selectedCurrency';
    final nextEnabled = _selectedMethod != _TopUpPaymentMethod.cryptoDeposit;
    final nextLabel = nextEnabled ? 'Next' : 'Copy address below';

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _hideBalance ? Icons.visibility_off : Icons.visibility,
              color: colors.textSecondary,
            ),
            onPressed: () => setState(() => _hideBalance = !_hideBalance),
          ),
        ],
      ),
      body: Column(
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
                    onCurrencyChanged: (currency) {
                      setState(() => _selectedCurrency = currency);
                    },
                  ),
                  const SizedBox(height: 8),
                  if (_isLoadingBalance && !_hasBalanceData)
                    SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: primary,
                      ),
                    )
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
                    title: 'Card / mobile money',
                    subtitle: _cardMobileMoneySubtitle,
                    brandIcon: Icons.payment,
                    selected: _selectedMethod == _TopUpPaymentMethod.cardMobileMoney,
                    onTap: () => setState(
                      () => _selectedMethod = _TopUpPaymentMethod.cardMobileMoney,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _PaymentMethodTile(
                    title: 'Direct fiat deposit',
                    subtitle: 'Bank transfer or mobile money deposit',
                    brandIcon: Icons.account_balance_outlined,
                    selected: _selectedMethod == _TopUpPaymentMethod.directFiatDeposit,
                    onTap: () => setState(
                      () => _selectedMethod = _TopUpPaymentMethod.directFiatDeposit,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _PaymentMethodTile(
                    title: 'Direct crypto deposit',
                    subtitle: 'Send USDT, USDC, or BNB to a wallet address',
                    brandIcon: Icons.currency_bitcoin,
                    selected: _selectedMethod == _TopUpPaymentMethod.cryptoDeposit,
                    onTap: () => setState(
                      () => _selectedMethod = _TopUpPaymentMethod.cryptoDeposit,
                    ),
                  ),
                  if (_selectedMethod == _TopUpPaymentMethod.cryptoDeposit) ...[
                    const SizedBox(height: 16),
                    _CryptoDepositDetails(),
                  ],
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
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
                  onPressed: _isProcessingPayment
                      ? null
                      : _onNextPressed,
                  child: _isProcessingPayment
                      ? SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: isDark ? colors.onPrimary : Colors.white,
                          ),
                        )
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
          ),
        ],
      ),
    );
  }
}

// Argo-style deposit layout widgets
class _DepositAmountField extends StatelessWidget {
  const _DepositAmountField({
    required this.controller,
    required this.selectedCurrency,
    required this.onCurrencyChanged,
  });

  final TextEditingController controller;
  final String selectedCurrency;
  final ValueChanged<String> onCurrencyChanged;

  Future<void> _openCurrencyPicker(BuildContext context) async {
    final colors = AppColors.getThemeColors(context);
    final currencies = _topupFiatCurrencyCodes(includeCode: selectedCurrency);

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
      'icon': '₮',
    },
    'USDC': {
      'address': 'FPJoay8fh2FpBBUM2pSmSdTrqpKepZPagGZfU6pwF2qo',
      'network': 'Solana Network',
      'icon': '🔵',
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
                      Text(data['icon']!, style: const TextStyle(fontSize: 18)),
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
