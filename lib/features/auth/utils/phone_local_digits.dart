/// Kenyan mobile local part: 9 digits starting with 7 (e.g. `742844875`).
final RegExp kenyaMobileLocalRegex = RegExp(r'^7\d{8}$');

final RegExp _kenyaMobileInDigits = RegExp(r'7\d{8}');

/// Strips trunk/country prefixes from a Kenyan number when +254 is already selected.
///
/// Handles pasted values like `0742844875`, `2540742844875`, `254742844875`,
/// or longer pasted strings where the real mobile is at the end
/// (e.g. `245742844875` → `742844875`).
String stripKenyaLocalDigits(String input) {
  var digits = input.replaceAll(RegExp(r'[^\d]'), '');
  if (digits.isEmpty) return digits;

  // Longest matching prefixes first.
  if (digits.startsWith('2540')) {
    digits = digits.substring(4);
  } else if (digits.startsWith('254')) {
    digits = digits.substring(3);
  } else if (digits.startsWith('0')) {
    digits = digits.substring(1);
  }

  if (digits.length <= 9) return digits;

  // Over-long paste: keep the mobile from the end, not the front prefix junk.
  final trailingNine = digits.substring(digits.length - 9);
  if (kenyaMobileLocalRegex.hasMatch(trailingNine)) {
    return trailingNine;
  }

  final match = _kenyaMobileInDigits.firstMatch(digits);
  if (match != null) return match.group(0)!;

  return trailingNine;
}

String? validatePhoneLocalDigits({
  required String? value,
  required String dialCode,
}) {
  final raw = value?.trim() ?? '';
  if (raw.isEmpty) return 'Please enter your phone number';

  final digits = raw.replaceAll(RegExp(r'[^\d]'), '');
  if (dialCode == '254') {
    final local = stripKenyaLocalDigits(digits);
    if (!kenyaMobileLocalRegex.hasMatch(local)) {
      return 'Enter a valid 9-digit Kenyan mobile number';
    }
    return null;
  }

  if (digits.length < 7 || digits.length > 15) {
    return 'Please enter a valid phone number';
  }
  return null;
}
