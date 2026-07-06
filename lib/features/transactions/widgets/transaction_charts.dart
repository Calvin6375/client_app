import 'package:flutter/material.dart';
import 'package:pretium/core/constants/app_colors.dart';
import 'package:pretium/models/transaction_model.dart';

/// Aggregates transaction data for chart widgets.
class TransactionChartData {
  TransactionChartData._();

  static List<DateTime> lastNDays(int n) {
    final now = DateTime.now();
    return List.generate(n, (i) {
      final d = now.subtract(Duration(days: n - 1 - i));
      return DateTime(d.year, d.month, d.day);
    });
  }

  static String weekdayLabel(DateTime day) {
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return labels[day.weekday - 1];
  }

  static bool _isOnDay(DateTime? createdAt, DateTime day) {
    if (createdAt == null) return false;
    return createdAt.year == day.year &&
        createdAt.month == day.month &&
        createdAt.day == day.day;
  }

  static List<double> dailyTotals(
    List<Transaction> transactions, {
    required bool credits,
    int days = 7,
  }) {
    final result = List<double>.filled(days, 0);
    final dayList = lastNDays(days);
    for (var i = 0; i < days; i++) {
      for (final t in transactions) {
        if (!_isOnDay(t.createdAt, dayList[i])) continue;
        if (credits && !t.isDebit) result[i] += t.amount;
        if (!credits && t.isDebit) result[i] += t.amount;
      }
    }
    return result;
  }

  static double totalCredits(List<Transaction> transactions) {
    return transactions
        .where((t) => !t.isDebit)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  static double totalDebits(List<Transaction> transactions) {
    return transactions
        .where((t) => t.isDebit)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  static Map<String, double> amountByCurrency(List<Transaction> transactions) {
    final map = <String, double>{};
    for (final t in transactions) {
      final code = (t.currency ?? 'USD').toUpperCase();
      map[code] = (map[code] ?? 0) + t.amount;
    }
    return map;
  }

  static Map<String, int> countByStatus(List<Transaction> transactions) {
    final map = <String, int>{};
    for (final t in transactions) {
      final key = (t.status ?? 'unknown').toLowerCase();
      map[key] = (map[key] ?? 0) + 1;
    }
    return map;
  }
}

/// Last 7 days: income (credit) vs expenses (debit) grouped bars.
class TransactionWeeklyBarChart extends StatelessWidget {
  const TransactionWeeklyBarChart({super.key, required this.transactions});

  final List<Transaction> transactions;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    const days = 7;
    const maxHeight = 88.0;

    final credits = TransactionChartData.dailyTotals(transactions, credits: true);
    final debits = TransactionChartData.dailyTotals(transactions, credits: false);
    final dayList = TransactionChartData.lastNDays(days);

    final maxVal = [...credits, ...debits].fold(0.0, (a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _LegendDot(color: colors.success, label: 'Income'),
            const SizedBox(width: 16),
            _LegendDot(color: colors.error, label: 'Expenses'),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 118,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(days, (i) {
              final creditH =
                  maxVal > 0 ? (credits[i] / maxVal) * maxHeight : 0.0;
              final debitH =
                  maxVal > 0 ? (debits[i] / maxVal) * maxHeight : 0.0;

              return Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _Bar(
                          height: creditH,
                          color: colors.success.withValues(alpha: 0.85),
                          maxHeight: maxHeight,
                        ),
                        const SizedBox(width: 3),
                        _Bar(
                          height: debitH,
                          color: colors.error.withValues(alpha: 0.85),
                          maxHeight: maxHeight,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      TransactionChartData.weekdayLabel(dayList[i]),
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
        if (maxVal == 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'No activity in the last 7 days',
              style: TextStyle(fontSize: 12, color: colors.textSecondary),
            ),
          ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.height,
    required this.color,
    required this.maxHeight,
  });

  final double height;
  final Color color;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final h = height <= 0 ? 4.0 : height.clamp(4.0, maxHeight);
    return Container(
      width: 10,
      height: h,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: colors.textSecondary),
        ),
      ],
    );
  }
}

/// Income vs expenses summary with proportional bar.
class TransactionIncomeExpenseChart extends StatelessWidget {
  const TransactionIncomeExpenseChart({super.key, required this.transactions});

