import 'package:flutter/material.dart';
import 'dart:async';
import 'package:pretium/core/constants/app_colors.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({Key? key}) : super(key: key);

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _iconFadeAnimation;
  int _currentTaglineIndex = 0;

  final List<String> _taglines = [
    'USD → KES Instantly',
    'Safe Wallet Verification',
    'Crypto to M-Pesa in Seconds',
  ];

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _scaleAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _iconFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.3, 1.0, curve: Curves.easeIn),
    ));

    // Start the animation
    _controller.forward();

    // Rotate taglines every 2 seconds
    Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted) {
        setState(() {
          _currentTaglineIndex = (_currentTaglineIndex + 1) % _taglines.length;
        });
      } else {
        timer.cancel();
      }
    });

    // Navigate after 3 seconds (reduced from 5)
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/splash_page_1');
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final primary = Theme.of(context).colorScheme.primary;

    // Dark navy background matching login page
    return Scaffold(
      backgroundColor: AppColors.backgroundDeepNavy, // Deep navy #0F172A
      body: Container(
        decoration: const BoxDecoration(
          color: AppColors.backgroundDeepNavy, // Deep navy background
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo with animation
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Image.asset(
                      'assets/images/icon_1.png',
                      width: 180,
                      height: 180,
                      errorBuilder: (context, error, stackTrace) {
                        // Fallback if image not found - show text logo
                        return Container(
                          width: 180,
                          height: 180,
                          decoration: BoxDecoration(
                            color: primary,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              'TP',
                              style: TextStyle(
                                fontSize: 64,
                                fontWeight: FontWeight.bold,
                                color: colors.onPrimary,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Main tagline
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Text(
                    'TruePay',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Rotating subtitle tagline
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  child: Text(
                    _taglines[_currentTaglineIndex],
                    key: ValueKey(_currentTaglineIndex),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: colors.textSecondary,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 48),

                // Service icons (subtle, below tagline)
                FadeTransition(
                  opacity: _iconFadeAnimation,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildServiceIcon(Icons.swap_horiz, primary, colors),
                      const SizedBox(width: 24),
                      _buildServiceIcon(Icons.account_balance_wallet, primary, colors),
                      const SizedBox(width: 24),
                      _buildServiceIcon(Icons.verified_user, primary, colors),
                      const SizedBox(width: 24),
                      _buildServiceIcon(Icons.phone_android, primary, colors),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Secondary tagline
                FadeTransition(
                  opacity: _iconFadeAnimation,
                  child: Text(
                    'Best Rates • Instant Payouts • Secure Crypto Ramps',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.normal,
                      color: colors.textTertiary,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildServiceIcon(IconData icon, Color color, AppThemeColors colors) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.surfaceDark.withOpacity(0.5), // Dark slate with some transparency
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        color: AppColors.brandPrimary, // Dark teal icons
        size: 24,
      ),
    );
  }
}
