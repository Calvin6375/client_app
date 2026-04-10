// Wallet Settings screen - profile, balance, security, preferences, network.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pretium/core/constants/app_colors.dart';
import 'package:pretium/core/theme/theme_provider.dart';
import 'package:pretium/repositories/user_repository.dart';
import 'package:pretium/repositories/wallet_repository.dart';
import 'package:pretium/services/auth_service.dart';
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

  bool _biometricEnabled = true;
  bool _twoFactorEnabled = false;
  bool _seedPhraseEnabled = false;
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
      if (mounted) {
        setState(() {
          _userName = profile?.fullName ?? 'User';
          _userEmail = profile?.email ?? user.email ?? '';
          _balance = wallet?.balance.toStringAsFixed(2) ?? '0.00';
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signOut() async {
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
            onPressed: () {},
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
                              backgroundColor: primary.withOpacity(0.2),
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
                      border: Border.all(color: colors.border.withOpacity(0.5)),
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
                  _SectionTitle(title: 'SECURITY'),
                  _SettingsTile(
                    icon: Icons.lock_outline,
                    title: 'Biometric Authentication',
                    trailing: Switch(
                      value: _biometricEnabled,
                      onChanged: (v) => setState(() => _biometricEnabled = v),
                      activeColor: primary,
                    ),
                  ),
                  _SettingsTile(
                    icon: Icons.shield_outlined,
                    title: 'Two-Factor Auth (2FA)',
                    subtitle: 'Enhanced account protection',
                    trailing: Switch(
                      value: _twoFactorEnabled,
                      onChanged: (v) => setState(() => _twoFactorEnabled = v),
                      activeColor: primary,
                    ),
                  ),
                  _SettingsTile(
                    icon: Icons.vpn_key_outlined,
                    title: 'Seed Phrase',
                    subtitle: 'View or backup your recovery phrase',
                    trailing: Switch(
                      value: _seedPhraseEnabled,
                      onChanged: (v) => setState(() => _seedPhraseEnabled = v),
                      activeColor: primary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _SectionTitle(title: 'PREFERENCES'),
                  _SettingsTile(
                    icon: Icons.attach_money,
                    title: 'Default Currency',
                    subtitle: 'USD (\$)',
                    trailing: const Icon(Icons.chevron_right),
                  ),
                  _SettingsTile(
                    icon: Icons.notifications_outlined,
                    title: 'Push Notifications',
                    trailing: Switch(
                      value: _pushNotificationsEnabled,
                      onChanged: (v) => setState(() => _pushNotificationsEnabled = v),
                      activeColor: primary,
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
                          activeColor: primary,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  _SectionTitle(title: 'NETWORK'),
                  _SettingsTile(
                    icon: Icons.account_tree_outlined,
                    title: 'Mainnet Node',
                    subtitle: 'Connected to Ethereum Mainnet',
                    trailing: const Icon(Icons.chevron_right),
                  ),
                  _SettingsTile(
                    icon: Icons.speed_outlined,
                    title: 'Gas Preference',
                    subtitle: 'Standard (Market Rate)',
                    trailing: const Icon(Icons.chevron_right),
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
                      'TruePay v1.0.0',
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
  final String? subtitle;
  final Widget trailing;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
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
        border: Border.all(color: colors.border.withOpacity(0.5)),
      ),
      child: ListTile(
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: primary.withOpacity(0.12),
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
        subtitle: subtitle != null
            ? Text(
                subtitle!,
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 13,
                ),
              )
            : null,
        trailing: trailing,
      ),
    );
  }
}
