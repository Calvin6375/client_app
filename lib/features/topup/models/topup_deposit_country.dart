/// Supported fiat top-up / direct-deposit countries.
/// Kept in one place so [SelectCountryTopUpScreen] and [DirectFiatDepositScreen] stay aligned.
///
/// The backend `/api/countries` may return ISO 3166-1 alpha-2 codes and/or
/// ISO 4217 currency codes; [fromIsoAlpha2] and [forDepositCode] map them.
class TopupDepositCountry {
  const TopupDepositCountry({
    required this.name,
    required this.currencyName,
    required this.code,
    required this.flagEmoji,
  });

  final String name;
  final String currencyName;

  /// ISO 4217 currency code (wallet / fees / dial logic).
  final String code;
  final String flagEmoji;

  static const TopupDepositCountry nigeria = TopupDepositCountry(
    name: 'Nigeria',
    currencyName: 'Nigerian Naira',
    code: 'NGN',
    flagEmoji: '🇳🇬',
  );

  static const TopupDepositCountry kenya = TopupDepositCountry(
    name: 'Kenya',
    currencyName: 'Kenyan Shilling',
    code: 'KES',
    flagEmoji: '🇰🇪',
  );

  static const TopupDepositCountry ghana = TopupDepositCountry(
    name: 'Ghana',
    currencyName: 'Ghanaian Cedi',
    code: 'GHS',
    flagEmoji: '🇬🇭',
  );

  static const TopupDepositCountry uganda = TopupDepositCountry(
    name: 'Uganda',
    currencyName: 'Ugandan Shilling',
    code: 'UGX',
    flagEmoji: '🇺🇬',
  );

  static const TopupDepositCountry tanzania = TopupDepositCountry(
    name: 'Tanzania',
    currencyName: 'Tanzanian Shilling',
    code: 'TZS',
    flagEmoji: '🇹🇿',
  );

  static const TopupDepositCountry ethiopia = TopupDepositCountry(
    name: 'Ethiopia',
    currencyName: 'Ethiopian Birr',
    code: 'ETB',
    flagEmoji: '🇪🇹',
  );

  static const TopupDepositCountry burundi = TopupDepositCountry(
    name: 'Burundi',
    currencyName: 'Burundian Franc',
    code: 'BIF',
    flagEmoji: '🇧🇮',
  );

  static const TopupDepositCountry unitedStates = TopupDepositCountry(
    name: 'United States',
    currencyName: 'US Dollar',
    code: 'USD',
    flagEmoji: '🇺🇸',
  );

  static const TopupDepositCountry unitedArabEmirates = TopupDepositCountry(
    name: 'United Arab Emirates',
    currencyName: 'UAE Dirham',
    code: 'AED',
    flagEmoji: '🇦🇪',
  );

  static const TopupDepositCountry china = TopupDepositCountry(
    name: 'China',
    currencyName: 'Chinese Yuan',
    code: 'CNY',
    flagEmoji: '🇨🇳',
  );

  static const TopupDepositCountry drCongo = TopupDepositCountry(
    name: 'Democratic Republic of the Congo',
    currencyName: 'Congolese Franc',
    code: 'CDF',
    flagEmoji: '🇨🇩',
  );

  /// Countries available for direct fiat deposit (top-up) when chosen from the in-flow wizard.
  static const List<TopupDepositCountry> depositSupported =
      <TopupDepositCountry>[
    nigeria,
    kenya,
    ghana,
    uganda,
    tanzania,
    ethiopia,
    burundi,
    unitedStates,
    unitedArabEmirates,
    china,
    drCongo,
  ];

  /// All ISO 4217 codes from [depositSupported], for dropdowns and validation.
  static List<String> get depositCurrencyCodes =>
      depositSupported.map((c) => c.code).toList(growable: false);

  /// Withdrawal wizard is Kenya-only.
  static const List<TopupDepositCountry> withdrawSupported =
      <TopupDepositCountry>[kenya];

  /// Maps API [isoAlpha2] (e.g. `KE`, `NG`) to a catalog entry. Add cases when backend enables new countries.
  static TopupDepositCountry? fromIsoAlpha2(String isoAlpha2) {
    switch (isoAlpha2.trim().toUpperCase()) {
      case 'NG':
        return nigeria;
      case 'KE':
        return kenya;
      case 'GH':
        return ghana;
      case 'UG':
        return uganda;
      case 'TZ':
        return tanzania;
      case 'ET':
        return ethiopia;
      case 'BI':
        return burundi;
      case 'US':
        return unitedStates;
      case 'AE':
        return unitedArabEmirates;
      case 'CN':
        return china;
      case 'CD':
        return drCongo;
      default:
        return null;
    }
  }

  static TopupDepositCountry? forDepositCode(String code) {
    final u = code.trim().toUpperCase();
    for (final c in depositSupported) {
      if (c.code == u) return c;
    }
    return null;
  }

  /// Resolves an API country/currency code to a catalog entry.
  /// Unknown codes get a generic fallback so the backend list is never dropped.
  static TopupDepositCountry resolve(String code) {
    final trimmed = code.trim().toUpperCase();
    return fromIsoAlpha2(trimmed) ??
        forDepositCode(trimmed) ??
        TopupDepositCountry(
          name: trimmed,
          currencyName: trimmed,
          code: trimmed,
          flagEmoji: '🌍',
        );
  }
}
