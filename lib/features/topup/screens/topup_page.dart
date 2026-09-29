// Top-up screen: fiat (Paystack / Transak card checkout) and crypto.
// Local and International topup: PaymentService.createPayment → hosted checkout in-app WebView.
// African currencies → Paystack; USD, GBP, EUR, and other non-African → Transak.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pretium/features/crypto/screens/crypto_deposit_page.dart';
import 'package:pretium/core/providers/user_profile_provider.dart';
import 'package:pretium/core/providers/wallet_accounts_provider.dart';
import 'package:pretium/services/payment_service.dart';
import 'package:pretium/services/wallet_balance_refresh.dart';
import 'package:pretium/core/constants/app_colors.dart';
import 'package:pretium/features/topup/models/topup_deposit_country.dart';
import 'package:pretium/features/topup/providers/topup_flow_provider.dart';
import 'package:pretium/features/topup/screens/deposit_review_screen.dart';
import 'package:pretium/features/topup/screens/payment_checkout_webview_page.dart';
import 'package:pretium/features/topup/screens/usd_funding_instructions_screen.dart';
import 'package:pretium/widgets/app_shimmer.dart';
import 'package:pretium/widgets/bottom_safe_action_bar.dart';

class TopUpPage extends ConsumerStatefulWidget {
  const TopUpPage({super.key, this.initialDepositCountry});

  /// When set, pre-selects that currency in Set amount and is passed to direct fiat deposit.
  final TopupDepositCountry? initialDepositCountry;

  @override
  ConsumerState<TopUpPage> createState() => _TopUpPageState();
}

class _TopUpPageState extends ConsumerState<TopUpPage> {
  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _firstNameCtrl = TextEditingController();
  final TextEditingController _lastNameCtrl = TextEditingController();

  bool _hideBalance = false;
  bool _profileFilled = false;

  static const double _kesFiatOptionMinimumAmount = 150;

  TopUpFlowState get _flow => ref.read(topUpFlowProvider);
  TopUpFlowNotifier get _flowN => ref.read(topUpFlowProvider.notifier);

  void _selectPaymentMethod(TopUpPaymentMethod method) {
    _flowN.selectMethod(method);
    if (method == TopUpPaymentMethod.cryptoDeposit) {
      _openCryptoDeposit();
    }
  }