  final List<Transaction> transactions;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final income = TransactionChartData.totalCredits(transactions);
    final expenses = TransactionChartData.totalDebits(transactions);
    final total = income + expenses;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _SummaryStat(
                label: 'Total income',
                value: income,
                valueColor: colors.success,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryStat(
                label: 'Total expenses',
                value: expenses,
                valueColor: colors.error,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 10,
            child: Row(
              children: [
                if (total > 0) ...[
                  Expanded(
                    flex: (income / total * 100).round().clamp(1, 100),
                    child: Container(color: colors.success),
                  ),
                  Expanded(
                    flex: (expenses / total * 100).round().clamp(1, 100),
                    child: Container(color: colors.error),
                  ),
                ] else
                  Expanded(child: Container(color: colors.surfaceVariant)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final String label;
  final double value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.surfaceVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: colors.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            value.toStringAsFixed(2),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// Horizontal bars for volume by currency.
class TransactionCurrencyChart extends StatelessWidget {
  const TransactionCurrencyChart({super.key, required this.transactions});

  final List<Transaction> transactions;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final primary = Theme.of(context).colorScheme.primary;
    final byCurrency = TransactionChartData.amountByCurrency(transactions);
    if (byCurrency.isEmpty) {
      return Text(
        'No currency data',
        style: TextStyle(color: colors.textSecondary, fontSize: 12),
      );
    }

    final entries = byCurrency.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final max = entries.first.value;

    return Column(
      children: entries.map((e) {
        final fraction = max > 0 ? e.value / max : 0.0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    e.key,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    e.value.toStringAsFixed(2),
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: fraction.clamp(0.05, 1.0),
                  minHeight: 8,
                  backgroundColor: colors.surfaceVariant,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    primary.withValues(alpha: 0.85),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

/// Donut chart for transaction status counts.
class TransactionStatusDonutChart extends StatelessWidget {
  const TransactionStatusDonutChart({super.key, required this.transactions});

  final List<Transaction> transactions;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final byStatus = TransactionChartData.countByStatus(transactions);
    if (byStatus.isEmpty) {
      return Text(
        'No status data',
        style: TextStyle(color: colors.textSecondary, fontSize: 12),
      );
    }

    final slices = <_StatusSlice>[];
    Color colorFor(String status) {
      switch (status) {
        case 'completed':
          return colors.success;
        case 'pending':
          return colors.warning;
        case 'failed':
          return colors.error;
        default:
          return colors.textSecondary;
      }
    }

    for (final entry in byStatus.entries) {
      slices.add(
        _StatusSlice(
          label: _formatStatus(entry.key),
          count: entry.value,
          color: colorFor(entry.key),
        ),
      );
    }

    final total = slices.fold<int>(0, (sum, s) => sum + s.count);

    return Row(
      children: [
        SizedBox(
          width: 88,
          height: 88,
          child: CustomPaint(
            painter: _DonutChartPainter(slices: slices, total: total),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: slices
                .map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: s.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            s.label,
                            style: TextStyle(
                              fontSize: 13,
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                        Text(
                          '${s.count}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  static String _formatStatus(String raw) {
    if (raw.isEmpty) return 'Unknown';
    return raw[0].toUpperCase() + raw.substring(1);
  }
}

class _StatusSlice {
  const _StatusSlice({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;
}

class _DonutChartPainter extends CustomPainter {
  _DonutChartPainter({required this.slices, required this.total});

  final List<_StatusSlice> slices;
  final int total;

  @override
  void paint(Canvas canvas, Size size) {
    if (total <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const stroke = 14.0;
    var startAngle = -3.141592653589793 / 2;

    for (final slice in slices) {
      final sweep = (slice.count / total) * 3.141592653589793 * 2;
      final paint = Paint()
        ..color = slice.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - stroke / 2),
        startAngle,
        sweep,
        false,
        paint,
      );
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.total != total || oldDelegate.slices != slices;
  }
}
