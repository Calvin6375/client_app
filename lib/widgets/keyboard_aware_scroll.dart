import 'dart:async';

import 'package:flutter/material.dart';

/// Puts [child] in a scroll view and moves the focused field above the keyboard.
class KeyboardAwareScroll extends StatefulWidget {
  const KeyboardAwareScroll({
    super.key,
    required this.child,
    this.padding,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  State<KeyboardAwareScroll> createState() => _KeyboardAwareScrollState();
}

class _KeyboardAwareScrollState extends State<KeyboardAwareScroll>
    with WidgetsBindingObserver {
  final _controller = ScrollController();
  double _lastInset = 0;
  Timer? _scrollDebounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    FocusManager.instance.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _scrollDebounce?.cancel();
    FocusManager.instance.removeListener(_onFocusChange);
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  double _keyboardInset() {
    final view = View.of(context);
    return view.viewInsets.bottom / view.devicePixelRatio;
  }

  @override
  void didChangeMetrics() {
    if (!mounted) return;
    final inset = _keyboardInset();
    final grew = inset > _lastInset + 24;
    _lastInset = inset;
    if (grew || inset > 80) {
      _scheduleEnsureVisible();
    }
  }

  void _onFocusChange() {
    if (!mounted) return;
    if (_keyboardInset() <= 80) return;
    _scheduleEnsureVisible();
  }

  void _scheduleEnsureVisible() {
    _scrollDebounce?.cancel();
    _scrollDebounce = Timer(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      _ensureFocusedVisible();
    });
  }

  void _ensureFocusedVisible() {
    final focused = FocusManager.instance.primaryFocus?.context;
    if (focused == null || !focused.mounted) return;
    Scrollable.ensureVisible(
      focused,
      alignment: 0.18,
      alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          controller: _controller,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: widget.padding,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: widget.child,
          ),
        );
      },
    );
  }
}
