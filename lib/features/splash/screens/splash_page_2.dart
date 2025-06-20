import 'package:flutter/material.dart';

class SplashPage1 extends StatefulWidget {
  const SplashPage1({super.key});

  @override
  State<SplashPage1> createState() => _SplashPage1State();
}

class _SplashPage1State extends State<SplashPage1> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  final Color primaryColor = const Color(0xFF176D68);

  void _nextPage() {
    if (_currentPage < 2) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // TODO: Navigate to the next screen
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
                  icon: Icons.receipt_long,
                  title: 'Accept Payments',
                  subtitle: 'Accept stablecoin payments hassle-free',
                ),
                _buildPage(
                  icon: Icons.lock,
                  title: 'Secure Transactions',
                  subtitle: 'End-to-end encryption for your safety',
                ),
                _buildPage(
                  icon: Icons.send,
                  title: 'Fast Transfers',
                  subtitle: 'Instant payments across countries',
                ),
              ],
            ),
            Positioned(
              top: 0,
              right: 5,
              child: TextButton(
                onPressed: () {
                  // TODO: Navigate to home or login
                },
                child: const Text('Skip', style: TextStyle(color: Colors.grey)),
              ),
            ),
            Positioned(
              bottom: 60,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (index) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: index == _currentPage ? 20 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color:
                          index == _currentPage
                              ? primaryColor
                              : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(8),
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
                  backgroundColor: primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text(
                  'Next',
                  style: TextStyle(color: Colors.white),
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
            color: const Color(0xFF176D68),
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

class SplashPage2Content extends StatelessWidget {
  const SplashPage2Content({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 55,
          backgroundColor: const Color.fromARGB(255, 210, 213, 212),
          child: Icon(
            Icons.receipt_long,
            color: const Color(0xFF176D68),
            size: 60,
          ),
        ),
        const SizedBox(height: 32),
        const Text(
          'Accept Payments',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        const Text(
          'Accept stablecoin payments hassle-free',
          style: TextStyle(color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
