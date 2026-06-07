import 'package:flutter/material.dart';
import 'package:pretium/core/constants/app_colors.dart';
import 'package:pretium/features/crypto/models/crypto_send_result.dart';
import 'package:pretium/features/crypto/services/crypto_api_service.dart';
import 'package:uuid/uuid.dart';

class UsdcSendScreen extends StatefulWidget {
  const UsdcSendScreen({super.key, this.availableBalance});

  /// Pre-fetched available balance; refreshed on confirm if null.
  final double? availableBalance;

  @override
  State<UsdcSendScreen> createState() => _UsdcSendScreenState();
}

class _UsdcSendScreenState extends State<UsdcSendScreen> {
  final CryptoApiService _cryptoApi = CryptoApiService();
  final _addressCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  double? _availableBalance;
  bool _loadingBalance = false;
  bool _submitting = false;
  CryptoSendResult? _pendingResult;

  @override
  void initState() {
    super.initState();
    _availableBalance = widget.availableBalance;
    if (_availableBalance == null) {
      _refreshBalance();
    }
  }

  @override
  void dispose() {
    _addressCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _refreshBalance() async {
    setState(() => _loadingBalance = true);
    try {
      final balance = await _cryptoApi.getBalance();
      if (!mounted) return;
      setState(() {
        _availableBalance = balance;
        _loadingBalance = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingBalance = false);
    }
  }

  bool _isValidEvmAddress(String value) {
    final trimmed = value.trim();
    if (!trimmed.startsWith('0x') || trimmed.length != 42) return false;
    return RegExp(r'^0x[0-9a-fA-F]{40}$').hasMatch(trimmed);
  }

  Future<void> _confirmSend() async {
    if (!_formKey.currentState!.validate()) return;

    await _refreshBalance();
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    final balance = _availableBalance ?? 0;

    if (amount > balance) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Insufficient USDC balance')),
      );
      return;
    }

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm send'),
        content: Text(
          'Send ${amount.toStringAsFixed(2)} USDC to\n${_addressCtrl.text.trim()}?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Send')),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _submitting = true);
    final idempotencyKey = const Uuid().v4();

    try {
      final result = await _cryptoApi.sendUsdc(
        toAddress: _addressCtrl.text.trim(),
        amount: amount,
        idempotencyKey: idempotencyKey,
      );
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _pendingResult = result;
      });
      _showPendingDialog(result);
    } on CryptoApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      final message = switch (e.statusCode) {
        429 => 'Too many sends. Please wait a minute and try again.',
        409 => 'Send already in progress. Please wait.',
        400 => e.message ?? 'Invalid send request',
        _ => e.message ?? 'Send failed',
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Send failed: $e'), backgroundColor: Colors.red.shade700),
      );
    }
  }

  void _showPendingDialog(CryptoSendResult result) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Processing'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Your send of ${result.amount.toStringAsFixed(2)} USDC is being processed. '
              'Your balance will update when the transaction completes.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context, true);
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Send USDC'),
        backgroundColor: colors.background,
        foregroundColor: colors.textPrimary,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Available', style: TextStyle(color: colors.textSecondary)),
                  _loadingBalance
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: primary),
                        )
                      : Text(
                          '${(_availableBalance ?? 0).toStringAsFixed(2)} USDC',
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _addressCtrl,
              decoration: const InputDecoration(
                labelText: 'Recipient address',
                hintText: '0x…',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter recipient address';
                }
                if (!_isValidEvmAddress(value)) {
                  return 'Enter a valid EVM address (0x + 40 hex chars)';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount (USDC)',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final amount = double.tryParse(value?.trim() ?? '');
                if (amount == null || amount <= 0) {
                  return 'Enter a valid amount';
                }
                return null;
              },
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _submitting ? null : _confirmSend,
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Send USDC'),
            ),
            if (_pendingResult != null) ...[
              const SizedBox(height: 16),
              Text(
                'Last send status: ${_pendingResult!.status}',
                style: TextStyle(color: colors.textSecondary, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
