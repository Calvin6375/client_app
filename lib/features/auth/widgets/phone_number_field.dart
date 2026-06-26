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
  /// When true, the country code is shown but cannot be changed (no picker).
  final bool lockCountryCode;

  const PhoneNumberField({
    super.key,
    required this.phoneController,
    required this.primaryColor,
    this.validator,
    this.labelColor,
    this.initialCountryCode,
    this.onCountryCodeChanged,
    this.lockCountryCode = false,
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
    _applyInitialCountryCode();
    // Notify parent of initial country code (editable flows only; locked code is fixed in parent)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!widget.lockCountryCode) {
        widget.onCountryCodeChanged?.call(_selectedCountry.dialCode);
      }
    });
  }

  void _applyInitialCountryCode() {
    if (widget.initialCountryCode != null) {
      final country = _countryCodes.firstWhere(
        (c) => c.dialCode == widget.initialCountryCode,
        orElse: () => _countryCodes.first,
      );
      _selectedCountry = country;
    }
  }

  @override
  void didUpdateWidget(covariant PhoneNumberField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.lockCountryCode &&
        widget.initialCountryCode != null &&
        widget.initialCountryCode != oldWidget.initialCountryCode) {
      setState(_applyInitialCountryCode);
    }
  }

  void _showCountryCodePicker() {
    final searchController = TextEditingController();
    var filtered = List<CountryCode>.from(_countryCodes);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            void applyFilter(String query) {
              final q = query.trim().toLowerCase();
              setSheetState(() {
                filtered = q.isEmpty
                    ? List<CountryCode>.from(_countryCodes)
                    : _countryCodes.where((country) {
                        return country.name.toLowerCase().contains(q) ||
                            country.code.toLowerCase().contains(q) ||
                            country.dialCode.contains(q.replaceAll('+', ''));
                      }).toList();
              });
            }

            final maxHeight = MediaQuery.of(context).size.height * 0.75;

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SizedBox(
                height: maxHeight,
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Select Country',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: searchController,
                        onChanged: applyFilter,
                        decoration: InputDecoration(
                          hintText: 'Search by country or code',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Text(
                                'No countries found',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            )
                          : ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final country = filtered[index];
                                final isSelected =
                                    country.dialCode == _selectedCountry.dialCode;
                                return ListTile(
                                  leading: Text(
                                    country.flag,
                                    style: const TextStyle(fontSize: 24),
                                  ),
                                  title: Text(country.name),
                                  trailing: Text(
                                    '+${country.dialCode}',
                                    style: TextStyle(
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: isSelected
                                          ? widget.primaryColor
                                          : Colors.black,
                                    ),
                                  ),
                                  selected: isSelected,
                                  onTap: () {
                                    setState(() {
                                      _selectedCountry = country;
                                    });
                                    widget.onCountryCodeChanged
                                        ?.call(country.dialCode);
                                    Navigator.pop(sheetContext);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(searchController.dispose);
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
        prefixIcon: widget.lockCountryCode
            ? Container(
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
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              )
            : GestureDetector(
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
                        style: const TextStyle(
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

