import 'package:flutter/material.dart';
import 'package:pretium/core/constants/app_colors.dart';

class CustomTextField extends StatefulWidget {
  final TextEditingController controller;
  final String labelText;
  final String hintText;
  final IconData prefixIcon;
  final bool isPassword;
  final TextInputType keyboardType;
  final Color primaryColor;
  final Color? labelColor;

  const CustomTextField({
    super.key,
    required this.controller,
    required this.labelText,
    required this.hintText,
    required this.prefixIcon,
    required this.primaryColor,
    this.isPassword = false,
    this.keyboardType = TextInputType.text,
    this.labelColor,
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    return TextField(
      controller: widget.controller,
      keyboardType: widget.keyboardType,
      obscureText: widget.isPassword ? _obscureText : false,
      cursorColor: widget.primaryColor,
      decoration: InputDecoration(
        prefixIcon: Icon(widget.prefixIcon, color: colors.iconPrimary),
        labelText: widget.labelText,
        hintText: widget.hintText,
        hintStyle: TextStyle(color: colors.inputPlaceholder),
        labelStyle: TextStyle(
          color: widget.labelColor ?? widget.primaryColor, // Not focused
        ),
        floatingLabelStyle: TextStyle(
          color: widget.labelColor ?? widget.primaryColor, // Focused
        ),
        border: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: colors.inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: colors.inputBorderFocused, width: 2),
          borderRadius: const BorderRadius.all(Radius.circular(12)),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: colors.inputBorder),
          borderRadius: const BorderRadius.all(Radius.circular(12)),
        ),
        suffixIcon:
            widget.isPassword
                ? IconButton(
                  icon: Icon(
                    _obscureText ? Icons.visibility_off : Icons.visibility,
                    color: widget.primaryColor,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureText = !_obscureText;
                    });
                  },
                )
                : null,
      ),
    );
  }
}
