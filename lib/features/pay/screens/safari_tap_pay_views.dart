import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pretium/core/constants/app_colors.dart';
import 'package:pretium/features/pay/providers/kenya_pay_flow_provider.dart';
import 'package:pretium/features/pay/screens/pay_review_screen.dart';
import 'package:pretium/features/safari_tap/services/safari_tap_pay_api_service.dart';
import 'package:pretium/features/safari_tap/services/safari_tap_pay_flow.dart';
import 'package:pretium/features/safari_tap/utils/payout_error_messages.dart';
import 'package:pretium/features/safari_tap/utils/safari_tap_phone.dart';
import 'package:pretium/features/safari_tap/utils/truepay_merchant_payload.dart';
import 'package:pretium/features/safari_tap/widgets/merchant_validation_panel.dart';
import 'package:pretium/features/topup/screens/payment_checkout_webview_page.dart';
import 'package:pretium/utils/async_action_guard.dart';
import 'package:uuid/uuid.dart';
import 'package:pretium/widgets/money_form_widgets.dart';

const String kSafariTapPayCurrency = 'KES';

mixin SafariTapPayValidationMixin<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  KenyaPayKind get payKind;

  KenyaPayFlowState get payFlow => ref.watch(kenyaPayFlowProvider(payKind));
  KenyaPayFlowNotifier get payFlowN =>
      ref.read(kenyaPayFlowProvider(payKind).notifier);

  SafariTapPayApiService get payApi;

  String? get beneficiaryName => payFlow.beneficiaryName;
  bool get validationLoading => payFlow.validationLoading;
  String? get validationError => payFlow.validationError;

  bool get isBeneficiaryValidated => payFlow.isValidated;

  bool get isReviewing => payFlow.step == KenyaPayStep.review;

  Future<bool> validateBeneficiary(Map<String, dynamic> body) =>
      payFlowN.validate(body);

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

class SafariTapPayBillView extends ConsumerStatefulWidget {
  const SafariTapPayBillView({
    super.key,
    required this.kesBalance,
    required this.payApi,
    required this.onPaid,
    this.onFlowStepChanged,
    this.onScanQr,
  });

  final double kesBalance;
  final SafariTapPayApiService payApi;
  final VoidCallback onPaid;
  final VoidCallback? onFlowStepChanged;
  final VoidCallback? onScanQr;

  @override
  ConsumerState<SafariTapPayBillView> createState() => SafariTapPayBillViewState();
}

class SafariTapPayBillViewState extends ConsumerState<SafariTapPayBillView>
    with SafariTapPayValidationMixin {
  @override
  KenyaPayKind get payKind => KenyaPayKind.payBill;
  final _businessCtrl = TextEditingController();
  final _accountCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  bool _submitting = false;

  @override
  SafariTapPayApiService get payApi => widget.payApi;

  void applyScannedCode(String code) => setState(() => _businessCtrl.text = code);

  /// Returns true when the back press was handled by leaving review.
  bool handleBack() {
    if (payFlow.step != KenyaPayStep.review || _submitting) return false;
    _goToForm();
    return true;
  }

  bool get isReviewStep => payFlow.step == KenyaPayStep.review;

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
    payFlowN.clearValidation();
  }

  void _goToForm() {
    payFlowN.goToForm();
    widget.onFlowStepChanged?.call();
  }

  Future<void> _loadQuote(double amount) async {
    await payFlowN.loadQuote(
      _quoteBody(amount),
      amount: amount,
      currency: kSafariTapPayCurrency,
    );
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

    if (!isBeneficiaryValidated) {
      await validateBeneficiary(_validateBody());
      return;
    }

    payFlowN.goToReview();
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
    if (payFlow.step == KenyaPayStep.review) {
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
        quote: payFlow.quote,
        isLoadingQuote: payFlow.isLoadingQuote,
        quoteError: payFlow.quoteError,
        onRetryQuote: payFlow.isLoadingQuote ? null : () => _loadQuote(amount),
        onEditPaymentDetails: _goToForm,
        onEditMerchant: _goToForm,
        isSubmitting: _submitting,
        onConfirm: _confirmPay,
      );
    }

    final colors = AppColors.getThemeColors(context);
    return _PayFormColumn(
      action: MoneyPrimaryButton(
        label: isBeneficiaryValidated ? 'Continue to pay' : 'Validate',
        loading: validationLoading,
        onPressed: _continueToReview,
      ),
      children: [
        MoneyLabeledField(
          controller: _businessCtrl,
          label: 'PayBill number',
          hint: 'e.g. 888880',
          keyboardType: TextInputType.number,
          onChanged: (_) => _clearValidation(),
          suffixIcon: widget.onScanQr == null
              ? null
              : MoneyQrFieldButton(onPressed: widget.onScanQr!),
        ),
              const SizedBox(height: 14),
              MoneyLabeledField(
                controller: _accountCtrl,
                label: 'Account Number',
                hint: 'Account number',
                onChanged: (_) => _clearValidation(),
              ),
              const SizedBox(height: 24),
              MoneyAmountEntry(
                controller: _amountCtrl,
                onChanged: (_) => setState(() {}),
              ),
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
    );
  }
}

