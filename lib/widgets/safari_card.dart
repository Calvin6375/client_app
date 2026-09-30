import 'package:flutter/material.dart';
import 'package:pretium/core/constants/app_colors.dart';
import 'package:pretium/widgets/app_shimmer.dart';

/// Virtual SafariTap / TruePay card shown on Home and Pay.
class SafariCard extends StatefulWidget {
  const SafariCard({
    super.key,
    required this.title,
    required this.currency,
    required this.balance,
    this.secondaryCurrency,
    this.secondaryBalance,
    this.updatedAt,
    this.loading = false,
    this.error,
    required this.backgroundColor,
  });

  final String title;
  final String currency;
  final double balance;
  final String? secondaryCurrency;
  final double? secondaryBalance;
  final DateTime? updatedAt;
  final bool loading;
  final String? error;
  final Color backgroundColor;

  @override
  State<SafariCard> createState() => _SafariCardState();
}

/// Home wallet carousel still constructs this name.
typedef WalletCardWidget = SafariCard;

class _SafariCardState extends State<SafariCard> {
  bool _balanceVisible = true;

  String get _currencySymbol {
    switch (widget.currency.toUpperCase()) {
      case 'USD':
        return '\$';
      case 'USDT':
      case 'USDC':
        return '${widget.currency.toUpperCase()} ';
      case 'KES':
        return 'KSh ';
      case 'NGN':
        return '₦';
      case 'GHS':
        return 'GH₵';
      case 'UGX':
        return 'USh ';
      default:
        return '${widget.currency.toUpperCase()} ';
    }
  }

  String get _maskedCardNumber {
    final seed = widget.currency.hashCode.abs();
    final last4 = (seed % 10000).toString().padLeft(4, '0');
    return '**** **** **** $last4';
  }

