import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pretium/core/constants/app_colors.dart';
import 'package:pretium/features/safari_card/services/safari_card_pay_api_service.dart';
import 'package:pretium/features/safari_card/services/safari_card_pay_flow.dart';
import 'package:pretium/features/safari_card/utils/payout_error_messages.dart';
import 'package:pretium/features/safari_card/utils/safari_card_phone.dart';
import 'package:pretium/features/safari_card/widgets/merchant_validation_panel.dart';
import 'package:pretium/utils/async_action_guard.dart';
import 'package:pretium/widgets/currency_logo.dart';
import 'package:uuid/uuid.dart';

const String kSafariCardPayCurrency = 'KES';

class SafariCardKesBalanceRow extends StatelessWidget {
  const SafariCardKesBalanceRow({
    super.key,
    required this.balance,
    required this.loading,
  });

  final double balance;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? colors.surface : Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(14),
        border: isDark ? null : Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          const CurrencyLogo(code: kSafariCardPayCurrency, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Available KES', style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                Text(
                  loading ? '…' : balance.toStringAsFixed(2),
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

mixin SafariCardPayValidationMixin<T extends StatefulWidget> on State<T> {
  String? beneficiaryName;
  bool validationLoading = false;
  String? validationError;

  SafariCardPayApiService get payApi;

  Future<bool> validateBeneficiary(Map<String, dynamic> body) async {
    setState(() {
      validationLoading = true;
      validationError = null;
      beneficiaryName = null;
    });
    try {
      final result = await payApi.validateBeneficiary(body);
      if (!result.hasDisplayName) {
        setState(() {
          validationLoading = false;
          validationError = 'Could not verify recipient';
        });
        return false;
      }
      setState(() {
        validationLoading = false;
        beneficiaryName = result.beneficiaryName;
      });
      return true;
    } on SafariCardPayApiException catch (e) {
      setState(() {
        validationLoading = false;
        validationError = safariCardPayoutErrorMessage(e);
      });
      return false;
    }
  }

  Future<bool> submitPayout({
    required BuildContext context,
    required Map<String, dynamic> payoutBody,
    required String clientRequestId,
    required VoidCallback onPaid,
  }) async {
    if (FirebaseAuth.instance.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to pay')),
      );
      return false;
    }

    final ok = await runSafariCardPayoutFlow(
      context: context,
      payoutBody: payoutBody,
      clientRequestId: clientRequestId,
      api: payApi,
    );
    if (ok) onPaid();
    return ok;
  }
}

class SafariCardPayBillView extends StatefulWidget {
  const SafariCardPayBillView({
    super.key,
    required this.kesBalance,
    required this.loadingBalance,
    required this.payApi,
    required this.onPaid,
  });

  final double kesBalance;
  final bool loadingBalance;
  final SafariCardPayApiService payApi;
  final VoidCallback onPaid;