class SafariTapBuyGoodsView extends ConsumerStatefulWidget {
  const SafariTapBuyGoodsView({
    super.key,
    required this.kesBalance,
    required this.payApi,
    required this.onPaid,
    this.onFlowStepChanged,
    this.onScanQr,
  });

  final double kesBalance;
  final SafariTapPayApiService payApi;
  final VoidCallback onPaid;
  final VoidCallback? onFlowStepChanged;
  final VoidCallback? onScanQr;

  @override
  ConsumerState<SafariTapBuyGoodsView> createState() => SafariTapBuyGoodsViewState();
}

class SafariTapBuyGoodsViewState extends ConsumerState<SafariTapBuyGoodsView>
    with SafariTapPayValidationMixin {
  @override
  KenyaPayKind get payKind => KenyaPayKind.buyGoods;
  final _tillCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  bool _submitting = false;

  @override
  SafariTapPayApiService get payApi => widget.payApi;

  void applyScannedCode(String code) => setState(() => _tillCtrl.text = code);

  /// Returns true when the back press was handled by leaving review.
  bool handleBack() {
    if (payFlow.step != KenyaPayStep.review || _submitting) return false;
    _goToForm();
    return true;
  }

  bool get isReviewStep => payFlow.step == KenyaPayStep.review;

  @override
  void dispose() {
    _tillCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  void _clearValidation() {
    payFlowN.clearValidation();
  }

  void _goToForm() {
    payFlowN.goToForm();
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
    await payFlowN.loadQuote(
      _quoteBody(amount),
      amount: amount,
      currency: kSafariTapPayCurrency,
    );
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

    if (!isBeneficiaryValidated) {
      await validateBeneficiary(_validateBody());
      return;
    }

    payFlowN.goToReview();
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
    if (payFlow.step == KenyaPayStep.review) {
      final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
      return PayReviewScreen(
        flowTitle: 'Buy Goods',
        merchantName: beneficiaryName?.trim().isNotEmpty == true
            ? beneficiaryName!.trim()
            : 'Till merchant',
        accountLabel: 'Till number',
        accountValue: _tillCtrl.text.trim(),
        amountLabel: '${amount.toStringAsFixed(2)} $kSafariTapPayCurrency',
        quote: payFlow.quote,
        isLoadingQuote: payFlow.isLoadingQuote,
        quoteError: payFlow.quoteError,
        onRetryQuote: payFlow.isLoadingQuote ? null : () => _loadQuote(amount),
        onEditPaymentDetails: _goToForm,
        onEditMerchant: _goToForm,
        isSubmitting: _submitting,
        onConfirm: _confirmPay,
      );
    }

    final colors = AppColors.getThemeColors(context);
    return _PayFormColumn(
      action: MoneyPrimaryButton(
        label: isBeneficiaryValidated ? 'Continue to pay' : 'Validate',
        loading: validationLoading,
        onPressed: _continueToReview,
      ),
      children: [
        MoneyLabeledField(
          controller: _tillCtrl,
          label: 'Till number',
          hint: 'Lipa Na M-Pesa till',
          keyboardType: TextInputType.number,
          onChanged: (_) => _clearValidation(),
          suffixIcon: widget.onScanQr == null
              ? null
              : MoneyQrFieldButton(onPressed: widget.onScanQr!),
        ),
        const SizedBox(height: 24),
        MoneyAmountEntry(
          controller: _amountCtrl,
          onChanged: (_) => setState(() {}),
        ),
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
    );
  }
}

class SafariTapTruePayMerchantView extends ConsumerStatefulWidget {
  const SafariTapTruePayMerchantView({
    super.key,
    required this.kesBalance,
    required this.payApi,
    required this.onPaid,
    this.onFlowStepChanged,
    this.onScanQr,
  });

  final double kesBalance;
  final SafariTapPayApiService payApi;
  final VoidCallback onPaid;
  final VoidCallback? onFlowStepChanged;
  final VoidCallback? onScanQr;

  @override
  ConsumerState<SafariTapTruePayMerchantView> createState() =>
      SafariTapTruePayMerchantViewState();
}

class SafariTapTruePayMerchantViewState extends ConsumerState<SafariTapTruePayMerchantView>
    with SafariTapPayValidationMixin {
  @override
  KenyaPayKind get payKind => KenyaPayKind.truePay;
  final _merchantCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  bool _submitting = false;
  bool _resolving = false;
  String? _qrPayload;

  @override
  SafariTapPayApiService get payApi => widget.payApi;

  Future<void> applyScannedCode(String code) => _resolvePayload(code);

  bool handleBack() {
    if (payFlow.step != KenyaPayStep.review || _submitting) return false;
    _goToForm();
    return true;
  }

  bool get isReviewStep => payFlow.step == KenyaPayStep.review;

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
    _qrPayload = null;
    payFlowN.clearValidation();
  }

  void _goToForm() {
    payFlowN.goToForm();
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

    setState(() => _resolving = true);
    payFlowN.applyValidation(clearValidationError: true);

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
        });
        final partner = resolved.partnerName?.trim();
        payFlowN.applyValidation(
          beneficiaryName: (partner != null && partner.isNotEmpty)
              ? partner
              : payFlow.beneficiaryName,
          clearValidationError: true,
        );
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
        });
        payFlowN.applyValidation(validationError: message);
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
      setState(() => _resolving = false);
      payFlowN.applyValidation(validationError: message);
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
    return payFlowN.validateTruePay(_validateBody());
  }

  Future<void> _loadQuote(double amount) async {
    await payFlowN.loadQuote(
      _quoteBody(amount),
      amount: amount,
      currency: kSafariTapPayCurrency,
    );
  }

  Future<void> _continueToReview() async {
    final alreadyValidated = isBeneficiaryValidated;
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

    if (!alreadyValidated) {
      if (!isBeneficiaryValidated) {
        await _validateTruePayMerchant();
      }
      return;
    }

    payFlowN.goToReview();
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
    if (payFlow.step == KenyaPayStep.review) {
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
        quote: payFlow.quote,
        isLoadingQuote: payFlow.isLoadingQuote,
        quoteError: payFlow.quoteError,
        onRetryQuote: payFlow.isLoadingQuote ? null : () => _loadQuote(amount),
        onEditPaymentDetails: _goToForm,
        onEditMerchant: _goToForm,
        isSubmitting: _submitting,
        onConfirm: _confirmPay,
      );
    }

    final colors = AppColors.getThemeColors(context);
    return _PayFormColumn(
      action: MoneyPrimaryButton(
        label: isBeneficiaryValidated ? 'Continue to pay' : 'Validate',
        loading: validationLoading || _resolving,
        onPressed: _continueToReview,
      ),
      children: [
        MoneyLabeledField(
          controller: _merchantCtrl,
          label: 'Merchant ID',
          hint: 'TruePay merchant ID',
          onChanged: (_) => _clearValidation(),
          suffixIcon: widget.onScanQr == null
              ? null
              : MoneyQrFieldButton(onPressed: widget.onScanQr!),
        ),
        const SizedBox(height: 24),
        MoneyAmountEntry(
          controller: _amountCtrl,
          onChanged: (_) => setState(() {}),
        ),
        MerchantValidationPanel(
          beneficiaryName: beneficiaryName,
          loading: validationLoading || _resolving,
          loadingMessage: _resolving ? 'Looking up merchant…' : 'Validating…',
          error: validationError,
        ),
        const SizedBox(height: 16),
        Text(
          'Payments are sent in KES from your SafariTap wallet.',
          style: TextStyle(color: colors.textTertiary, fontSize: 12),
        ),
      ],
    );
  }
}

