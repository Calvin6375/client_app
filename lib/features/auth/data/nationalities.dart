/// Nationality options for registration and profile forms.
final class NationalityOption {
  const NationalityOption({
    required this.name,
    required this.isoCode,
    required this.flag,
  });

  final String name;
  final String isoCode;
  final String flag;
}

/// Curated list for C2B registration (Africa-focused + common international).
const List<NationalityOption> kNationalities = [
  NationalityOption(name: 'Burundi', isoCode: 'BI', flag: '🇧🇮'),
  NationalityOption(name: 'Cameroon', isoCode: 'CM', flag: '🇨🇲'),
  NationalityOption(name: 'China', isoCode: 'CN', flag: '🇨🇳'),
  NationalityOption(name: 'DR Congo', isoCode: 'CD', flag: '🇨🇩'),
  NationalityOption(name: 'Egypt', isoCode: 'EG', flag: '🇪🇬'),
  NationalityOption(name: 'Ethiopia', isoCode: 'ET', flag: '🇪🇹'),
  NationalityOption(name: 'Ghana', isoCode: 'GH', flag: '🇬🇭'),
  NationalityOption(name: 'India', isoCode: 'IN', flag: '🇮🇳'),
  NationalityOption(name: 'Kenya', isoCode: 'KE', flag: '🇰🇪'),
  NationalityOption(name: 'Malawi', isoCode: 'MW', flag: '🇲🇼'),
  NationalityOption(name: 'Morocco', isoCode: 'MA', flag: '🇲🇦'),
  NationalityOption(name: 'Mozambique', isoCode: 'MZ', flag: '🇲🇿'),
  NationalityOption(name: 'Nigeria', isoCode: 'NG', flag: '🇳🇬'),
  NationalityOption(name: 'Rwanda', isoCode: 'RW', flag: '🇷🇼'),
  NationalityOption(name: 'Senegal', isoCode: 'SN', flag: '🇸🇳'),
  NationalityOption(name: 'South Africa', isoCode: 'ZA', flag: '🇿🇦'),
  NationalityOption(name: 'Tanzania', isoCode: 'TZ', flag: '🇹🇿'),
  NationalityOption(name: 'Uganda', isoCode: 'UG', flag: '🇺🇬'),
  NationalityOption(name: 'United Arab Emirates', isoCode: 'AE', flag: '🇦🇪'),
  NationalityOption(name: 'United Kingdom', isoCode: 'GB', flag: '🇬🇧'),
  NationalityOption(name: 'United States', isoCode: 'US', flag: '🇺🇸'),
  NationalityOption(name: 'Zambia', isoCode: 'ZM', flag: '🇿🇲'),
  NationalityOption(name: 'Zimbabwe', isoCode: 'ZW', flag: '🇿🇼'),
];

NationalityOption? nationalityByIsoCode(String? isoCode) {
  if (isoCode == null || isoCode.isEmpty) return null;
  final upper = isoCode.toUpperCase();
  for (final n in kNationalities) {
    if (n.isoCode == upper) return n;
  }
  return null;
}