  @override
  State<SafariCardPayBillView> createState() => SafariCardPayBillViewState();
}

class SafariCardPayBillViewState extends State<SafariCardPayBillView>
    with SafariCardPayValidationMixin {
  final _businessCtrl = TextEditingController();
  final _accountCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  bool _submitting = false;

  @override
  SafariCardPayApiService get payApi => widget.payApi;

  void applyScannedCode(String code) => setState(() => _businessCtrl.text = code);

  @override
  void dispose() {
    _businessCtrl.dispose();
    _accountCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Map<String, dynamic> _validateBody() {
    return {
      'type': 'MPESA_B2B',
      'accountType': 'PayBill',
      'recipient': {
        'account': _businessCtrl.text.trim(),
        'accountReference': _accountCtrl.text.trim(),
        'name': beneficiaryName ?? 'PayBill',
      },
    };
  }

  Future<void> _pay() async {
    final business = _businessCtrl.text.trim();
    final account = _accountCtrl.text.trim();
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (business.isEmpty || account.isEmpty || amount <= 0) {
      _snack('Enter business number, account reference, and amount');
      return;
    }
    if (account.length > 20) {
      _snack('Account reference must be 1–20 characters');
      return;
    }
    if (amount > widget.kesBalance) {
      _snack('Insufficient KES balance');
      return;
    }

    await runGuardedAsync(
      this,
      isSubmitting: () => _submitting,
      setSubmitting: (v) => setState(() => _submitting = v),
      action: () async {
        final valid = beneficiaryName != null || await validateBeneficiary(_validateBody());
        if (!valid || !mounted) return;

        final clientRequestId = const Uuid().v4();
        await submitPayout(
          context: context,
          clientRequestId: clientRequestId,
          onPaid: widget.onPaid,
          payoutBody: {
            'type': 'MPESA_B2B',
            'accountType': 'PayBill',
            'amount': amount,
            'currency': kSafariCardPayCurrency,
            'clientRequestId': clientRequestId,
            'recipient': {
              'account': business,
              'accountReference': account,
              'name': beneficiaryName ?? 'PayBill',
            },
            'narrative': 'Safari Card payment',
          },
        );
      },
    );
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              SafariCardKesBalanceRow(balance: widget.kesBalance, loading: widget.loadingBalance),
              const SizedBox(height: 20),
              SafariCardPayField(
                controller: _businessCtrl,
                label: 'PayBill number',
                hint: 'e.g. 888880',
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {
                  beneficiaryName = null;
                  validationError = null;
                }),
              ),
              const SizedBox(height: 12),
              SafariCardPayField(
                controller: _accountCtrl,
                label: 'Account reference',
                hint: 'Invoice / account reference',
                onChanged: (_) => setState(() {
                  beneficiaryName = null;
                  validationError = null;
                }),
              ),
              const SizedBox(height: 12),
              SafariCardPayAmountField(controller: _amountCtrl),
              MerchantValidationPanel(
                beneficiaryName: beneficiaryName,
                loading: validationLoading,
                error: validationError,
                idleMessage: 'Merchant name will appear here after validation',
              ),
              const SizedBox(height: 16),
              Text(
                'Payments are sent in KES from your Safari Card wallet.',
                style: TextStyle(color: colors.textTertiary, fontSize: 12),
              ),
            ],
          ),
        ),
        SafariCardPayBottomButton(
          label: 'Confirm Payment',
          loading: _submitting,
          onPressed: _pay,
        ),
      ],
    );
  }
}

class SafariCardBuyGoodsView extends StatefulWidget {
  const SafariCardBuyGoodsView({
    super.key,
    required this.kesBalance,
    required this.loadingBalance,
    required this.payApi,
    required this.onPaid,
  });

  final double kesBalance;
  final bool loadingBalance;
  final SafariCardPayApiService payApi;
  final VoidCallback onPaid;

  @override
  State<SafariCardBuyGoodsView> createState() => SafariCardBuyGoodsViewState();
}

class SafariCardBuyGoodsViewState extends State<SafariCardBuyGoodsView>
    with SafariCardPayValidationMixin {
  final _tillCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  bool _submitting = false;

  @override
  SafariCardPayApiService get payApi => widget.payApi;

  void applyScannedCode(String code) => setState(() => _tillCtrl.text = code);

  @override
  void dispose() {
    _tillCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _pay() async {
    final till = _tillCtrl.text.trim();
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (till.isEmpty || amount <= 0) {
      _snack('Enter till number and amount');
      return;
    }
    if (amount > widget.kesBalance) {
      _snack('Insufficient KES balance');
      return;
    }

    await runGuardedAsync(
      this,
      isSubmitting: () => _submitting,
      setSubmitting: (v) => setState(() => _submitting = v),
      action: () async {
        final valid = beneficiaryName != null ||
            await validateBeneficiary({
              'type': 'MPESA_B2B',
              'accountType': 'TillNumber',
              'recipient': {
                'account': till,
                'name': beneficiaryName ?? 'Till',
              },
            });
        if (!valid || !mounted) return;

        final clientRequestId = const Uuid().v4();
        await submitPayout(
          context: context,
          clientRequestId: clientRequestId,
          onPaid: widget.onPaid,
          payoutBody: {
            'type': 'MPESA_B2B',
            'accountType': 'TillNumber',
            'amount': amount,
            'currency': kSafariCardPayCurrency,
            'clientRequestId': clientRequestId,
            'recipient': {
              'account': till,
              'name': beneficiaryName ?? 'Till',
            },
            'narrative': 'Safari Card payment',
          },
        );
      },
    );
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              SafariCardKesBalanceRow(balance: widget.kesBalance, loading: widget.loadingBalance),
              const SizedBox(height: 20),
              SafariCardPayField(
                controller: _tillCtrl,
                label: 'Till number',
                hint: 'Lipa Na M-Pesa till',
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {
                  beneficiaryName = null;
                  validationError = null;
                }),
              ),
              const SizedBox(height: 12),
              SafariCardPayAmountField(controller: _amountCtrl),
              MerchantValidationPanel(
                beneficiaryName: beneficiaryName,
                loading: validationLoading,
                error: validationError,
              ),
              const SizedBox(height: 16),
              Text(
                'Payments are sent in KES from your Safari Card wallet.',
                style: TextStyle(color: colors.textTertiary, fontSize: 12),
              ),
            ],
          ),
        ),
        SafariCardPayBottomButton(
          label: 'Confirm Payment',
          loading: _submitting,
          onPressed: _pay,
        ),
      ],
    );
  }
}

