import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Country code data model
class CountryCode {
  final String name;
  final String code;
  final String dialCode;
  final String flag;

  CountryCode({
    required this.name,
    required this.code,
    required this.dialCode,
    required this.flag,
  });
}

/// Phone number field with country code selector
class PhoneNumberField extends StatefulWidget {
  final TextEditingController phoneController;
  final String? Function(String?)? validator;
  final Color primaryColor;
  final Color? labelColor;
  final String? initialCountryCode;
  final ValueChanged<String>? onCountryCodeChanged;

  const PhoneNumberField({
    super.key,
    required this.phoneController,
    required this.primaryColor,
    this.validator,
    this.labelColor,
    this.initialCountryCode,
    this.onCountryCodeChanged,
  });

  @override
  State<PhoneNumberField> createState() => _PhoneNumberFieldState();
}

class _PhoneNumberFieldState extends State<PhoneNumberField> {
  CountryCode _selectedCountry = _countryCodes.first;
  
  /// Get formatted phone number: country code + number (e.g., '254742844875')
  String? getFormattedPhoneNumber() {
    final phoneNumber = widget.phoneController.text.trim();
    if (phoneNumber.isEmpty) return null;
    // Remove any non-digit characters
    final digitsOnly = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    if (digitsOnly.isEmpty) return null;
    // Combine country code and phone number
    return '${_selectedCountry.dialCode}$digitsOnly';
  }
  
  // Common country codes (you can expand this list)
  static final List<CountryCode> _countryCodes = [
    CountryCode(name: 'Kenya', code: 'KE', dialCode: '254', flag: '🇰🇪'),
    CountryCode(name: 'Uganda', code: 'UG', dialCode: '256', flag: '🇺🇬'),
    CountryCode(name: 'Tanzania', code: 'TZ', dialCode: '255', flag: '🇹🇿'),
    CountryCode(name: 'Rwanda', code: 'RW', dialCode: '250', flag: '🇷🇼'),
    CountryCode(name: 'Ghana', code: 'GH', dialCode: '233', flag: '🇬🇭'),
    CountryCode(name: 'Nigeria', code: 'NG', dialCode: '234', flag: '🇳🇬'),
    CountryCode(name: 'South Africa', code: 'ZA', dialCode: '27', flag: '🇿🇦'),
    CountryCode(name: 'United States', code: 'US', dialCode: '1', flag: '🇺🇸'),
    CountryCode(name: 'United Kingdom', code: 'GB', dialCode: '44', flag: '🇬🇧'),
    CountryCode(name: 'India', code: 'IN', dialCode: '91', flag: '🇮🇳'),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialCountryCode != null) {
      final country = _countryCodes.firstWhere(
        (c) => c.dialCode == widget.initialCountryCode,
        orElse: () => _countryCodes.first,
      );
      _selectedCountry = country;
    }
    // Notify parent of initial country code
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onCountryCodeChanged?.call(_selectedCountry.dialCode);
    });
  }

  void _showCountryCodePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'Select Country',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _countryCodes.length,
                  itemBuilder: (context, index) {
                    final country = _countryCodes[index];
                    final isSelected = country.dialCode == _selectedCountry.dialCode;
                    return ListTile(
                      leading: Text(country.flag, style: const TextStyle(fontSize: 24)),
                      title: Text(country.name),
                      trailing: Text(
                        '+${country.dialCode}',
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? widget.primaryColor : Colors.black,
                        ),
                      ),
                      selected: isSelected,
                      onTap: () {
                        setState(() {
                          _selectedCountry = country;
                        });
                        widget.onCountryCodeChanged?.call(country.dialCode);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.phoneController,
      keyboardType: TextInputType.phone,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
      ],
      cursorColor: widget.primaryColor,
      validator: widget.validator,
      decoration: InputDecoration(
        prefixIcon: GestureDetector(
          onTap: _showCountryCodePicker,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _selectedCountry.flag,
                  style: const TextStyle(fontSize: 20),
                ),
                const SizedBox(width: 4),
                Text(
                  '+${_selectedCountry.dialCode}',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Icon(Icons.arrow_drop_down, color: Colors.black),
              ],
            ),
          ),
        ),
        labelText: 'Phone Number',
        hintText: 'Enter your phone number',
        hintStyle: TextStyle(color: Colors.grey.shade400),
        labelStyle: TextStyle(
          color: widget.labelColor ?? widget.primaryColor,
        ),
        floatingLabelStyle: TextStyle(
          color: widget.labelColor ?? widget.primaryColor,
        ),
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: widget.primaryColor, width: 2),
          borderRadius: const BorderRadius.all(Radius.circular(12)),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.grey.shade300),
          borderRadius: const BorderRadius.all(Radius.circular(12)),
        ),
      ),
    );
  }
}

