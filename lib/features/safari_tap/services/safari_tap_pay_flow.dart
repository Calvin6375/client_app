import 'package:flutter/material.dart';
import 'package:pretium/core/constants/app_colors.dart';
import 'package:pretium/features/safari_tap/screens/safari_tap_payout_processing_page.dart';
import 'package:pretium/features/safari_tap/services/safari_tap_pay_api_service.dart';
import 'package:pretium/features/safari_tap/utils/payout_error_messages.dart';
import 'package:pretium/services/wallet_balance_refresh.dart';
import 'package:uuid/uuid.dart';

/// Creates a payout and navigates to a processing page where status can be polled.
Future<bool> runSafariTapPayoutFlow({
  required BuildContext context,
  required Map<String, dynamic> payoutBody,
  required String flowLabel,
  String? clientRequestId,
  SafariTapPayApiService? api,
}) async {
  final service = api ?? SafariTapPayApiService();
  final requestId = clientRequestId ?? const Uuid().v4();
  final body = {...payoutBody, 'clientRequestId': requestId};
  final summary = SafariTapPayoutSummary.fromPayoutBody(body, flowLabel: flowLabel);

  if (!context.mounted) return false;

  try {
    final created = await service.createPayout(body);
    if (!context.mounted) return false;

    // Immediate SUCCESS (e.g. SAFARITAP_WALLET) — refresh before the status UI.
    if (created.isSuccess) {
      await WalletBalanceRefresh.afterSuccessfulTransaction();
    }
    if (!context.mounted) return created.isSuccess;

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SafariTapPayoutProcessingPage(
          clientRequestId: requestId,
          summary: summary,
          initialPayout: created,
          api: service,
        ),
      ),
    );
    if (result == true && !created.isSuccess) {
      await WalletBalanceRefresh.afterSuccessfulTransaction();
    }
    return result == true;
  } on SafariTapPayApiException catch (e) {
    if (context.mounted) {
      _showResultSnackBar(context, safariTapPayoutErrorMessage(e), success: false);
    }
    return false;
  }
}

void _showResultSnackBar(BuildContext context, String message, {required bool success}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: success ? AppColors.successGreen : AppColors.errorRed,
    ),
  );
}
