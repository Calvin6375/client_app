import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pretium/core/constants/app_colors.dart';
import 'package:pretium/features/safari_tap/models/safari_tap_payout.dart';
import 'package:pretium/features/safari_tap/services/safari_tap_pay_api_service.dart';
import 'package:pretium/features/safari_tap/utils/payout_error_messages.dart';
import 'package:pretium/widgets/app_shimmer.dart';

class SafariTapPayoutSummary {
  const SafariTapPayoutSummary({
    required this.flowLabel,
    required this.amount,
    required this.currency,
    required this.recipientName,
    this.accountLabel,
    this.accountValue,
  });

  final String flowLabel;
  final double amount;
  final String currency;
  final String recipientName;
  final String? accountLabel;
  final String? accountValue;

  static SafariTapPayoutSummary fromPayoutBody(
    Map<String, dynamic> body, {
    required String flowLabel,
  }) {
    final recipient = body['recipient'];
    final r = recipient is Map ? Map<String, dynamic>.from(recipient) : <String, dynamic>{};
    final accountType = body['accountType']?.toString();

    String? accountLabel;
    String? accountValue;
    if (accountType == 'TillNumber') {
      accountLabel = 'Till number';
      accountValue = r['account']?.toString();
    } else if (accountType == 'PayBill') {
      accountLabel = 'PayBill number';
      accountValue = r['account']?.toString();
    } else if (r['phoneNumber'] != null) {
      accountLabel = 'Phone number';
      accountValue = r['phoneNumber']?.toString();
    } else if (r['accountNumber'] != null) {
      accountLabel = 'Account number';
      accountValue = r['accountNumber']?.toString();
    }

    return SafariTapPayoutSummary(
      flowLabel: flowLabel,
      amount: (body['amount'] as num?)?.toDouble() ?? 0,
      currency: body['currency']?.toString() ?? 'KES',
      recipientName: r['name']?.toString().trim().isNotEmpty == true
          ? r['name'].toString()
          : 'Recipient',
      accountLabel: accountLabel,
      accountValue: accountValue,
    );
  }
}

class SafariTapPayoutProcessingPage extends StatefulWidget {
  const SafariTapPayoutProcessingPage({
    super.key,
    required this.clientRequestId,
    required this.summary,
    required this.initialPayout,
    this.api,
  });

  final String clientRequestId;
  final SafariTapPayoutSummary summary;
  final SafariTapPayout initialPayout;
  final SafariTapPayApiService? api;

  @override
  State<SafariTapPayoutProcessingPage> createState() =>
      _SafariTapPayoutProcessingPageState();
}

class _SafariTapPayoutProcessingPageState extends State<SafariTapPayoutProcessingPage> {
  static const _pollIntervals = <Duration>[
    Duration(seconds: 5),
    Duration(seconds: 10),
    Duration(seconds: 15),
    Duration(seconds: 30),
  ];

  late SafariTapPayApiService _api;
  SafariTapPayout? _payout;
  String? _fetchError;
  bool _refreshing = false;
  Timer? _pollTimer;
  int _pollStep = 0;
  bool _autoPollFinished = false;

  SafariTapPayout get _current => _payout ?? widget.initialPayout;

  bool get _isTerminal => _current.isTerminal;

  bool get _isSuccess => _current.isSuccess;

  String get _displayName => _current.displayName;

  double get _displayDebit => _current.displayDebit;

  String? get _mpesaReference {
    final ref = _current.mpesaReference?.trim();
    return ref != null && ref.isNotEmpty ? ref : null;
  }

