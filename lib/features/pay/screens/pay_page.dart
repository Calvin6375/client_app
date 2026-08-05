import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pretium/core/constants/app_colors.dart';
import 'package:pretium/repositories/wallet_repository.dart';
import 'package:pretium/services/payment_service.dart';
import 'package:pretium/utils/async_action_guard.dart';
import 'package:pretium/utils/firebase_utils.dart';

enum _PayOption { scanQr, merchant, truePayUser }

/// Pay merchants or TruePay users via QR, merchant code, or phone.
class PayPage extends StatefulWidget {
  const PayPage({super.key, this.initialCurrency = 'USD'});

  final String initialCurrency;

  @override
  State<PayPage> createState() => _PayPageState();
}

class _PayPageState extends State<PayPage> {
  _PayOption? _selected;

  void _openOption(_PayOption option) {
    setState(() => _selected = option);
  }

  void _backToHub() {
    setState(() => _selected = null);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    final title = switch (_selected) {
      _PayOption.scanQr => 'Scan QR',
      _PayOption.merchant => 'Pay Merchant',
      _PayOption.truePayUser => 'Pay TruePay User',
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
      ),
      body: _selected == null
          ? _PayHub(onSelect: _openOption)
          : switch (_selected!) {
              _PayOption.scanQr => _ScanQrPayView(
                  currency: widget.initialCurrency,
                  onPaid: () => Navigator.of(context).pop(true),
                ),
              _PayOption.merchant => _MerchantPayView(
                  currency: widget.initialCurrency,
                  onPaid: () => Navigator.of(context).pop(true),
                ),
              _PayOption.truePayUser => _TruePayUserPayView(
                  currency: widget.initialCurrency,
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
          'Pay merchants or other TruePay users instantly from your wallet.',
          style: TextStyle(color: colors.textSecondary, fontSize: 14),
        ),
        const SizedBox(height: 24),
        _PayOptionCard(
          icon: Icons.qr_code_scanner_rounded,
          title: 'Scan QR Code',
          subtitle: 'Scan a merchant QR or enter a payment code',
          onTap: () => onSelect(_PayOption.scanQr),
        ),
        const SizedBox(height: 12),
        _PayOptionCard(
          icon: Icons.storefront_rounded,
          title: 'Pay Merchant',
          subtitle: 'Enter a merchant ID and amount',
          onTap: () => onSelect(_PayOption.merchant),
        ),
        const SizedBox(height: 12),
        _PayOptionCard(
          icon: Icons.person_outline_rounded,
          title: 'Pay TruePay User',
          subtitle: 'Send payment to a phone number',
          onTap: () => onSelect(_PayOption.truePayUser),
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

// ─── Scan QR ────────────────────────────────────────────────────────────────

class _ScanQrPayView extends StatefulWidget {
  const _ScanQrPayView({required this.currency, required this.onPaid});

  final String currency;
  final VoidCallback onPaid;

  @override
  State<_ScanQrPayView> createState() => _ScanQrPayViewState();
}

class _ScanQrPayViewState extends State<_ScanQrPayView> {
  final _codeCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  bool _submitting = false;

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
      _snack('Enter a payment code');
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
          note: 'Pay via QR/code $code',
          metadata: {
            'flow': 'pay',
            'payMethod': 'qr_code',
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
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? colors.surface : Colors.white,
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
                        'Position QR code in frame',
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Camera scanning coming soon —\nenter a payment code below',
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
              const SizedBox(height: 24),
              _PayField(
                controller: _codeCtrl,
                label: 'Payment code',
                hint: 'Enter merchant or payment code',
              ),
              const SizedBox(height: 12),
              _PayAmountField(
                controller: _amountCtrl,
                currency: widget.currency,
              ),
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

// ─── Merchant ───────────────────────────────────────────────────────────────

class _MerchantPayView extends StatefulWidget {
  const _MerchantPayView({required this.currency, required this.onPaid});

  final String currency;
  final VoidCallback onPaid;

  @override
  State<_MerchantPayView> createState() => _MerchantPayViewState();
}

class _MerchantPayViewState extends State<_MerchantPayView> {
  final _merchantCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  bool _submitting = false;
  double _balance = 0;
  bool _loadingBalance = true;

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  @override
  void dispose() {
    _merchantCtrl.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBalance() async {
    if (!isFirebaseInitialized()) {
      setState(() => _loadingBalance = false);
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _loadingBalance = false);
      return;
    }
    try {
      final wallet = await WalletRepository().getWalletBalance(
        user.uid,
        currency: widget.currency,
      );
      if (!mounted) return;
      setState(() {
        _balance = wallet?.balance ?? 0;
        _loadingBalance = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingBalance = false);
    }
  }

  Future<void> _pay() async {
    final merchant = _merchantCtrl.text.trim();
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (merchant.isEmpty) {
      _snack('Enter a merchant ID');
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
        final note = _noteCtrl.text.trim();
        final ok = await _submitPay(
          context: context,
          amount: amount,
          currency: widget.currency,
          note: note.isEmpty
              ? 'Pay merchant $merchant'
              : 'Pay merchant $merchant — $note',
          metadata: {
            'flow': 'pay',
            'payMethod': 'merchant',
            'merchantId': merchant,
            if (note.isNotEmpty) 'customerNote': note,
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
                controller: _merchantCtrl,
                label: 'Merchant ID',
                hint: 'e.g. TP-MERCHANT-001',
              ),
              const SizedBox(height: 12),
              _PayAmountField(
                controller: _amountCtrl,
                currency: widget.currency,
              ),
              const SizedBox(height: 12),
              _PayField(
                controller: _noteCtrl,
                label: 'Note (optional)',
                hint: 'What is this payment for?',
              ),
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

// ─── TruePay user ───────────────────────────────────────────────────────────

class _TruePayUserPayView extends StatefulWidget {
  const _TruePayUserPayView({required this.currency, required this.onPaid});

  final String currency;
  final VoidCallback onPaid;

  @override
  State<_TruePayUserPayView> createState() => _TruePayUserPayViewState();
}

class _TruePayUserPayViewState extends State<_TruePayUserPayView> {
  final _phoneCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _submitting = false;
  double _balance = 0;
  bool _loadingBalance = true;

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _amountCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBalance() async {
    if (!isFirebaseInitialized()) {
      setState(() => _loadingBalance = false);
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _loadingBalance = false);
      return;
    }
    try {
      final wallet = await WalletRepository().getWalletBalance(
        user.uid,
        currency: widget.currency,
      );
      if (!mounted) return;
      setState(() {
        _balance = wallet?.balance ?? 0;
        _loadingBalance = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingBalance = false);
    }
  }

  Future<void> _pay() async {
    final phoneDigits = _phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (phoneDigits.length < 9) {
      _snack('Enter a valid phone number');
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

    final phoneE164 =
        phoneDigits.startsWith('254') ? '+$phoneDigits' : '+$phoneDigits';

    await runGuardedAsync(
      this,
      isSubmitting: () => _submitting,
      setSubmitting: (v) => setState(() => _submitting = v),
      action: () async {
        final name = _nameCtrl.text.trim();
        final ok = await _submitPay(
          context: context,
          amount: amount,
          currency: widget.currency,
          phoneNumber: phoneE164,
          note: name.isEmpty
              ? 'Pay TruePay user $phoneE164'
              : 'Pay TruePay user $name ($phoneE164)',
          metadata: {
            'flow': 'pay',
            'payMethod': 'truepay_user',
            'recipientPhone': phoneE164,
            if (name.isNotEmpty) 'recipientName': name,
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
                controller: _nameCtrl,
                label: 'Recipient name (optional)',
                hint: 'Full name',
              ),
              const SizedBox(height: 12),
              _PayField(
                controller: _phoneCtrl,
                label: 'Phone number',
                hint: 'Include country code',
                keyboardType: TextInputType.phone,
                prefixText: '+',
              ),
              const SizedBox(height: 12),
              _PayAmountField(
                controller: _amountCtrl,
                currency: widget.currency,
              ),
            ],
          ),
        ),
        _PayBottomButton(
          label: 'Send Payment',
          loading: _submitting,
          onPressed: _pay,
        ),
      ],
    );
  }
}

// ─── Shared pay helpers / widgets ───────────────────────────────────────────

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
    this.prefixText,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType? keyboardType;
  final String? prefixText;

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
        prefixText: prefixText,
        filled: true,
        fillColor: colors.inputBackground,
        labelStyle: TextStyle(color: colors.textSecondary),
        hintStyle: TextStyle(color: colors.inputPlaceholder),
        prefixStyle: TextStyle(
          color: colors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
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
