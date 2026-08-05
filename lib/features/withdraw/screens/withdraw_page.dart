import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pretium/core/constants/app_colors.dart';
import 'package:pretium/features/crypto/screens/usdc_send_screen.dart';
import 'package:pretium/features/topup/models/topup_deposit_country.dart';
import 'package:pretium/features/topup/screens/direct_fiat_deposit_flow.dart';
import 'package:pretium/repositories/wallet_repository.dart';
import 'package:pretium/services/payment_service.dart';
import 'package:pretium/utils/async_action_guard.dart';
import 'package:pretium/utils/firebase_utils.dart';

enum _WithdrawDestination { mobileMoney, bank, cryptoWallet }

/// Withdraw funds from fiat or crypto wallet.
class WithdrawPage extends StatefulWidget {
  const WithdrawPage({
    super.key,
    this.isCrypto = false,
    this.currencyCode = 'KES',
    this.availableBalance,
  });

  final bool isCrypto;
  final String currencyCode;
  final double? availableBalance;

  @override
  State<WithdrawPage> createState() => _WithdrawPageState();
}

class _WithdrawPageState extends State<WithdrawPage> {
  final _amountCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _bankNameCtrl = TextEditingController();
  final _bankAccountCtrl = TextEditingController();
  final _walletRepository = WalletRepository();

  late String _currency;
  double _balance = 0;
  bool _loadingBalance = true;
  bool _submitting = false;
  _WithdrawDestination _destination = _WithdrawDestination.mobileMoney;

  bool get _isCrypto => widget.isCrypto;
  bool get _isUsdc => _isCrypto && _currency.toUpperCase() == 'USDC';
  bool get _fiatWithdrawSupported =>
      !_isCrypto && TopupDepositCountry.withdrawSupported.any((c) => c.code == _currency);

