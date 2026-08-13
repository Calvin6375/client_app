import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pretium/core/constants/app_colors.dart';
import 'package:pretium/features/pay/screens/qr_scan_page.dart';
import 'package:pretium/repositories/wallet_repository.dart';
import 'package:pretium/services/payment_service.dart';
import 'package:pretium/utils/async_action_guard.dart';
import 'package:pretium/utils/firebase_utils.dart';

enum _PayOption { payBill, buyGoods, pochiLaBiashara, truePayMerchant }

/// Pay bills, buy goods, Pochi La Biashara, or TruePay merchants (QR).
class PayPage extends StatefulWidget {
  const PayPage({super.key, this.initialCurrency = 'KES'});

  final String initialCurrency;

  @override
  State<PayPage> createState() => _PayPageState();
}

class _PayPageState extends State<PayPage> {
  _PayOption? _selected;
  final _payBillKey = GlobalKey<_PayBillViewState>();
  final _buyGoodsKey = GlobalKey<_BuyGoodsViewState>();
  final _pochiKey = GlobalKey<_PochiLaBiasharaViewState>();
  final _truePayMerchantKey = GlobalKey<_TruePayMerchantQrViewState>();

  void _openOption(_PayOption option) {
    setState(() => _selected = option);
  }

  void _backToHub() {
    setState(() => _selected = null);
  }

  String get _currency {
    final c = widget.initialCurrency.trim().toUpperCase();
    if (c == 'USDT' || c == 'USDC' || c.isEmpty) return 'KES';
    return c;
  }

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
      case _PayOption.truePayMerchant:
        _truePayMerchantKey.currentState?.applyScannedCode(scanned);
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
      _PayOption.payBill => 'Pay Bill',
      _PayOption.buyGoods => 'Buy Goods',
      _PayOption.pochiLaBiashara => 'Pochi La Biashara',
      _PayOption.truePayMerchant => 'TruePay Merchant',
      null => 'Pay',
    };

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: isDark ? Colors.transparent : primary.withValues(alpha: 0.08),
        elevation: 0,
        title: Text(title, style: TextStyle(color: colors.textPrimary)),
        iconTheme: IconThemeData(color: colors.textPrimary),
        leading: _selected != null
            ? IconButton(
                icon: Icon(Icons.arrow_back, color: colors.textPrimary),
                onPressed: _backToHub,
              )
            : null,
        actions: [
          if (_selected != null)
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
              _PayOption.payBill => _PayBillView(
                  key: _payBillKey,
                  currency: _currency,
                  onPaid: () => Navigator.of(context).pop(true),
                ),
              _PayOption.buyGoods => _BuyGoodsView(
                  key: _buyGoodsKey,
                  currency: _currency,
                  onPaid: () => Navigator.of(context).pop(true),
                ),
              _PayOption.pochiLaBiashara => _PochiLaBiasharaView(
                  key: _pochiKey,
                  currency: _currency,
                  onPaid: () => Navigator.of(context).pop(true),
                ),
              _PayOption.truePayMerchant => _TruePayMerchantQrView(
                  key: _truePayMerchantKey,
                  currency: _currency,
                  onPaid: () => Navigator.of(context).pop(true),
                ),
            },
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
          'Pay bills, buy goods, or pay TruePay merchants from your wallet.',
          style: TextStyle(color: colors.textSecondary, fontSize: 14),
        ),
        const SizedBox(height: 24),
        _PayOptionCard(
          icon: Icons.receipt_long_rounded,
          title: 'Pay to Pay Bill',
          subtitle: 'Enter business number, account, and amount',
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
        const SizedBox(height: 12),
        _PayOptionCard(
          icon: Icons.qr_code_scanner_rounded,
          title: 'Pay to TruePay Merchant',
          subtitle: 'Scan merchant QR code only',
          onTap: () => onSelect(_PayOption.truePayMerchant),
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

// ─── Pay Bill ───────────────────────────────────────────────────────────────

class _PayBillView extends StatefulWidget {
  const _PayBillView({super.key, required this.currency, required this.onPaid});

  final String currency;
  final VoidCallback onPaid;

  @override
  State<_PayBillView> createState() => _PayBillViewState();
}

class _PayBillViewState extends State<_PayBillView> {
  final _businessCtrl = TextEditingController();
  final _accountCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  bool _submitting = false;
  double _balance = 0;
  bool _loadingBalance = true;

  void applyScannedCode(String code) {
    setState(() => _businessCtrl.text = code);
  }

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  @override
  void dispose() {
    _businessCtrl.dispose();
    _accountCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBalance() => _loadWalletBalance(
        currency: widget.currency,
        onLoaded: (b) => setState(() {
          _balance = b;
          _loadingBalance = false;
        }),
        onDoneWithoutBalance: () => setState(() => _loadingBalance = false),
        mounted: () => mounted,
      );

  Future<void> _pay() async {
    final business = _businessCtrl.text.trim();
    final account = _accountCtrl.text.trim();
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (business.isEmpty) {
      _snack('Enter a business number');
      return;
    }
    if (account.isEmpty) {
      _snack('Enter an account number');
      return;
    }
    if (amount <= 0) {
      _snack('Enter a valid amount');
      return;
    }
    if (amount > _balance) {
      _snack('Insufficient balance');
      return;
    }

    await runGuardedAsync(
      this,
      isSubmitting: () => _submitting,
      setSubmitting: (v) => setState(() => _submitting = v),
      action: () async {
        final ok = await _submitPay(
          context: context,
          amount: amount,
          currency: widget.currency,
          note: 'Pay bill $business / $account',
          metadata: {
            'flow': 'pay',
            'payMethod': 'pay_bill',
            'businessNumber': business,
            'accountNumber': account,
          },
        );
        if (ok && mounted) widget.onPaid();
      },
    );
  }

  void _snack(String m) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              _AvailableRow(
                currency: widget.currency,
                balance: _balance,
                loading: _loadingBalance,
              ),
              const SizedBox(height: 20),
              _PayField(
                controller: _businessCtrl,
                label: 'Business number',
                hint: 'e.g. 888880',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              _PayField(
                controller: _accountCtrl,
                label: 'Account number',
                hint: 'Account / invoice reference',
              ),
              const SizedBox(height: 12),
              _PayAmountField(
                controller: _amountCtrl,
                currency: widget.currency,
              ),
              const _MerchantValidationSpace(),
              const SizedBox(height: 16),
              Text(
                'Payment is deducted from your ${widget.currency} wallet.',
                style: TextStyle(color: colors.textTertiary, fontSize: 12),
              ),
            ],
          ),
        ),
        _PayBottomButton(
          label: 'Confirm Payment',
          loading: _submitting,
          onPressed: _pay,
        ),
      ],
    );
  }
}

