import 'package:flutter/material.dart';
import 'package:pretium/core/constants/app_colors.dart';
import 'package:pretium/features/safari_tap/models/safari_tap_payout_quote.dart';
import 'package:pretium/models/transaction_details_model.dart';
import 'package:pretium/widgets/app_shimmer.dart';
import 'package:pretium/widgets/bottom_safe_action_bar.dart';

class ReviewDetailsScreen extends StatelessWidget {
  final VoidCallback onNext;
  final TransactionDetails details;
  final VoidCallback? onEditTransferDetails;
  final VoidCallback? onEditRecipientDetails;
  final bool isSubmitting;
  final SafariTapPayoutQuote? quote;
  final bool isLoadingQuote;
  final String? quoteError;
  final VoidCallback? onRetryQuote;

  const ReviewDetailsScreen({
    super.key,
    required this.onNext,
    required this.details,
    this.onEditTransferDetails,
    this.onEditRecipientDetails,
    this.isSubmitting = false,
    this.quote,
    this.isLoadingQuote = false,
    this.quoteError,
    this.onRetryQuote,
  });

  bool get _canSend =>
      !isSubmitting && !isLoadingQuote && quoteError == null && quote != null;

  String get _fallbackAmount =>
      '${details.amountToSend.toStringAsFixed(2)} ${details.fromCurrency}';

  String get _youSend => quote?.youSend ?? _fallbackAmount;

  String get _artoFees => quote?.artoFees ?? '—';

  String get _paymentMethodFees => quote?.paymentMethodFees ?? '—';

  String get _youWillPay => quote?.youWillPay ?? _fallbackAmount;

  String get _recipientAmount =>
      '${details.amountToReceive.toStringAsFixed(2)} ${details.toCurrency}';

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Review your detail transfer',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 24),
                if (quoteError != null) ...[
                  _QuoteErrorBanner(
                    message: quoteError!,
                    onRetry: onRetryQuote,
                  ),
                  const SizedBox(height: 16),
                ],
                Expanded(
                  child: ListView(
                    children: [
                      _buildDetailsCard(
                        context,
                        title: 'Transfer details',
                        onEdit: onEditTransferDetails,
                        children: [
                          _DetailRow(
                            label: 'You send',
                            value: _youSend,
                            loading: isLoadingQuote,
                          ),
                          _DetailRow(
                            label: 'Fees',
                            value: isLoadingQuote ? '—' : _artoFees,
                            loading: isLoadingQuote,
                          ),
                          _DetailRow(
                            label: 'Payment method fees',
                            value: isLoadingQuote ? '—' : _paymentMethodFees,
                            loading: isLoadingQuote,
                          ),
                          _DetailRow(
                            label: 'You will pay',
                            value: _youWillPay,
                            isBold: true,
                            loading: isLoadingQuote,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _buildDetailsCard(
                        context,
                        title: 'Recipient details',
                        onEdit: onEditRecipientDetails,
                        children: [
                          _buildRecipientTile(
                            context,
                            details.recipientFullName,
                            details.recipientPhoneNumber.trim().isNotEmpty
                                ? details.recipientPhoneNumber
                                : (details.hasSafariTapUserId
                                    ? 'SafariTap wallet'
                                    : details.recipientPhoneNumber),
                            _recipientAmount,
                          ),
                          if (details.verifiedBeneficiaryName
                              .trim()
                              .isNotEmpty) ...[
                            const SizedBox(height: 12),
                            _DetailRow(
                              label: 'Verified name',
                              value: details.verifiedBeneficiaryName.trim(),
                            ),
                          ],
                          if (details.recipientBankName?.trim().isNotEmpty ==
                              true) ...[
                            const SizedBox(height: 12),
                            _DetailRow(
                              label: 'Bank',
                              value: details.recipientBankName!.trim(),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        BottomSafeActionBar(
          child: ElevatedButton(
            onPressed: _canSend ? onNext : null,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              minimumSize: const Size(double.infinity, 50),
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: isDark ? colors.onPrimary : Colors.white,
              disabledBackgroundColor: colors.textTertiary,
            ),
            child: isSubmitting
                ? const ShimmerBusyIndicator(onPrimary: true)
                : Text(
                    'Send',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? colors.onPrimary : Colors.white,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailsCard(
    BuildContext context, {
    required String title,
    VoidCallback? onEdit,
    required List<Widget> children,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = AppColors.getThemeColors(context);
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: isDark
            ? colors.surface
            : Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        border: isDark
            ? null
            : Border.all(
                color: const Color(0xFFE5E7EB),
                width: 1,
              ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),
              TextButton.icon(
                onPressed: onEdit,
                icon: Icon(
                  Icons.edit,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                label: Text(
                  'Edit',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          Divider(
            height: 24,
            color: isDark ? colors.surfaceVariant : const Color(0xFFE5E7EB),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildRecipientTile(
    BuildContext context,
    String name,
    String email,
    String amount,
  ) {
    final colors = AppColors.getThemeColors(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor:
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            child: Text(
              'R',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
                Text(
                  email,
                  style: TextStyle(color: colors.textSecondary),
                ),
              ],
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuoteErrorBanner extends StatelessWidget {
  const _QuoteErrorBanner({
    required this.message,
    this.onRetry,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.error.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: colors.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 13,
              ),
            ),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              child: Text(
                'Retry',
                style: TextStyle(
                  color: primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;
  final bool loading;

  const _DetailRow({
    required this.label,
    required this.value,
    this.isBold = false,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isBold ? colors.textPrimary : colors.textSecondary,
            ),
          ),
          if (loading)
            const AppShimmer(child: ShimmerBox(width: 88, height: 14))
          else
            Text(
              value,
              style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: colors.textPrimary,
              ),
            ),
        ],
      ),
    );
  }
}
