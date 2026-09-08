import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pretium/core/constants/app_colors.dart';
import 'package:pretium/features/pay/screens/pay_review_screen.dart';
import 'package:pretium/features/safari_tap/models/safari_tap_payout_quote.dart';
import 'package:pretium/features/safari_tap/services/safari_tap_pay_api_service.dart';
import 'package:pretium/features/safari_tap/services/safari_tap_pay_flow.dart';
import 'package:pretium/features/safari_tap/utils/payout_error_messages.dart';
import 'package:pretium/features/safari_tap/utils/safari_tap_phone.dart';
import 'package:pretium/features/safari_tap/utils/truepay_merchant_payload.dart';
import 'package:pretium/features/safari_tap/widgets/merchant_validation_panel.dart';
import 'package:pretium/features/topup/screens/payment_checkout_webview_page.dart';
import 'package:pretium/utils/async_action_guard.dart';
import 'package:pretium/widgets/currency_logo.dart';
import 'package:uuid/uuid.dart';
import 'package:pretium/widgets/app_shimmer.dart';
import 'package:pretium/widgets/bottom_safe_action_bar.dart';

const String kSafariTapPayCurrency = 'KES';

enum _PayFlowStep { form, review }

class SafariTapKesBalanceRow extends StatelessWidget {
  const SafariTapKesBalanceRow({
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
          const CurrencyLogo(code: kSafariTapPayCurrency, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Available KES', style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                if (loading)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: ShimmerBusyIndicator(width: 72, height: 14),
                  )
                else
                  Text(
                    balance.toStringAsFixed(2),
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

mixin SafariTapPayValidationMixin<T extends StatefulWidget> on State<T> {
  String? beneficiaryName;
  bool validationLoading = false;
  String? validationError;

  SafariTapPayApiService get payApi;

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
    } on SafariTapPayApiException catch (e) {
      setState(() {
        validationLoading = false;
        validationError = safariTapPayoutErrorMessage(e);
      });
      return false;
    }
  }

  Future<bool> submitPayout({
    required BuildContext context,
    required Map<String, dynamic> payoutBody,
    required String clientRequestId,
    required String flowLabel,
    required VoidCallback onPaid,
  }) async {
    if (FirebaseAuth.instance.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to pay')),
      );
      return false;
    }

    final ok = await runSafariTapPayoutFlow(
      context: context,
      payoutBody: payoutBody,
      flowLabel: flowLabel,
      clientRequestId: clientRequestId,
      api: payApi,
    );
    if (ok) onPaid();
    return ok;
  }
}

class SafariTapPayBillView extends StatefulWidget {
  const SafariTapPayBillView({
    super.key,
    required this.kesBalance,
    required this.loadingBalance,
    required this.payApi,
    required this.onPaid,
    this.onFlowStepChanged,
  });

  final double kesBalance;
  final bool loadingBalance;
  final SafariTapPayApiService payApi;
  final VoidCallback onPaid;
  final VoidCallback? onFlowStepChanged;

