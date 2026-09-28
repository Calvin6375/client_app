import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pretium/features/send_money/providers/send_money_flow_provider.dart';
import 'package:pretium/features/send_money/screens/send_money_form_screen.dart';
import 'package:pretium/features/send_money/screens/payment_method_screen.dart';
import 'package:pretium/features/send_money/screens/review_details_screen.dart';
import 'package:pretium/core/constants/app_colors.dart';
import 'package:pretium/features/safari_tap/services/safari_tap_pay_flow.dart';
import 'package:pretium/utils/async_action_guard.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

class SendMoneyPage extends ConsumerStatefulWidget {
  final String? initialFromCurrency;

  const SendMoneyPage({super.key, this.initialFromCurrency});

  @override
  ConsumerState<SendMoneyPage> createState() => _SendMoneyPageState();
}

class _SendMoneyPageState extends ConsumerState<SendMoneyPage> {
  Future<void> _onFormContinue() async {
    final error =
        await ref.read(sendMoneyFlowProvider.notifier).continueFromForm();
    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: error.startsWith('Could not')
              ? null
              : Colors.red.shade700,
        ),
      );
    }
  }

  Future<void> _onReviewConfirm() async {
    final flow = ref.read(sendMoneyFlowProvider);
    await runGuardedAsync(
      this,
      isSubmitting: () => flow.isSubmitting,
      setSubmitting: (value) =>
          ref.read(sendMoneyFlowProvider.notifier).setSubmitting(value),
      action: () async {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please sign in to send money')),
          );
          return;
        }

        final details = ref.read(sendMoneyFlowProvider).details;
        final amount = details.amountToSend;
        if (amount <= 0) return;

        if (details.paymentMethod == PaymentMethod.truePay &&
            details.fromCurrency.toUpperCase() != 'KES') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('SafariTap wallet transfers require a KES wallet.'),
            ),
          );
          return;
        }

        if (details.paymentMethod == PaymentMethod.bank &&
            (amount < 100 || amount > 999999)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Bank transfers must be between KES 100 and 999,999',
              ),
            ),
          );
          return;
        }

        final clientRequestId = const Uuid().v4();
        final isWallet = details.paymentMethod == PaymentMethod.truePay;
        final notifier = ref.read(sendMoneyFlowProvider.notifier);
        final ok = await runSafariTapPayoutFlow(
          context: context,
          payoutBody: notifier.buildPayoutBody(clientRequestId),
          flowLabel: isWallet ? 'SafariTap wallet' : 'Send money',
          clientRequestId: clientRequestId,
        );
        if (ok && mounted) Navigator.of(context).pop();
      },
    );
  }

  Widget _buildCurrentStep(SendMoneyFlowState flow) {
    switch (flow.step) {
      case SendMoneyStep.form:
        return SendMoneyFormScreen(
          onContinue: _onFormContinue,
          onUpdate: ref.read(sendMoneyFlowProvider.notifier).updateDetails,
          initialDetails: flow.details,
          isValidating: flow.isValidating,
        );
      case SendMoneyStep.review:
        return ReviewDetailsScreen(
          onNext: _onReviewConfirm,
          details: flow.details,
          onEditTransferDetails:
              ref.read(sendMoneyFlowProvider.notifier).goToForm,
          onEditRecipientDetails:
              ref.read(sendMoneyFlowProvider.notifier).goToForm,
          isSubmitting: flow.isSubmitting,
          quote: flow.quote,
          isLoadingQuote: flow.isLoadingQuote,
          quoteError: flow.quoteError,
          onRetryQuote: flow.isLoadingQuote
              ? null
              : ref.read(sendMoneyFlowProvider.notifier).loadPayoutQuote,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final flow = ref.watch(sendMoneyFlowProvider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor:
            isDark ? Colors.transparent : primary.withValues(alpha: 0.08),
        elevation: 0,
        title: Text('Send Money', style: TextStyle(color: colors.textPrimary)),
        iconTheme: IconThemeData(color: colors.textPrimary),
        leading: flow.step == SendMoneyStep.review
            ? IconButton(
                icon: Icon(Icons.arrow_back, color: colors.textPrimary),
                onPressed: ref.read(sendMoneyFlowProvider.notifier).goToForm,
              )
            : null,
      ),
      body: _buildCurrentStep(flow),
    );
  }
}
