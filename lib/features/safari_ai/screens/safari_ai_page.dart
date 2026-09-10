import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:pretium/core/constants/app_colors.dart';
import 'package:pretium/features/safari_ai/data/safari_ai_guide.dart';

class SafariAiPage extends StatefulWidget {
  const SafariAiPage({super.key});

  @override
  State<SafariAiPage> createState() => _SafariAiPageState();
}

class _SafariAiMessage {
  const _SafariAiMessage({
    required this.fromGuide,
    required this.text,
    this.picks = const [],
    this.suggestions = const [],
  });

  final bool fromGuide;
  final String text;
  final List<SafariDestination> picks;
  final List<String> suggestions;
}

class _SafariAiPageState extends State<SafariAiPage> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();
  final _rng = math.Random();
  final _session = SafariAiSession();

  late final List<_SafariAiMessage> _messages = [
    _SafariAiMessage(
      fromGuide: true,
      text: _session.opening.text,
      suggestions: _session.opening.suggestions,
    ),
  ];

  bool _typing = false;
  SafariDestination? _expanded;

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _send(String raw) async {
    final text = raw.trim();
    if (text.isEmpty || _typing) return;

    _controller.clear();
    setState(() {
      _messages.add(_SafariAiMessage(fromGuide: false, text: text));
      _typing = true;
      _expanded = null;
    });
    _jumpToEnd();

    await Future<void>.delayed(
      Duration(milliseconds: 1100 + _rng.nextInt(900)),
    );
    if (!mounted) return;

    if (text.toLowerCase() == 'start over') {
      _session.reset();
    }
    final reply = _session.advance(text);
    setState(() {
      _typing = false;
      _messages.add(
        _SafariAiMessage(
          fromGuide: true,
          text: reply.text,
          picks: reply.picks,
          suggestions: reply.suggestions,
        ),
      );
    });
    _jumpToEnd();
  }

  void _jumpToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 120,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dusk = isDark ? const Color(0xFF0C1A17) : const Color(0xFFECF4F1);
    const ochre = Color(0xFFC4A574);

    return Scaffold(
      backgroundColor: dusk,
      appBar: AppBar(
        backgroundColor: dusk,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.14),
                shape: BoxShape.circle,
                border: Border.all(color: ochre.withValues(alpha: 0.55)),
              ),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: FaIcon(
                    FontAwesomeIcons.binoculars,
                    color: colors.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Safari AI',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                    ),
                  ),
                  Text(
                    _typing ? 'Reading the map…' : 'Field guide · East Africa',
                    style: TextStyle(
                      color: ochre,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              itemCount: _messages.length + (_typing ? 1 : 0),
              itemBuilder: (context, index) {
                if (_typing && index == _messages.length) {
                  return const _ThinkingBubble();
                }
                final isLatestGuide = !_typing &&
                    index == _messages.lastIndexWhere((m) => m.fromGuide);
                return _MessageBlock(
                  message: _messages[index],
                  expanded: _expanded,
                  choicesEnabled: isLatestGuide,
                  onExpand: (dest) {
                    setState(() {
                      _expanded = _expanded == dest ? null : dest;
                    });
                    _jumpToEnd();
                  },
                  onSuggestion: _send,
                );
              },
            ),
          ),
          _Composer(
            controller: _controller,
            focus: _focus,
            enabled: !_typing,
            onSend: () => _send(_controller.text),
          ),
        ],
      ),
    );
  }
}

class _MessageBlock extends StatelessWidget {
  const _MessageBlock({
    required this.message,
    required this.expanded,
    required this.choicesEnabled,
    required this.onExpand,
    required this.onSuggestion,
  });