  @override
  State<SafariTapPayBillView> createState() => SafariTapPayBillViewState();
}

class SafariTapPayBillViewState extends State<SafariTapPayBillView>
    with SafariTapPayValidationMixin {
  final _businessCtrl = TextEditingController();
  final _accountCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  bool _submitting = false;
  _PayFlowStep _step = _PayFlowStep.form;

  SafariTapPayoutQuote? _quote;
  bool _isLoadingQuote = false;
  String? _quoteError;
  int _quoteRequestId = 0;

  @override
  SafariTapPayApiService get payApi => widget.payApi;

  void applyScannedCode(String code) => setState(() => _businessCtrl.text = code);

  /// Returns true when the back press was handled by leaving review.
  bool handleBack() {
    if (_step != _PayFlowStep.review || _submitting) return false;
    _goToForm();
    return true;
  }

  bool get isReviewStep => _step == _PayFlowStep.review;

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
        'accountType': 'PayBill',
        'accountReference': _accountCtrl.text.trim(),
        'name': beneficiaryName ?? 'PayBill',
      },
    };
  }

  Map<String, dynamic> _quoteBody(double amount) {
    return {
      'type': 'MPESA_B2B',
      'accountType': 'PayBill',
      'amount': amount,
      'currency': kSafariTapPayCurrency,
      'recipient': {
        'account': _businessCtrl.text.trim(),
        'accountType': 'PayBill',
        'accountReference': _accountCtrl.text.trim(),
      },
    };
  }

  Map<String, dynamic> _payoutBody(double amount, String clientRequestId) {
    return {
      'type': 'MPESA_B2B',
      'accountType': 'PayBill',
      'amount': amount,
      'currency': kSafariTapPayCurrency,
      'clientRequestId': clientRequestId,
      'recipient': {
        'account': _businessCtrl.text.trim(),
        'accountType': 'PayBill',
        'accountReference': _accountCtrl.text.trim(),
        'name': beneficiaryName ?? 'PayBill',
      },
      'narrative': 'SafariTap payment',
    };
  }

  void _clearValidation() {
    setState(() {
      beneficiaryName = null;
      validationError = null;
    });
  }

  void _goToForm() {
    _quoteRequestId++;
    setState(() {
      _step = _PayFlowStep.form;
      _isLoadingQuote = false;
      _quoteError = null;
    });
    widget.onFlowStepChanged?.call();
  }

  Future<void> _loadQuote(double amount) async {
    final requestId = ++_quoteRequestId;
    setState(() {
      _isLoadingQuote = true;
      _quoteError = null;
    });
    try {
      final quote = await widget.payApi.quotePayout(_quoteBody(amount));
      if (!mounted || requestId != _quoteRequestId) return;
      setState(() {
        _quote = quote;
        _isLoadingQuote = false;
        _quoteError = null;
      });
    } catch (e) {
      if (!mounted || requestId != _quoteRequestId) return;
      final message = e is SafariTapPayApiException
          ? safariTapPayoutErrorMessage(e)
          : 'Unable to load payment quote. Please try again.';
      setState(() {
        _isLoadingQuote = false;
        _quoteError = message;
        _quote = SafariTapPayoutQuote.fallback(
          amount: amount,
          currency: kSafariTapPayCurrency,
        );
      });
    }
  }

  Future<void> _continueToReview() async {
    final business = _businessCtrl.text.trim();
    final account = _accountCtrl.text.trim();
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (business.isEmpty || account.isEmpty) {
      _snack('Enter business number and account number');
      return;
    }
    if (account.length > 20) {
      _snack('Account number must be 1–20 characters');
      return;
    }
    if (amount <= 0) {
      _snack('Enter an amount to pay');
      return;
    }
    if (amount > widget.kesBalance) {
      _snack('Insufficient KES balance');
      return;
    }

    final ok = await validateBeneficiary(_validateBody());
    if (!ok || !mounted) return;

    setState(() {
      _step = _PayFlowStep.review;
      _quote = null;
      _quoteError = null;
      _isLoadingQuote = true;
    });
    widget.onFlowStepChanged?.call();
    await _loadQuote(amount);
  }

  Future<void> _confirmPay() async {
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (amount <= 0) return;

    await runGuardedAsync(
      this,
      isSubmitting: () => _submitting,
      setSubmitting: (v) => setState(() => _submitting = v),
      action: () async {
        final clientRequestId = const Uuid().v4();
        await submitPayout(
          context: context,
          clientRequestId: clientRequestId,
          flowLabel: 'PayBill',
          onPaid: widget.onPaid,
          payoutBody: _payoutBody(amount, clientRequestId),
        );
      },
    );
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    if (_step == _PayFlowStep.review) {
      final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
      return PayReviewScreen(
        flowTitle: 'Pay Bill',
        merchantName: beneficiaryName?.trim().isNotEmpty == true
            ? beneficiaryName!.trim()
            : 'Pay Bill merchant',
        accountLabel: 'PayBill number',
        accountValue: _businessCtrl.text.trim(),
        accountReferenceLabel: 'Account number',
        accountReferenceValue: _accountCtrl.text.trim(),
        amountLabel: '${amount.toStringAsFixed(2)} $kSafariTapPayCurrency',
        quote: _quote,
        isLoadingQuote: _isLoadingQuote,
        quoteError: _quoteError,
        onRetryQuote: _isLoadingQuote ? null : () => _loadQuote(amount),
        onEditPaymentDetails: _goToForm,
        onEditMerchant: _goToForm,
        isSubmitting: _submitting,
        onConfirm: _confirmPay,
      );
    }

    final colors = AppColors.getThemeColors(context);
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              SafariTapKesBalanceRow(
                balance: widget.kesBalance,
                loading: widget.loadingBalance,
              ),
              const SizedBox(height: 20),
              SafariTapPayField(
                controller: _businessCtrl,
                label: 'PayBill number',
                hint: 'e.g. 888880',
                keyboardType: TextInputType.number,
                onChanged: (_) => _clearValidation(),
              ),
              const SizedBox(height: 12),
              SafariTapPayField(
                controller: _accountCtrl,
                label: 'Account Number',
                hint: 'Account number',
                onChanged: (_) => _clearValidation(),
              ),
              const SizedBox(height: 12),
              SafariTapPayAmountField(controller: _amountCtrl),
              MerchantValidationPanel(
                beneficiaryName: beneficiaryName,
                loading: validationLoading,
                error: validationError,
                idleMessage: 'Merchant name will appear here after validation',
              ),
              const SizedBox(height: 16),
              Text(
                'Payments are sent in KES from your SafariTap wallet.',
                style: TextStyle(color: colors.textTertiary, fontSize: 12),
              ),
            ],
          ),
        ),
        SafariTapPayBottomButton(
          label: 'Continue',
          loading: validationLoading,
          onPressed: _continueToReview,
        ),
      ],
    );
  }
}

