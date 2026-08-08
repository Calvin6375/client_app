// Wallet Settings screen - profile, balance, security, preferences.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pretium/core/constants/app_colors.dart';
import 'package:pretium/core/theme/theme_provider.dart';
import 'package:pretium/repositories/user_repository.dart';
import 'package:pretium/repositories/wallet_repository.dart';
import 'package:pretium/services/auth_service.dart';
import 'package:pretium/services/biometric_session_service.dart';
import 'package:pretium/utils/async_action_guard.dart';
import 'package:pretium/app/route_names.dart';

class WalletSettingsPage extends StatefulWidget {
  const WalletSettingsPage({super.key});

  @override
  State<WalletSettingsPage> createState() => _WalletSettingsPageState();
}

class _WalletSettingsPageState extends State<WalletSettingsPage> {
  final UserRepository _userRepository = UserRepository();
  final WalletRepository _walletRepository = WalletRepository();
  final AuthService _authService = AuthService();
  final BiometricSessionService _biometricSession =
      BiometricSessionService.instance;
  final _biometricToggleGuard = AsyncActionGuard();
  final _signOutGuard = AsyncActionGuard();

  bool _biometricEnabled = false;
  bool _pushNotificationsEnabled = true;
  String _balance = '0.00';
  String _userName = '';
  String _userEmail = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final profile = await _userRepository.getUserProfile(user.uid);
      final wallet = await _walletRepository.getWalletBalance(user.uid);
      final biometricEnabled = await _biometricSession.isBiometricLoginEnabled();
      if (mounted) {
        setState(() {
          _userName = profile?.fullName ?? 'User';
          _userEmail = profile?.email ?? user.email ?? '';
          _balance = wallet?.balance.toStringAsFixed(2) ?? '0.00';
          _biometricEnabled = biometricEnabled;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleBiometric(bool enabled) async {
    await _biometricToggleGuard.run(() async {
      if (!enabled) {
        await _biometricSession.disableBiometricLogin();
        if (mounted) setState(() => _biometricEnabled = false);
        return;
      }

      if (!await _biometricSession.isDeviceSupported()) {
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
        email: _userEmail,
        password: password,
      );
      if (mounted) setState(() => _biometricEnabled = true);
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
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile
                  Center(
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 44,
                              backgroundColor: primary.withValues(alpha: 0.2),
                              child: Text(
                                _userName.isNotEmpty ? _userName[0].toUpperCase() : '?',
                                style: TextStyle(
                                  fontSize: 32,
                                  color: primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: CircleAvatar(
                                radius: 14,
                                backgroundColor: primary,
                                child: Icon(Icons.edit, size: 16, color: colors.onPrimary),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _userName,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _userEmail,
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Balance card
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '\$$_balance',
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 24,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: colors.successLight,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '+2.4%',
                                style: TextStyle(
                                  color: colors.success,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Wallet Address',
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '0x71C...8a29',
                                style: TextStyle(
                                  color: colors.textPrimary,
                                  fontSize: 14,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy, size: 20),
                              onPressed: () {},
                            ),
                            TextButton(
                              onPressed: () {},
                              child: const Text('Manage'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  const _SectionTitle(title: 'SECURITY'),
                  _SettingsTile(
                    icon: Icons.lock_outline,
                    title: 'Biometric Authentication',
                    trailing: Switch(
                      value: _biometricEnabled,
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
                    trailing: Consumer<ThemeProvider>(
                      builder: (context, themeProvider, _) {
                        final isDark = themeProvider.themeMode == ThemeMode.dark ||
                            (themeProvider.themeMode == ThemeMode.system &&
                                MediaQuery.platformBrightnessOf(context) == Brightness.dark);
                        return Switch(
                          value: isDark,
                          onChanged: (_) => themeProvider.toggleTheme(),
                          activeThumbColor: primary,
                        );
                      },
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
                      'SafariTap v1.0.0',
                      style: TextStyle(
                        color: colors.textTertiary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Center(
                    child: Text(
                      'Securely encrypted',
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
