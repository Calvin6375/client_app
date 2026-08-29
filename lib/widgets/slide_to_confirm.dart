import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pretium/core/constants/app_colors.dart';
import 'package:pretium/widgets/app_shimmer.dart';

/// Horizontal slide-to-confirm control used on exchange confirmation.
class SlideToConfirm extends StatefulWidget {
  const SlideToConfirm({
    super.key,
    required this.onConfirmed,
    this.label = 'Slide to confirm',
    this.enabled = true,
    this.isLoading = false,
  });

  final VoidCallback onConfirmed;
  final String label;
  final bool enabled;
  final bool isLoading;

  @override
  State<SlideToConfirm> createState() => _SlideToConfirmState();
}

class _SlideToConfirmState extends State<SlideToConfirm>
    with SingleTickerProviderStateMixin {
  double _dragX = 0;
  bool _confirmed = false;
  static const double _thumbSize = 52;
  static const double _padding = 4;

  @override
  void didUpdateWidget(covariant SlideToConfirm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isLoading && oldWidget.isLoading && _confirmed) {
      // Reset after a failed submit so the user can try again.
      setState(() {
        _confirmed = false;
        _dragX = 0;
      });
    }
  }

  void _onDragUpdate(DragUpdateDetails details, double maxDrag) {
    if (!widget.enabled || widget.isLoading || _confirmed) return;
    setState(() {
      _dragX = (_dragX + details.delta.dx).clamp(0.0, maxDrag);
    });
  }

  void _onDragEnd(double maxDrag) {
    if (!widget.enabled || widget.isLoading || _confirmed) return;
    final threshold = maxDrag * 0.85;
    if (_dragX >= threshold) {
      HapticFeedback.mediumImpact();
      setState(() {
        _dragX = maxDrag;
        _confirmed = true;
      });
      widget.onConfirmed();
    } else {
      setState(() => _dragX = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final primary = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final disabled = !widget.enabled || widget.isLoading;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final maxDrag = (width - _thumbSize - _padding * 2).clamp(0.0, width);
        final progress = maxDrag == 0 ? 0.0 : _dragX / maxDrag;

        return Opacity(
          opacity: disabled && !widget.isLoading ? 0.45 : 1,
          child: Container(
            height: _thumbSize + _padding * 2,
            decoration: BoxDecoration(
              color: isDark
                  ? colors.surface
                  : colors.surfaceVariant.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(40),
              border: Border.all(
                color: isDark
                    ? colors.border.withValues(alpha: 0.5)
                    : const Color(0xFFE5E7EB),
              ),
            ),
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                // Fill track as user slides.
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.all(_padding),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(36),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: progress.clamp(0.0, 1.0),
                          child: Container(
                            color: primary.withValues(alpha: 0.18),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Center(
                  child: widget.isLoading
                      ? const ShimmerBusyIndicator(width: 96, height: 12)
                      : Text(
                          widget.label,
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                ),
                Positioned(
                  left: _padding + _dragX,
                  child: GestureDetector(
                    onHorizontalDragUpdate: disabled
                        ? null
                        : (d) => _onDragUpdate(d, maxDrag),
                    onHorizontalDragEnd:
                        disabled ? null : (_) => _onDragEnd(maxDrag),
                    child: Container(
                      width: _thumbSize,
                      height: _thumbSize,
                      decoration: BoxDecoration(
                        color: primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: primary.withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        _confirmed || widget.isLoading
                            ? Icons.check_rounded
                            : Icons.arrow_forward_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
