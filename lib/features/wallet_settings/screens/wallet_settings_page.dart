// Wallet Settings screen - profile, balance, security, preferences.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pretium/core/constants/app_colors.dart';
import 'package:pretium/core/providers/auth_providers.dart';
import 'package:pretium/core/providers/biometric_enabled_provider.dart';
import 'package:pretium/core/providers/recent_transactions_provider.dart';
import 'package:pretium/core/providers/user_profile_provider.dart';
import 'package:pretium/core/providers/wallet_accounts_provider.dart';
import 'package:pretium/core/theme/theme_provider.dart';
import 'package:pretium/features/topup/utils/receipt_image_export.dart';
import 'package:pretium/models/user_model.dart';
import 'package:pretium/services/auth_service.dart';
import 'package:pretium/services/biometric_session_service.dart';
import 'package:pretium/utils/async_action_guard.dart';
import 'package:pretium/utils/share_image.dart';
import 'package:pretium/app/route_names.dart';
import 'package:pretium/features/wallet_settings/providers/user_settings_provider.dart';
import 'package:pretium/widgets/app_shimmer.dart';
import 'package:pretium/widgets/tappable_user_avatar.dart';
import 'package:pretium/widgets/truepay_qr_code.dart';

class WalletSettingsPage extends ConsumerStatefulWidget {
  const WalletSettingsPage({super.key});

  @override
  ConsumerState<WalletSettingsPage> createState() => _WalletSettingsPageState();
}

class _WalletSettingsPageState extends ConsumerState<WalletSettingsPage> {
  final AuthService _authService = AuthService();
  final BiometricSessionService _biometricSession =
      BiometricSessionService.instance;
  final _biometricToggleGuard = AsyncActionGuard();
  final _signOutGuard = AsyncActionGuard();

  bool _pushNotificationsEnabled = true;

  String _resolvedUserName(UserModel? profile) {
    final name = profile?.fullName.trim() ?? '';
    return name.isNotEmpty ? name : 'User';
  }

  String _resolvedUserEmail(UserModel? profile) {
    final fromProfile = profile?.email.trim() ?? '';
    if (fromProfile.isNotEmpty) return fromProfile;
    return ref.read(currentUserProvider)?.email ?? '';
  }

