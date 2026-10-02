import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pretium/core/constants/app_colors.dart';
import 'package:pretium/core/providers/service_providers.dart';
import 'package:pretium/core/providers/wallet_accounts_provider.dart';
import 'package:pretium/features/pay/screens/qr_scan_page.dart';
import 'package:pretium/features/pay/screens/safari_tap_pay_views.dart';
import 'package:pretium/widgets/keyboard_aware_scroll.dart';
import 'package:pretium/widgets/money_form_widgets.dart';
import 'package:pretium/widgets/safari_card.dart';

enum _PayOption { truePayMerchant, payBill, buyGoods, pochiLaBiashara }

const String _kPayAmountCurrency = 'KES';

/// Kenya M-Pesa pay flows via `safariCardApi` (PayBill, Till, Pochi).
class PayPage extends ConsumerStatefulWidget {
  const PayPage({super.key, this.initialCurrency = 'KES'});

  final String initialCurrency;

  @override
  ConsumerState<PayPage> createState() => _PayPageState();
}

class _PayPageState extends ConsumerState<PayPage> {
  _PayOption? _selected;
  late String _selectedCurrency;
  final _truePayMerchantKey = GlobalKey<SafariTapTruePayMerchantViewState>();
  final _payBillKey = GlobalKey<SafariTapPayBillViewState>();
  final _buyGoodsKey = GlobalKey<SafariTapBuyGoodsViewState>();
  final _pochiKey = GlobalKey<SafariTapPochiViewState>();

  @override
  void initState() {
    super.initState();
    _selectedCurrency = widget.initialCurrency.trim().toUpperCase();
    if (_selectedCurrency.isEmpty) _selectedCurrency = _kPayAmountCurrency;
  }

  void _openOption(_PayOption option) {
    setState(() => _selected = option);
  }

  void _backToHub() {
    setState(() => _selected = null);
  }

  bool _handleNestedBack() {
    switch (_selected) {
      case _PayOption.truePayMerchant:
        return _truePayMerchantKey.currentState?.handleBack() ?? false;
      case _PayOption.payBill:
        return _payBillKey.currentState?.handleBack() ?? false;
      case _PayOption.buyGoods:
        return _buyGoodsKey.currentState?.handleBack() ?? false;
      case _PayOption.pochiLaBiashara:
        return false;
      case null:
        return false;
    }
  }

  void _onBackPressed() {
    if (_handleNestedBack()) return;
    if (_selected != null) {
      _backToHub();
    }
  }

  double get _kesBalance =>
      ref.watch(walletAccountsProvider).valueOrNull?.fiatWallets[_kPayAmountCurrency]?.balance ??
      0;

  bool get _loadingWallets {
    final accounts = ref.watch(walletAccountsProvider);
    return accounts.isLoading && accounts.valueOrNull == null;
  }

