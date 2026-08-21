class SafariCardBank {
  const SafariCardBank({required this.name, required this.code});

  final String name;
  final String code;

  factory SafariCardBank.fromJson(Map<String, dynamic> json) {
    return SafariCardBank(
      name: json['bank_name']?.toString() ?? '',
      code: json['bank_code']?.toString() ?? '',
    );
  }
}
