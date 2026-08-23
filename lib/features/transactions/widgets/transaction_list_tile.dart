import 'package:flutter/material.dart';
import 'package:pretium/core/constants/app_colors.dart';
import 'package:pretium/features/transactions/utils/transaction_display.dart';
import 'package:pretium/models/transaction_model.dart';

enum TransactionListTileStyle { compact, standard, card }

class TransactionListTile extends StatelessWidget {
  const TransactionListTile({
    super.key,
    required this.transaction,
    required this.onTap,
    this.style = TransactionListTileStyle.standard,
  });

  final Transaction transaction;
  final VoidCallback onTap;
  final TransactionListTileStyle style;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final primary = Theme.of(context).colorScheme.primary;

    switch (style) {
      case TransactionListTileStyle.compact:
        return _buildCompact(context, colors, primary);
      case TransactionListTileStyle.card:
        return _buildCard(context, colors, primary);
      case TransactionListTileStyle.standard:
        return _buildStandard(context, colors, primary);
    }
  }

  Widget _buildCompact(
    BuildContext context,
    AppThemeColors colors,
    Color primary,
  ) {
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: colors.infoLight,
        child: Icon(
          TransactionDisplay.iconFor(transaction),
          color: colors.primary,
        ),
      ),
      title: Text(
        transaction.displayTitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: colors.textPrimary),
      ),
      subtitle: Text(
        transaction.listSubtitle(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: colors.textSecondary),
      ),
      trailing: Text(
        transaction.formattedSignedAmount(),
        style: TextStyle(
          color: TransactionDisplay.amountColor(colors, transaction),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildStandard(
    BuildContext context,
    AppThemeColors colors,
    Color primary,
  ) {
    final status = transaction.statusDisplay;
    final dateStr = TransactionDisplay.formatListDate(transaction.createdAt);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: primary.withValues(alpha: 0.15),
                child: Icon(
                  TransactionDisplay.iconFor(transaction),
                  color: primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.displayTitle,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                      ),
                    ),
                    if (dateStr.isNotEmpty)
                      Text(
                        dateStr,
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    transaction.formattedSignedAmount(),
                    style: TextStyle(
                      color: TransactionDisplay.amountColor(colors, transaction),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: TransactionDisplay.statusBackground(colors, status),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        fontSize: 11,
                        color: TransactionDisplay.statusForeground(colors, status),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard(
    BuildContext context,
    AppThemeColors colors,
    Color primary,
  ) {
    final status = transaction.statusDisplay;
    final dateStr =
        TransactionDisplay.formatListDateShort(transaction.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: primary.withValues(alpha: 0.12),
                  radius: 24,
                  child: Icon(
                    TransactionDisplay.iconFor(transaction),
                    color: primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transaction.displayTitle,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      if (dateStr.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          dateStr,
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        status,
                        style: TextStyle(
                          color: colors.textTertiary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  transaction.formattedSignedAmount(),
                  style: TextStyle(
                    color: TransactionDisplay.amountColor(colors, transaction),
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
