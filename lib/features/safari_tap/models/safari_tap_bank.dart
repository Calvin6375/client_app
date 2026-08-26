class SafariTapBank {
  const SafariTapBank({required this.name, required this.code});

  final String name;
  final String code;

  factory SafariTapBank.fromJson(Map<String, dynamic> json) {
    return SafariTapBank(
      name: json['bank_name']?.toString() ?? '',
      code: json['bank_code']?.toString() ?? '',
    );
  }
}
