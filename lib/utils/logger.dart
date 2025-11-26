/// Centralized logging utility
/// Replaces all print() statements with proper logging
class Logger {
  static const bool _enableDebugLogs = true;
  static const bool _enableInfoLogs = true;
  static const bool _enableWarningLogs = true;
  static const bool _enableErrorLogs = true;

  /// Debug level logs (development only)
  static void debug(String message, [Object? error, StackTrace? stackTrace]) {
    if (_enableDebugLogs) {
      _log('🐛 DEBUG', message, error, stackTrace);
    }
  }

  /// Info level logs
  static void info(String message, [Object? error, StackTrace? stackTrace]) {
    if (_enableInfoLogs) {
      _log('ℹ️ INFO', message, error, stackTrace);
    }
  }

  /// Warning level logs
  static void warning(String message, [Object? error, StackTrace? stackTrace]) {
    if (_enableWarningLogs) {
      _log('⚠️ WARNING', message, error, stackTrace);
    }
  }

  /// Error level logs
  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    if (_enableErrorLogs) {
      _log('🚨 ERROR', message, error, stackTrace);
    }
  }

  /// Success level logs
  static void success(String message) {
    if (_enableInfoLogs) {
      _log('✅ SUCCESS', message, null, null);
    }
  }

  static void _log(
    String level,
    String message,
    Object? error,
    StackTrace? stackTrace,
  ) {
    final timestamp = DateTime.now().toIso8601String();
    print('[$timestamp] $level: $message');
    
    if (error != null) {
      print('  Error: $error');
    }
    
    if (stackTrace != null) {
      print('  StackTrace: $stackTrace');
    }
  }
}