// ─── Buy Goods ──────────────────────────────────────────────────────────────

class _BuyGoodsView extends StatefulWidget {
  const _BuyGoodsView({super.key, required this.currency, required this.onPaid});

  final String currency;
  final VoidCallback onPaid;

  @override
  State<_BuyGoodsView> createState() => _BuyGoodsViewState();
}

class _BuyGoodsViewState extends State<_BuyGoodsView> {
  final _tillCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  bool _submitting = false;
  double _balance = 0;
  bool _loadingBalance = true;

  void applyScannedCode(String code) {
    setState(() => _tillCtrl.text = code);
  }

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  @override
  void dispose() {
    _tillCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBalance() => _loadWalletBalance(
        currency: widget.currency,
        onLoaded: (b) => setState(() {
          _balance = b;
          _loadingBalance = false;
        }),
        onDoneWithoutBalance: () => setState(() => _loadingBalance = false),
        mounted: () => mounted,
      );

  Future<void> _pay() async {
    final till = _tillCtrl.text.trim();
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (till.isEmpty) {
      _snack('Enter a till number');
      return;
    }
    if (amount <= 0) {
      _snack('Enter a valid amount');
      return;
    }
    if (amount > _balance) {
      _snack('Insufficient balance');
      return;
    }

    await runGuardedAsync(
      this,
      isSubmitting: () => _submitting,
      setSubmitting: (v) => setState(() => _submitting = v),
      action: () async {
        final ok = await _submitPay(
          context: context,
          amount: amount,
          currency: widget.currency,
          note: 'Buy goods till $till',
          metadata: {
            'flow': 'pay',
            'payMethod': 'buy_goods',
            'tillNumber': till,
          },
        );
        if (ok && mounted) widget.onPaid();
      },
    );
  }

  void _snack(String m) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              _AvailableRow(
                currency: widget.currency,
                balance: _balance,
                loading: _loadingBalance,
              ),
              const SizedBox(height: 20),
              _PayField(
                controller: _tillCtrl,
                label: 'Till number',
                hint: 'Lipa Na M-Pesa till',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              _PayAmountField(
                controller: _amountCtrl,
                currency: widget.currency,
              ),
              const _MerchantValidationSpace(),
              const SizedBox(height: 16),
              Text(
                'Payment is deducted from your ${widget.currency} wallet.',
                style: TextStyle(color: colors.textTertiary, fontSize: 12),
              ),
            ],
          ),
        ),
        _PayBottomButton(
          label: 'Confirm Payment',
          loading: _submitting,
          onPressed: _pay,
        ),
      ],
    );
  }
}

// ─── Pochi La Biashara ──────────────────────────────────────────────────────