  Future<void> _openQrScanner() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const QrScanPage()),
    );
    if (!mounted || code == null || code.trim().isEmpty) return;
    final scanned = code.trim();

    switch (_selected) {
      case _PayOption.truePayMerchant:
        _truePayMerchantKey.currentState?.applyScannedCode(scanned);
      case _PayOption.payBill:
        _payBillKey.currentState?.applyScannedCode(scanned);
      case _PayOption.buyGoods:
        _buyGoodsKey.currentState?.applyScannedCode(scanned);
      case _PayOption.pochiLaBiashara:
        _pochiKey.currentState?.applyScannedCode(scanned);
      case null:
        _openOption(_PayOption.truePayMerchant);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _truePayMerchantKey.currentState?.applyScannedCode(scanned);
        });
    }
  }

  bool get _isReviewing {
    switch (_selected) {
      case _PayOption.truePayMerchant:
        return _truePayMerchantKey.currentState?.isReviewing ?? false;
      case _PayOption.payBill:
        return _payBillKey.currentState?.isReviewing ?? false;
      case _PayOption.buyGoods:
        return _buyGoodsKey.currentState?.isReviewing ?? false;
      case _PayOption.pochiLaBiashara:
        return _pochiKey.currentState?.isReviewing ?? false;
      case null:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final snap = ref.watch(walletAccountsProvider).valueOrNull;
    final wallets = SafariCardEntry.fromSnapshot(snap);

    final title = switch (_selected) {
      _PayOption.truePayMerchant => 'TruePay merchant',
      _PayOption.payBill => 'Pay Bill',
      _PayOption.buyGoods => 'Buy Goods',
      _PayOption.pochiLaBiashara => 'Pochi La Biashara',
      null => 'Pay',
    };

    return PopScope(
      canPop: _selected == null,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _onBackPressed();
      },
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          backgroundColor: isDark ? Colors.transparent : primary.withValues(alpha: 0.08),
          elevation: 0,
          title: Text(title, style: TextStyle(color: colors.textPrimary)),
          iconTheme: IconThemeData(color: colors.textPrimary),
          leading: _selected != null
              ? IconButton(
                  icon: Icon(Icons.arrow_back, color: colors.textPrimary),
                  onPressed: _onBackPressed,
                )
              : null,
        ),
        body: _isReviewing
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _walletCard(wallets),
                  const SizedBox(height: 16),
                  _methodDropdown(),
                  const SizedBox(height: 16),
                  Expanded(child: _selectedFlow()),
                ],
              )
            : KeyboardAwareScroll(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _walletCard(wallets),
                    const SizedBox(height: 16),
                    _methodDropdown(),
                    const SizedBox(height: 16),
                    _selectedFlow(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _walletCard(List<SafariCardEntry> wallets) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: SafariCardPager(
        key: const ValueKey('pay-safari-card'),
        wallets: wallets,
        loading: _loadingWallets,
        initialCurrency: _selectedCurrency,
        onCurrencyChanged: (code) => setState(() => _selectedCurrency = code),
      ),
    );
  }

  Widget _methodDropdown() {
    final colors = AppColors.getThemeColors(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Select Method',
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          MoneyMethodDropdown<_PayOption>(
            value: _selected,
            onChanged: _openOption,
            options: const [
              MoneyMethodOption(
                value: _PayOption.truePayMerchant,
                label: 'TruePay merchant',
                icon: Icons.storefront_outlined,
              ),
              MoneyMethodOption(
                value: _PayOption.payBill,
                label: 'Pay Bill',
                icon: Icons.receipt_long_rounded,
              ),
              MoneyMethodOption(
                value: _PayOption.buyGoods,
                label: 'Buy Goods',
                icon: Icons.storefront_rounded,
              ),
              MoneyMethodOption(
                value: _PayOption.pochiLaBiashara,
                label: 'Pochi La Biashara',
                icon: Icons.account_balance_wallet_outlined,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _selectedFlow() {
    if (_selected == null) return const SizedBox.shrink();
    return switch (_selected!) {
      _PayOption.truePayMerchant => SafariTapTruePayMerchantView(
          key: _truePayMerchantKey,
          kesBalance: _kesBalance,
          payApi: ref.read(safariTapPayApiProvider),
          onPaid: () => Navigator.of(context).pop(true),
          onScanQr: _openQrScanner,
          onFlowStepChanged: () {
            if (mounted) setState(() {});
          },
        ),
      _PayOption.payBill => SafariTapPayBillView(
          key: _payBillKey,
          kesBalance: _kesBalance,
          payApi: ref.read(safariTapPayApiProvider),
          onPaid: () => Navigator.of(context).pop(true),
          onScanQr: _openQrScanner,
          onFlowStepChanged: () {
            if (mounted) setState(() {});
          },
        ),
      _PayOption.buyGoods => SafariTapBuyGoodsView(
          key: _buyGoodsKey,
          kesBalance: _kesBalance,
          payApi: ref.read(safariTapPayApiProvider),
          onPaid: () => Navigator.of(context).pop(true),
          onScanQr: _openQrScanner,
          onFlowStepChanged: () {
            if (mounted) setState(() {});
          },
        ),
      _PayOption.pochiLaBiashara => SafariTapPochiView(
          key: _pochiKey,
          kesBalance: _kesBalance,
          payApi: ref.read(safariTapPayApiProvider),
          onPaid: () => Navigator.of(context).pop(true),
          onScanQr: _openQrScanner,
        ),
    };
  }
}
