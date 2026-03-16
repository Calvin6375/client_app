// Transactions feature - Transaction History screen.
// Clean architecture: presentation layer; data from TransactionsService.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pretium/core/constants/app_colors.dart';
import 'package:pretium/models/transaction_model.dart';
import 'package:pretium/services/transactions_service.dart';
import 'package:pretium/features/transactions/screens/transaction_detail_page.dart';
import 'package:pretium/app/route_names.dart';

class TransactionsPage extends StatefulWidget {
  const TransactionsPage({super.key});

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  final TransactionsService _transactionsService = TransactionsService();
  TransactionsResponse? _response;
  bool _isLoading = true;
  String? _error;
  String _filter = 'all'; // 'all' | 'income' | 'expenses' | 'pending'

  @override
  void initState() {
    super.initState();
    _loadTransactions();
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
      TransactionsResponse res;
      switch (_filter) {
        case 'income':
          res = await _transactionsService.getCreditTransactions(limit: 50);
          break;
        case 'expenses':
          res = await _transactionsService.getDebitTransactions(limit: 50);
          break;
        case 'pending':
          res = await _transactionsService.getPendingTransactions(limit: 50);
          break;
        default:
          res = await _transactionsService.getTransactions(limit: 50);
      }
      if (mounted) {
        setState(() {
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
          _TransactionTile(
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
            // Spending Overview
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
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
                    _SpendingChart(transactions: _response?.transactions ?? []),
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

class _SpendingChart extends StatelessWidget {
  final List<Transaction> transactions;

  const _SpendingChart({required this.transactions});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final colors = AppColors.getThemeColors(context);
    final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final now = DateTime.now();
    final amounts = List<double>.filled(7, 0);
    for (var i = 0; i < 7; i++) {
      final d = now.subtract(Duration(days: 6 - i));
      final dayStart = DateTime(d.year, d.month, d.day);
      final dayEnd = dayStart.add(const Duration(days: 1));
      for (final t in transactions) {
        if (t.createdAt != null && t.isDebit) {
          if (!t.createdAt!.isBefore(dayStart) && t.createdAt!.isBefore(dayEnd)) {
            amounts[i] += t.amount;
          }
        }
      }
    }
    final maxVal = amounts.reduce((a, b) => a > b ? a : b);
    final maxHeight = 80.0;

    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(7, (i) {
          final h = maxVal > 0 ? (amounts[i] / maxVal) * maxHeight : 0.0;
          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                width: 24,
                height: h.clamp(4.0, maxHeight),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                days[i],
                style: TextStyle(
                  fontSize: 12,
                  color: colors.textSecondary,
                ),
              ),
            ],
          );
        }),
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

class _TransactionTile extends StatelessWidget {
  final Transaction transaction;
  final VoidCallback onTap;

  const _TransactionTile({
    required this.transaction,
    required this.onTap,
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
        ? '${_month(date.month)} ${date.day}, ${date.year} • ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}'
        : '';
    final amount = transaction.amount;
    final currency = transaction.currency ?? 'USD';
    final isDebit = transaction.isDebit;
    final status = transaction.status ?? 'Completed';

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
                child: Icon(_iconFor(title), color: primary, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
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
                    '${isDebit ? '-' : '+'}${amount.toStringAsFixed(2)} $currency',
                    style: TextStyle(
                      color: isDebit ? colors.error : colors.success,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: status == 'Completed'
                          ? colors.successLight
                          : status == 'Pending'
                              ? colors.warningLight
                              : colors.errorLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        fontSize: 11,
                        color: status == 'Completed'
                            ? colors.success
                            : status == 'Pending'
                                ? colors.warning
                                : colors.error,
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

  static String _month(int m) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[m - 1];
  }
}