class SafariTapBuyGoodsView extends StatefulWidget {
  const SafariTapBuyGoodsView({
    super.key,
    required this.kesBalance,
    required this.loadingBalance,
    required this.payApi,
    required this.onPaid,
    this.onFlowStepChanged,
  });

  final double kesBalance;
  final bool loadingBalance;
  final SafariTapPayApiService payApi;
  final VoidCallback onPaid;
  final VoidCallback? onFlowStepChanged;

  @override
  State<SafariTapBuyGoodsView> createState() => SafariTapBuyGoodsViewState();
}

class SafariTapBuyGoodsViewState extends State<SafariTapBuyGoodsView>
    with SafariTapPayValidationMixin {
  final _tillCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  bool _submitting = false;
  _PayFlowStep _step = _PayFlowStep.form;

  SafariTapPayoutQuote? _quote;
  bool _isLoadingQuote = false;
  String? _quoteError;
  int _quoteRequestId = 0;

  @override
  SafariTapPayApiService get payApi => widget.payApi;

  void applyScannedCode(String code) => setState(() => _tillCtrl.text = code);

  /// Returns true when the back press was handled by leaving review.
  bool handleBack() {
    if (_step != _PayFlowStep.review || _submitting) return false;
    _goToForm();
    return true;
  }

  bool get isReviewStep => _step == _PayFlowStep.review;

  @override
  void dispose() {
    _tillCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  void _clearValidation() {
    setState(() {
      beneficiaryName = null;
      validationError = null;
    });
  }

  void _goToForm() {
    _quoteRequestId++;
    setState(() {
      _step = _PayFlowStep.form;
      _isLoadingQuote = false;
      _quoteError = null;
    });
    widget.onFlowStepChanged?.call();
  }

  Map<String, dynamic> _validateBody() {
    return {
      'type': 'MPESA_B2B',
      'accountType': 'TillNumber',
      'recipient': {
        'account': _tillCtrl.text.trim(),
        'accountType': 'TillNumber',
        'name': beneficiaryName ?? 'Till',
      },
    };
  }

  Map<String, dynamic> _quoteBody(double amount) {
    return {
      'type': 'MPESA_B2B',
      'accountType': 'TillNumber',
      'amount': amount,
      'currency': kSafariTapPayCurrency,
      'recipient': {
        'account': _tillCtrl.text.trim(),
        'accountType': 'TillNumber',
      },
    };
  }

  Map<String, dynamic> _payoutBody(double amount, String clientRequestId) {
    return {
      'type': 'MPESA_B2B',
      'accountType': 'TillNumber',
      'amount': amount,
      'currency': kSafariTapPayCurrency,
      'clientRequestId': clientRequestId,
      'recipient': {
        'account': _tillCtrl.text.trim(),
        'accountType': 'TillNumber',
        'name': beneficiaryName ?? 'Till',
      },
      'narrative': 'SafariTap payment',
    };
  }

  Future<void> _loadQuote(double amount) async {
    final requestId = ++_quoteRequestId;
    setState(() {
      _isLoadingQuote = true;
      _quoteError = null;
    });
    try {
      final quote = await widget.payApi.quotePayout(_quoteBody(amount));
      if (!mounted || requestId != _quoteRequestId) return;
      setState(() {
        _quote = quote;
        _isLoadingQuote = false;
        _quoteError = null;
      });
    } catch (e) {
      if (!mounted || requestId != _quoteRequestId) return;
      final message = e is SafariTapPayApiException
          ? safariTapPayoutErrorMessage(e)
          : 'Unable to load payment quote. Please try again.';
      setState(() {
        _isLoadingQuote = false;
        _quoteError = message;
        _quote = SafariTapPayoutQuote.fallback(
          amount: amount,
          currency: kSafariTapPayCurrency,
        );
      });
    }
  }

  Future<void> _continueToReview() async {
    final till = _tillCtrl.text.trim();
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (till.isEmpty) {
      _snack('Enter till number');
      return;
    }
    if (amount <= 0) {
      _snack('Enter an amount to pay');
      return;
    }
    if (amount > widget.kesBalance) {
      _snack('Insufficient KES balance');
      return;
    }

    final ok = await validateBeneficiary(_validateBody());
    if (!ok || !mounted) return;

    setState(() {
      _step = _PayFlowStep.review;
      _quote = null;
      _quoteError = null;
      _isLoadingQuote = true;
    });
    widget.onFlowStepChanged?.call();
    await _loadQuote(amount);
  }

  Future<void> _confirmPay() async {
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (amount <= 0) return;

    await runGuardedAsync(
      this,
      isSubmitting: () => _submitting,
      setSubmitting: (v) => setState(() => _submitting = v),
      action: () async {
        final clientRequestId = const Uuid().v4();
        await submitPayout(
          context: context,
          clientRequestId: clientRequestId,
          flowLabel: 'Buy Goods',
          onPaid: widget.onPaid,
          payoutBody: _payoutBody(amount, clientRequestId),
        );
      },
    );
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    if (_step == _PayFlowStep.review) {
      final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
      return PayReviewScreen(
        flowTitle: 'Buy Goods',
        merchantName: beneficiaryName?.trim().isNotEmpty == true
            ? beneficiaryName!.trim()
            : 'Till merchant',
        accountLabel: 'Till number',
        accountValue: _tillCtrl.text.trim(),
        amountLabel: '${amount.toStringAsFixed(2)} $kSafariTapPayCurrency',
        quote: _quote,
        isLoadingQuote: _isLoadingQuote,
        quoteError: _quoteError,
        onRetryQuote: _isLoadingQuote ? null : () => _loadQuote(amount),
        onEditPaymentDetails: _goToForm,
        onEditMerchant: _goToForm,
        isSubmitting: _submitting,
        onConfirm: _confirmPay,
      );
    }

    final colors = AppColors.getThemeColors(context);
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              SafariTapKesBalanceRow(
                balance: widget.kesBalance,
                loading: widget.loadingBalance,
              ),
              const SizedBox(height: 20),
              SafariTapPayField(
                controller: _tillCtrl,
                label: 'Till number',
                hint: 'Lipa Na M-Pesa till',
                keyboardType: TextInputType.number,
                onChanged: (_) => _clearValidation(),
              ),
              const SizedBox(height: 12),
              SafariTapPayAmountField(controller: _amountCtrl),
              MerchantValidationPanel(
                beneficiaryName: beneficiaryName,
                loading: validationLoading,
                error: validationError,
              ),
              const SizedBox(height: 16),
              Text(
                'Payments are sent in KES from your SafariTap wallet.',
                style: TextStyle(color: colors.textTertiary, fontSize: 12),
              ),
            ],
          ),
        ),
        SafariTapPayBottomButton(
          label: 'Continue',
          loading: validationLoading,
          onPressed: _continueToReview,
        ),
      ],
    );
  }
}

