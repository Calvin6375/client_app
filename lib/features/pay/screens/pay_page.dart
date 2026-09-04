import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pretium/core/constants/app_colors.dart';
import 'package:pretium/features/pay/screens/qr_scan_page.dart';
import 'package:pretium/features/pay/screens/safari_tap_pay_views.dart';
import 'package:pretium/features/safari_tap/services/safari_tap_pay_api_service.dart';
import 'package:pretium/models/wallet_model.dart';
import 'package:pretium/repositories/wallet_repository.dart';
import 'package:pretium/services/dashboard_session_cache.dart';
import 'package:pretium/utils/firebase_utils.dart';

enum _PayOption { payBill, buyGoods, pochiLaBiashara }

const String _kPayAmountCurrency = 'KES';

/// Kenya M-Pesa pay flows via `safariCardApi` (PayBill, Till, Pochi).
class PayPage extends StatefulWidget {
  const PayPage({super.key, this.initialCurrency = 'KES'});

  final String initialCurrency;

  @override
  State<PayPage> createState() => _PayPageState();
}

class _PayPageState extends State<PayPage> {
  _PayOption? _selected;
  final _payBillKey = GlobalKey<SafariTapPayBillViewState>();
  final _buyGoodsKey = GlobalKey<SafariTapBuyGoodsViewState>();
  final _pochiKey = GlobalKey<SafariTapPochiViewState>();

  final WalletRepository _walletRepository = WalletRepository();

  final Map<String, double> _balances = {};
  bool _loadingWallets = true;
  final SafariTapPayApiService _payApi = SafariTapPayApiService();

  @override
  void initState() {
    super.initState();
    _hydrateFromCache();
    _loadWallets();
  }

  void _hydrateFromCache() {
    final snap = DashboardSessionCache.instance.readWalletLastKnown();
    if (snap == null) return;

    for (final code in snap.availableFiatCurrencies) {
      if (code == _kPayAmountCurrency) {
        _balances[code] = snap.fiatWallets[code]?.balance ?? 0;
      }
    }
    if (_balances.containsKey(_kPayAmountCurrency)) {
      _loadingWallets = false;
    }
  }

  Future<void> _loadWallets() async {
    if (!isFirebaseInitialized()) {
      if (mounted) setState(() => _loadingWallets = false);
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _loadingWallets = false);
      return;
    }

