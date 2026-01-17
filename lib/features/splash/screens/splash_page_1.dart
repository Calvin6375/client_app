import 'package:flutter/material.dart';
import 'package:pretium/core/constants/app_colors.dart';

class SplashPage1 extends StatefulWidget {
  const SplashPage1({super.key});

  @override
  State<SplashPage1> createState() => _SplashPage1State();
}

class _SplashPage1State extends State<SplashPage1> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  void _nextPage() {
    if (_currentPage < 3) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // Navigate to the next screen
      Navigator.of(
        context,
      ).pushReplacementNamed('/login'); // or your desired route
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final colors = AppColors.getThemeColors(context);
    
    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Stack(
          children: [
            PageView(
              controller: _controller,
              onPageChanged: (index) {
                setState(() => _currentPage = index);
              },
              children: [
                _buildPage(
                  icon: Icons.swap_horiz,
                  title: 'True Exchange Rates',
                  subtitle: 'Get the best USD to KES rates with zero hidden fees',
                ),
                _buildPage(
                  icon: Icons.account_balance_wallet,
                  title: 'Crypto On & Off-Ramp',
                  subtitle: 'Buy/sell 500+ cryptos instantly to M-Pesa or bank',
                ),
                _buildPage(
                  icon: Icons.verified_user,
                  title: 'Instant Wallet Verification',
                  subtitle: 'Secure scam, risk, and address checks in seconds',
                ),
                _buildPage(
                  icon: Icons.phone_android,
                  title: 'Safe & Instant',
                  subtitle: 'Bank-level security, verified wallets, instant payouts',
                ),
              ],
            ),
            Positioned(
              top: 0,
              right: 5,
              child: TextButton(
                onPressed: () {
                  Navigator.of(
                    context,
                  ).pushReplacementNamed('/login'); // or your desired route
                },
                child: Text(
                  'Skip',
                  style: TextStyle(color: colors.textSecondary),
                ),
              ),
            ),
            Positioned(
              bottom:
                  100, // Increased bottom padding to place above Next button
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width:
                        index == _currentPage ? 24 : 8, // Active dot is wider
                    height: 8,
                    decoration: BoxDecoration(
                      color:
                          index == _currentPage
                              ? primary
                              : colors.textTertiary.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),
            Positioned(
              bottom: 20,
              left: 16,
              right: 16,
              child: ElevatedButton(
                onPressed: _nextPage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  minimumSize: const Size.fromHeight(48),
                ),
                child: Text(
                  _currentPage == 3
                      ? 'Get Started'
                      : 'Next', // Change text based on page
                  style: TextStyle(color: colors.onPrimary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final primary = Theme.of(context).colorScheme.primary;
    final colors = AppColors.getThemeColors(context);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDark
                ? primary.withOpacity(0.1) // Subtle background for dark mode
                : Colors.white.withOpacity(0.7), // Translucent white for glassmorphism
            border: isDark
                ? null
                : Border.all(
                    color: Colors.white.withOpacity(0.5),
                    width: 1,
                  ),
            boxShadow: isDark
                ? null
                : [
                    // Glassmorphism shadows for light mode
                    BoxShadow(
                      color: Colors.white.withOpacity(0.8),
                      blurRadius: 15,
                      offset: const Offset(-3, -3),
                      spreadRadius: -1,
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 10,
                      offset: const Offset(3, 3),
                    ),
                  ],
          ),
          child: Icon(
            icon,
            color: primary,
            size: 60,
          ),
        ),
        const SizedBox(height: 32),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: Text(
            subtitle,
            style: TextStyle(
              fontSize: 16,
              color: colors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

class SplashPage1Content extends StatelessWidget {
  const SplashPage1Content({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 55,
          backgroundColor: const Color.fromARGB(255, 210, 213, 212),
          child: Icon(
            Icons.credit_card,
            color: Theme.of(context).colorScheme.primary,
            size: 60,
          ),
        ),
        const SizedBox(height: 32),
        const Text(
          'Direct Pay',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        const Text(
          'Pay with crypto across Africa effortlessly',
          style: TextStyle(color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
