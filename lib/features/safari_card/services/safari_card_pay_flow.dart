import 'package:flutter/material.dart';
import 'package:pretium/core/constants/app_colors.dart';
import 'package:pretium/features/safari_card/screens/safari_card_payout_processing_page.dart';
import 'package:pretium/features/safari_card/services/safari_card_pay_api_service.dart';
import 'package:pretium/features/safari_card/utils/payout_error_messages.dart';
import 'package:uuid/uuid.dart';

/// Creates a payout and navigates to a processing page where status can be polled.
Future<bool> runSafariCardPayoutFlow({
  required BuildContext context,
  required Map<String, dynamic> payoutBody,
  required String flowLabel,
  String? clientRequestId,
  SafariCardPayApiService? api,
}) async {
  final service = api ?? SafariCardPayApiService();
  final requestId = clientRequestId ?? const Uuid().v4();
  final body = {...payoutBody, 'clientRequestId': requestId};
  final summary = SafariCardPayoutSummary.fromPayoutBody(body, flowLabel: flowLabel);

  if (!context.mounted) return false;

  try {
    final created = await service.createPayout(body);
    if (!context.mounted) return false;

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SafariCardPayoutProcessingPage(
          clientRequestId: requestId,
          summary: summary,
          initialPayout: created,
          api: service,
        ),
      ),
    );
    return result == true;
  } on SafariCardPayApiException catch (e) {
    if (context.mounted) {
      _showResultSnackBar(context, safariCardPayoutErrorMessage(e), success: false);
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