class SafariCardPochiView extends StatefulWidget {
  const SafariCardPochiView({
    super.key,
    required this.kesBalance,
    required this.loadingBalance,
    required this.payApi,
    required this.onPaid,
  });

  final double kesBalance;
  final bool loadingBalance;
  final SafariCardPayApiService payApi;
  final VoidCallback onPaid;

  @override
  State<SafariCardPochiView> createState() => SafariCardPochiViewState();
}

class SafariCardPochiViewState extends State<SafariCardPochiView>
    with SafariCardPayValidationMixin {
  final _pochiCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  bool _submitting = false;

  @override
  SafariCardPayApiService get payApi => widget.payApi;

  void applyScannedCode(String code) => setState(() => _pochiCtrl.text = code);

  @override
  void dispose() {
    _pochiCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _pay() async {
    final pochi = normalizeKenyaPhone(_pochiCtrl.text);
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (pochi.length < 12 || amount <= 0) {
      _snack('Enter a valid Pochi number and amount');
      return;
    }
    if (amount > widget.kesBalance) {
      _snack('Insufficient KES balance');
      return;
    }

    await runGuardedAsync(
      this,
      isSubmitting: () => _submitting,
      setSubmitting: (v) => setState(() => _submitting = v),
      action: () async {
        final valid = beneficiaryName != null ||
            await validateBeneficiary({
              'type': 'MPESA_B2C',
              'recipient': {
                'phoneNumber': pochi,
                'name': beneficiaryName ?? 'Recipient',
              },
            });
        if (!valid || !mounted) return;

        final clientRequestId = const Uuid().v4();
        await submitPayout(
          context: context,
          clientRequestId: clientRequestId,
          onPaid: widget.onPaid,
          payoutBody: {
            'type': 'MPESA_B2C',
            'amount': amount,
            'currency': kSafariCardPayCurrency,
            'clientRequestId': clientRequestId,
            'recipient': {
              'phoneNumber': pochi,
              'name': beneficiaryName ?? 'Recipient',
            },
            'narrative': 'Safari Card payment',
          },
        );
      },
    );
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              SafariCardKesBalanceRow(balance: widget.kesBalance, loading: widget.loadingBalance),
              const SizedBox(height: 20),
              SafariCardPayField(
                controller: _pochiCtrl,
                label: 'Pochi number',
                hint: '07XXXXXXXX or 2547XXXXXXXX',
                keyboardType: TextInputType.phone,
                onChanged: (_) => setState(() {
                  beneficiaryName = null;
                  validationError = null;
                }),
              ),
              const SizedBox(height: 12),
              SafariCardPayAmountField(controller: _amountCtrl),
              MerchantValidationPanel(
                beneficiaryName: beneficiaryName,
                loading: validationLoading,
                error: validationError,
              ),
              const SizedBox(height: 16),
              Text(
                'Payments are sent in KES from your Safari Card wallet.',
                style: TextStyle(color: colors.textTertiary, fontSize: 12),
              ),
            ],
          ),
        ),
        SafariCardPayBottomButton(
          label: 'Confirm Payment',
          loading: _submitting,
          onPressed: _pay,
        ),
      ],
    );
  }
}

class SafariCardPayField extends StatelessWidget {
  const SafariCardPayField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    this.keyboardType,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: onChanged,
      style: TextStyle(color: colors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: isDark ? colors.surface : Colors.white.withValues(alpha: 0.95),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class SafariCardPayAmountField extends StatelessWidget {
  const SafariCardPayAmountField({super.key, required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return SafariCardPayField(
      controller: controller,
      label: 'Amount (KES)',
      hint: '0.00',
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
    );
  }
}

class SafariCardPayBottomButton extends StatelessWidget {
  const SafariCardPayBottomButton({
    super.key,
    required this.label,
    required this.loading,
    required this.onPressed,
  });

  final String label;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: loading ? null : onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          ),
        ),
      ),
    );
  }
}
