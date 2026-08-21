import 'package:flutter/material.dart';
import 'package:pretium/core/constants/app_colors.dart';
import 'package:pretium/features/safari_card/services/safari_card_pay_api_service.dart';
import 'package:pretium/features/safari_card/utils/payout_error_messages.dart';
import 'package:uuid/uuid.dart';

/// Creates a payout, polls until terminal, and shows processing UI.
Future<bool> runSafariCardPayoutFlow({
  required BuildContext context,
  required Map<String, dynamic> payoutBody,
  String? clientRequestId,
  SafariCardPayApiService? api,
}) async {
  final service = api ?? SafariCardPayApiService();
  final requestId = clientRequestId ?? const Uuid().v4();
  final body = {...payoutBody, 'clientRequestId': requestId};

  if (!context.mounted) return false;

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _PayoutProcessingDialog(),
  );

  try {
    final created = await service.createPayout(body);
    final finalPayout = created.isTerminal
        ? created
        : await service.pollPayoutUntilTerminal(created.payoutId);

    if (!context.mounted) return false;
    Navigator.of(context, rootNavigator: true).pop();

    if (finalPayout.isSuccess) {
      _showResultSnackBar(
        context,
        'Payment successful: ${finalPayout.amount.toStringAsFixed(0)} ${finalPayout.currency}',
        success: true,
      );
      return true;
    }

    final reason = finalPayout.failureReason?.trim();
    _showResultSnackBar(
      context,
      reason?.isNotEmpty == true
          ? reason!
          : 'Payment ${finalPayout.status.toLowerCase()}',
      success: false,
    );
    return false;
  } on SafariCardPayApiException catch (e) {
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      _showResultSnackBar(context, safariCardPayoutErrorMessage(e), success: false);
    }
    return false;
  } catch (_) {
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      _showResultSnackBar(
        context,
        'Payment is still processing or could not be confirmed. Check your history.',
        success: false,
      );
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

class _PayoutProcessingDialog extends StatelessWidget {
  const _PayoutProcessingDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Processing payment…',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'This usually takes a few seconds.',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
