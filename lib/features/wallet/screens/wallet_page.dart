// Wallet page - balance, Fiat/Crypto toggle, Spending Activity, Recent Transactions, FAB.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pretium/core/constants/app_colors.dart';
import 'package:pretium/app/route_names.dart';
import 'package:pretium/models/transaction_model.dart';
import 'package:pretium/services/transactions_service.dart';
import 'package:pretium/features/transactions/screens/transaction_detail_page.dart';
import 'package:pretium/features/send_money/screens/send_money_page.dart';
import '/widgets/wallet_card.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  int _selectedTab = 0; // 0 = Fiat, 1 = Crypto
  final GlobalKey<State<WalletCard>> _walletCardKey = GlobalKey<State<WalletCard>>();
  final TransactionsService _transactionsService = TransactionsService();
  TransactionsResponse? _transactionsResponse;
  bool _transactionsLoading = true;
  String? _transactionsError;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _transactionsLoading = false);
      return;
    }
    setState(() {
      _transactionsLoading = true;
      _transactionsError = null;
    });
    try {
      final response = await _transactionsService.getTransactions(limit: 10);
      if (mounted) {
        setState(() {
          _transactionsResponse = response;
          _transactionsLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _transactionsError = e.toString();
          _transactionsLoading = false;
        });
      }
    }
  }

  Future<void> _handleRefresh() async {
    final state = _walletCardKey.currentState;
    if (state != null) {
      try {
        await (state as dynamic).refreshBalance(forceRefresh: true);
      } catch (_) {}
    }
    await _loadTransactions();
    await Future.delayed(const Duration(milliseconds: 300));
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
          'Wallet',
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              showModalBottomSheet<void>(
                context: context,
                builder: (context) => SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.settings_outlined),
                        title: const Text('Wallet Settings'),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, RouteNames.walletSettings);
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.notifications_outlined),
                        title: const Text('Notifications'),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, RouteNames.notifications);
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
            color: colors.textPrimary,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        color: primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              // Fiat / Crypto toggle
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.surfaceDark
                      : Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(16),
                  border: Theme.of(context).brightness == Brightness.light
                      ? Border.all(color: const Color(0xFFE5E7EB), width: 1)
                      : null,
                  boxShadow: Theme.of(context).brightness == Brightness.light
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildPillTab('Fiat Wallet', 0),
                    const SizedBox(width: 4),
                    _buildPillTab('Crypto Wallet', 1),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              WalletCard(
                key: _walletCardKey,
                selectedTab: _selectedTab,
              ),
              const SizedBox(height: 24),
              // Spending Activity
              _SpendingActivityCard(
                transactions: _transactionsResponse?.transactions ?? [],
              ),
              const SizedBox(height: 24),
              // Recent Transactions header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent Transactions',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pushNamed(context, RouteNames.transactions),
                    child: Text(
                      'See All',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _RecentTransactionsList(
                response: _transactionsResponse,
                loading: _transactionsLoading,
                error: _transactionsError,
                onRetry: _loadTransactions,
                onTapTransaction: (t) {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (context) => TransactionDetailPage(transaction: t),
                    ),
                  );
                },
              ),
              const SizedBox(height: 80), // Space for FAB
            ],
          ),
        ),
      ),
      floatingActionButton: Container(
        margin: const EdgeInsets.only(right: 20, bottom: 24),
        child: FloatingActionButton.extended(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (context) => const SendMoneyPage(initialFromCurrency: 'USD'),
              ),
            );
          },
          backgroundColor: primary,
          icon: const Icon(Icons.add, color: Colors.white, size: 24),
          label: Text(
            'New Transaction',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPillTab(String label, int index) {
    final primary = Theme.of(context).colorScheme.primary;
    final colors = AppColors.getThemeColors(context);
    final isSelected = _selectedTab == index;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? primary : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected
                  ? (Theme.of(context).brightness == Brightness.dark
                      ? AppColors.backgroundDeepNavy
                      : Colors.white)
                  : colors.textSecondary,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

/// Spending Activity card with bar chart for the week.
class _SpendingActivityCard extends StatelessWidget {
  final List<Transaction> transactions;

  const _SpendingActivityCard({required this.transactions});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final primary = Theme.of(context).colorScheme.primary;
    const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
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
    final maxVal = amounts.fold<double>(0, (a, b) => a > b ? a : b);
    const maxHeight = 80.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
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
                'Spending Activity',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              Text(
                'This Week',
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 100,
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
                        color: primary.withValues(alpha: 0.85),
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
          ),
        ],
      ),
    );
  }
}

/// Recent transactions as rounded cards.
class _RecentTransactionsList extends StatelessWidget {
  final TransactionsResponse? response;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;
  final void Function(Transaction) onTapTransaction;

  const _RecentTransactionsList({
    required this.response,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.onTapTransaction,
  });

  static IconData _iconFor(String? title) {
    final t = (title ?? '').toLowerCase();
    if (t.contains('apple')) return Icons.shopping_bag;
    if (t.contains('salary') || t.contains('deposit')) return Icons.account_balance_wallet;
    if (t.contains('coffee') || t.contains('starbucks')) return Icons.restaurant;
    if (t.contains('netflix')) return Icons.play_circle_filled;
    if (t.contains('uber') || t.contains('trip')) return Icons.directions_car;
    if (t.contains('amazon')) return Icons.shopping_cart;
    if (t.contains('refund')) return Icons.reply;
    if (t.contains('electric') || t.contains('bill') || t.contains('utility')) return Icons.bolt;
    return Icons.receipt;
  }

  static String _formatDate(DateTime? d) {
    if (d == null) return '';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final h = d.hour == 0 ? 12 : (d.hour > 12 ? d.hour - 12 : d.hour);
    final amPm = d.hour >= 12 ? 'PM' : 'AM';
    return '${months[d.month - 1]} ${d.day}, ${d.year} • $h:${d.minute.toString().padLeft(2, '0')} $amPm';
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final primary = Theme.of(context).colorScheme.primary;

    if (loading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: CircularProgressIndicator(color: primary),
        ),
      );
    }
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Text('Unable to load transactions', style: TextStyle(color: colors.error, fontSize: 14)),
            const SizedBox(height: 8),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      );
    }
    final list = response?.transactions ?? [];
    if (list.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(
          'No recent transactions',
          style: TextStyle(color: colors.textSecondary, fontSize: 14),
        ),
      );
    }

    return Column(
      children: list.map((t) {
        final title = t.title ?? (t.isDebit ? 'Sent' : 'Received');
        final dateStr = _formatDate(t.createdAt);
        final amount = t.amount;
        final isDebit = t.isDebit;
        final status = t.status ?? 'Completed';

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
              onTap: () => onTapTransaction(t),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: primary.withValues(alpha: 0.12),
                      radius: 24,
                      child: Icon(_iconFor(title), color: primary, size: 24),
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
                      '${isDebit ? '-' : '+'}\$${amount.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: isDebit ? colors.error : colors.success,
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
      }).toList(),
    );
  }
}
