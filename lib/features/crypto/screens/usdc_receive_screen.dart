import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pretium/core/constants/app_colors.dart';
import 'package:pretium/features/crypto/models/crypto_wallet_info.dart';
import 'package:pretium/features/crypto/screens/crypto_transactions_screen.dart';
import 'package:pretium/features/crypto/services/crypto_api_service.dart';

class UsdcReceiveScreen extends StatefulWidget {
  const UsdcReceiveScreen({super.key});

  @override
  State<UsdcReceiveScreen> createState() => _UsdcReceiveScreenState();
}

class _UsdcReceiveScreenState extends State<UsdcReceiveScreen> {
  final CryptoApiService _cryptoApi = CryptoApiService();

  CryptoWalletInfo? _wallet;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadWallet();
  }

  Future<void> _loadWallet() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final wallet = await _cryptoApi.getWallet();
      if (!mounted) return;
      setState(() {
        _wallet = wallet;
        _loading = false;
      });
    } on CryptoApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message ?? 'Failed to load deposit address';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _copyAddress(String address) async {
    await Clipboard.setData(ClipboardData(text: address));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Address copied')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Receive USDC'),
        backgroundColor: colors.background,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Transactions',
            onPressed: () {
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => const CryptoTransactionsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadWallet,
        color: primary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(48),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_error != null)
              _ErrorState(message: _error!, onRetry: _loadWallet)
            else if (_wallet != null)
              _WalletContent(
                wallet: _wallet!,
                onCopy: _copyAddress,
              ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 32),
        Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
        const SizedBox(height: 16),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 24),
        ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    );
  }
}

class _WalletContent extends StatelessWidget {
  const _WalletContent({required this.wallet, required this.onCopy});

  final CryptoWalletInfo wallet;
  final Future<void> Function(String) onCopy;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final primary = Theme.of(context).colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: primary.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Only send USDC on ${wallet.chain}. Sending on another network may result in lost funds.',
                  style: TextStyle(color: colors.textPrimary, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (wallet.qrDataUrl != null && wallet.qrDataUrl!.startsWith('data:image'))
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                base64Decode(wallet.qrDataUrl!.split(',').last),
                width: 220,
                height: 220,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(Icons.qr_code_2, size: 120),
              ),
            ),
          )
        else
          Center(
            child: Icon(Icons.qr_code_2, size: 120, color: colors.textSecondary),
          ),
        const SizedBox(height: 24),
        Text(
          'Your deposit address',
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.border),
          ),
          child: SelectableText(
            wallet.address,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 14,
              fontFamily: 'monospace',
            ),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () => onCopy(wallet.address),
          icon: const Icon(Icons.copy),
          label: const Text('Copy address'),
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Send USDC from an external wallet to this address. Your balance will update automatically once the deposit is confirmed.',
          style: TextStyle(color: colors.textSecondary, fontSize: 13),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
