import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pretium/core/theme/theme_provider.dart';

/// A simple theme toggle button widget
/// Can be added to any screen to switch between light and dark modes
class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode(context);

    return IconButton(
      icon: Icon(
        isDark ? Icons.light_mode : Icons.dark_mode,
        color: Theme.of(context).colorScheme.onSurface,
      ),
      onPressed: () => themeProvider.toggleTheme(),
      tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
    );
  }
}
