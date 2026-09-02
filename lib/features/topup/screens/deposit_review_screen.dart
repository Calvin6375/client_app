import 'package:flutter/material.dart';
import 'package:pretium/core/constants/app_colors.dart';
import 'package:pretium/features/topup/models/topup_quote.dart';
import 'package:pretium/widgets/app_shimmer.dart';
import 'package:pretium/widgets/bottom_safe_action_bar.dart';

/// Review step before hosted checkout — mirrors Send Money's review layout.
///
/// Fee rows are bound from `POST /funding/topup/quote`.
class DepositReviewScreen extends StatelessWidget {
  const DepositReviewScreen({
    super.key,
    required this.paymentMethodTitle,
    required this.paymentMethodSubtitle,
    required this.onConfirm,
    this.quote,
    this.isLoadingQuote = false,
    this.quoteError,
    this.onRetryQuote,
    this.onEditDepositDetails,
    this.onEditPaymentMethod,
    this.isSubmitting = false,
    this.fallbackAmountLabel,
  });

  final TopupQuote? quote;
  final bool isLoadingQuote;
  final String? quoteError;
  final VoidCallback? onRetryQuote;
  final String paymentMethodTitle;
  final String paymentMethodSubtitle;
  final VoidCallback onConfirm;
  final VoidCallback? onEditDepositDetails;
  final VoidCallback? onEditPaymentMethod;
  final bool isSubmitting;

  /// Shown while quote is loading / as fallback before the API responds.
  final String? fallbackAmountLabel;

  bool get _canConfirm =>
      !isSubmitting && !isLoadingQuote && quoteError == null && quote != null;

  String get _youDeposit =>
      quote?.youDeposit ?? fallbackAmountLabel ?? '—';

  String get _processingFees => quote?.processingFees ?? '—';

  String get _paymentMethodFees => quote?.paymentMethodFees ?? '—';

  String get _youWillPay =>
      quote?.youWillPay ?? fallbackAmountLabel ?? '—';

  String get _methodAmount => _youWillPay == '—' ? _youDeposit : _youWillPay;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

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
                  'Review your deposit',
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
                        title: 'Deposit details',
                        onEdit: onEditDepositDetails,
                        children: [
                          _DetailRow(
                            label: 'You deposit',
                            value: _youDeposit,
                            loading: isLoadingQuote,
                          ),
                          _DetailRow(
                            label: 'Processing fees',
                            value: isLoadingQuote ? '—' : _processingFees,
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
                        title: 'Payment method',
                        onEdit: onEditPaymentMethod,
                        children: [
                          _buildMethodTile(
                            context,
                            title: paymentMethodTitle,
                            subtitle: paymentMethodSubtitle,
                            amount: _methodAmount,
                            loading: isLoadingQuote,
                          ),
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
            onPressed: _canConfirm ? onConfirm : null,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              minimumSize: const Size(double.infinity, 50),
              backgroundColor: primary,
              foregroundColor: isDark ? colors.onPrimary : Colors.white,
              disabledBackgroundColor: colors.textTertiary,
            ),
            child: isSubmitting
                ? const ShimmerBusyIndicator(onPrimary: true)
                : Text(
                    'Confirm & Pay',
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
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(16),
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
                icon: Icon(Icons.edit, size: 16, color: primary),
                label: Text(
                  'Edit',
                  style: TextStyle(color: primary),
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

  Widget _buildMethodTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String amount,
    required bool loading,
  }) {
    final colors = AppColors.getThemeColors(context);
    final primary = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: primary.withValues(alpha: 0.1),
            child: Icon(
              Icons.account_balance_wallet_outlined,
              color: primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
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
          const SizedBox(width: 8),
          if (loading)
            const AppShimmer(child: ShimmerBox(width: 72, height: 14))
          else
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
  const _DetailRow({
    required this.label,
    required this.value,
    this.isBold = false,
    this.loading = false,
  });

  final String label;
  final String value;
  final bool isBold;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
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