  Future<void> _showProfileQr() async {
    final settings = ref.read(userSettingsProvider);
    if (settings.loadingQr) return;
    if (settings.profileQr == null ||
        settings.profileQr!.qrPayload.trim().isEmpty) {
      await ref.read(userSettingsProvider.notifier).loadProfileQr();
      if (!mounted) return;
    }
    final qr = ref.read(userSettingsProvider).profileQr;
    final payload = qr?.qrPayload.trim() ?? '';
    if (payload.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your receive QR is not available yet.')),
      );
      return;
    }
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return _SafariTapQrDialog(
          payload: payload,
          displayName: qr?.displayName.isNotEmpty == true
              ? qr!.displayName
              : _resolvedUserName(ref.read(userProfileProvider).valueOrNull),
        );
      },
    );
  }

  Future<void> _toggleBiometric(bool enabled) async {
    await _biometricToggleGuard.run(() async {
      if (!enabled) {
        await _biometricSession.disableBiometricLogin();
        if (mounted) {
          ref.read(biometricEnabledProvider.notifier).setLocal(false);
        }
        return;
      }

      if (!await _biometricSession.hasUsableBiometrics()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Biometrics are not available on this device.')),
        );
        return;
      }

      final password = await _promptForPassword();
      if (password == null || password.isEmpty) return;

      final verified = await _biometricSession.authenticate(
        reason: 'Verify your identity to enable biometric login',
      );
      if (!verified) return;

      await _biometricSession.enableBiometricLogin(
        email: _resolvedUserEmail(ref.read(userProfileProvider).valueOrNull),
        password: password,
      );
      if (mounted) {
        ref.read(biometricEnabledProvider.notifier).setLocal(true);
      }
    });
  }

  Future<String?> _promptForPassword() async {
    return showDialog<String>(
      context: context,
      builder: (ctx) => const _PasswordConfirmDialog(),
    );
  }

  Future<void> _signOut() async {
    await _signOutGuard.run(() async {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Sign Out'),
          content: const Text('Are you sure you want to sign out?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Sign Out'),
            ),
          ],
        ),
      );
      if (confirm == true) {
        await _authService.signOut();
        ref.invalidate(walletAccountsProvider);
        ref.invalidate(recentTransactionsProvider);
        ref.invalidate(userProfileProvider);
        ref.invalidate(biometricEnabledProvider);
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            RouteNames.login,
            (route) => false,
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final primary = Theme.of(context).colorScheme.primary;
    final themeMode = ref.watch(themeControllerProvider);
    final profileAsync = ref.watch(userProfileProvider);
    final walletsAsync = ref.watch(walletAccountsProvider);
    final biometricAsync = ref.watch(biometricEnabledProvider);
    final profile = profileAsync.valueOrNull;
    final userName = _resolvedUserName(profile);
    final userEmail = _resolvedUserEmail(profile);
    final kesBalance =
        walletsAsync.valueOrNull?.fiatWallets['KES']?.balance ?? 0;
    final biometricEnabled = biometricAsync.valueOrNull ?? false;
    final loading = profileAsync.isLoading &&
        walletsAsync.isLoading &&
        biometricAsync.isLoading;

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
          'Wallet Settings',
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () =>
                Navigator.of(context).pushNamed(RouteNames.contactSupport),
            color: colors.textPrimary,
          ),
        ],
      ),
      body: loading
          ? const SettingsPageShimmer()
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile
                  Center(
                    child: Column(
                      children: [
                        TappableUserAvatar(
                          initial: userName.isNotEmpty
                              ? userName[0].toUpperCase()
                              : '?',
                          radius: 44,
                          pulse: true,
                          tooltip: 'Show receive QR',
                          badgeIcon: ref.watch(userSettingsProvider).loadingQr
                              ? Icons.hourglass_top_rounded
                              : Icons.qr_code_2_rounded,
                          onTap: _showProfileQr,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Tap to show your QR',
                          style: TextStyle(
                            color: primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          userName,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colors.border.withValues(alpha: 0.5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current Balance',
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'KES ${kesBalance.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 24,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Material(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      onTap: () {
                        Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (_) => _ProfileDetailsPage(
                              profile: profile,
                              fallbackEmail: userEmail,
                            ),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: colors.border.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: primary.withValues(alpha: 0.12),
                              child: Icon(
                                Icons.person_outline_rounded,
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
                                    'Profile',
                                    style: TextStyle(
                                      color: colors.textPrimary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'View your name, phone number, and more',
                                    style: TextStyle(
                                      color: colors.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: colors.textTertiary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  const _SectionTitle(title: 'SECURITY'),
                  _SettingsTile(
                    icon: Icons.lock_outline,
                    title: 'Biometric Authentication',
                    trailing: Switch(
                      value: biometricEnabled,
                      onChanged: _toggleBiometric,
                      activeThumbColor: primary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const _SectionTitle(title: 'PREFERENCES'),
                  _SettingsTile(
                    icon: Icons.notifications_outlined,
                    title: 'Push Notifications',
                    trailing: Switch(
                      value: _pushNotificationsEnabled,
                      onChanged: (v) => setState(() => _pushNotificationsEnabled = v),
                      activeThumbColor: primary,
                    ),
                  ),
                  _SettingsTile(
                    icon: Icons.dark_mode_outlined,
                    title: 'Dark Mode',
                    trailing: Switch(
                      value: themeMode == ThemeMode.dark ||
                          (themeMode == ThemeMode.system &&
                              MediaQuery.platformBrightnessOf(context) ==
                                  Brightness.dark),
                      onChanged: (_) => ref
                          .read(themeControllerProvider.notifier)
                          .toggleTheme(),
                      activeThumbColor: primary,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Center(
                    child: TextButton.icon(
                      onPressed: _signOut,
                      icon: const Icon(Icons.logout, size: 20),
                      label: const Text('Sign Out'),
                      style: TextButton.styleFrom(
                        foregroundColor: colors.error,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      'version: 1.0.0+14',
                      style: TextStyle(
                        color: colors.textTertiary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }
}

class _SafariTapQrDialog extends StatefulWidget {
  const _SafariTapQrDialog({
    required this.payload,
    required this.displayName,
  });

  final String payload;
  final String displayName;

  @override
  State<_SafariTapQrDialog> createState() => _SafariTapQrDialogState();
}

class _SafariTapQrDialogState extends State<_SafariTapQrDialog> {
  final GlobalKey _qrCardKey = GlobalKey();
  bool _busy = false;

  Rect? _shareOrigin(BuildContext buttonContext) {
    final box = buttonContext.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  Future<Uint8List?> _captureQrPng() async {
    await WidgetsBinding.instance.endOfFrame;
    return ReceiptImageExport.captureRepaintBoundaryPng(_qrCardKey);
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _share(BuildContext buttonContext) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final png = await _captureQrPng();
      if (png == null || png.isEmpty) {
        _toast('Could not capture QR. Try again.');
        return;
      }
      final stamp = DateTime.now().millisecondsSinceEpoch;
      await sharePngImage(
        pngBytes: png,
        fileBaseName: 'truepay_safaritap_qr_$stamp',
        subject: 'My SafariTap QR',
        text: 'Scan this QR to send to my SafariTap wallet.',
        // ignore: use_build_context_synchronously
        sharePositionOrigin: _shareOrigin(buttonContext),
        onMessage: _toast,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _download() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final png = await _captureQrPng();
      if (png == null || png.isEmpty) {
        _toast('Could not capture QR. Try again.');
        return;
      }
      final stamp = DateTime.now().millisecondsSinceEpoch;
      await savePngToGallery(
        pngBytes: png,
        fileBaseName: 'truepay_safaritap_qr_$stamp',
        onMessage: (m) {
          _toast(m == 'Saved to gallery' ? 'QR saved to gallery' : m);
        },
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final surface = Theme.of(context).colorScheme.surface;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'My SafariTap QR',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 16),
              RepaintBoundary(
                key: _qrCardKey,
                child: ColoredBox(
                  color: surface,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.displayName,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TruePayQrCode(data: widget.payload, size: 220),
                      const SizedBox(height: 12),
                      Text(
                        'Others can scan this to send to your SafariTap wallet.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _busy ? null : _download,
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: const Text('Download'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: Builder(
                  builder: (buttonContext) {
                    return OutlinedButton.icon(
                      onPressed: _busy ? null : () => _share(buttonContext),
                      icon: const Icon(Icons.ios_share_rounded, size: 18),
                      label: const Text('Share'),
                    );
                  },
                ),
              ),
              TextButton(
                onPressed: _busy ? null : () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PasswordConfirmDialog extends StatefulWidget {
  const _PasswordConfirmDialog();

  @override
  State<_PasswordConfirmDialog> createState() => _PasswordConfirmDialogState();
}

class _PasswordConfirmDialogState extends State<_PasswordConfirmDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Confirm password'),
      content: TextField(
        controller: _controller,
        obscureText: true,
        autofocus: true,
        onSubmitted: (value) => Navigator.of(context).pop(value),
        decoration: const InputDecoration(
          labelText: 'Password',
          hintText: 'Enter your account password',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          color: colors.textTertiary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget trailing;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border.withValues(alpha: 0.5)),
      ),
      child: ListTile(
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: primary.withValues(alpha: 0.12),
          child: Icon(icon, color: primary, size: 22),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w500,
            fontSize: 15,
          ),
        ),
        trailing: trailing,
      ),
    );
  }
}

class _ProfileDetailsPage extends StatelessWidget {
  const _ProfileDetailsPage({
    required this.profile,
    required this.fallbackEmail,
  });

  final UserModel? profile;
  final String fallbackEmail;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final email = (profile?.email.trim().isNotEmpty == true)
        ? profile!.email.trim()
        : fallbackEmail.trim();
    final rows = <(String, String)>[
      ('First name', profile?.firstName.trim() ?? ''),
      ('Last name', profile?.lastName.trim() ?? ''),
      ('Full name', profile?.fullName ?? ''),
      ('Email', email),
      ('Phone number', profile?.phoneNumber?.trim() ?? ''),
      ('Country', profile?.country?.trim() ?? ''),
      ('City', profile?.city?.trim() ?? ''),
      ('State', profile?.state?.trim() ?? ''),
      ('Street address', profile?.streetAddress?.trim() ?? ''),
      ('Postal code', profile?.postalCode?.trim() ?? ''),
    ].where((row) => row.$2.isNotEmpty).toList();

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Profile',
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        iconTheme: IconThemeData(color: colors.textPrimary),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.border.withValues(alpha: 0.5)),
            ),
            child: Column(
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      color: colors.border.withValues(alpha: 0.45),
                    ),
                  _ProfileFieldRow(
                    label: rows[i].$1,
                    value: rows[i].$2.isEmpty ? '—' : rows[i].$2,
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

class _ProfileFieldRow extends StatelessWidget {
  const _ProfileFieldRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
