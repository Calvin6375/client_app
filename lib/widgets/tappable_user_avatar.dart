import 'package:flutter/material.dart';
import 'package:pretium/core/constants/app_colors.dart';

/// Initial avatar with a story-style ring, press scale, and badge so it
/// reads as a tappable control rather than a static monogram.
class TappableUserAvatar extends StatefulWidget {
  const TappableUserAvatar({
    super.key,
    required this.initial,
    required this.onTap,
    this.radius = 22,
    this.tooltip,
    this.badgeIcon = Icons.chevron_right_rounded,
    this.pulse = false,
  });

  final String initial;
  final VoidCallback onTap;
  final double radius;
  final String? tooltip;
  final IconData badgeIcon;
  final bool pulse;

  @override
  State<TappableUserAvatar> createState() => _TappableUserAvatarState();
}

class _TappableUserAvatarState extends State<TappableUserAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    if (widget.pulse) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant TappableUserAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pulse && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!widget.pulse && _pulse.isAnimating) {
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final primary = colors.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill = isDark
        ? colors.primary
        : Color.alphaBlend(primary.withValues(alpha: 0.16), Colors.white);
    final glyph = isDark ? colors.onPrimary : primary;
    final ringGap = isDark ? colors.background : Colors.white;
    final badgeR = (widget.radius * 0.36).clamp(9.0, 16.0);
    final ringPad = widget.radius >= 36 ? 5.0 : 3.5;

    Widget avatar = AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final t = widget.pulse ? _pulse.value : 0.0;
        return Container(
          padding: EdgeInsets.all(ringPad),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: SweepGradient(
              colors: [
                primary,
                primary.withValues(alpha: 0.35 + (t * 0.35)),
                primary.withValues(alpha: 0.85),
                primary,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: primary.withValues(alpha: 0.18 + (t * 0.12)),
                blurRadius: 10 + (t * 6),
                spreadRadius: 0.4,
              ),
            ],
          ),
          child: child,
        );
      },
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: fill,
          border: Border.all(
            color: ringGap,
            width: widget.radius >= 36 ? 3 : 2,
          ),
        ),
        child: CircleAvatar(
          radius: widget.radius,
          backgroundColor: fill,
          foregroundColor: glyph,
          child: Text(
            widget.initial,
            style: TextStyle(
              color: glyph,
              fontSize: widget.radius * 0.72,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
        ),
      ),
    );

    final stack = Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        Positioned(
          right: -2,
          bottom: -2,
          child: Container(
            width: badgeR * 2,
            height: badgeR * 2,
            decoration: BoxDecoration(
              color: primary,
              shape: BoxShape.circle,
              border: Border.all(
                color: ringGap,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Icon(
              widget.badgeIcon,
              size: badgeR * 1.15,
              color: colors.onPrimary,
            ),
          ),
        ),
      ],
    );

    final scaled = AnimatedScale(
      scale: _pressed ? 0.92 : 1,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: stack,
    );

    final button = Semantics(
      button: true,
      label: widget.tooltip ?? 'Open profile',
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: widget.onTap,
          onHighlightChanged: (v) => setState(() => _pressed = v),
          customBorder: const CircleBorder(),
          splashColor: primary.withValues(alpha: 0.18),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: scaled,
          ),
        ),
      ),
    );

    if (widget.tooltip == null) return button;
    return Tooltip(message: widget.tooltip!, child: button);
  }
}
