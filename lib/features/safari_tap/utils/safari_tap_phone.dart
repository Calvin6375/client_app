/// Normalizes Kenyan mobile numbers to `2547XXXXXXXX` when possible.
String normalizeKenyaPhone(String input) {
  final digits = input.replaceAll(RegExp(r'[^\d]'), '');
  if (digits.isEmpty) return digits;
  if (digits.startsWith('254')) return digits;
  if (digits.startsWith('0') && digits.length >= 10) {
    return '254${digits.substring(1)}';
  }
  if (digits.length == 9) return '254$digits';
  return digits;
}
