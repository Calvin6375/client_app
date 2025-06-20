import 'package:flutter/material.dart';

class TermsCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool?> onChanged;
  final VoidCallback? onTermsTap;
  final Color color;

  const TermsCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.onTermsTap,
    this.color = const Color(0xFF176D68),
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Checkbox(
          value: value,
          activeColor: color,
          checkColor: Colors.white,
          side: const BorderSide(
            color: Color.fromARGB(255, 75, 72, 72),
            width: 3.0,
          ),
          onChanged: onChanged,
        ),
        GestureDetector(
          onTap: onTermsTap,
          child: Text(
            'Accept Terms and Conditions',
            style: TextStyle(
              decoration: TextDecoration.underline,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
