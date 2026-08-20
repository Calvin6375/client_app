import 'package:flutter/material.dart';

/// Renders a currency mark: asset logos for USDT/USDC, emoji (or icon) otherwise.
class CurrencyLogo extends StatelessWidget {
  const CurrencyLogo({
    super.key,
    required this.code,
    this.size = 20,
    this.fallbackEmoji,
  });

  final String code;
  final double size;
  final String? fallbackEmoji;

  static String? assetPathFor(String code) {
    switch (code.trim().toUpperCase()) {
      case 'USDT':
        return 'assets/icons/usdt-logo.png';
      case 'USDC':
        return 'assets/icons/usdc-logo.png';
      default:
        return null;
    }
  }

  static String? defaultEmojiFor(String code) {
    switch (code.trim().toUpperCase()) {
      case 'USD':
        return '🇺🇸';
      case 'KES':
        return '🇰🇪';
      case 'NGN':
        return '🇳🇬';
      case 'GHS':
        return '🇬🇭';
      case 'UGX':
        return '🇺🇬';
      case 'EUR':
        return '🇪🇺';
      case 'GBP':
        return '🇬🇧';
      default:
        return null;
    }
  }

  static bool hasAssetLogo(String code) => assetPathFor(code) != null;

  @override
  Widget build(BuildContext context) {
    final asset = assetPathFor(code);
    if (asset != null) {
      return Image.asset(
        asset,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _fallback(context),
      );
    }
    return _fallback(context);
  }

  Widget _fallback(BuildContext context) {
    final emoji = fallbackEmoji ?? defaultEmojiFor(code);
    if (emoji != null && emoji.isNotEmpty) {
      return Text(emoji, style: TextStyle(fontSize: size * 0.9, height: 1));
    }
    return Icon(
      Icons.currency_bitcoin,
      size: size,
      color: Theme.of(context).colorScheme.onSurface,
    );
  }
}
