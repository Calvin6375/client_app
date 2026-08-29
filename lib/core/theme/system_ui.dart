import 'package:flutter/services.dart';

/// System bar styling for edge-to-edge Android.
///
/// Omits [SystemUiOverlayStyle.statusBarColor],
/// [SystemUiOverlayStyle.systemNavigationBarColor], and
/// [SystemUiOverlayStyle.systemNavigationBarDividerColor] so Flutter does not
/// call the Android 15-deprecated `Window.setStatusBarColor` /
/// `setNavigationBarColor` / `setNavigationBarDividerColor` APIs. Icon
/// appearance is set via `WindowInsetsController` instead; bar backgrounds
/// come from the app content drawn behind the system bars.
SystemUiOverlayStyle edgeToEdgeSystemUiOverlay(Brightness brightness) {
  final lightIcons = brightness == Brightness.dark;
  return SystemUiOverlayStyle(
    statusBarIconBrightness: lightIcons ? Brightness.light : Brightness.dark,
    statusBarBrightness: lightIcons ? Brightness.dark : Brightness.light,
    systemNavigationBarIconBrightness:
        lightIcons ? Brightness.light : Brightness.dark,
    systemStatusBarContrastEnforced: false,
    systemNavigationBarContrastEnforced: false,
  );
}
