// Transactions feature - Transaction History screen.
// Clean architecture: presentation layer; data from TransactionsService.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pretium/core/constants/app_colors.dart';
import 'package:pretium/models/transaction_model.dart';
import 'package:pretium/services/transactions_service.dart';
import 'package:pretium/features/transactions/screens/transaction_detail_page.dart';
import 'package:pretium/features/transactions/widgets/transaction_charts.dart';
import 'package:pretium/features/transactions/widgets/transaction_list_tile.dart';
import 'package:pretium/app/route_names.dart';

class TransactionsPage extends StatefulWidget {
  const TransactionsPage({super.key});

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  final TransactionsService _transactionsService = TransactionsService();
  TransactionsResponse? _response;
  List<Transaction> _chartTransactions = const [];
  bool _isLoading = true;
  bool _loadingMore = false;
  String? _error;
  String _filter = 'all'; // 'all' | 'income' | 'expenses' | 'pending'

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<TransactionsResponse> _fetchFilteredTransactions({
    int limit = 50,
    String? startAfter,
  }) {
    switch (_filter) {
      case 'income':
        return _transactionsService.getCreditTransactions(
          limit: limit,
          startAfter: startAfter,
        );
      case 'expenses':
        return _transactionsService.getDebitTransactions(
          limit: limit,
          startAfter: startAfter,
        );
      case 'pending':
        return _transactionsService.getPendingTransactions(
          limit: limit,
          startAfter: startAfter,
        );
      default:
        return _transactionsService.getTransactions(
          limit: limit,
          startAfter: startAfter,
        );
    }
  }

  Future<void> _loadTransactions() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _isLoading = false;
        _response = TransactionsResponse(transactions: []);
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final chartRes = await _transactionsService.getTransactions(limit: 50);
      final res = await _fetchFilteredTransactions(limit: 50);
      if (mounted) {
        setState(() {
          _chartTransactions = chartRes.transactions;
          _response = res;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMoreTransactions() async {
    final current = _response;
    if (_loadingMore || current == null || !current.hasMore) return;
    final startAfter = current.nextPageToken;
    if (startAfter == null || startAfter.isEmpty) return;

    setState(() => _loadingMore = true);
    try {
      final nextPage = await _fetchFilteredTransactions(
        limit: 50,
        startAfter: startAfter,
      );
      if (!mounted) return;
      setState(() {
        _response = TransactionsResponse(
          transactions: [...current.transactions, ...nextPage.transactions],
          nextPageToken: nextPage.nextPageToken,
          totalCount: nextPage.totalCount,
          hasMore: nextPage.hasMore,
          sources: nextPage.sources,
        );
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

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
    if (_response == null) return [];
    final grouped = _groupByDate(_response!.transactions);
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
    if (_response?.hasMore == true) {
      items.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: OutlinedButton(
            onPressed: _loadingMore ? null : _loadMoreTransactions,
            child: _loadingMore
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
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
        onRefresh: _loadTransactions,
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
                    TransactionWeeklyBarChart(transactions: _chartTransactions),
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
                      transactions: _chartTransactions,
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
                    TransactionCurrencyChart(transactions: _chartTransactions),
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
                      transactions: _chartTransactions,
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
                      isSelected: _filter == 'all',
                      onTap: () {
                        setState(() => _filter = 'all');
                        _loadTransactions();
                      },
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Income',
                      icon: Icons.check_circle_outline,
                      isSelected: _filter == 'income',
                      onTap: () {
                        setState(() => _filter = 'income');
                        _loadTransactions();
                      },
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Expenses',
                      icon: Icons.trending_up,
                      isSelected: _filter == 'expenses',
                      onTap: () {
                        setState(() => _filter = 'expenses');
                        _loadTransactions();
                      },
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Pending',
                      icon: Icons.schedule,
                      isSelected: _filter == 'pending',
                      onTap: () {
                        setState(() => _filter = 'pending');
                        _loadTransactions();
                      },
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
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
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
                        onPressed: _loadTransactions,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            else if (_response == null || _response!.transactions.isEmpty)
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