  @override
  void initState() {
    super.initState();
    _currency = widget.currencyCode.trim().isEmpty
        ? (widget.isCrypto ? 'USDC' : 'KES')
        : widget.currencyCode.trim().toUpperCase();
    if (!_isCrypto && !_fiatWithdrawSupported) {
      _currency = 'KES';
    }
    _balance = widget.availableBalance ?? 0;
    _destination = _isCrypto
        ? _WithdrawDestination.cryptoWallet
        : _WithdrawDestination.mobileMoney;
    _amountCtrl.addListener(() => setState(() {}));
    _loadBalance();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _phoneCtrl.dispose();
    _bankNameCtrl.dispose();
    _bankAccountCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBalance() async {
    if (widget.availableBalance != null) {
      setState(() {
        _balance = widget.availableBalance!;
        _loadingBalance = false;
      });
      return;
    }
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
      setState(() => _loadingBalance = true);
      final wallet = _isCrypto
          ? await _walletRepository.getCryptoWalletBalance(user.uid, _currency)
          : await _walletRepository.getWalletBalance(user.uid, currency: _currency);
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

  double get _amount => double.tryParse(_amountCtrl.text.trim()) ?? 0;

  bool get _canSubmit {
    if (_isCrypto) return _isUsdc && !_submitting;
    if (_amount <= 0 || _amount > _balance) return false;
    if (!_fiatWithdrawSupported) return false;
    if (_destination == _WithdrawDestination.mobileMoney) {
      return _phoneCtrl.text.replaceAll(RegExp(r'\D'), '').length >= 9;
    }
    if (_destination == _WithdrawDestination.bank) {
      return _bankNameCtrl.text.trim().isNotEmpty &&
          _bankAccountCtrl.text.replaceAll(RegExp(r'\s'), '').length >= 6;
    }
    return false;
  }

  void _setMax() {
    _amountCtrl.text = _balance > 0 ? _balance.toStringAsFixed(2) : '';
  }

  void _setPercent(double fraction) {
    if (_balance <= 0) return;
    _amountCtrl.text = (_balance * fraction).toStringAsFixed(2);
  }

  Future<void> _openFullWizard() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => DirectFiatDepositScreen(
          fiatBalance: _balance,
          walletCurrencyCode: _currency,
          flowKind: DirectFiatFlowKind.withdraw,
        ),
      ),
    );
    if (mounted) await _loadBalance();
  }

  Future<void> _openCryptoSend() async {
    final refreshed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => UsdcSendScreen(availableBalance: _balance),
      ),
    );
    if (mounted && refreshed == true) await _loadBalance();
  }

  Future<void> _confirmWithdraw() async {
    if (!_canSubmit || _submitting) return;

    if (_isCrypto) {
      await _openCryptoSend();
      return;
    }

    await runGuardedAsync(
      this,
      isSubmitting: () => _submitting,
      setSubmitting: (v) => setState(() => _submitting = v),
      action: () async {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          _snack('Please sign in to withdraw');
          return;
        }

        final isMobile = _destination == _WithdrawDestination.mobileMoney;
        final phoneDigits = _phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
        final phoneE164 = phoneDigits.isEmpty
            ? null
            : (phoneDigits.startsWith('254')
                ? '+$phoneDigits'
                : '+254${phoneDigits.replaceFirst(RegExp(r'^0'), '')}');

        final note = isMobile
            ? 'Withdrawal ${_amount.toStringAsFixed(2)} $_currency — Mobile money'
            : 'Withdrawal ${_amount.toStringAsFixed(2)} $_currency — Bank (${_bankNameCtrl.text.trim()})';

        final metadata = <String, dynamic>{
          'flow': 'withdraw',
          'currency': _currency,
          'amount': _amount,
          'payoutMethod': isMobile ? 'mobile_money' : 'bank',
          if (!isMobile) ...{
            'bankName': _bankNameCtrl.text.trim(),
            'destinationAccountNumber':
                _bankAccountCtrl.text.replaceAll(RegExp(r'\s'), ''),
          },
        };

        final result = await PaymentService().createDirectPayout(
          amount: _amount,
          currency: _currency,
          phoneNumber: phoneE164,
          note: note,
          payoutMethod: isMobile ? 'mobile_money' : 'bank',
          metadata: metadata,
        );

        if (!mounted) return;

        if (result['success'] != true) {
          final code = result['code']?.toString();
          final raw = result['error']?.toString() ?? 'Withdrawal failed';
          final message = switch (code) {
            'unauthenticated' => 'Please sign in to withdraw.',
            'failed-precondition' =>
              'Insufficient balance for this withdrawal.',
            'invalid-argument' => raw,
            _ => raw,
          };
          _snack(message, isError: true);
          return;
        }

        final amt = result['amount'];
        final amtStr = amt is num ? amt.toString() : _amount.toStringAsFixed(2);
        final cur = result['currency']?.toString() ?? _currency;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Withdrawal submitted: $amtStr $cur'),
            backgroundColor: AppColors.successGreen,
          ),
        );
        Navigator.of(context).pop(true);
      },
    );
  }

  void _snack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.errorRed : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: isDark ? Colors.transparent : primary.withValues(alpha: 0.08),
        elevation: 0,
        title: Text('Withdraw', style: TextStyle(color: colors.textPrimary)),
        iconTheme: IconThemeData(color: colors.textPrimary),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                _BalanceCard(
                  currency: _currency,
                  balance: _balance,
                  loading: _loadingBalance,
                ),
                const SizedBox(height: 24),
                if (!_isCrypto) ...[
                  Text(
                    'Amount',
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _AmountField(
                    controller: _amountCtrl,
                    currency: _currency,
                    onMax: _setMax,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _QuickChip(label: '25%', onTap: () => _setPercent(0.25)),
                      const SizedBox(width: 8),
                      _QuickChip(label: '50%', onTap: () => _setPercent(0.5)),
                      const SizedBox(width: 8),
                      _QuickChip(label: 'Max', onTap: _setMax),
                    ],
                  ),
                  if (_amount > _balance && _amount > 0) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Amount exceeds available balance',
                      style: TextStyle(color: colors.error, fontSize: 13),
                    ),
                  ],
                  const SizedBox(height: 28),
                ],
                Text(
                  'Withdraw to',
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),
                if (_isCrypto) ...[
                  _DestinationCard(
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'Crypto wallet',
                    subtitle: _isUsdc
                        ? 'Send USDC to an external wallet address'
                        : '$_currency withdrawals coming soon',
                    selected: true,
                    onTap: () {},
                  ),
                  if (!_isUsdc) ...[
                    const SizedBox(height: 12),
                    const _InfoBanner(
                      message:
                          'This crypto asset cannot be withdrawn yet. Switch to USDC to withdraw.',
                    ),
                  ],
                ] else ...[
                  _DestinationCard(
                    icon: Icons.phone_android_rounded,
                    title: 'Mobile Money',
                    subtitle: 'M-Pesa, Airtel Money, and similar',
                    selected: _destination == _WithdrawDestination.mobileMoney,
                    onTap: () => setState(
                      () => _destination = _WithdrawDestination.mobileMoney,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _DestinationCard(
                    icon: Icons.account_balance_rounded,
                    title: 'Bank Account',
                    subtitle: 'Withdraw to a local bank account',
                    selected: _destination == _WithdrawDestination.bank,
                    onTap: () => setState(
                      () => _destination = _WithdrawDestination.bank,
                    ),
                  ),
                  if (!_fiatWithdrawSupported) ...[
                    const SizedBox(height: 12),
                    const _InfoBanner(
                      message:
                          'Fiat withdrawals are currently available in Kenya (KES).',
                    ),
                  ],
                  const SizedBox(height: 20),
                  if (_destination == _WithdrawDestination.mobileMoney)
                    _ThemedField(
                      controller: _phoneCtrl,
                      label: 'Mobile number',
                      hint: '7XX XXX XXX',
                      keyboardType: TextInputType.phone,
                      prefixText: '+254 ',
                      onChanged: (_) => setState(() {}),
                    )
                  else ...[
                    _ThemedField(
                      controller: _bankNameCtrl,
                      label: 'Bank name',
                      hint: 'e.g. Equity Bank',
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    _ThemedField(
                      controller: _bankAccountCtrl,
                      label: 'Account number',
                      hint: 'Enter account number',
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _openFullWizard,
                    child: Text(
                      'Use guided withdrawal instead',
                      style: TextStyle(color: primary, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ],
            ),
          ),
          _BottomBar(
            enabled: _canSubmit && !_submitting,
            loading: _submitting,
            label: _isCrypto && _isUsdc
                ? 'Continue'
                : 'Confirm Withdrawal',
            onPressed: _confirmWithdraw,
          ),
        ],
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
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
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? colors.surface : Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: isDark
            ? null
            : Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Available balance',
            style: TextStyle(color: colors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 8),
          if (loading)
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2, color: primary),
            )
          else
            Text(
              '$currency ${balance.toStringAsFixed(2)}',
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 28,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}

class _AmountField extends StatelessWidget {
  const _AmountField({
    required this.controller,
    required this.currency,
    required this.onMax,
  });

  final TextEditingController controller;
  final String currency;
  final VoidCallback onMax;

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
              ),
            ),
          ),
          TextButton(
            onPressed: onMax,
            child: Text(
              'MAX',
              style: TextStyle(
                color: primary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    return Material(
      color: isDark ? colors.surface : Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? colors.surfaceVariant : const Color(0xFFE5E7EB),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: primary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _DestinationCard extends StatelessWidget {
  const _DestinationCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? colors.surface : Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? primary
                : (isDark ? colors.surfaceVariant : const Color(0xFFE5E7EB)),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: primary, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.check_circle : Icons.circle_outlined,
              color: selected ? primary : colors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemedField extends StatelessWidget {
  const _ThemedField({
    required this.controller,
    required this.label,
    required this.hint,
    this.keyboardType,
    this.prefixText,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType? keyboardType;
  final String? prefixText;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final primary = Theme.of(context).colorScheme.primary;

    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: onChanged,
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

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: primary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: colors.textSecondary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.enabled,
    required this.loading,
    required this.label,
    required this.onPressed,
  });

  final bool enabled;
  final bool loading;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: BoxDecoration(
        color: colors.background,
        boxShadow: Theme.of(context).brightness == Brightness.light
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ]
            : null,
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: enabled ? onPressed : null,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: enabled ? primary : colors.textTertiary,
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
