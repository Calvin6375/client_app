import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pretium/core/constants/app_colors.dart';
import 'package:pretium/core/providers/auth_providers.dart';
import 'package:pretium/core/providers/recent_transactions_provider.dart';
import 'package:pretium/features/transactions/screens/transaction_detail_page.dart';
import 'package:pretium/features/transactions/widgets/transaction_list_tile.dart';
import 'package:pretium/widgets/app_shimmer.dart';

class PlaceholderTransactions extends ConsumerWidget {
  const PlaceholderTransactions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) {
      return const TransactionListShimmer(itemCount: 3);
    }

    final asyncTx = ref.watch(recentTransactionsProvider);
    if (asyncTx.isLoading && !asyncTx.hasValue) {
      return const TransactionListShimmer(itemCount: 3);
    }

    if (asyncTx.hasError && !asyncTx.hasValue) {
      return _ErrorTransactions(
        error: asyncTx.error.toString(),
        onRetry: () => ref.read(recentTransactionsProvider.notifier).refresh(),
      );
    }

    final response = asyncTx.valueOrNull;
    if (response == null || response.transactions.isEmpty) {
      return const _EmptyTransactions();
    }

    return Column(
      children: response.transactions.map((transaction) {
        return TransactionListTile(
          transaction: transaction,
          style: TransactionListTileStyle.compact,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) =>
                    TransactionDetailPage(transaction: transaction),
              ),
            );
          },
        );
      }).toList(),
    );
  }
}

class _EmptyTransactions extends StatelessWidget {
  const _EmptyTransactions();
  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        'No recent transactions',
        style: TextStyle(color: colors.textSecondary),
      ),
    );
  }
}

class _ErrorTransactions extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorTransactions({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Column(
        children: [
          Text(
            'Failed to load transactions',
            style: TextStyle(color: colors.error),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
