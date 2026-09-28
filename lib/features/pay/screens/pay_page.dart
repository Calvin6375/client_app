import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pretium/core/constants/app_colors.dart';
import 'package:pretium/core/providers/service_providers.dart';
import 'package:pretium/core/providers/wallet_accounts_provider.dart';
import 'package:pretium/features/pay/screens/qr_scan_page.dart';
import 'package:pretium/features/pay/screens/safari_tap_pay_views.dart';
import 'package:pretium/widgets/money_form_widgets.dart';

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
  final _truePayMerchantKey = GlobalKey<SafariTapTruePayMerchantViewState>();
  final _payBillKey = GlobalKey<SafariTapPayBillViewState>();
  final _buyGoodsKey = GlobalKey<SafariTapBuyGoodsViewState>();
  final _pochiKey = GlobalKey<SafariTapPochiViewState>();

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
    return accounts.isLoading &&
        accounts.valueOrNull?.fiatWallets[_kPayAmountCurrency] == null;
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

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

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
        body: _selected == null
            ? _PayHub(
                kesBalance: _kesBalance,
                loadingBalance: _loadingWallets,
                onSelect: _openOption,
              )
            : switch (_selected!) {
                _PayOption.truePayMerchant => SafariTapTruePayMerchantView(
                    key: _truePayMerchantKey,
                    kesBalance: _kesBalance,
                    loadingBalance: _loadingWallets,
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
                    loadingBalance: _loadingWallets,
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
                    loadingBalance: _loadingWallets,
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
                    loadingBalance: _loadingWallets,
                    payApi: ref.read(safariTapPayApiProvider),
                    onPaid: () => Navigator.of(context).pop(true),
                    onScanQr: _openQrScanner,
                  ),
              },
      ),
    );
  }
}

class _PayHub extends StatelessWidget {
  const _PayHub({
    required this.kesBalance,
    required this.loadingBalance,
    required this.onSelect,
  });

  final double kesBalance;
  final bool loadingBalance;
  final ValueChanged<_PayOption> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        MoneyBalanceCard(
          currency: _kPayAmountCurrency,
          balance: kesBalance,
          loading: loadingBalance,
          caption: 'Pay from your $_kPayAmountCurrency wallet',
        ),
        const SizedBox(height: 24),
        Text(
          'Select Method',
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        MoneyMethodTile(
          icon: Icons.storefront_outlined,
          title: 'TruePay merchant',
          selected: false,
          onTap: () => onSelect(_PayOption.truePayMerchant),
        ),
        const SizedBox(height: 10),
        MoneyMethodTile(
          icon: Icons.receipt_long_rounded,
          title: 'Pay Bill',
          selected: false,
          onTap: () => onSelect(_PayOption.payBill),
        ),
        const SizedBox(height: 10),
        MoneyMethodTile(
          icon: Icons.storefront_rounded,
          title: 'Buy Goods',
          selected: false,
          onTap: () => onSelect(_PayOption.buyGoods),
        ),
        const SizedBox(height: 10),
        MoneyMethodTile(
          icon: Icons.account_balance_wallet_outlined,
          title: 'Pochi La Biashara',
          selected: false,
          onTap: () => onSelect(_PayOption.pochiLaBiashara),
        ),
      ],
    );
  }
}