    try {
      final wallet =
          await _walletRepository.getWalletBalance(user.uid, currency: _kPayAmountCurrency);
      final bal = wallet?.balance ?? 0;

      if (!mounted) return;
      setState(() {
        _balances[_kPayAmountCurrency] = bal;
        _loadingWallets = false;
      });

      final existing = DashboardSessionCache.instance.readWalletLastKnown();
      DashboardSessionCache.instance.recordWalletSnapshot(
        fiatWallets: {_kPayAmountCurrency: Wallet(currencyCode: _kPayAmountCurrency, balance: bal)},
        availableFiatCurrencies: const [_kPayAmountCurrency],
        cryptoWallets: existing?.cryptoWallets ?? const {},
        availableCryptoCurrencies: existing?.availableCryptoCurrencies ?? const [],
        cachedFiatWallet: existing?.cachedFiatWallet,
        cachedCryptoWallet: existing?.cachedCryptoWallet,
      );
    } catch (_) {
      if (mounted) setState(() => _loadingWallets = false);
    }
  }

  void _openOption(_PayOption option) {
    setState(() => _selected = option);
  }

  void _backToHub() {
    setState(() => _selected = null);
  }

  bool _handleNestedBack() {
    switch (_selected) {
      case _PayOption.payBill:
        return _payBillKey.currentState?.handleBack() ?? false;
      case _PayOption.buyGoods:
        return _buyGoodsKey.currentState?.handleBack() ?? false;
      case _PayOption.pochiLaBiashara:
      case null:
        return false;
    }
  }

  bool get _isReviewStep {
    switch (_selected) {
      case _PayOption.payBill:
        return _payBillKey.currentState?.isReviewStep ?? false;
      case _PayOption.buyGoods:
        return _buyGoodsKey.currentState?.isReviewStep ?? false;
      case _PayOption.pochiLaBiashara:
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

  double get _kesBalance => _balances[_kPayAmountCurrency] ?? 0;

  Future<void> _openQrScanner() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const QrScanPage()),
    );
    if (!mounted || code == null || code.trim().isEmpty) return;
    final scanned = code.trim();

    switch (_selected) {
      case _PayOption.payBill:
        _payBillKey.currentState?.applyScannedCode(scanned);
      case _PayOption.buyGoods:
        _buyGoodsKey.currentState?.applyScannedCode(scanned);
      case _PayOption.pochiLaBiashara:
        _pochiKey.currentState?.applyScannedCode(scanned);
      case null:
        _openOption(_PayOption.buyGoods);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _buyGoodsKey.currentState?.applyScannedCode(scanned);
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    final title = switch (_selected) {
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
          actions: [
            if (_selected != null && !_isReviewStep)
              IconButton(
                tooltip: 'Scan QR code',
                icon: Icon(Icons.qr_code_scanner_rounded, color: colors.textPrimary),
                onPressed: _openQrScanner,
              ),
          ],
        ),
        body: _selected == null
            ? _PayHub(onSelect: _openOption)
            : switch (_selected!) {
                _PayOption.payBill => SafariTapPayBillView(
                    key: _payBillKey,
                    kesBalance: _kesBalance,
                    loadingBalance: _loadingWallets,
                    payApi: _payApi,
                    onPaid: () => Navigator.of(context).pop(true),
                    onFlowStepChanged: () {
                      if (mounted) setState(() {});
                    },
                  ),
                _PayOption.buyGoods => SafariTapBuyGoodsView(
                    key: _buyGoodsKey,
                    kesBalance: _kesBalance,
                    loadingBalance: _loadingWallets,
                    payApi: _payApi,
                    onPaid: () => Navigator.of(context).pop(true),
                    onFlowStepChanged: () {
                      if (mounted) setState(() {});
                    },
                  ),
                _PayOption.pochiLaBiashara => SafariTapPochiView(
                    key: _pochiKey,
                    kesBalance: _kesBalance,
                    loadingBalance: _loadingWallets,
                    payApi: _payApi,
                    onPaid: () => Navigator.of(context).pop(true),
                  ),
              },
      ),
    );
  }
}

class _PayHub extends StatelessWidget {
  const _PayHub({required this.onSelect});

  final ValueChanged<_PayOption> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        Text(
          'How would you like to pay?',
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Pay bills, buy goods, or send to Pochi from your KES wallet.',
          style: TextStyle(color: colors.textSecondary, fontSize: 14),
        ),
        const SizedBox(height: 24),
        _PayOptionCard(
          icon: Icons.receipt_long_rounded,
          title: 'Pay to Pay Bill',
          subtitle: 'Enter PayBill number, account number, and amount',
          onTap: () => onSelect(_PayOption.payBill),
        ),
        const SizedBox(height: 12),
        _PayOptionCard(
          icon: Icons.storefront_rounded,
          title: 'Pay to Buy Goods',
          subtitle: 'Enter till number and amount',
          onTap: () => onSelect(_PayOption.buyGoods),
        ),
        const SizedBox(height: 12),
        _PayOptionCard(
          icon: Icons.account_balance_wallet_outlined,
          title: 'Pay to Pochi La Biashara',
          subtitle: 'Enter Pochi number and amount',
          onTap: () => onSelect(_PayOption.pochiLaBiashara),
        ),
      ],
    );
  }
}

class _PayOptionCard extends StatelessWidget {
  const _PayOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    return Material(
      color: isDark ? colors.surface : Colors.white.withValues(alpha: 0.95),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? colors.surfaceVariant : const Color(0xFFE5E7EB),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: primary, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: colors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}
