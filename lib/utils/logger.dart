import 'package:flutter/foundation.dart';

/// Centralized logging utility.
///
/// Release/profile builds emit nothing to the console (avoids leaking payment
/// references and debug noise on Flutter Web).
class Logger {
  static bool get _enabled => kDebugMode;

  /// Debug level logs (development only)
  static void debug(String message, [Object? error, StackTrace? stackTrace]) {
    if (_enabled) {
      _log('DEBUG', message, error, stackTrace);
    }
  }

  /// Info level logs
  static void info(String message, [Object? error, StackTrace? stackTrace]) {
    if (_enabled) {
      _log('INFO', message, error, stackTrace);
    }
  }

  /// Warning level logs
  static void warning(String message, [Object? error, StackTrace? stackTrace]) {
    if (_enabled) {
      _log('WARNING', message, error, stackTrace);
    }
  }

  /// Error level logs
  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    if (_enabled) {
      _log('ERROR', message, error, stackTrace);
    }
  }

  /// Success level logs
  static void success(String message) {
    if (_enabled) {
      _log('SUCCESS', message, null, null);
    }
  }

  static void _log(
    String level,
    String message,
    Object? error,
    StackTrace? stackTrace,
  ) {
    final timestamp = DateTime.now().toIso8601String();
    debugPrint('[$timestamp] $level: $message');

    if (error != null) {
      debugPrint('  Error: $error');
    }

    if (stackTrace != null) {
      debugPrint('  StackTrace: $stackTrace');
    }
  }
}
