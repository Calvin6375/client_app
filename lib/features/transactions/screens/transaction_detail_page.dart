// Transaction Details screen - shows full info for a single transaction.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pretium/core/constants/app_colors.dart';
import 'package:pretium/models/transaction_model.dart';

class TransactionDetailPage extends StatelessWidget {
  final Transaction transaction;

  const TransactionDetailPage({
    super.key,
    required this.transaction,
  });

  IconData _iconFor(String? title) {
    final t = (title ?? '').toLowerCase();
    if (t.contains('apple')) return Icons.computer;
    if (t.contains('salary') || t.contains('deposit')) return Icons.work;
    if (t.contains('coffee') || t.contains('starbucks')) return Icons.coffee;
    if (t.contains('netflix')) return Icons.play_circle_filled;
    if (t.contains('uber') || t.contains('trip')) return Icons.directions_car;
    if (t.contains('amazon')) return Icons.shopping_bag;
    if (t.contains('refund')) return Icons.reply;
    if (t.contains('electric') || t.contains('bill')) return Icons.bolt;
    return Icons.receipt;
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final primary = Theme.of(context).colorScheme.primary;
    final title = transaction.title ?? (transaction.isDebit ? 'Sent' : 'Received');
    final date = transaction.createdAt;
    final dateStr = date != null
        ? '${_month(date.month)} ${date.day}, ${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}'
        : '—';
    final amount = transaction.amount;
    final currency = transaction.currency ?? 'USD';
    final isDebit = transaction.isDebit;
    final status = transaction.status ?? 'Completed';
    final paymentMethod = transaction.metadata?['paymentMethod'] as String? ??
        transaction.metadata?['payment_method'] as String? ??
        '—';
    final txId = transaction.id;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
          color: colors.textPrimary,
        ),
        title: Text(
          'Transaction Details',
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {},
            color: colors.textPrimary,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Main card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.border.withOpacity(0.5)),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: primary.withOpacity(0.15),
                    child: Icon(_iconFor(title), color: primary, size: 32),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dateStr,
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '${isDebit ? '-' : '+'} ${amount.toStringAsFixed(2)} $currency',
                    style: TextStyle(
                      color: isDebit ? colors.error : colors.success,
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _StatusChip(status: status),
                  const SizedBox(height: 24),
                  _DetailRow(label: 'Amount', value: '${amount.toStringAsFixed(2)} $currency'),
                  const SizedBox(height: 12),
                  _DetailRow(
                    label: 'Status',
                    value: status,
                    trailing: status == 'Completed'
                        ? Icon(Icons.check_circle, color: colors.success, size: 20)
                        : null,
                  ),
                  const SizedBox(height: 12),
                  _DetailRow(label: 'Payment Method', value: paymentMethod),
                  const SizedBox(height: 12),
                  _DetailRow(
                    label: 'Transaction ID',
                    value: txId,
                    trailing: IconButton(
                      icon: const Icon(Icons.copy, size: 20),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: txId));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Transaction ID copied')),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.download, size: 20),
                    label: const Text('Download Receipt'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      foregroundColor: colors.textPrimary,
                      side: BorderSide(color: colors.border),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Report Issue'),
                          content: const Text(
                            'Describe the issue with this transaction and we\'ll look into it.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              child: const Text('Submit'),
                            ),
                          ],
                        ),
                      );
                    },
                    icon: const Icon(Icons.flag, size: 20),
                    label: const Text('Report Issue'),
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.error,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _month(int m) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[m - 1];
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final isCompleted = status == 'Completed';
    final isPending = status == 'Pending';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isCompleted
            ? colors.successLight
            : isPending
                ? colors.warningLight
                : colors.errorLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isCompleted ? Icons.check_circle : Icons.schedule,
            size: 16,
            color: isCompleted ? colors.success : isPending ? colors.warning : colors.error,
          ),
          const SizedBox(width: 6),
          Text(
            status,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isCompleted ? colors.success : isPending ? colors.warning : colors.error,
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
  final Widget? trailing;

  const _DetailRow({
    required this.label,
    required this.value,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 14,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
