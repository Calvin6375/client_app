import 'package:flutter/material.dart';
import 'package:pretium/core/constants/app_colors.dart';
import 'package:pretium/models/transaction_model.dart';

/// Icons and formatting helpers for transaction history UI.
class TransactionDisplay {
  TransactionDisplay._();

  static IconData iconFor(Transaction transaction) {
    final slug = (transaction.reconType ?? transaction.type ?? transaction.displayTitle)
        .toLowerCase();

    if (slug.contains('merchant') || slug.contains('payment')) {
      return Icons.storefront_rounded;
    }
    if (slug.contains('funding') ||
        slug.contains('topup') ||
        slug.contains('top_up') ||
        slug.contains('direct_topup') ||
        slug.contains('deposit')) {
      return Icons.account_balance_wallet_outlined;
    }
    if (slug.contains('withdraw') ||
        slug.contains('payout') ||
        slug.contains('send')) {
      return Icons.call_made_rounded;
    }
    if (slug.contains('receive') || slug.contains('credit')) {
      return Icons.call_received_rounded;
    }
    if (slug.contains('swap')) return Icons.swap_horiz_rounded;
    if (slug.contains('refund')) return Icons.reply_rounded;

    return transaction.isDebit
        ? Icons.call_made_rounded
        : Icons.call_received_rounded;
  }

  static String formatListDate(DateTime? date) {
    if (date == null) return '';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final local = date.toLocal();
    return '${months[local.month - 1]} ${local.day}, ${local.year} · '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  static String formatListDateShort(DateTime? date) {
    if (date == null) return '';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final local = date.toLocal();
    final h = local.hour == 0
        ? 12
        : (local.hour > 12 ? local.hour - 12 : local.hour);
    final amPm = local.hour >= 12 ? 'PM' : 'AM';
    return '${months[local.month - 1]} ${local.day}, ${local.year} · '
        '$h:${local.minute.toString().padLeft(2, '0')} $amPm';
  }

  static Color amountColor(AppThemeColors colors, Transaction transaction) {
    return transaction.isDebit ? colors.error : colors.success;
  }

  static Color statusBackground(AppThemeColors colors, String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'success':
        return colors.successLight;
      case 'pending':
      case 'processing':
      case 'queued':
      case 'in_progress':
        return colors.warningLight;
      default:
        return colors.errorLight;
    }
  }

  static Color statusForeground(AppThemeColors colors, String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'success':
        return colors.success;
      case 'pending':
      case 'processing':
      case 'queued':
      case 'in_progress':
        return colors.warning;
      default:
        return colors.error;
    }
  }
}