class _PochiLaBiasharaView extends StatefulWidget {
  const _PochiLaBiasharaView({
    super.key,
    required this.currency,
    required this.onPaid,
  });

  final String currency;
  final VoidCallback onPaid;

  @override
  State<_PochiLaBiasharaView> createState() => _PochiLaBiasharaViewState();
}

class _PochiLaBiasharaViewState extends State<_PochiLaBiasharaView> {
  final _pochiCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  bool _submitting = false;
  double _balance = 0;
  bool _loadingBalance = true;

  void applyScannedCode(String code) {
    setState(() => _pochiCtrl.text = code);
  }

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  @override
  void dispose() {
    _pochiCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBalance() => _loadWalletBalance(
        currency: widget.currency,
        onLoaded: (b) => setState(() {
          _balance = b;
          _loadingBalance = false;
        }),
        onDoneWithoutBalance: () => setState(() => _loadingBalance = false),
        mounted: () => mounted,
      );

  Future<void> _pay() async {
    final pochi = _pochiCtrl.text.replaceAll(RegExp(r'\s+'), '');
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (pochi.length < 9) {
      _snack('Enter a valid Pochi number');
      return;
    }
    if (amount <= 0) {
      _snack('Enter a valid amount');
      return;
    }
    if (amount > _balance) {
      _snack('Insufficient balance');
      return;
    }

    await runGuardedAsync(
      this,
      isSubmitting: () => _submitting,
      setSubmitting: (v) => setState(() => _submitting = v),
      action: () async {
        final ok = await _submitPay(
          context: context,
          amount: amount,
          currency: widget.currency,
          phoneNumber: pochi.startsWith('+') ? pochi : '+$pochi',
          note: 'Pochi La Biashara $pochi',
          metadata: {
            'flow': 'pay',
            'payMethod': 'pochi_la_biashara',
            'pochiNumber': pochi,
          },
        );
        if (ok && mounted) widget.onPaid();
      },
    );
  }

  void _snack(String m) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              _AvailableRow(
                currency: widget.currency,
                balance: _balance,
                loading: _loadingBalance,
              ),
              const SizedBox(height: 20),
              _PayField(
                controller: _pochiCtrl,
                label: 'Pochi number',
                hint: 'Business phone / Pochi number',
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              _PayAmountField(
                controller: _amountCtrl,
                currency: widget.currency,
              ),
              const _MerchantValidationSpace(),
              const SizedBox(height: 16),
              Text(
                'Payment is deducted from your ${widget.currency} wallet.',
                style: TextStyle(color: colors.textTertiary, fontSize: 12),
              ),
            ],
          ),
        ),
        _PayBottomButton(
          label: 'Confirm Payment',
          loading: _submitting,
          onPressed: _pay,
        ),
      ],
    );
  }
}

// ─── TruePay Merchant (QR only) ─────────────────────────────────────────────

class _TruePayMerchantQrView extends StatefulWidget {
  const _TruePayMerchantQrView({
    super.key,
    required this.currency,
    required this.onPaid,
  });

  final String currency;
  final VoidCallback onPaid;

  @override
  State<_TruePayMerchantQrView> createState() => _TruePayMerchantQrViewState();
}

class _TruePayMerchantQrViewState extends State<_TruePayMerchantQrView> {
  final _codeCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  bool _submitting = false;

  void applyScannedCode(String code) {
    setState(() => _codeCtrl.text = code);
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _pay() async {
    final code = _codeCtrl.text.trim();
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (code.isEmpty) {
      _snack('Scan or enter the merchant QR code');
      return;
    }
    if (amount <= 0) {
      _snack('Enter a valid amount');
      return;
    }

    await runGuardedAsync(
      this,
      isSubmitting: () => _submitting,
      setSubmitting: (v) => setState(() => _submitting = v),
      action: () async {
        final ok = await _submitPay(
          context: context,
          amount: amount,
          currency: widget.currency,
          note: 'Pay TruePay merchant via QR $code',
          metadata: {
            'flow': 'pay',
            'payMethod': 'truepay_merchant_qr',
            'paymentCode': code,
          },
        );
        if (ok && mounted) widget.onPaid();
      },
    );
  }

  void _snack(String m) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _openCameraScan() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const QrScanPage(title: 'Scan merchant QR'),
      ),
    );
    if (!mounted || code == null || code.trim().isEmpty) return;
    applyScannedCode(code.trim());
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final primary = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: Material(
                  color: isDark ? colors.surface : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    onTap: _openCameraScan,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: primary.withValues(alpha: 0.45),
                          width: 2,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.qr_code_scanner_rounded,
                            size: 72,
                            color: primary.withValues(alpha: 0.85),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Tap to scan TruePay merchant QR',
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Use camera or upload from gallery',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: colors.textTertiary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _PayField(
                controller: _codeCtrl,
                label: 'QR payment code',
                hint: 'Code from TruePay merchant QR',
              ),
              const SizedBox(height: 12),
              _PayAmountField(
                controller: _amountCtrl,
                currency: widget.currency,
              ),
              const _MerchantValidationSpace(),
            ],
          ),
        ),
        _PayBottomButton(
          label: 'Pay Now',
          loading: _submitting,
          onPressed: _pay,
        ),
      ],
    );
  }
}

