import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pretium/core/constants/app_colors.dart';
import 'package:pretium/models/notification_model.dart';
import 'package:pretium/services/notification_service.dart';
import 'package:pretium/utils/async_action_guard.dart';
import 'package:url_launcher/url_launcher.dart';

final _markAllAsReadGuard = AsyncActionGuard();
final _openDetailGuard = AsyncActionGuard();

IconData _notificationIconFor(NotificationModel notification) {
  if (notification.isPromotion) return Icons.local_offer_rounded;
  if (notification.isSystem) return Icons.info_outline_rounded;

  final type = notification.type.toLowerCase();
  switch (type) {
    case 'transaction':
    case 'payment':
    case 'payment_completed':
    case 'payment_failed':
      return Icons.payment_rounded;
    case 'transfer':
      return Icons.swap_horiz_rounded;
    case 'topup':
    case 'top_up':
    case 'top-up':
    case 'deposit':
    case 'direct_topup':
    case 'direct_top_up':
      return Icons.add_circle_outline_rounded;
    case 'wallet_funded':
    case 'wallet_credited':
    case 'funding':
    case 'funding_success':
      return Icons.account_balance_wallet_outlined;
    case 'funding_failed':
    case 'transaction_failed':
      return Icons.error_outline_rounded;
    case 'payout':
    case 'withdraw':
    case 'withdrawal':
      return Icons.outbound_rounded;
    default:
      if (notification.isTransaction) return Icons.receipt_long_outlined;
      return Icons.notifications_rounded;
  }
}

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

enum _NotificationFilterTab { transaction, system, promotions }

class _NotificationsPageState extends State<NotificationsPage> {
  _NotificationFilterTab _selectedTab = _NotificationFilterTab.transaction;
  bool _isMarkingAllRead = false;
  String? _openingNotificationId;
  final Set<String> _markingReadIds = {};

