// Transaction details — receipt-style view with TrouPay watermark download.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pretium/core/constants/app_colors.dart';
import 'package:pretium/features/topup/utils/receipt_image_export.dart';
import 'package:pretium/features/topup/utils/receipt_save_helper.dart';
import 'package:pretium/models/transaction_model.dart';
import 'package:pretium/utils/async_action_guard.dart';

class TransactionDetailPage extends StatefulWidget {
  final Transaction transaction;

  const TransactionDetailPage({
    super.key,
    required this.transaction,
  });

  @override
  State<TransactionDetailPage> createState() => _TransactionDetailPageState();
}

class _TransactionDetailPageState extends State<TransactionDetailPage> {
  final GlobalKey _receiptCardKey = GlobalKey();
  bool _savingReceipt = false;

  Transaction get _t => widget.transaction;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final primary = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final title = _t.title ?? (_t.isDebit ? 'Sent' : 'Received');
    final currency = _t.currency ?? _metaString(['currency']) ?? 'KES';
    final isDebit = _t.isDebit;
    final resolvedStatus = _resolvedTransactionStatus();
    final statusLabel = _capitalize(resolvedStatus.replaceAll('_', ' '));
    final showDownloadReceipt = _shouldShowDownloadReceipt(resolvedStatus);
    final detailRows = _buildDetailRows(
      reference: _referenceDisplay(),
      typeLabel: isDebit ? 'Debit (outgoing)' : 'Credit (incoming)',
      dateStr: _formatDateTime(_t.createdAt),
      statusLabel: statusLabel,
      currency: currency,
    );

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.close, color: colors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Transaction details',
          style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: colors.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                _subtitleLine(),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: colors.textSecondary),
              ),
              const SizedBox(height: 24),
              RepaintBoundary(
                key: _receiptCardKey,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? colors.surface : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colors.border),
                    boxShadow: isDark
                        ? null
                        : [BoxShadow(color: colors.shadowLight, blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Total amount', style: TextStyle(fontSize: 13, color: colors.textSecondary)),
                      const SizedBox(height: 8),
                      Text(
                        '$currency ${_t.amount.toStringAsFixed(2)}',
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: colors.textPrimary),
                      ),
                      Divider(height: 32, color: colors.divider),
                      for (final row in detailRows)
                        _receiptRow(
                          colors,
                          row.label,
                          row.value,
                          copyable: row.copyable,
                        ),
                    ],
                  ),
                ),
              ),
              if (showDownloadReceipt) ...[
                const SizedBox(height: 20),
                _infoBanner(colors, isDark),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _savingReceipt ? null : _downloadReceipt,
                  icon: _savingReceipt
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: primary),
                        )
                      : Icon(Icons.download_rounded, color: primary),
                  label: Text(
                    _savingReceipt ? 'Saving…' : 'Download receipt',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primary,
                    side: BorderSide(color: primary.withValues(alpha: 0.45)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Prefer top-level [Transaction.status], else metadata from API.
  String _resolvedTransactionStatus() {
    final s = _t.status?.trim();
    if (s != null && s.isNotEmpty) return s;
    final m = _t.metadata?['status'] ?? _t.metadata?['orderStatus'];
    final fromMeta = m?.toString().trim();
    if (fromMeta != null && fromMeta.isNotEmpty) return fromMeta;
    return 'completed';
  }

  /// Receipt download is only offered once the transaction is no longer in-flight.
  bool _shouldShowDownloadReceipt(String status) {
    final s = status.toLowerCase().trim();
    const inFlight = {
      'pending',
      'processing',
      'queued',
      'in_progress',
      'awaiting',
      'awaiting_settlement',
      'initiated',
    };
    if (s.isEmpty) return true;
    return !inFlight.contains(s);
  }

  String _subtitleLine() {
    final s = _statusLabelForHeadline();
    final cur = _t.currency ?? '';
    if (cur.isNotEmpty) {
      return '$s · $cur';
    }
    return s;
  }

  String _statusLabelForHeadline() {
    final raw = _resolvedTransactionStatus().toLowerCase();
    if (raw == 'completed' || raw == 'success') return 'Transaction successful';
    if (raw == 'pending' || raw == 'processing') return 'Transaction in progress';
    if (raw == 'failed') return 'Transaction failed';
    return _capitalize(raw.replaceAll('_', ' '));
  }

  String _referenceDisplay() {
    final r = _metaValue(['referenceId', 'reference', 'reference_id']);
    if (r != null && r.toString().isNotEmpty) return r.toString();
    return _t.id.isNotEmpty ? _t.id : '—';
  }

  static const Set<String> _hiddenFieldKeys = {
    'source',
    'userId',
    'user_id',
    'uid',
    'paymentMethod',
    'payment_method',
    'paymentMethodId',
    'payoutMethod',
    'payout_method',
    'provider',
    'mobileProvider',
    'review.paymentMethod',
    'review.paymentMethodId',
    'review.mobileProvider',
  };

  static const Set<String> _hiddenLabels = {
    'Source',
    'User Id',
    'User ID',
    'User id',
    'Payment method',
    'Payment method ID',
    'Provider',
    'Payout method',
    'Mobile provider',
  };

  static bool _isCopyableLabel(String label) =>
      label == 'Reference' || label == 'Funding order ID';

  /// Builds labeled rows for every meaningful field from the API response.
  List<({String label, String value, bool copyable})> _buildDetailRows({
    required String reference,
    required String typeLabel,
    required String dateStr,
    required String statusLabel,
    required String currency,
  }) {
    final rows = <({String label, String value, bool copyable})>[];
    final consumed = <String>{};

    void addRow(String label, String value, {bool copyable = false}) {
      final v = value.trim();
      if (v.isEmpty || v == '—') return;
      if (_hiddenLabels.contains(label)) return;
      rows.add((
        label: label,
        value: v,
        copyable: copyable || _isCopyableLabel(label),
      ));
    }

    void consumeKeys(Iterable<String> keys) => consumed.addAll(keys);

    // Always hide these API fields from the receipt.
    consumeKeys(_hiddenFieldKeys);

    addRow('Reference', reference, copyable: true);
    consumeKeys(['referenceId', 'reference', 'reference_id']);

    if (_t.id.isNotEmpty && _t.id != reference) {
      addRow('Transaction ID', _t.id);
    }
    consumeKeys(['id', 'transactionId', 'transaction_id']);

    addRow('Type', typeLabel);
    consumeKeys(['type']);

    final category = _t.subtitle?.trim();
    if (category != null && category.isNotEmpty) {
      addRow('Category', category);
    }
    consumeKeys(['subtitle', 'category']);

    final description = _t.description?.trim();
    if (description != null && description.isNotEmpty) {
      addRow('Description', description);
    }
    consumeKeys(['description']);

    addRow('Date & time', dateStr);
    consumeKeys(['createdAt', 'created_at', 'timestamp', 'updatedAt', 'updated_at']);

    addRow('Status', statusLabel);
    consumeKeys(['status', 'orderStatus']);

    addRow('Currency', currency);
    consumeKeys(['currency']);

    // Prefer friendly labels for known metadata / extra keys.
    const orderedLabels = <String, String>{
      'fundingOrderId': 'Funding order ID',
      'funding_order_id': 'Funding order ID',
      'orderId': 'Order ID',
      'order_id': 'Order ID',
      'correlationId': 'Correlation ID',
      'correlation_id': 'Correlation ID',
      'flow': 'Flow',
      'orderType': 'Order type',
      'bankName': 'Bank name',
      'mobileProviderId': 'Mobile provider ID',
      'newBalance': 'New balance',
      'previousBalance': 'Previous balance',
      'clientWalletCurrency': 'Wallet currency',
      'clientFiatBalance': 'Fiat balance',
      'amount': 'Amount',
    };

    final flat = _flattenedApiFields();
    for (final entry in orderedLabels.entries) {
      if (consumed.contains(entry.key) || !flat.containsKey(entry.key)) continue;
      final value = _stringifyValue(flat[entry.key]);
      if (value.isEmpty) continue;
      addRow(
        entry.value,
        value,
        copyable: entry.value == 'Funding order ID',
      );
      consumed.add(entry.key);
    }

    // Nested review.* fields with friendly labels (payment method intentionally omitted).
    const reviewLabels = <String, String>{
      'review.country': 'Country',
      'review.countryCode': 'Country code',
      'review.phone': 'Phone',
      'review.processingFeeFormatted': 'Processing fee',
      'review.depositAmountFormatted': 'Deposit amount',
      'review.totalDueFormatted': 'Total due',
      'review.estimatedArrival': 'Estimated arrival',
      'review.bankName': 'Bank name',
      'review.accountNumberMasked': 'Account number',
    };
    for (final entry in reviewLabels.entries) {
      if (consumed.contains(entry.key) || !flat.containsKey(entry.key)) continue;
      final value = _stringifyValue(flat[entry.key]);
      if (value.isEmpty) continue;
      addRow(entry.value, value);
      consumed.add(entry.key);
    }

    // Remaining fields from metadata + extras so nothing useful from the API is dropped.
    final remaining = flat.keys.where((k) => !consumed.contains(k)).toList()..sort();
    for (final key in remaining) {
      if (key == 'review') continue;
      if (_hiddenFieldKeys.contains(key)) continue;
      final value = _stringifyValue(flat[key]);
      if (value.isEmpty) continue;
      final label = _humanizeKey(key.replaceFirst(RegExp(r'^review\.'), ''));
      if (_hiddenLabels.contains(label)) continue;
      addRow(label, value);
    }

    // Ensure core rows still appear even when value was "—" (user expects the labels).
    final labelsPresent = rows.map((r) => r.label).toSet();
    void ensureCore(String label, String value, {bool copyable = false}) {
      if (labelsPresent.contains(label)) return;
      rows.insert(
        _coreInsertIndex(rows, label),
        (
          label: label,
          value: value.trim().isEmpty ? '—' : value,
          copyable: copyable || _isCopyableLabel(label),
        ),
      );
    }

    ensureCore('Reference', reference, copyable: true);
    ensureCore('Type', typeLabel);
    ensureCore('Date & time', dateStr);
    ensureCore('Status', statusLabel);

    return rows;
  }

  int _coreInsertIndex(
    List<({String label, String value, bool copyable})> rows,
    String label,
  ) {
    const order = [
      'Reference',
      'Transaction ID',
      'Type',
      'Category',
      'Description',
      'Date & time',
      'Status',
      'Currency',
    ];
    final target = order.indexOf(label);
    if (target < 0) return rows.length;
    for (var i = 0; i < rows.length; i++) {
      final at = order.indexOf(rows[i].label);
      if (at < 0 || at > target) return i;
    }
    return rows.length;
  }

  /// Flattens metadata + unknown top-level API fields (including nested `review`).
  Map<String, dynamic> _flattenedApiFields() {
    final flat = <String, dynamic>{};
    void merge(Map<String, dynamic>? source) {
      if (source == null) return;
      source.forEach((k, v) {
        if (k == 'review' && v is Map) {
          Map<String, dynamic>.from(v).forEach((rk, rv) {
            flat['review.$rk'] = rv;
          });
        } else {
          flat[k] = v;
        }
      });
    }

    merge(_t.metadata);
    merge(_t.extraFields);
    return flat;
  }

  dynamic _metaValue(List<String> keys) {
    final m = _t.metadata;
    if (m != null) {
      for (final k in keys) {
        final v = m[k];
        if (v != null && v.toString().trim().isNotEmpty) return v;
      }
    }
    for (final k in keys) {
      final v = _t.extraFields[k];
      if (v != null && v.toString().trim().isNotEmpty) return v;
    }
    // Nested review map
    final review = _t.metadata?['review'];
    if (review is Map) {
      for (final k in keys) {
        final v = review[k];
        if (v != null && v.toString().trim().isNotEmpty) return v;
      }
    }
    return null;
  }

  String? _metaString(List<String> keys) {
    final v = _metaValue(keys);
    final s = v?.toString().trim();
    if (s == null || s.isEmpty) return null;
    return s;
  }

  String _stringifyValue(dynamic v) {
    if (v == null) return '';
    if (v is num) {
      final d = v.toDouble();
      if ((d - d.roundToDouble()).abs() < 1e-9) return d.round().toString();
      return d.toStringAsFixed(2);
    }
    if (v is Map || v is List) return v.toString();
    return v.toString().trim();
  }

  String _humanizeKey(String k) {
    if (k.isEmpty) return k;
    final spaced = k.replaceAllMapped(RegExp(r'([A-Z])'), (m) => ' ${m.group(1)}').trim();
    final parts = spaced.split(RegExp(r'[_\s.]+')).where((s) => s.isNotEmpty);
    return parts.map((p) => p[0].toUpperCase() + p.substring(1).toLowerCase()).join(' ');
  }

  String _formatDateTime(DateTime? d) {
    if (d == null) return '—';
    final local = d.toLocal();
    final y = local.year;
    final mo = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final h = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$y-$mo-$day · $h:$min';
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  Widget _receiptRow(
    AppThemeColors colors,
    String label,
    String value, {
    bool copyable = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: TextStyle(color: colors.textSecondary, fontSize: 13)),
          ),
          Expanded(
            flex: 3,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: SelectableText(
                    value,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (copyable && value.trim().isNotEmpty && value != '—') ...[
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: () => _copyValue(label, value),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Icon(
                        Icons.copy_rounded,
                        size: 16,
                        color: colors.textTertiary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _copyValue(String label, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied')),
    );
  }

  Widget _infoBanner(AppThemeColors colors, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.infoLight.withValues(alpha: isDark ? 0.35 : 1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: colors.primary, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Keep this receipt for your records. Download adds a TrouPay watermark for authenticity.',
              style: TextStyle(fontSize: 13, color: colors.textSecondary, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadReceipt() async {
    await runGuardedAsync(
      this,
      isSubmitting: () => _savingReceipt,
      setSubmitting: (value) => setState(() => _savingReceipt = value),
      action: () async {
        try {
          await Future<void>.delayed(Duration.zero);
          await WidgetsBinding.instance.endOfFrame;
          final raw = await ReceiptImageExport.captureRepaintBoundaryPng(_receiptCardKey);
          if (raw == null || raw.isEmpty) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Could not capture receipt. Try again.')),
              );
            }
            return;
          }
          final logoBytes = await rootBundle.load('assets/images/troupay_logo.png');
          final out = ReceiptImageExport.applyTroupayWatermark(
            receiptPng: raw,
            logoPng: logoBytes.buffer.asUint8List(),
          );
          final stamp = DateTime.now().millisecondsSinceEpoch;
          await saveReceiptPngToGalleryOrShare(
            pngBytes: out,
            fileBaseName: 'troupay_tx_${_t.id}_$stamp',
            onMessage: (m) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
              }
            },
          );
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Could not save receipt: $e')),
            );
          }
        }
      },
    );
  }
}
