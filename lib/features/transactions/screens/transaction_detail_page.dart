// Transaction details — receipt-style view with TrouPay watermark download.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pretium/core/constants/app_colors.dart';
import 'package:pretium/features/topup/utils/receipt_image_export.dart';
import 'package:pretium/features/topup/utils/receipt_save_helper.dart';
import 'package:pretium/models/transaction_model.dart';

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
    final currency = _t.currency ?? 'KES';
    final isDebit = _t.isDebit;
    final resolvedStatus = _resolvedTransactionStatus();
    final statusLabel = _capitalize(resolvedStatus.replaceAll('_', ' '));
    final showDownloadReceipt = _shouldShowDownloadReceipt(resolvedStatus);
    final reference = _referenceDisplay();
    final paymentMethod = _paymentMethodDisplay();
    final dateStr = _formatDateTime(_t.createdAt);

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
                      _receiptRow(colors, 'Reference', reference),
                      _receiptRow(colors, 'Type', isDebit ? 'Debit (outgoing)' : 'Credit (incoming)'),
                      _receiptRow(colors, 'Payment method', paymentMethod),
                      if (_t.subtitle != null && _t.subtitle!.trim().isNotEmpty)
                        _receiptRow(colors, 'Category', _t.subtitle!.trim()),
                      if (_t.description != null && _t.description!.trim().isNotEmpty)
                        _receiptRow(colors, 'Description', _t.description!.trim()),
                      _receiptRow(colors, 'Date & time', dateStr),
                      _receiptRow(colors, 'Status', statusLabel),
                      if (_metadataPreview().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Additional details',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.textTertiary),
                        ),
                        const SizedBox(height: 6),
                        SelectableText(
                          _metadataPreview(),
                          style: TextStyle(fontSize: 12, color: colors.textSecondary, height: 1.35),
                        ),
                      ],
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
    final m = _t.metadata;
    if (m == null) return _t.id.isNotEmpty ? _t.id : '—';
    final r = m['referenceId'] ?? m['reference'] ?? m['reference_id'];
    if (r != null && r.toString().isNotEmpty) return r.toString();
    return _t.id.isNotEmpty ? _t.id : '—';
  }

  String _paymentMethodDisplay() {
    final m = _t.metadata;
    if (m == null) return '—';
    final pm = m['paymentMethod'] ?? m['payment_method'] ?? m['paymentMethodId'];
    if (pm != null && pm.toString().isNotEmpty) return pm.toString();
    return '—';
  }

  String _metadataPreview() {
    final m = _t.metadata;
    if (m == null || m.isEmpty) return '';
    final skip = {'paymentMethod', 'payment_method', 'paymentMethodId', 'referenceId', 'reference', 'reference_id'};
    final buf = StringBuffer();
    m.forEach((k, v) {
      if (skip.contains(k)) return;
      if (v == null || v.toString().isEmpty) return;
      buf.writeln('$k: $v');
    });
    return buf.toString().trim();
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

  Widget _receiptRow(AppThemeColors colors, String label, String value) {
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
        ],
      ),
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
    if (_savingReceipt) return;
    setState(() => _savingReceipt = true);
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
    } finally {
      if (mounted) setState(() => _savingReceipt = false);
    }
  }
}
