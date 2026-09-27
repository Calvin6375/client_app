class SafariTapUserValidate {
  const SafariTapUserValidate({
    required this.valid,
    required this.customerId,
    required this.fullName,
    required this.nameEditable,
    required this.self,
    this.phoneNumber,
  });

  final bool valid;
  final String customerId;
  final String fullName;
  final bool nameEditable;
  final bool self;
  final String? phoneNumber;

  factory SafariTapUserValidate.fromJson(Map<String, dynamic> json) {
    return SafariTapUserValidate(
      valid: json['valid'] == true,
      customerId: json['customerId']?.toString() ?? '',
      fullName: json['fullName']?.toString().trim() ?? '',
      nameEditable: json['nameEditable'] == true,
      self: json['self'] == true,
      phoneNumber: json['phoneNumber']?.toString(),
    );
  }
}