  String? get _accountValue {
    final fromSummary = widget.summary.accountValue?.trim();
    if (fromSummary != null && fromSummary.isNotEmpty) return fromSummary;
    final account = _current.recipient?['account']?.toString().trim();
    if (account != null && account.isNotEmpty) return account;
    final phone = _current.recipient?['phoneNumber']?.toString().trim();
    if (phone != null && phone.isNotEmpty) return phone;
    return null;
  }

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? SafariTapPayApiService();
    _payout = widget.initialPayout.isTerminal ? widget.initialPayout : null;
    if (!_isTerminal) {
      _startAutoPoll();
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _startAutoPoll() {
    _pollTimer?.cancel();
    _pollStep = 0;
    _autoPollFinished = false;
    _scheduleNextPoll();
  }

  void _scheduleNextPoll() {
    if (!mounted || _isTerminal || _pollStep >= _pollIntervals.length) {
      if (mounted && !_isTerminal && _pollStep >= _pollIntervals.length) {
        setState(() => _autoPollFinished = true);
      }
      return;
    }

    final delay = _pollIntervals[_pollStep];
    _pollStep++;
    _pollTimer = Timer(delay, () async {
      if (!mounted || _isTerminal) return;
      await _refreshStatus(silent: true);
      if (!mounted || _isTerminal) return;
      _scheduleNextPoll();
    });
  }

  void _stopAutoPoll() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _refreshStatus({bool silent = false}) async {
    if (_refreshing) return;
    if (!silent) setState(() => _refreshing = true);

    try {
      final payout = await _api.getPayoutByClientRequestId(widget.clientRequestId);
      if (!mounted) return;
      setState(() {
        _payout = payout;
        _fetchError = null;
        _refreshing = false;
      });
      if (payout.isTerminal) _stopAutoPoll();
    } on SafariTapPayApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 404) {
        setState(() {
          _fetchError = silent ? null : 'Payment is still being set up. Pull down to try again.';
          _refreshing = false;
        });
        return;
      }
      setState(() {
        _fetchError = safariTapPayoutErrorMessage(e);
        _refreshing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _fetchError = 'Could not refresh status. Pull down to try again.';
        _refreshing = false;
      });
    }
  }

  void _finish({required bool success}) {
    Navigator.of(context).pop(success);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final primary = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final statusTitle = _isSuccess
        ? 'Payment successful'
        : _current.status == 'FAILED' || _current.status == 'CANCELLED'
            ? 'Payment ${_current.status.toLowerCase()}'
            : 'Processing payment…';

    final statusSubtitle = _isSuccess
        ? 'Transaction successful · ${widget.summary.currency}'
        : _isTerminal
            ? (_current.failureReason?.trim().isNotEmpty == true
                ? _current.failureReason!
                : 'Your payment could not be completed.')
            : _autoPollFinished
                ? 'Still confirming with M-Pesa. Pull down to refresh.'
                : 'This usually takes a few seconds. Pull down to refresh.';

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.textPrimary),
          onPressed: () => _finish(success: _isSuccess),
        ),
        title: Text(
          widget.summary.flowLabel,
          style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                color: primary,
                onRefresh: () => _refreshStatus(),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    const SizedBox(height: 12),
                    _StatusHeader(
                      isSuccess: _isSuccess,
                      isFailed: _isTerminal && !_isSuccess,
                      isProcessing: !_isTerminal,
                      title: statusTitle,
                      subtitle: statusSubtitle,
                      primary: primary,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _displayName,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '-${_current.currency} ${_displayDebit.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: isDark ? colors.surface : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: isDark ? null : Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Column(
                        children: [
                          _DetailRow(
                            label: 'Status',
                            value: _formatStatus(_current.status),
                            valueColor: _isSuccess
                                ? AppColors.successGreen
                                : _isTerminal && !_isSuccess
                                    ? AppColors.errorRed
                                    : primary,
                          ),
                          if (_mpesaReference != null)
                            _DetailRow(
                              label: 'Mpesa reference',
                              value: _mpesaReference!,
                              copyable: true,
                            ),
                          if (widget.summary.accountLabel != null &&
                              _accountValue != null) ...[
                            _DetailRow(
                              label: widget.summary.accountLabel!,
                              value: _accountValue!,
                              copyable: true,
                            ),
                          ],
                          _DetailRow(
                            label: 'Total amount',
                            value: '${_current.currency} ${_displayDebit.toStringAsFixed(2)}',
                          ),
                          if (_current.fee > 0)
                            _DetailRow(
                              label: 'Fee',
                              value:
                                  '${widget.summary.currency} ${_current.fee.toStringAsFixed(2)}',
                            ),
                        ],
                      ),
                    ),
                    if (_fetchError != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.errorRed.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _fetchError!,
                          style: const TextStyle(color: AppColors.errorRed, fontSize: 13),
                        ),
                      ),
                    ],
                    if (!_isTerminal) ...[
                      const SizedBox(height: 20),
                      Text(
                        _autoPollFinished
                            ? 'Automatic checks have finished. Pull down to refresh or check your transaction history.'
                            : 'Payment is being confirmed with M-Pesa. You can leave this screen and check your transaction history.',
                        style: TextStyle(color: colors.textTertiary, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isTerminal ? () => _finish(success: _isSuccess) : null,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    _isTerminal
                        ? 'Done'
                        : _refreshing
                            ? 'Checking status…'
                            : 'Waiting for confirmation…',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatStatus(String status) {
    if (status == 'SUCCESS') return 'Successful';
    if (status == 'FAILED') return 'Failed';
    if (status == 'CANCELLED') return 'Cancelled';
    if (status == 'PROCESSING') return 'Processing';
    return status.replaceAll('_', ' ');
  }
}

class _StatusHeader extends StatelessWidget {
  const _StatusHeader({
    required this.isSuccess,
    required this.isFailed,
    required this.isProcessing,
    required this.title,
    required this.subtitle,
    required this.primary,
  });

  final bool isSuccess;
  final bool isFailed;
  final bool isProcessing;
  final String title;
  final String subtitle;
  final Color primary;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget icon;
    Color accent;
    if (isSuccess) {
      icon = const Icon(Icons.check_circle, color: AppColors.successGreen, size: 48);
      accent = AppColors.successGreen;
    } else if (isFailed) {
      icon = const Icon(Icons.error_outline, color: AppColors.errorRed, size: 48);
      accent = AppColors.errorRed;
    } else {
      icon = const AppShimmer(
        child: ShimmerCircle(size: 48),
      );
      accent = primary;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? colors.surface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          icon,
          const SizedBox(height: 14),
          Text(
            title,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(color: colors.textSecondary, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.copyable = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool copyable;

  Future<void> _copyValue(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: colors.textSecondary, fontSize: 13),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(
                  child: Text(
                    value,
                    style: TextStyle(
                      color: valueColor ?? colors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                if (copyable && value.trim().isNotEmpty) ...[
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: () => _copyValue(context),
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
}