class SafariTapTruePayMerchantView extends StatefulWidget {
  const SafariTapTruePayMerchantView({
    super.key,
    required this.kesBalance,
    required this.loadingBalance,
    required this.payApi,
    required this.onPaid,
    this.onFlowStepChanged,
  });

  final double kesBalance;
  final bool loadingBalance;
  final SafariTapPayApiService payApi;
  final VoidCallback onPaid;
  final VoidCallback? onFlowStepChanged;

  @override
  State<SafariTapTruePayMerchantView> createState() =>
      SafariTapTruePayMerchantViewState();
}

class SafariTapTruePayMerchantViewState extends State<SafariTapTruePayMerchantView>
    with SafariTapPayValidationMixin {
  final _merchantCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  bool _submitting = false;
  bool _resolving = false;
  _PayFlowStep _step = _PayFlowStep.form;
  String? _qrPayload;

  SafariTapPayoutQuote? _quote;
  bool _isLoadingQuote = false;
  String? _quoteError;
  int _quoteRequestId = 0;

  @override
  SafariTapPayApiService get payApi => widget.payApi;

  Future<void> applyScannedCode(String code) => _resolvePayload(code);

  bool handleBack() {
    if (_step != _PayFlowStep.review || _submitting) return false;
    _goToForm();
    return true;
  }

  bool get isReviewStep => _step == _PayFlowStep.review;

  String get _merchantId =>
      TruePayMerchantPayload.extractMerchantId(_merchantCtrl.text) ??
      _merchantCtrl.text.trim();

  @override
  void dispose() {
    _merchantCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  void _clearValidation() {
    setState(() {
      beneficiaryName = null;
      validationError = null;
      _qrPayload = null;
    });
  }

  void _goToForm() {
    _quoteRequestId++;
    setState(() {
      _step = _PayFlowStep.form;
      _isLoadingQuote = false;
      _quoteError = null;
    });
    widget.onFlowStepChanged?.call();
  }

  Map<String, dynamic> _validateBody() {
    return {
      'type': 'TRUEPAY_MERCHANT',
      'merchantId': _merchantId,
      if (_qrPayload != null && _qrPayload!.isNotEmpty) 'qrPayload': _qrPayload,
    };
  }

  Map<String, dynamic> _quoteBody(double amount) {
    return {
      'type': 'TRUEPAY_MERCHANT',
      'amount': amount,
      'currency': kSafariTapPayCurrency,
      'recipient': {
        'merchantId': _merchantId,
      },
    };
  }

  Map<String, dynamic> _payoutBody(double amount, String clientRequestId) {
    return {
      'type': 'TRUEPAY_MERCHANT',
      'amount': amount,
      'currency': kSafariTapPayCurrency,
      'clientRequestId': clientRequestId,
      'recipient': {
        'merchantId': _merchantId,
        if (beneficiaryName != null && beneficiaryName!.trim().isNotEmpty)
          'name': beneficiaryName!.trim(),
      },
    };
  }

  Future<void> _openProductCheckout({
    required String checkoutUrl,
    String? linkId,
  }) async {
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PaymentCheckoutWebViewPage(
          checkoutUrl: checkoutUrl,
          paymentId: linkId ?? 'truepay-product',
          title: 'Product payment',
        ),
      ),
    );
  }

  Future<void> _resolvePayload(String raw) async {
    final payload = raw.trim();
    if (payload.isEmpty || _resolving) return;

    setState(() {
      _resolving = true;
      validationError = null;
    });

    try {
      final resolved = await widget.payApi.resolveMerchant(payload);
      if (!mounted) return;

      if (resolved.isProduct) {
        setState(() => _resolving = false);
        await _openResolvedProduct(
          checkoutUrl: resolved.checkoutUrl,
          linkId: resolved.linkId,
          fallbackPayload: payload,
        );
        return;
      }

      final merchantId = resolved.merchantId ??
          TruePayMerchantPayload.extractMerchantId(payload);
      if (resolved.isProfile || (merchantId != null && merchantId.isNotEmpty)) {
        if (merchantId == null || merchantId.isEmpty) {
          setState(() => _resolving = false);
          _snack('Could not read a merchant ID from this code.');
          return;
        }
        setState(() {
          _resolving = false;
          _merchantCtrl.text = merchantId;
          _qrPayload = payload;
          beneficiaryName = resolved.partnerName?.trim().isNotEmpty == true
              ? resolved.partnerName!.trim()
              : beneficiaryName;
          validationError = null;
        });
        return;
      }

      setState(() => _resolving = false);
      _snack('Could not recognize this QR code.');
    } catch (e) {
      if (!mounted) return;
      final message = e is SafariTapPayApiException
          ? safariTapPayoutErrorMessage(e)
          : 'Could not resolve this merchant code.';
      final extracted = TruePayMerchantPayload.extractMerchantId(payload);
      if (extracted != null) {
        setState(() {
          _resolving = false;
          _merchantCtrl.text = extracted;
          _qrPayload = payload;
          validationError = message;
        });
        return;
      }
      if (TruePayMerchantPayload.looksLikeProductLink(payload)) {
        setState(() => _resolving = false);
        await _openResolvedProduct(
          checkoutUrl: null,
          fallbackPayload: payload,
        );
        return;
      }
      setState(() {
        _resolving = false;
        validationError = message;
      });
    }
  }

  Future<void> _openResolvedProduct({
    String? checkoutUrl,
    String? linkId,
    required String fallbackPayload,
  }) async {
    final url = checkoutUrl ??
        (TruePayMerchantPayload.looksLikeProductLink(fallbackPayload) &&
                (fallbackPayload.startsWith('http://') ||
                    fallbackPayload.startsWith('https://'))
            ? fallbackPayload
            : null);
    if (url == null || url.isEmpty) {
      _snack('This product link could not be opened.');
      return;
    }
    await _openProductCheckout(checkoutUrl: url, linkId: linkId);
  }

  Future<bool> _validateTruePayMerchant() async {
    setState(() {
      validationLoading = true;
      validationError = null;
    });
    try {
      final result = await widget.payApi.validateBeneficiary(_validateBody());
      if (!mounted) return false;
      if (!result.valid) {
        setState(() {
          validationLoading = false;
          validationError = 'Could not verify this merchant';
        });
        return false;
      }
      final name = result.beneficiaryName.trim();
      setState(() {
        validationLoading = false;
        if (name.isNotEmpty) beneficiaryName = name;
      });
      return true;
    } on SafariTapPayApiException catch (e) {
      if (!mounted) return false;
      setState(() {
        validationLoading = false;
        validationError = safariTapPayoutErrorMessage(e);
      });
      return false;
    }
  }

  Future<void> _loadQuote(double amount) async {
    final requestId = ++_quoteRequestId;
    setState(() {
      _isLoadingQuote = true;
      _quoteError = null;
    });
    try {
      final quote = await widget.payApi.quotePayout(_quoteBody(amount));
      if (!mounted || requestId != _quoteRequestId) return;
      setState(() {
        _quote = quote;
        _isLoadingQuote = false;
        _quoteError = null;
      });
    } catch (e) {
      if (!mounted || requestId != _quoteRequestId) return;
      final message = e is SafariTapPayApiException
          ? safariTapPayoutErrorMessage(e)
          : 'Unable to load payment quote. Please try again.';
      setState(() {
        _isLoadingQuote = false;
        _quoteError = message;
        _quote = SafariTapPayoutQuote.fallback(
          amount: amount,
          currency: kSafariTapPayCurrency,
        );
      });
    }
  }

  Future<void> _continueToReview() async {
    final typed = _merchantCtrl.text.trim();
    if (typed.isEmpty) {
      _snack('Enter merchant ID');
      return;
    }

    if (TruePayMerchantPayload.looksLikeProductLink(typed)) {
      await _resolvePayload(typed);
      return;
    }
    if (TruePayMerchantPayload.shouldResolve(typed)) {
      await _resolvePayload(typed);
    }

    final merchantId = _merchantId;
    if (!TruePayMerchantPayload.isMerchantId(merchantId)) {
      _snack('Enter a TruePay merchant ID (partner_…)');
      return;
    }

    if (_qrPayload == null &&
        (typed.contains('/p/') || typed.contains('://'))) {
      _qrPayload = typed;
    }

    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (amount <= 0) {
      _snack('Enter an amount to pay');
      return;
    }
    if (amount > widget.kesBalance) {
      _snack('Insufficient KES balance');
      return;
    }

    final ok = await _validateTruePayMerchant();
    if (!ok || !mounted) return;

    setState(() {
      _step = _PayFlowStep.review;
      _quote = null;
      _quoteError = null;
      _isLoadingQuote = true;
    });
    widget.onFlowStepChanged?.call();
    await _loadQuote(amount);
  }

  Future<void> _confirmPay() async {
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (amount <= 0) return;

    await runGuardedAsync(
      this,
      isSubmitting: () => _submitting,
      setSubmitting: (v) => setState(() => _submitting = v),
      action: () async {
        final clientRequestId = const Uuid().v4();
        await submitPayout(
          context: context,
          clientRequestId: clientRequestId,
          flowLabel: 'TruePay merchant',
          onPaid: widget.onPaid,
          payoutBody: _payoutBody(amount, clientRequestId),
        );
      },
    );
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    if (_step == _PayFlowStep.review) {
      final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
      return PayReviewScreen(
        flowTitle: 'TruePay merchant',
        merchantName: beneficiaryName?.trim().isNotEmpty == true
            ? beneficiaryName!.trim()
            : 'TruePay merchant',
        accountLabel: 'Recipient',
        accountValue: beneficiaryName?.trim().isNotEmpty == true
            ? beneficiaryName!.trim()
            : _merchantId,
        amountLabel: '${amount.toStringAsFixed(2)} $kSafariTapPayCurrency',
        quote: _quote,
        isLoadingQuote: _isLoadingQuote,
        quoteError: _quoteError,
        onRetryQuote: _isLoadingQuote ? null : () => _loadQuote(amount),
        onEditPaymentDetails: _goToForm,
        onEditMerchant: _goToForm,
        isSubmitting: _submitting,
        onConfirm: _confirmPay,
      );
    }

    final colors = AppColors.getThemeColors(context);
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              SafariTapKesBalanceRow(
                balance: widget.kesBalance,
                loading: widget.loadingBalance,
              ),
              const SizedBox(height: 20),
              SafariTapPayField(
                controller: _merchantCtrl,
                label: 'Merchant ID',
                hint: 'TruePay merchant ID',
                onChanged: (_) => _clearValidation(),
              ),
              const SizedBox(height: 12),
              SafariTapPayAmountField(controller: _amountCtrl),
              MerchantValidationPanel(
                beneficiaryName: beneficiaryName,
                loading: validationLoading || _resolving,
                loadingMessage:
                    _resolving ? 'Looking up merchant…' : 'Validating…',
                error: validationError,
              ),
              const SizedBox(height: 16),
              Text(
                'Payments are sent in KES from your SafariTap wallet.',
                style: TextStyle(color: colors.textTertiary, fontSize: 12),
              ),
            ],
          ),
        ),
        SafariTapPayBottomButton(
          label: 'Continue',
          loading: validationLoading || _resolving,
          onPressed: _continueToReview,
        ),
      ],
    );
  }
}

