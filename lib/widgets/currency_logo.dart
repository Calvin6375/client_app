import 'package:flutter/material.dart';
import 'package:pretium/features/topup/models/topup_deposit_country.dart';

/// Renders a currency mark: PNG logos for USDT/USDC, flag emoji for fiat.
class CurrencyLogo extends StatelessWidget {
  const CurrencyLogo({
    super.key,
    required this.code,
    this.size = 20,
    this.fallbackEmoji,
  });

  final String code;
  final double size;

  /// Optional override. Prefer omitting this so [emojiFor] can resolve flags.
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

  /// Flag / symbol for [code]. Fiat uses [TopupDepositCountry]; crypto uses glyphs.
  static String emojiFor(String code) {
    final upper = code.trim().toUpperCase();
    switch (upper) {
      case 'USDT':
        return '₮';
      case 'USDC':
        return '🇺🇸';
      default:
        return TopupDepositCountry.flagEmojiForCode(upper);
    }
  }

  @Deprecated('Use emojiFor')
  static String? defaultEmojiFor(String code) => emojiFor(code);

  static String displayNameFor(String code) {
    final upper = code.trim().toUpperCase();
    switch (upper) {
      case 'USDT':
        return 'Tether';
      case 'USDC':
        return 'USD Coin';
      default:
        return TopupDepositCountry.resolve(upper).currencyName;
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
        errorBuilder: (_, __, ___) => _emojiMark(context),
      );
    }
    return _emojiMark(context);
  }

  Widget _emojiMark(BuildContext context) {
    final emoji = (fallbackEmoji != null &&
            fallbackEmoji!.isNotEmpty &&
            fallbackEmoji != '💱' &&
            fallbackEmoji != '🌍')
        ? fallbackEmoji!
        : emojiFor(code);

    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Text(
          emoji,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: size * 0.92,
            height: 1.05,
          ),
        ),
      ),
    );
  }
}