  String get _displayBalance {
    if (!_balanceVisible) return '****';
    return '$_currencySymbol${widget.balance.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final fallbackWidth = MediaQuery.of(context).size.width - 40;
    const cardAspectRatio = 1.586;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = fallbackWidth;
        final cardHeight = cardWidth / cardAspectRatio;

        return Center(
          child: FittedBox(
            fit: BoxFit.contain,
            child: Container(
              width: cardWidth,
              height: cardHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: isDark
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDark
                          ? [
                              AppColors.surfaceDark,
                              AppColors.surfaceDark.withValues(alpha: 0.95),
                              AppColors.backgroundDeepNavy,
                            ]
                          : [
                              widget.backgroundColor.withValues(alpha: 0.95),
                              widget.backgroundColor.withValues(alpha: 0.75),
                              widget.backgroundColor.withValues(alpha: 0.55),
                            ],
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        top: -cardHeight * 0.12,
                        right: -cardWidth * 0.08,
                        child: Container(
                          width: cardWidth * 0.5,
                          height: cardWidth * 0.5,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: widget.backgroundColor
                                .withValues(alpha: isDark ? 0.12 : 0.18),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: -cardHeight * 0.18,
                        left: -cardWidth * 0.12,
                        child: Container(
                          width: cardWidth * 0.42,
                          height: cardWidth * 0.42,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: widget.backgroundColor
                                .withValues(alpha: isDark ? 0.08 : 0.12),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topRight,
                              end: Alignment.bottomLeft,
                              colors: [
                                Colors.white
                                    .withValues(alpha: isDark ? 0.06 : 0.12),
                                Colors.transparent,
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.35, 1.0],
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(22),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _BrandLogo(),
                                const Spacer(),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    GestureDetector(
                                      onTap: () => setState(
                                        () => _balanceVisible = !_balanceVisible,
                                      ),
                                      child: Icon(
                                        _balanceVisible
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                        color: colors.textPrimary
                                            .withValues(alpha: 0.85),
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Balance',
                                      style: TextStyle(
                                        color: colors.textSecondary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    if (widget.loading)
                                      const ShimmerBusyIndicator(
                                        width: 72,
                                        height: 18,
                                      )
                                    else if (widget.error != null)
                                      Text(
                                        '—',
                                        style: TextStyle(
                                          color: colors.textPrimary,
                                          fontSize: 22,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      )
                                    else
                                      Text(
                                        _displayBalance,
                                        style: TextStyle(
                                          color: colors.textPrimary,
                                          fontSize: 22,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                            const Spacer(),
                            Text(
                              'Card Number',
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _maskedCardNumber,
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const Spacer(),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                _CardDetailColumn(
                                  label: 'Expiry Date',
                                  value: '**/**',
                                  colors: colors,
                                ),
                                const SizedBox(width: 28),
                                _CardDetailColumn(
                                  label: 'CVC',
                                  value: '***',
                                  colors: colors,
                                ),
                                const Spacer(),
                                const _SafariTapBrand(),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BrandLogo extends StatelessWidget {
  const _BrandLogo();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          padding: const EdgeInsets.all(5),
          child: Image.asset(
            'assets/images/troupay_logo.png',
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Icon(
              Icons.account_balance_wallet,
              size: 18,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'TruePay',
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

class _CardDetailColumn extends StatelessWidget {
  const _CardDetailColumn({
    required this.label,
    required this.value,
    required this.colors,
  });

  final String label;
  final String value;
  final AppThemeColors colors;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }
}

class _SafariTapBrand extends StatelessWidget {
  const _SafariTapBrand();

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final colors = AppColors.getThemeColors(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Image.asset(
          'assets/images/card.png',
          height: 52,
          width: 52,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Icon(
            Icons.credit_card,
            size: 40,
            color: primary,
          ),
        ),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
                children: [
                  TextSpan(
                    text: 'Safari',
                    style: TextStyle(color: colors.textPrimary),
                  ),
                  TextSpan(
                    text: 'Tap',
                    style: TextStyle(color: primary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  height: 1,
                ),
                children: [
                  TextSpan(
                    text: 'by ',
                    style: TextStyle(color: colors.textPrimary),
                  ),
                  TextSpan(
                    text: 'truepay',
                    style: TextStyle(color: primary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class SafariCardEntry {
  const SafariCardEntry({
    required this.currency,
    required this.balance,
    this.isCrypto = false,
  });

  final String currency;
  final double balance;
  final bool isCrypto;
}

/// Swipeable SafariTap cards for every wallet, matching Home.
class SafariCardPager extends StatefulWidget {
  const SafariCardPager({
    super.key,
    required this.wallets,
    this.loading = false,
    this.initialCurrency,
    this.onCurrencyChanged,
  });

  final List<SafariCardEntry> wallets;
  final bool loading;
  final String? initialCurrency;
  final ValueChanged<String>? onCurrencyChanged;

  @override
  State<SafariCardPager> createState() => _SafariCardPagerState();
}

class _SafariCardPagerState extends State<SafariCardPager> {
  static const _viewportFraction = 0.88;
  static const _cardAspectRatio = 1.586;

  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = _indexFor(widget.initialCurrency, widget.wallets);
    _controller = PageController(
      initialPage: _index,
      viewportFraction: _viewportFraction,
    );
  }

  @override
  void didUpdateWidget(covariant SafariCardPager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.wallets.length != widget.wallets.length &&
        widget.wallets.isNotEmpty) {
      final next = _index.clamp(0, widget.wallets.length - 1);
      if (next != _index) {
        _index = next;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static int _indexFor(String? currency, List<SafariCardEntry> wallets) {
    if (wallets.isEmpty) return 0;
    final wanted = currency?.trim().toUpperCase();
    if (wanted == null || wanted.isEmpty) return 0;
    final i = wallets.indexWhere((w) => w.currency.toUpperCase() == wanted);
    return i >= 0 ? i : 0;
  }

  double _cardHeight(BuildContext context) {
    final cardWidth = MediaQuery.of(context).size.width - 40;
    return cardWidth / _cardAspectRatio;
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final wallets = widget.wallets;
    if (wallets.isEmpty) {
      return SafariCard(
        title: 'Fiat Wallet',
        currency: 'KES',
        balance: 0,
        loading: widget.loading,
        backgroundColor: primary,
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: _cardHeight(context),
          child: PageView.builder(
            controller: _controller,
            clipBehavior: Clip.none,
            padEnds: true,
            onPageChanged: (index) {
              setState(() => _index = index);
              widget.onCurrencyChanged?.call(wallets[index].currency);
            },
            itemCount: wallets.length,
            itemBuilder: (context, index) {
              final wallet = wallets[index];
              return _SafariCardCarouselPage(
                controller: _controller,
                index: index,
                fallbackPage: _index.toDouble(),
                viewportFraction: _viewportFraction,
                child: SafariCard(
                  title: wallet.isCrypto ? 'Crypto Wallet' : 'Fiat Wallet',
                  currency: wallet.currency,
                  balance: wallet.balance,
                  loading: widget.loading && index == _index,
                  backgroundColor: primary,
                ),
              );
            },
          ),
        ),
        if (wallets.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                wallets.length,
                (index) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _index == index ? 10 : 6,
                  height: _index == index ? 10 : 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _index == index
                        ? primary
                        : primary.withValues(alpha: 0.25),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SafariCardCarouselPage extends StatelessWidget {
  const _SafariCardCarouselPage({
    required this.controller,
    required this.index,
    required this.fallbackPage,
    required this.viewportFraction,
    required this.child,
  });

  final PageController controller;
  final int index;
  final double fallbackPage;
  final double viewportFraction;
  final Widget child;

  double get _page {
    if (controller.hasClients && controller.position.hasContentDimensions) {
      return controller.page ?? fallbackPage;
    }
    return fallbackPage;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final page = _page;
        final delta = page - index;
        final distance = delta.abs().clamp(0.0, 1.0);
        final zoomOut = Curves.easeOutCubic.transform(distance);
        final scale = (1 / viewportFraction) * (1.0 - 0.16 * zoomOut);
        final slide = 14.0 * zoomOut;
        final dx = delta == 0 ? 0.0 : -delta.sign * slide;

        return Transform.translate(
          offset: Offset(dx, 0),
          child: Transform.scale(
            scale: scale,
            alignment: Alignment.center,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

