import 'package:flutter/material.dart';
import 'package:pretium/models/transaction_details_model.dart';
import 'package:pretium/core/constants/app_colors.dart';

class ReviewDetailsScreen extends StatelessWidget {
  final VoidCallback onNext;
  final TransactionDetails details;
  const ReviewDetailsScreen({super.key, required this.onNext, required this.details});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Review your detail transfer',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: colors.textPrimary, // Theme-aware text
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView(
              children: [
                _buildDetailsCard(
                  context,
                  title: 'Transfer details',
                  children: [
                    _DetailRow(label: 'You send', value: '${details.amountToSend.toStringAsFixed(2)} ${details.fromCurrency}'),
                    const _DetailRow(label: 'Arto+ fees', value: 'Free'),
                    const _DetailRow(label: 'Payment method fees', value: 'Free'),
                    _DetailRow(label: 'You will pay', value: '${details.amountToSend.toStringAsFixed(2)} ${details.fromCurrency}', isBold: true),
                  ],
                ),
                const SizedBox(height: 24),
                _buildDetailsCard(
                  context,
                  title: 'Recipient details',
                  children: [
                    _buildRecipientTile(
                      context,
                      details.recipientFullName,
                      details.recipientPhoneNumber,
                      '${details.amountToReceive.toStringAsFixed(2)} ${details.toCurrency}',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: onNext,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              minimumSize: const Size(double.infinity, 50),
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: isDark ? colors.onPrimary : Colors.white,
            ),
            child: Text(
              'Continue',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? colors.onPrimary : Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsCard(BuildContext context, {required String title, required List<Widget> children}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = AppColors.getThemeColors(context);
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: isDark 
            ? colors.surface // Dark slate for dark mode
            : Colors.white.withOpacity(0.9), // Translucent white for light mode
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
                  onPressed: () {},
                  icon: Icon(Icons.edit, size: 16, color: Theme.of(context).colorScheme.primary),
                  label: Text(
                    'Edit',
                    style: TextStyle(color: Theme.of(context).colorScheme.primary),
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

  Widget _buildRecipientTile(BuildContext context, String name, String email, String amount) {
    final colors = AppColors.getThemeColors(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
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

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;

  const _DetailRow({
    required this.label,
    required this.value,
    this.isBold = false,
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