// ─── Shared pay helpers / widgets ───────────────────────────────────────────

/// Reserved area under pay fields for post-validation merchant names.
class _MerchantValidationSpace extends StatelessWidget {
  const _MerchantValidationSpace();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 128),
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: isDark
            ? colors.surface.withValues(alpha: 0.55)
            : Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? colors.surfaceVariant.withValues(alpha: 0.55)
              : const Color(0xFFE5E7EB),
        ),
      ),
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Merchant',
            style: TextStyle(
              color: colors.textTertiary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Merchant name will appear here after validation',
            style: TextStyle(
              color: colors.textTertiary,
              fontSize: 14,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _loadWalletBalance({
  required String currency,
  required void Function(double balance) onLoaded,
  required VoidCallback onDoneWithoutBalance,
  required bool Function() mounted,
}) async {
  if (!isFirebaseInitialized()) {
    onDoneWithoutBalance();
    return;
  }
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    onDoneWithoutBalance();
    return;
  }
  try {
    final wallet = await WalletRepository().getWalletBalance(
      user.uid,
      currency: currency,
    );
    if (!mounted()) return;
    onLoaded(wallet?.balance ?? 0);
  } catch (_) {
    if (!mounted()) return;
    onDoneWithoutBalance();
  }
}

Future<bool> _submitPay({
  required BuildContext context,
  required double amount,
  required String currency,
  required String note,
  required Map<String, dynamic> metadata,
  String? phoneNumber,
}) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please sign in to pay')),
    );
    return false;
  }

  final result = await PaymentService().createDirectPayout(
    amount: amount,
    currency: currency,
    phoneNumber: phoneNumber,
    note: note,
    payoutMethod: 'mobile_money',
    metadata: metadata,
  );

  if (!context.mounted) return false;

  if (result['success'] != true) {
    final code = result['code']?.toString();
    final raw = result['error']?.toString() ?? 'Payment failed';
    final message = switch (code) {
      'unauthenticated' => 'Please sign in to pay.',
      'failed-precondition' => 'Insufficient balance for this payment.',
      'not-found' => 'Recipient not found. Check the details and try again.',
      'invalid-argument' => raw,
      _ => raw,
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.errorRed),
    );
    return false;
  }

  final amt = result['amount'];
  final amtStr = amt is num ? amt.toString() : amount.toStringAsFixed(2);
  final cur = result['currency']?.toString() ?? currency;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Payment submitted: $amtStr $cur'),
      backgroundColor: AppColors.successGreen,
    ),
  );
  return true;
}

class _AvailableRow extends StatelessWidget {
  const _AvailableRow({
    required this.currency,
    required this.balance,
    required this.loading,
  });

  final String currency;
  final double balance;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? colors.surface : Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(14),
        border: isDark ? null : Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Available',
            style: TextStyle(color: colors.textSecondary, fontSize: 13),
          ),
          if (loading)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: primary),
            )
          else
            Text(
              '$currency ${balance.toStringAsFixed(2)}',
              style: TextStyle(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
        ],
      ),
    );
  }
}

class _PayField extends StatelessWidget {
  const _PayField({
    required this.controller,
    required this.label,
    required this.hint,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final primary = Theme.of(context).colorScheme.primary;

    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(color: colors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: colors.inputBackground,
        labelStyle: TextStyle(color: colors.textSecondary),
        hintStyle: TextStyle(color: colors.inputPlaceholder),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colors.inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: primary, width: 2),
        ),
      ),
    );
  }
}

class _PayAmountField extends StatelessWidget {
  const _PayAmountField({
    required this.controller,
    required this.currency,
  });

  final TextEditingController controller;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? colors.inputBackground : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.inputBorder),
      ),
      child: Row(
        children: [
          Text(
            currency,
            style: TextStyle(
              color: primary,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: '0.00',
                hintStyle: TextStyle(color: colors.inputPlaceholder),
                border: InputBorder.none,
                labelText: 'Amount',
                labelStyle: TextStyle(color: colors.textSecondary, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PayBottomButton extends StatelessWidget {
  const _PayBottomButton({
    required this.label,
    required this.loading,
    required this.onPressed,
  });

  final String label;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      color: colors.background,
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: loading ? null : onPressed,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: colors.textTertiary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: loading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    label,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