  final _SafariAiMessage message;
  final SafariDestination? expanded;
  final bool choicesEnabled;
  final ValueChanged<SafariDestination> onExpand;
  final ValueChanged<String> onSuggestion;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isGuide = message.fromGuide;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment:
            isGuide ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          if (isGuide)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 6),
              child: Text(
                'SAFARI AI',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w700,
                  color: colors.primary,
                ),
              ),
            ),
          Align(
            alignment: isGuide ? Alignment.centerLeft : Alignment.centerRight,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.84,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: isGuide
                      ? (isDark ? AppColors.surfaceDark : Colors.white)
                      : colors.primary,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(isGuide ? 4 : 18),
                    bottomRight: Radius.circular(isGuide ? 18 : 4),
                  ),
                  border: isGuide && !isDark
                      ? Border.all(color: const Color(0xFFE5E7EB))
                      : null,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Text(
                    message.text,
                    style: TextStyle(
                      height: 1.45,
                      fontSize: 14.5,
                      color: isGuide ? colors.textPrimary : Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
          for (final pick in message.picks)
            _DestinationCard(
              destination: pick,
              expanded: expanded == pick,
              onToggle: () => onExpand(pick),
              onPlan: choicesEnabled
                  ? () => onSuggestion('Sketch this trip')
                  : null,
            ),
          if (message.suggestions.isNotEmpty && choicesEnabled)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final chip in message.suggestions)
                    ActionChip(
                      label: Text(chip),
                      onPressed: () => onSuggestion(chip),
                      backgroundColor:
                          isDark ? AppColors.surfaceDark : Colors.white,
                      side: BorderSide(
                        color: colors.primary.withValues(alpha: 0.35),
                      ),
                      labelStyle: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DestinationCard extends StatelessWidget {
  const _DestinationCard({
    required this.destination,
    required this.expanded,
    required this.onToggle,
    required this.onPlan,
  });

  final SafariDestination destination;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback? onPlan;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const ochre = Color(0xFFC4A574);

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Material(
        color: isDark ? const Color(0xFF16302B) : const Color(0xFFF7F1E8),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        destination.name.toUpperCase(),
                        style: TextStyle(
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        destination.vibe,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: colors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  destination.region,
                  style: TextStyle(
                    color: ochre,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  destination.why,
                  style: TextStyle(
                    color: colors.textSecondary,
                    height: 1.4,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  destination.season,
                  style: TextStyle(color: colors.textPrimary, fontSize: 12.5),
                ),
                const SizedBox(height: 2),
                Text(
                  destination.fromKes,
                  style: TextStyle(
                    color: colors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                if (expanded) ...[
                  const SizedBox(height: 12),
                  Text(
                    'FIELD NOTES',
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 1.3,
                      fontWeight: FontWeight.w700,
                      color: ochre,
                    ),
                  ),
                  const SizedBox(height: 6),
                  for (final line in destination.itinerary)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        line,
                        style: TextStyle(
                          color: colors.textPrimary,
                          height: 1.4,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                ],
                const SizedBox(height: 4),
                Row(
                  children: [
                    TextButton(
                      onPressed: onToggle,
                      child: Text(expanded ? 'Hide notes' : 'Open field notes'),
                    ),
                    TextButton(
                      onPressed: onPlan,
                      child: const Text('Sketch this trip'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ThinkingBubble extends StatefulWidget {
  const _ThinkingBubble();

  @override
  State<_ThinkingBubble> createState() => _ThinkingBubbleState();
}

class _ThinkingBubbleState extends State<_ThinkingBubble>
    with TickerProviderStateMixin {
  static const _lines = [
    'Reading the tracks',
    'Checking the map',
    'Asking the wind',
  ];

  late final AnimationController _dots;
  late final AnimationController _copy;
  int _line = 0;

  @override
  void initState() {
    super.initState();
    _dots = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
    _copy = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() => _line = (_line + 1) % _lines.length);
          _copy.forward(from: 0);
        }
      });
    _copy.forward();
  }

  @override
  void dispose() {
    _dots.dispose();
    _copy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(
              'SAFARI AI',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w700,
                color: colors.primary,
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(4),
                  bottomRight: Radius.circular(18),
                ),
                border: isDark
                    ? null
                    : Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _BouncingDots(animation: _dots, color: colors.primary),
                    const SizedBox(width: 10),
                    AnimatedBuilder(
                      animation: _copy,
                      builder: (context, child) {
                        final fade = 0.45 +
                            0.55 * Curves.easeInOut.transform(_copy.value);
                        return Opacity(opacity: fade, child: child);
                      },
                      child: Text(
                        _lines[_line],
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 13.5,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BouncingDots extends StatelessWidget {
  const _BouncingDots({required this.animation, required this.color});

  final Animation<double> animation;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final t = (animation.value + i * 0.18) % 1.0;
            final bounce = math.sin(t * math.pi);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Transform.translate(
                offset: Offset(0, -4 * bounce),
                child: Opacity(
                  opacity: 0.35 + 0.65 * bounce,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focus,
    required this.enabled,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focus;
  final bool enabled;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final safe = MediaQuery.of(context).padding.bottom;

    return Material(
      color: isDark ? AppColors.surfaceDark : Colors.white,
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 10, 12, math.max(safe, 10) + bottom),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focus,
                enabled: enabled,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                inputFormatters: [
                  LengthLimitingTextInputFormatter(280),
                ],
                decoration: InputDecoration(
                  hintText: 'Where should the dust take you?',
                  hintStyle: TextStyle(color: colors.textTertiary),
                  filled: true,
                  fillColor: isDark
                      ? AppColors.backgroundDeepNavy
                      : const Color(0xFFF0FDFA),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: enabled ? onSend : null,
              style: IconButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.north_east_rounded),
            ),
          ],
        ),
      ),
    );
  }
}
