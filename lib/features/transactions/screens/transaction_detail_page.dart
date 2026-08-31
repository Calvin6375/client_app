// Transaction details — receipt-style view with TrouPay watermark download.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pretium/core/constants/app_colors.dart';
import 'package:pretium/features/topup/utils/receipt_image_export.dart';
import 'package:pretium/features/topup/utils/receipt_save_helper.dart';
import 'package:pretium/models/transaction_model.dart';
import 'package:pretium/services/transactions_service.dart';
import 'package:pretium/utils/async_action_guard.dart';
import 'package:pretium/utils/logger.dart';
import 'package:pretium/utils/provider_display_sanitizer.dart';
import 'package:pretium/widgets/app_shimmer.dart';

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
  final TransactionsService _transactionsService = TransactionsService();
  bool _savingReceipt = false;
  bool _loadingDetails = true;
  Transaction? _transaction;
  String? _loadError;

  Transaction get _t => _transaction ?? widget.transaction;

  @override
  void initState() {
    super.initState();
    unawaited(_loadFullTransaction());
  }

  Future<void> _loadFullTransaction() async {
    const encoder = JsonEncoder.withIndent('  ');
    Logger.info(
      'Transaction detail — list item parsed:\n${encoder.convert(widget.transaction.toJson())}',
    );

    try {
      final full = await _transactionsService.getTransaction(widget.transaction.id);
      Logger.info(
        'Transaction detail — single fetch parsed:\n${encoder.convert(full.toJson())}',
      );
      if (!mounted) return;
      setState(() {
        _transaction = full;
        _loadingDetails = false;
        _loadError = null;
      });
    } catch (e) {
      Logger.warning('Transaction detail — single fetch failed', e);
      if (!mounted) return;
      setState(() {
        _loadingDetails = false;
        _loadError = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final primary = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final title = _t.displayTitle;
    final currency = _t.currency ?? _metaString(['currency']) ?? 'KES';
    final typeLabel = () {
      final fromRecon = ProviderDisplaySanitizer.labelFromReconType(
        _t.reconType,
        isDebit: _t.isDebit,
      );
      if (fromRecon.isNotEmpty) return fromRecon;
      final sanitizedType = ProviderDisplaySanitizer.sanitize(_t.type);
      if (sanitizedType.isNotEmpty) return sanitizedType;
      return _t.directionLabel;
    }();
    final resolvedStatus = _resolvedTransactionStatus();
    final statusLabel = _capitalize(resolvedStatus.replaceAll('_', ' '));
    final showDownloadReceipt = _shouldShowDownloadReceipt(resolvedStatus);
    final detailRows = _buildDetailRows(
      reference: _referenceDisplay(),
      typeLabel: typeLabel,
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
        child: _loadingDetails
            ? const PageContentShimmer()
            : SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_loadError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Showing summary only (full details unavailable).',
                    style: TextStyle(color: colors.textSecondary, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),
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
                        _t.formattedSignedAmount(currencyOverride: currency),
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
                      ? const ShimmerBusyIndicator()
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
    'payoutId',
    'payout_id',
    'providerTrackingId',
    'provider_tracking_id',
    'recipientType',
    'recipient_type',
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
    'Payout Id',
    'Payout ID',
    'Provider Tracking Id',
    'Provider Tracking ID',
  };

  static bool _isCopyableLabel(String label) {
    final normalized = label.trim().toLowerCase();
    return normalized == 'reference' ||
        normalized == 'funding order id' ||
        normalized == 'mpesa reference';
  }

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
    consumeKeys(['type', 'displayName', 'label', 'title', 'reconType']);

    addRow('Direction', _t.directionLabel);
    consumeKeys(['direction']);

    final category = ProviderDisplaySanitizer.sanitize(_t.subtitle);
    if (category.isNotEmpty) {
      addRow('Category', category);
    }
    consumeKeys(['subtitle', 'category']);

    final description = ProviderDisplaySanitizer.sanitize(_t.description);
    if (description.isNotEmpty) {
      addRow('Description', description);
    }
    consumeKeys(['description']);

    addRow('Date & time', dateStr);
    consumeKeys(['createdAt', 'created_at', 'timestamp', 'updatedAt', 'updated_at']);

    addRow('Status', statusLabel);
    consumeKeys(['status', 'orderStatus']);

    addRow('Currency', currency);
    consumeKeys(['currency']);

    _addRecipientRows(addRow, consumeKeys);

    // Prefer friendly labels for known metadata / extra keys.
    const orderedLabels = <String, String>{
      'orderId': 'Order ID',
      'order_id': 'Order ID',
      'correlationId': 'Transaction ID',
      'correlation_id': 'Transaction ID',
      'transactionId': 'Transaction ID',
      'transaction_id': 'Transaction ID',
      'flow': 'Flow',
      'orderType': 'Order type',
      'bankName': 'Bank name',
      'mobileProviderId': 'Mobile provider ID',
      'newBalance': 'New balance',
      'previousBalance': 'Previous balance',
      'clientWalletCurrency': 'Wallet currency',
      'clientFiatBalance': 'Fiat balance',
      'amount': 'Amount',
      'signedAmount': 'Signed amount',
    };

    final flat = _flattenedApiFields();
    // Hide funding order IDs from the details view.
    for (final k in ['fundingOrderId', 'funding_order_id']) {
      consumed.add(k);
    }
    for (final entry in orderedLabels.entries) {
      if (consumed.contains(entry.key) || !flat.containsKey(entry.key)) continue;
      final value = _stringifyValue(flat[entry.key]);
      if (value.isEmpty) continue;
      addRow(
        entry.value,
        value,
        copyable: entry.value == 'Transaction ID',
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
      if (ProviderDisplaySanitizer.isHiddenMetadataKey(key)) continue;
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
      'Recipient name',
      'Account type',
      'Account',
      'Account reference',
    ];
    final target = order.indexOf(label);
    if (target < 0) return rows.length;
    for (var i = 0; i < rows.length; i++) {
      final at = order.indexOf(rows[i].label);
      if (at < 0 || at > target) return i;
    }
    return rows.length;
  }

  void _addRecipientRows(
    void Function(String label, String value, {bool copyable}) addRow,
    void Function(Iterable<String> keys) consumeKeys,
  ) {
    final recipient = _recipientMap();
    if (recipient == null || recipient.isEmpty) return;

    consumeKeys(['recipient']);

    final name = _recipientField(recipient, ['name']);
    if (name.isNotEmpty) addRow('Recipient name', name);

    final accountType = _formatAccountType(
      _recipientFieldRaw(recipient, ['account_type', 'accountType']),
    );
    if (accountType.isNotEmpty) addRow('Account type', accountType);

    final account = _recipientField(recipient, ['account']);
    if (account.isNotEmpty) addRow('Account', account, copyable: true);

    final accountReference = _recipientField(
      recipient,
      ['account_reference', 'accountReference'],
    );
    if (accountReference.isNotEmpty) {
      addRow('Account reference', accountReference, copyable: true);
    }

    consumeKeys([
      'recipient.name',
      'recipient.account_type',
      'recipient.accountType',
      'recipient.account',
      'recipient.account_reference',
      'recipient.accountReference',
      'recipientType',
      'recipient_type',
    ]);
  }

  Map<String, dynamic>? _recipientMap() {
    if (_t.recipient != null && _t.recipient!.isNotEmpty) {
      return _t.recipient;
    }
    for (final source in [_t.metadata, _t.extraFields]) {
      if (source == null) continue;
      final raw = source['recipient'];
      if (raw is Map) {
        return raw.map((k, v) => MapEntry(k.toString(), v));
      }
    }
    return null;
  }

  dynamic _recipientFieldRaw(
    Map<String, dynamic> recipient,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = recipient[key];
      if (value != null && value.toString().trim().isNotEmpty) return value;
    }
    return null;
  }

  String _recipientField(Map<String, dynamic> recipient, List<String> keys) {
    final value = _recipientFieldRaw(recipient, keys);
    if (value == null) return '';
    return ProviderDisplaySanitizer.sanitize(value.toString());
  }

  String _formatAccountType(dynamic value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) return '';
    final spaced = raw.replaceAllMapped(
      RegExp(r'([a-z])([A-Z])|([A-Z]+)([A-Z][a-z])'),
      (m) => '${m[1] ?? m[3]} ${m[2] ?? m[4]}',
    );
    return spaced
        .replaceAll('_', ' ')
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .map(
          (part) => part.length == 1
              ? part.toUpperCase()
              : part[0].toUpperCase() + part.substring(1).toLowerCase(),
        )
        .join(' ');
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
        } else if (k == 'recipient' && v is Map) {
          Map<String, dynamic>.from(v).forEach((rk, rv) {
            flat['recipient.$rk'] = rv;
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
    return ProviderDisplaySanitizer.sanitize(v.toString());
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