class SafariTapPochiView extends ConsumerStatefulWidget {
  const SafariTapPochiView({
    super.key,
    required this.kesBalance,
    required this.payApi,
    required this.onPaid,
    this.onScanQr,
  });

  final double kesBalance;
  final SafariTapPayApiService payApi;
  final VoidCallback onPaid;
  final VoidCallback? onScanQr;

  @override
  ConsumerState<SafariTapPochiView> createState() => SafariTapPochiViewState();
}

class SafariTapPochiViewState extends ConsumerState<SafariTapPochiView>
    with SafariTapPayValidationMixin {
  @override
  KenyaPayKind get payKind => KenyaPayKind.pochi;
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

    if (!isBeneficiaryValidated) {
      await validateBeneficiary({
        'type': 'MPESA_B2C',
        'recipient': {
          'phoneNumber': pochi,
          'name': beneficiaryName ?? 'Recipient',
        },
      });
      return;
    }

    await runGuardedAsync(
      this,
      isSubmitting: () => _submitting,
      setSubmitting: (v) => setState(() => _submitting = v),
      action: () async {
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
    return _PayFormColumn(
      action: MoneyPrimaryButton(
        label: isBeneficiaryValidated ? 'Confirm Payment' : 'Validate',
        loading: validationLoading || _submitting,
        onPressed: _pay,
      ),
      children: [
        MoneyLabeledField(
          controller: _pochiCtrl,
          label: 'Pochi number',
          hint: '07XXXXXXXX or 2547XXXXXXXX',
          keyboardType: TextInputType.phone,
          onChanged: (_) => payFlowN.clearValidation(),
          suffixIcon: widget.onScanQr == null
              ? null
              : MoneyQrFieldButton(onPressed: widget.onScanQr!),
        ),
        const SizedBox(height: 24),
        MoneyAmountEntry(
          controller: _amountCtrl,
          onChanged: (_) => setState(() {}),
        ),
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
    );
  }
}

class _PayFormColumn extends StatelessWidget {
  const _PayFormColumn({
    required this.children,
    required this.action,
  });

  final List<Widget> children;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
        action,
      ],
    );
  }
}
