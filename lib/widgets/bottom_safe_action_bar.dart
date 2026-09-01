import 'package:flutter/material.dart';

/// Wraps a pinned bottom CTA so it clears the system nav bar / home indicator.
///
/// Use at the bottom of a [Column] (typically under an [Expanded] scroll area).
class BottomSafeActionBar extends StatelessWidget {
  const BottomSafeActionBar({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }
}
