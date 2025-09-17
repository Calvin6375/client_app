import 'package:flutter/material.dart';

class SplashPage1 extends StatefulWidget {
  const SplashPage1({super.key});

  @override
  State<SplashPage1> createState() => _SplashPage1State();
}

class _SplashPage1State extends State<SplashPage1> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  void _nextPage() {
    if (_currentPage < 2) {
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
    return Scaffold(
      backgroundColor: Colors.white,
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
                  icon: Icons.credit_card,
                  title: 'Direct Pay',
                  subtitle: 'Pay with crypto across Africa effortlessly',
                ),
                _buildPage(
                  icon: Icons.account_balance_wallet,
                  title: 'Accept Payments',
                  subtitle: 'Accept stablecoin payments hassle-free',
                ),
                _buildPage(
                  icon: Icons.receipt_long,
                  title: 'Pay Bills',
                  subtitle: 'Pay for utility services and earn rewards',
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
                child: const Text('Skip', style: TextStyle(color: Colors.grey)),
              ),
            ),
            Positioned(
              bottom:
                  100, // Increased bottom padding to place above Next button
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (index) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width:
                        index == _currentPage ? 24 : 8, // Active dot is wider
                    height: 8,
                    decoration: BoxDecoration(
                      color:
                          index == _currentPage
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey.withOpacity(0.3),
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
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  minimumSize: const Size.fromHeight(48),
                ),
                child: Text(
                  _currentPage == 2
                      ? 'Get Started'
                      : 'Next', // Change text based on page
                  style: const TextStyle(color: Colors.white),
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
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 55,
          backgroundColor: const Color.fromARGB(255, 210, 213, 212),
          child: Icon(
            icon,
            color: Theme.of(context).colorScheme.primary,
            size: 60, // Increased icon size from 40 to 60
          ),
        ),
        const SizedBox(height: 32),
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Text(
          subtitle,
          style: const TextStyle(color: Colors.grey),
          textAlign: TextAlign.center,
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
