// Transactions feature - Transaction History screen.
// Clean architecture: presentation layer; data from TransactionsService.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pretium/core/constants/app_colors.dart';
import 'package:pretium/models/transaction_model.dart';
import 'package:pretium/features/transactions/providers/transactions_feed_provider.dart';
import 'package:pretium/features/transactions/screens/transaction_detail_page.dart';
import 'package:pretium/features/transactions/widgets/transaction_charts.dart';
import 'package:pretium/features/transactions/widgets/transaction_list_tile.dart';
import 'package:pretium/app/route_names.dart';
import 'package:pretium/widgets/app_shimmer.dart';

class TransactionsPage extends ConsumerStatefulWidget {
  const TransactionsPage({super.key});

  @override
  ConsumerState<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends ConsumerState<TransactionsPage> {

  Map<String, List<Transaction>> _groupByDate(List<Transaction> list) {
    final map = <String, List<Transaction>>{};
    for (final t in list) {
      final date = t.createdAt;
      final key = date != null
          ? '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}'
          : 'Unknown';
      map.putIfAbsent(key, () => []).add(t);
    }
    final sortedKeys = map.keys.toList()..sort((a, b) => b.compareTo(a));
    return Map.fromEntries(sortedKeys.map((k) => MapEntry(k, map[k]!)));
  }

  String _formatDateHeader(String isoDate) {
    final parts = isoDate.split('-');
    if (parts.length != 3) return isoDate;
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final y = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 1;
    final d = int.tryParse(parts[2]) ?? 1;
    if (m >= 1 && m <= 12) {
      return '${months[m - 1]} $d, $y';
    }
    return isoDate;
  }

  List<Widget> _buildGroupedListItems() {
    final feed = ref.read(transactionsFeedProvider);
    final response = feed.response;
    if (response == null) return [];
    final grouped = _groupByDate(response.transactions);
    final items = <Widget>[];
    for (final key in grouped.keys) {
      items.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Text(
            _formatDateHeader(key),
            style: TextStyle(
              color: AppColors.getThemeColors(context).textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      );
      for (final t in grouped[key]!) {
        items.add(
          TransactionListTile(
            transaction: t,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => TransactionDetailPage(transaction: t),
                ),
              );
            },
          ),
        );
      }
    }
    if (response.hasMore == true) {
      items.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: OutlinedButton(
            onPressed: feed.loadingMore
                ? null
                : () => ref.read(transactionsFeedProvider.notifier).loadMore(),
            child: feed.loadingMore
                ? const ShimmerBusyIndicator(onPrimary: false)
                : const Text('Load more'),
          ),
        ),
      );
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final primary = Theme.of(context).colorScheme.primary;
    final feed = ref.watch(transactionsFeedProvider);
    final feedN = ref.read(transactionsFeedProvider.notifier);

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
          'Transactions',
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {},
            color: colors.textPrimary,
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.of(context).pushNamed(RouteNames.walletSettings);
            },
            color: colors.textPrimary,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: feedN.load,
        color: primary,
        child: CustomScrollView(
          slivers: [
            // Charts overview (always from full transaction set)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Spending Overview',
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'Last 7 Days',
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TransactionWeeklyBarChart(transactions: feed.chartTransactions),
                    const SizedBox(height: 24),
                    Text(
                      'Income vs Expenses',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TransactionIncomeExpenseChart(
                      transactions: feed.chartTransactions,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Volume by currency',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TransactionCurrencyChart(transactions: feed.chartTransactions),
                    const SizedBox(height: 24),
                    Text(
                      'By status',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TransactionStatusDonutChart(
                      transactions: feed.chartTransactions,
                    ),
                  ],
                ),
              ),
            ),
            // Filter chips
            SliverToBoxAdapter(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'All',
                      icon: Icons.format_list_bulleted,
                      isSelected: feed.filter == 'all',
                      onTap: () => feedN.setFilter('all'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Income',
                      icon: Icons.check_circle_outline,
                      isSelected: feed.filter == 'income',
                      onTap: () => feedN.setFilter('income'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Expenses',
                      icon: Icons.trending_up,
                      isSelected: feed.filter == 'expenses',
                      onTap: () => feedN.setFilter('expenses'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Pending',
                      icon: Icons.schedule,
                      isSelected: feed.filter == 'pending',
                      onTap: () => feedN.setFilter('pending'),
                    ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
            // Recent Activity header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Recent Activity',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            if (feed.loading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 8, 20, 24),
                  child: TransactionListShimmer(itemCount: 8),
                ),
              )
            else if (feed.error != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Text(
                        'Failed to load transactions',
                        style: TextStyle(color: colors.error),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: feedN.load,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            else if (feed.response == null || feed.response!.transactions.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'No transactions yet',
                    style: TextStyle(color: colors.textSecondary),
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildListDelegate(_buildGroupedListItems()),
              )
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final colors = AppColors.getThemeColors(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? primary : colors.surface,
            borderRadius: BorderRadius.circular(20),
            border: isSelected ? null : Border.all(color: colors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? Colors.white : colors.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : colors.textSecondary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
