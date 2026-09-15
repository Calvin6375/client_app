import 'package:flutter/material.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';

/// TruePay-branded QR: teal dotted modules, rounded finders, shield mark.
class TruePayQrCode extends StatelessWidget {
  const TruePayQrCode({
    super.key,
    required this.data,
    this.size = 240,
  });

  final String data;
  final double size;

  static const Color _ink = Color(0xFF008CA8);

  @override
  Widget build(BuildContext context) {
    if (data.trim().isEmpty) {
      return SizedBox(
        width: size,
        height: size,
        child: const Center(child: Icon(Icons.qr_code_2, size: 72)),
      );
    }

    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: PrettyQrView.data(
        data: data,
        errorCorrectLevel: QrErrorCorrectLevel.H,
        decoration: const PrettyQrDecoration(
          background: Colors.white,
          quietZone: PrettyQrQuietZone.zero,
          shape: PrettyQrDotsSymbol(
            color: _ink,
            unifiedFinderPattern: true,
            unifiedAlignmentPatterns: true,
          ),
          image: PrettyQrDecorationImage(
            image: AssetImage('assets/images/icon_2.png'),
            padding: EdgeInsets.all(6),
            position: PrettyQrDecorationImagePosition.embedded,
          ),
        ),
      ),
    );
  }
}
