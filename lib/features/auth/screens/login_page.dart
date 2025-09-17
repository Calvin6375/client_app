import 'package:flutter/material.dart';
import 'package:pretium/features/auth/screens/register_page.dart';
import 'package:pretium/features/auth/widgets/custom_text_field.dart';
import 'package:pretium/features/auth/widgets/wallet_icon_header.dart';
import 'package:pretium/features/auth/widgets/welcome_text_section.dart';
import 'package:pretium/features/home/screens/landing_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _rememberMe = false;
  bool _isLoading = false;

  // Key for storing email in SharedPreferences
  static const String _emailForSignInKey = 'email_for_sign_in';

  @override
  void initState() {
    super.initState();
    // Check if app was opened from an email link
    _checkEmailLink();
  }

  // Check if the app was opened with an email sign-in link
  // This is a simplified version for the demo
  Future<void> _checkEmailLink() async {
    try {
      // In a real app, this would check for dynamic links
      // For this demo, we don't need to do anything here
      // print('Demo: Checking for email links (simplified)');
    } catch (e) {
      //print('Error checking email link: $e');
    }
  }

  // This method is no longer needed but kept as a placeholder for future implementation
  void _showEmailInputDialog(String emailLink) {
    // Implementation removed for demo version
  }

  // Send sign-in link to email (Mock implementation)
  Future<void> _sendSignInLinkToEmail(String email) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // In a real app, this would send an email with a sign-in link
      // For this demo, we'll just simulate the process

      // Save email to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_emailForSignInKey, email);

      // Simulate network delay
      await Future.delayed(const Duration(seconds: 2));

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Sign-in link sent! Check your email. (Demo: Link not actually sent)',
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );

        // For demo purposes, show a dialog to simulate clicking the link
        _showSimulatedLinkDialog(email);
      }
    } catch (e) {
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending link: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Show a dialog to simulate clicking the email link (for demo purposes)
  void _showSimulatedLinkDialog(String email) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Demo: Simulate Email Link'),
            content: const Text(
              'In a real app, you would receive an email with a sign-in link. '
              'For this demo, you can simulate clicking the link by pressing the button below.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  // Simulate successful sign-in
                  _simulateSuccessfulSignIn(email);
                },
                child: const Text('Simulate Clicking Link'),
              ),
            ],
          ),
    );
  }

  // Simulate a successful sign-in (for demo purposes)
  Future<void> _simulateSuccessfulSignIn(String email) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Simulate network delay
      await Future.delayed(const Duration(seconds: 1));

      // Clear stored email
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_emailForSignInKey);

      // Navigate to home page
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => LandingPage()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error signing in: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              // Wallet icon header
              WalletIconHeader(color: Theme.of(context).colorScheme.primary),

              const SizedBox(height: 80),

              // Welcome text section
              const WelcomeTextSection(),
              const SizedBox(height: 48),

              // Email field
              CustomTextField(
                controller: _emailController,
                labelText: 'Email',
                hintText: 'Enter your email',
                prefixIcon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                primaryColor: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),

              // Password field
              CustomTextField(
                controller: _passwordController,
                labelText: 'Password',
                hintText: 'Enter your password',
                prefixIcon: Icons.lock_outline,
                isPassword: true,
                primaryColor: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),

              // Remember Me and Forgot Password
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Checkbox(
                        value: _rememberMe,
                        activeColor: Theme.of(context).colorScheme.primary,
                        checkColor: Colors.white,
                        side: const BorderSide(
                          color: Color.fromARGB(255, 75, 72, 72),
                          width: 3.0,
                        ),
                        onChanged: (value) {
                          setState(() {
                            _rememberMe = value ?? false;
                          });
                        },
                      ),
                      const Text('Remember me'),
                    ],
                  ),
                  TextButton(
                    onPressed: () {},
                    child: Text(
                      'Forgot Password?',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 48),

              // Login button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed:
                      _isLoading
                          ? null
                          : () async {
                            final email = _emailController.text.trim();
                            final password = _passwordController.text;
                            if (email.isEmpty || password.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Enter email and password'),
                                ),
                              );
                              return;
                            }

                            setState(() => _isLoading = true);
                            try {
                              await FirebaseAuth.instance
                                  .signInWithEmailAndPassword(
                                    email: email,
                                    password: password,
                                  );
                              if (!mounted) return;
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => LandingPage(),
                                ),
                                (route) => false,
                              );
                            } on FirebaseAuthException catch (e) {
                              final code =
                                  e.code; // e.g., 'wrong-password', 'user-not-found'
                              String message = 'Login failed';
                              if (code == 'user-not-found')
                                message = 'No user found for that email';
                              if (code == 'wrong-password')
                                message = 'Wrong password';
                              if (code == 'invalid-email')
                                message = 'Invalid email';
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('$message ($code)')),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Login failed: $e')),
                              );
                            } finally {
                              if (mounted) setState(() => _isLoading = false);
                            }
                          },
                  child:
                      _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                            'Login',
                            style: TextStyle(fontSize: 18, color: Colors.white),
                          ),
                ),
              ),
              const SizedBox(height: 24),

              // OR divider
              Row(
                children: const [
                  Expanded(child: Divider(thickness: 1)),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('OR', style: TextStyle(color: Colors.grey)),
                  ),
                  Expanded(child: Divider(thickness: 1)),
                ],
              ),
              const SizedBox(height: 24),

              // Email Link Login button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.primary,
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed:
                      _isLoading
                          ? null
                          : () {
                            final email = _emailController.text.trim();
                            if (email.isNotEmpty) {
                              _sendSignInLinkToEmail(email);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Please enter your email address',
                                  ),
                                ),
                              );
                            }
                          },
                  child: Text(
                    'Login with Email Link',
                    style: TextStyle(
                      fontSize: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Sign Up text
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Don't have an account? "),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const RegisterPage(),
                        ),
                      );
                    },
                    child: Text(
                      'Sign Up',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