  List<NotificationModel> _filterNotifications(List<NotificationModel> notifications) {
    switch (_selectedTab) {
      case _NotificationFilterTab.transaction:
        return notifications.where((n) => n.isTransaction).toList();
      case _NotificationFilterTab.system:
        return notifications.where((n) => n.isSystem).toList();
      case _NotificationFilterTab.promotions:
        return notifications.where((n) => n.isPromotion).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final colors = AppColors.getThemeColors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    if (user == null) {
      return Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          backgroundColor: isDark ? Colors.transparent : primary.withValues(alpha: 0.08),
          elevation: 0,
          title: Text('Notifications', style: TextStyle(color: colors.textPrimary)),
          iconTheme: IconThemeData(color: colors.textPrimary),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              'Sign in to view notifications',
              style: TextStyle(color: colors.textSecondary, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return StreamBuilder<List<NotificationModel>>(
      stream: NotificationService().getNotificationsStream(user.uid),
      builder: (context, snapshot) {
        final notifications = snapshot.data ?? [];
        final filtered = _filterNotifications(notifications);
        final loading = snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData;
        final hasUnread = filtered.any((n) => !n.read);
        final interactionLocked =
            loading || _isMarkingAllRead || _openingNotificationId != null;

        return Scaffold(
          backgroundColor: colors.background,
          appBar: AppBar(
            backgroundColor: isDark ? Colors.transparent : primary.withValues(alpha: 0.08),
            elevation: 0,
            title: Text(
              'Notifications',
              style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold),
            ),
            iconTheme: IconThemeData(color: colors.textPrimary),
            actions: [
              if (!loading && hasUnread)
                IconButton(
                  tooltip: 'Mark all as read',
                  onPressed: interactionLocked
                      ? null
                      : () => _markAllAsRead(context, user.uid),
                  icon: _isMarkingAllRead
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.textPrimary,
                          ),
                        )
                      : Icon(Icons.done_all_rounded, color: colors.textPrimary),
                ),
            ],
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _NotificationTabBar(
                  selectedTab: _selectedTab,
                  enabled: !interactionLocked,
                  onChanged: (tab) {
                    if (interactionLocked) return;
                    setState(() => _selectedTab = tab);
                  },
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    _buildBody(
                      context,
                      snapshot,
                      colors,
                      primary,
                      user,
                      filtered,
                      interactionLocked: interactionLocked,
                    ),
                    if (_isMarkingAllRead)
                      Positioned.fill(
                        child: ColoredBox(
                          color: colors.background.withValues(alpha: 0.45),
                          child: Center(
                            child: CircularProgressIndicator(color: primary),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    AsyncSnapshot<List<NotificationModel>> snapshot,
    AppThemeColors colors,
    Color primary,
    User user,
    List<NotificationModel> notifications, {
    required bool interactionLocked,
  }) {
    if (snapshot.connectionState == ConnectionState.waiting &&
        !snapshot.hasData) {
      return Center(child: CircularProgressIndicator(color: primary));
    }
    if (snapshot.hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: colors.textTertiary),
              const SizedBox(height: 16),
              Text(
                'Could not load notifications',
                style: TextStyle(color: colors.textPrimary, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    if (notifications.isEmpty) {
      return _EmptyNotifications(
        colors: colors,
        primary: primary,
        tab: _selectedTab,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: notifications.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final notification = notifications[index];
        final isOpening = _openingNotificationId == notification.id;
        return _NotificationTile(
          notification: notification,
          isLoading: isOpening,
          onTap: interactionLocked
              ? null
              : () => _openNotificationDetail(context, notification, user),
        );
      },
    );
  }

  Future<void> _markAllAsRead(BuildContext context, String userId) async {
    await _markAllAsReadGuard.run(() async {
      if (!mounted) return;
      setState(() => _isMarkingAllRead = true);
      try {
        await NotificationService().markAllNotificationsAsRead(userId);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('All notifications marked as read')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not update notifications: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isMarkingAllRead = false);
      }
    });
  }

  void _markReadInBackground(User user, String notificationId) {
    if (_markingReadIds.contains(notificationId)) return;
    _markingReadIds.add(notificationId);
    unawaited(() async {
      try {
        final token = await user.getIdToken();
        await NotificationService().markNotificationAsRead(
          notificationId,
          authToken: token,
        );
      } catch (_) {
        // Best-effort; list stream will reflect unread if it fails.
      } finally {
        _markingReadIds.remove(notificationId);
      }
    }());
  }

  Future<void> _openNotificationDetail(
    BuildContext context,
    NotificationModel notification,
    User user,
  ) async {
    await _openDetailGuard.run(() async {
      if (!mounted) return;
      setState(() => _openingNotificationId = notification.id);

      // Don't block the sheet on the mark-as-read API (often slow).
      if (!notification.read) {
        _markReadInBackground(user, notification.id);
      }

      if (!context.mounted) {
        if (mounted) setState(() => _openingNotificationId = null);
        return;
      }

      final colors = AppColors.getThemeColors(context);
      final primary = Theme.of(context).colorScheme.primary;
      final isDark = Theme.of(context).brightness == Brightness.dark;

      try {
        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (ctx) {
            return _NotificationDetailSheet(
              notification: notification,
              colors: colors,
              primary: primary,
              surfaceColor: isDark ? colors.surface : Colors.white,
            );
          },
        );
      } finally {
        if (mounted) setState(() => _openingNotificationId = null);
      }
    });
  }
}

class _NotificationDetailSheet extends StatelessWidget {
  const _NotificationDetailSheet({
    required this.notification,
    required this.colors,
    required this.primary,
    required this.surfaceColor,
  });

  final NotificationModel notification;
  final AppThemeColors colors;
  final Color primary;
  final Color surfaceColor;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.88,
      ),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottom),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _notificationIconFor(notification),
                          color: primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          notification.title,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Message',
                    style: TextStyle(
                      color: colors.textTertiary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SelectableText(
                    notification.message,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 15,
                      height: 1.45,
                    ),
                  ),
                  if (notification.metadata.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text(
                      'Details',
                      style: TextStyle(
                        color: colors.textTertiary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: isDark ? colors.surface : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: colors.border),
                        boxShadow: isDark
                            ? null
                            : [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.06),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: _metadataReceiptRows(
                          context,
                          colors,
                          notification.metadata,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  _detailRow(
                    colors,
                    'Type',
                    notification.type.isEmpty ? '—' : notification.type,
                  ),
                  if (notification.createdAt != null)
                    _detailRow(
                      colors,
                      'Received',
                      _formatFullTimestamp(notification.createdAt!),
                    ),
                  if (notification.updatedAt != null)
                    _detailRow(
                      colors,
                      'Updated',
                      _formatFullTimestamp(notification.updatedAt!),
                    ),
                  if (notification.actionUrl != null && notification.actionUrl!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    FilledButton.tonal(
                      onPressed: () async {
                        final uri = Uri.tryParse(notification.actionUrl!);
                        if (uri != null && await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      },
                      child: const Text('Open link'),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _detailRow(AppThemeColors colors, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: TextStyle(color: colors.textTertiary, fontSize: 13),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(color: colors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  /// Receipt-style rows (label left, value right) — same pattern as transaction receipt.
  static List<Widget> _metadataReceiptRows(
    BuildContext context,
    AppThemeColors colors,
    Map<String, dynamic> raw,
  ) {
    final entries = _flattenMetadataEntries(raw);
    if (entries.isEmpty) {
      return [
        Text(
          'No extra details',
          style: TextStyle(color: colors.textSecondary, fontSize: 13),
        ),
      ];
    }
    return [
      for (final e in entries)
        _receiptRow(context, colors, e.label, e.value, copyable: e.copyable),
    ];
  }

  static Widget _receiptRow(
    BuildContext context,
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
            child: Text(
              label,
              style: TextStyle(color: colors.textSecondary, fontSize: 13),
            ),
          ),
          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
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
                if (copyable) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    tooltip: 'Copy $label',
                    icon: Icon(Icons.copy, size: 16, color: colors.textSecondary),
                    onPressed: () => _copyMetadataValue(context, label, value),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> _copyMetadataValue(
    BuildContext context,
    String label,
    String value,
  ) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied')),
    );
  }

  static bool _isCopyableMetadataKey(String key) {
    const keys = {
      'correlationId',
      'correlation_id',
      'fundingOrderId',
      'funding_order_id',
    };
    return keys.contains(key);
  }

  /// Flattens notification metadata (and nested `review`) into ordered label/value pairs.
  static List<({String label, String value, bool copyable})> _flattenMetadataEntries(
    Map<String, dynamic> raw,
  ) {
    final flat = <String, dynamic>{};
    raw.forEach((k, v) {
      if (k == 'review' && v is Map) {
        final rm = Map<String, dynamic>.from(v);
        rm.forEach((rk, rv) {
          flat['review.$rk'] = rv;
        });
      } else {
        flat[k] = v;
      }
    });

    final consumed = <String>{};
    final out = <({String label, String value, bool copyable})>[];

    void take(String key, String label, String Function() build) {
      if (!flat.containsKey(key) || consumed.contains(key)) return;
      final s = build();
      if (s.isEmpty) return;
      consumed.add(key);
      out.add((label: label, value: s, copyable: _isCopyableMetadataKey(key)));
    }

    // Prefer combined amount line when both present
    final cur = flat['currency']?.toString();
    if (flat.containsKey('amount') && cur != null && cur.isNotEmpty) {
      final a = flat['amount'];
      consumed.add('amount');
      consumed.add('currency');
      out.add((label: 'Amount', value: '$cur ${_formatNumberish(a)}', copyable: false));
    } else if (flat.containsKey('amount')) {
      take('amount', 'Amount', () => _formatNumberish(flat['amount']));
    }

    // Single Reference row (dedupe referenceId / reference_id / reference)
    final refVal = flat['referenceId'] ?? flat['reference_id'] ?? flat['reference'];
    if (refVal != null && refVal.toString().isNotEmpty) {
      for (final k in ['referenceId', 'reference_id', 'reference']) {
        if (flat.containsKey(k)) consumed.add(k);
      }
      out.add((label: 'Reference', value: refVal.toString(), copyable: false));
    }

    const orderedPairs = <(String, String)>[
      ('correlationId', 'Correlation ID'),
      ('correlation_id', 'Correlation ID'),
      ('fundingOrderId', 'Funding order ID'),
      ('funding_order_id', 'Funding order ID'),
      ('orderId', 'Order ID'),
      ('transactionId', 'Transaction ID'),
      ('currency', 'Currency'),
      ('newBalance', 'New balance'),
      ('orderType', 'Order type'),
      ('payoutMethod', 'Payout method'),
      ('paymentMethod', 'Payment method'),
      ('payment_method', 'Payment method'),
      ('bankName', 'Bank name'),
      ('mobileProvider', 'Mobile provider'),
      ('mobileProviderId', 'Mobile provider ID'),
      ('status', 'Status'),
      ('flow', 'Flow'),
      ('clientWalletCurrency', 'Wallet currency'),
      ('clientFiatBalance', 'Fiat balance'),
    ];
    for (final p in orderedPairs) {
      final key = p.$1;
      take(key, p.$2, () {
        final v = flat[key];
        if (key == 'newBalance' && v is num) {
          return v.toDouble().toStringAsFixed(2);
        }
        return _stringifyFlatValue(v);
      });
    }

    // Nested review.* with friendly labels
    const reviewLabels = <String, String>{
      'review.paymentMethod': 'Payment method',
      'review.paymentMethodId': 'Payment method ID',
      'review.country': 'Country',
      'review.countryCode': 'Country code',
      'review.phone': 'Phone',
      'review.processingFeeFormatted': 'Processing fee',
      'review.depositAmountFormatted': 'Deposit amount',
      'review.totalDueFormatted': 'Total due',
      'review.estimatedArrival': 'Estimated arrival',
      'review.bankName': 'Bank name',
      'review.accountNumberMasked': 'Account number',
      'review.mobileProvider': 'Mobile provider',
    };
    for (final e in reviewLabels.entries) {
      take(e.key, e.value, () => _stringifyFlatValue(flat[e.key]));
    }

    final remaining = flat.keys.where((k) => !consumed.contains(k)).toList()..sort();
    for (final k in remaining) {
      if (k == 'review') continue;
      final label = _humanizeKey(k.replaceFirst(RegExp(r'^review\.'), ''));
      out.add((
        label: label,
        value: _stringifyFlatValue(flat[k]),
        copyable: _isCopyableMetadataKey(k),
      ));
    }

    return out;
  }

  static String _stringifyFlatValue(dynamic v) {
    if (v == null) return '';
    if (v is Map || v is List) return v.toString();
    return v.toString();
  }

  static String _formatNumberish(dynamic v) {
    if (v == null) return '';
    if (v is num) {
      final d = v.toDouble();
      if ((d - d.roundToDouble()).abs() < 1e-9) return d.round().toString();
      return d.toStringAsFixed(2);
    }
    return v.toString();
  }

  static String _humanizeKey(String k) {
    if (k.isEmpty) return k;
    final spaced = k.replaceAllMapped(RegExp(r'([A-Z])'), (m) => ' ${m.group(1)}').trim();
    final parts = spaced.split(RegExp(r'[_\s]+')).where((s) => s.isNotEmpty);
    return parts.map((p) => p[0].toUpperCase() + p.substring(1).toLowerCase()).join(' ');
  }

  String _formatFullTimestamp(DateTime d) {
    final local = d.toLocal();
    final y = local.year;
    final mo = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final h = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$y-$mo-$day · $h:$min';
  }
}

class _NotificationTabBar extends StatelessWidget {
  const _NotificationTabBar({
    required this.selectedTab,
    required this.onChanged,
    this.enabled = true,
  });

  final _NotificationFilterTab selectedTab;
  final ValueChanged<_NotificationFilterTab> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final primary = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: IgnorePointer(
        ignoring: !enabled,
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(16),
            border: isDark
                ? null
                : Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            children: [
              _NotificationTab(
                label: 'Transaction',
                isSelected: selectedTab == _NotificationFilterTab.transaction,
                onTap: () => onChanged(_NotificationFilterTab.transaction),
                primary: primary,
                unselectedColor: colors.textSecondary,
              ),
              const SizedBox(width: 4),
              _NotificationTab(
                label: 'System',
                isSelected: selectedTab == _NotificationFilterTab.system,
                onTap: () => onChanged(_NotificationFilterTab.system),
                primary: primary,
                unselectedColor: colors.textSecondary,
              ),
              const SizedBox(width: 4),
              _NotificationTab(
                label: 'Promotions',
                isSelected: selectedTab == _NotificationFilterTab.promotions,
                onTap: () => onChanged(_NotificationFilterTab.promotions),
                primary: primary,
                unselectedColor: colors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationTab extends StatelessWidget {
  const _NotificationTab({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.primary,
    required this.unselectedColor,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color primary;
  final Color unselectedColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? primary : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isSelected
                  ? (isDark ? AppColors.backgroundDeepNavy : Colors.white)
                  : unselectedColor,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyNotifications extends StatelessWidget {
  final AppThemeColors colors;
  final Color primary;
  final _NotificationFilterTab tab;

  const _EmptyNotifications({
    required this.colors,
    required this.primary,
    required this.tab,
  });

  @override
  Widget build(BuildContext context) {
    final (icon, title, subtitle) = switch (tab) {
      _NotificationFilterTab.transaction => (
          Icons.receipt_long_outlined,
          'No transactions yet',
          'Payments, transfers, and top-ups will show up here.',
        ),
      _NotificationFilterTab.system => (
          Icons.notifications_none_rounded,
          'No system notifications',
          'Maintenance windows, outages, and service notices will show up here.',
        ),
      _NotificationFilterTab.promotions => (
          Icons.local_offer_outlined,
          'No promotions yet',
          'Offers and rewards will appear here when available.',
        ),
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 56,
                color: primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback? onTap;
  final bool isLoading;

  const _NotificationTile({
    required this.notification,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? colors.surface : Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(16),
            border: isDark ? null : Border.all(color: const Color(0xFFE5E7EB), width: 1),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: isLoading
                    ? Padding(
                        padding: const EdgeInsets.all(10),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: primary,
                        ),
                      )
                    : Icon(
                        _notificationIconFor(notification),
                        color: primary,
                        size: 22,
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 15,
                        fontWeight: notification.read ? FontWeight.w500 : FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.message,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 13,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (notification.createdAt != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        _formatDate(notification.createdAt!),
                        style: TextStyle(
                          color: colors.textTertiary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (isLoading)
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 4),
                  child: Text(
                    'Opening…',
                    style: TextStyle(
                      color: colors.textTertiary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                )
              else if (!notification.read)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(left: 8, top: 6),
                  decoration: BoxDecoration(
                    color: primary,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}