class SafariTapPochiView extends StatefulWidget {
  const SafariTapPochiView({
    super.key,
    required this.kesBalance,
    required this.loadingBalance,
    required this.payApi,
    required this.onPaid,
  });

  final double kesBalance;
  final bool loadingBalance;
  final SafariTapPayApiService payApi;
  final VoidCallback onPaid;

  @override
  State<SafariTapPochiView> createState() => SafariTapPochiViewState();
}

class SafariTapPochiViewState extends State<SafariTapPochiView>
    with SafariTapPayValidationMixin {
  final _pochiCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  bool _submitting = false;

  @override
  SafariTapPayApiService get payApi => widget.payApi;

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
          flowLabel: 'Pochi La Biashara',
          onPaid: widget.onPaid,
          payoutBody: {
            'type': 'MPESA_B2C',
            'amount': amount,
            'currency': kSafariTapPayCurrency,
            'clientRequestId': clientRequestId,
            'recipient': {
              'phoneNumber': pochi,
              'name': beneficiaryName ?? 'Recipient',
            },
            'narrative': 'SafariTap payment',
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
              SafariTapKesBalanceRow(balance: widget.kesBalance, loading: widget.loadingBalance),
              const SizedBox(height: 20),
              SafariTapPayField(
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
              SafariTapPayAmountField(controller: _amountCtrl),
              MerchantValidationPanel(
                beneficiaryName: beneficiaryName,
                loading: validationLoading,
                error: validationError,
              ),
              const SizedBox(height: 16),
              Text(
                'Payments are sent in KES from your SafariTap wallet.',
                style: TextStyle(color: colors.textTertiary, fontSize: 12),
              ),
            ],
          ),
        ),
        SafariTapPayBottomButton(
          label: 'Confirm Payment',
          loading: _submitting,
          onPressed: _pay,
        ),
      ],
    );
  }
}

class SafariTapPayField extends StatelessWidget {
  const SafariTapPayField({
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

class SafariTapPayAmountField extends StatelessWidget {
  const SafariTapPayAmountField({super.key, required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return SafariTapPayField(
      controller: controller,
      label: 'Amount (KES)',
      hint: '0.00',
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
    );
  }
}

class SafariTapPayBottomButton extends StatelessWidget {
  const SafariTapPayBottomButton({
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
    return BottomSafeActionBar(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: loading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: loading
              ? const ShimmerBusyIndicator(onPrimary: true)
              : Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
        ),
      ),
    );
  }
}