  Future<void> _openCryptoDeposit() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CryptoDepositPage(
          initialAsset:
              _flow.selectedCurrency == 'USDC' ? 'USDC' : 'USDT',
        ),
      ),
    );
    if (!mounted) return;
    await WalletBalanceRefresh.afterSuccessfulTransaction();
    await ref.read(walletAccountsProvider.notifier).refresh(force: true);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _flowN.configureInitialCurrency(widget.initialDepositCountry?.code);
    });
  }

  void _fillProfileIfNeeded() {
    if (_profileFilled) return;
    final profile = ref.read(userProfileProvider).valueOrNull;
    if (profile == null) return;
    _profileFilled = true;
    if (_emailCtrl.text.isEmpty) _emailCtrl.text = profile.email;
    if (_firstNameCtrl.text.isEmpty) _firstNameCtrl.text = profile.firstName;
    if (_lastNameCtrl.text.isEmpty) _lastNameCtrl.text = profile.lastName;
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
    if (_flow.selectedCurrency != 'KES') return true;
    return _parsedSetAmount() >= _kesFiatOptionMinimumAmount;
  }

  String get _paymentMethodTitle {
    switch (_flow.method) {
      case TopUpPaymentMethod.directFiatDeposit:
        return 'Local Topup';
      case TopUpPaymentMethod.cardMobileMoney:
        return 'International Topup';
      case TopUpPaymentMethod.cryptoDeposit:
        return 'Crypto Deposit';
    }
  }

  String get _paymentMethodSubtitle {
    switch (_flow.method) {
      case TopUpPaymentMethod.directFiatDeposit:
        return 'Local bank or card or mobile money';
      case TopUpPaymentMethod.cardMobileMoney:
        return 'International bank or card, Apple Pay or Google Pay';
      case TopUpPaymentMethod.cryptoDeposit:
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
    _flowN.goToReview();
    _flowN.loadQuote(amount: _parsedSetAmount());
  }

  void _goToForm() {
    if (_flow.isProcessingPayment) return;
    _flowN.goToForm();
  }

  Future<void> _loadTopupQuote() {
    return _flowN.loadQuote(amount: _parsedSetAmount());
  }

  void _onBackPressed() {
    if (_flow.step == TopUpStep.review) {
      _goToForm();
      return;
    }
    Navigator.of(context).pop();
  }

  /// Card checkout: createPayment (Cloud Function) → open hosted checkout in-app.
  Future<void> _processFiatTopUp() async {
    if (!_validateFiatDepositForm()) return;
    if (_flow.isProcessingPayment) return;

    final amount = _parsedSetAmount();
    final user = FirebaseAuth.instance.currentUser;
    final email = _emailCtrl.text.trim().isNotEmpty
        ? _emailCtrl.text.trim()
        : user?.email;

    _flowN.setProcessing(true);

    try {
      String? userPhoneNumber;
      try {
        if (user != null) {
          userPhoneNumber =
              ref.read(userProfileProvider).valueOrNull?.phoneNumber;
        }
      } catch (_) {}

      final paymentService = PaymentService();
      final result = await paymentService.createPayment(
        amount: amount,
        currency: _flow.selectedCurrency,
        provider: _flow.cardMobileMoneyProvider,
        email: email!,
        firstName: _firstNameCtrl.text.trim().isNotEmpty
            ? _firstNameCtrl.text.trim()
            : null,
        lastName: _lastNameCtrl.text.trim().isNotEmpty
            ? _lastNameCtrl.text.trim()
            : null,
        phoneNumber: userPhoneNumber,
      );

      if (result.isError) {
        _showError(result.error ?? 'Payment failed');
        return;
      }

      if (!mounted) return;

      if (result.opensHostedCheckout &&
          result.checkoutUrl != null &&
          result.checkoutUrl!.isNotEmpty &&
          result.invoiceId != null &&
          result.invoiceId!.isNotEmpty) {
        await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => PaymentCheckoutWebViewPage(
              checkoutUrl: result.checkoutUrl!,
              paymentId: result.invoiceId!,
              title: 'Secure checkout',
            ),
          ),
        );
        await WalletBalanceRefresh.afterSuccessfulTransaction();
        if (mounted) {
          await ref.read(walletAccountsProvider.notifier).refresh(force: true);
        }
        return;
      }

      if (result.showsGridUsdInstructions) {
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => UsdFundingInstructionsScreen(result: result),
          ),
        );
        return;
      }

      if (!result.opensHostedCheckout ||
          result.checkoutUrl == null ||
          result.checkoutUrl!.isEmpty ||
          result.invoiceId == null ||
          result.invoiceId!.isEmpty) {
        _showError('No checkout URL returned from server');
        return;
      }

      await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => PaymentCheckoutWebViewPage(
            checkoutUrl: result.checkoutUrl!,
            paymentId: result.invoiceId!,
            title: 'Secure checkout',
          ),
        ),
      );
      // Checkout may have settled while the WebView was open — refresh ledger.
      await WalletBalanceRefresh.afterSuccessfulTransaction();
      if (mounted) {
        await ref.read(walletAccountsProvider.notifier).refresh(force: true);
      }
    } catch (e) {
      _showError('Error processing payment: $e');
    } finally {
      if (mounted) {
        _flowN.setProcessing(false);
      }
    }
  }

  void _onNextPressed() {
    if (_flow.isProcessingPayment) return;
    switch (_flow.method) {
      case TopUpPaymentMethod.cardMobileMoney:
      case TopUpPaymentMethod.directFiatDeposit:
        if (_validateFiatDepositForm()) {
          _goToReview();
        }
      case TopUpPaymentMethod.cryptoDeposit:
        _openCryptoDeposit();
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
    ref.watch(topUpFlowProvider);
    ref.watch(userProfileProvider);
    _fillProfileIfNeeded();
    final colors = AppColors.getThemeColors(context);
    final isReview = _flow.step == TopUpStep.review;

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
        '${amount.toStringAsFixed(2)} ${_flow.selectedCurrency}';

    return DepositReviewScreen(
      quote: _flow.quote,
      isLoadingQuote: _flow.isLoadingQuote,
      quoteError: _flow.quoteError,
      onRetryQuote: _flow.isLoadingQuote ? null : _loadTopupQuote,
      fallbackAmountLabel: fallbackAmount,
      paymentMethodTitle: _paymentMethodTitle,
      paymentMethodSubtitle: _paymentMethodSubtitle,
      isSubmitting: _flow.isProcessingPayment,
      onEditDepositDetails: _goToForm,
      onEditPaymentMethod: _goToForm,
      onConfirm: _processFiatTopUp,
    );
  }

  Widget _buildFormStep(AppThemeColors colors) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final availableLabel = _hideBalance
        ? 'Available: •••• ${_flow.selectedCurrency}'
        : 'Available: ${_flow.availableBalance.toStringAsFixed(2)} ${_flow.selectedCurrency}';
    final nextLabel = _flow.method == TopUpPaymentMethod.cryptoDeposit
        ? 'Continue'
        : 'Next';

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
                  selectedCurrency: _flow.selectedCurrency,
                  currencies: _flow.depositPickerCurrencies,
                  loadingCurrencies: _flow.loadingCountries,
                  onCurrencyChanged: _flowN.selectCurrency,
                ),
                const SizedBox(height: 8),
                if (ref.watch(walletAccountsProvider).isLoading &&
                    _flow.fiatBalances.isEmpty)
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
                      _flow.method == TopUpPaymentMethod.directFiatDeposit,
                  onTap: () =>
                      _selectPaymentMethod(TopUpPaymentMethod.directFiatDeposit),
                ),
                const SizedBox(height: 12),
                _PaymentMethodTile(
                  title: 'International Topup',
                  subtitle:
                      'International bank or card, Apple Pay or Google Pay.',
                  brandIcon: Icons.payment,
                  selected:
                      _flow.method == TopUpPaymentMethod.cardMobileMoney,
                  onTap: () =>
                      _selectPaymentMethod(TopUpPaymentMethod.cardMobileMoney),
                ),
                const SizedBox(height: 12),
                _PaymentMethodTile(
                  title: 'Crypto Deposit',
                  subtitle:
                      'Send any crypto or stablecoin from any network to a wallet address',
                  brandIcon: Icons.currency_bitcoin,
                  selected:
                      _flow.method == TopUpPaymentMethod.cryptoDeposit,
                  onTap: () =>
                      _selectPaymentMethod(TopUpPaymentMethod.cryptoDeposit),
                ),
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
              onPressed: _flow.isProcessingPayment ? null : _onNextPressed,
              child: _flow.isProcessingPayment
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
