import 'package:flutter/widgets.dart';

/// Ensures an async action runs at most once until it completes.
///
/// Use one instance per user action (e.g. submit payout, sign in).
final class AsyncActionGuard {
  bool _running = false;

  bool get isRunning => _running;

  /// Returns `null` when skipped because an action is already in progress.
  Future<T?> run<T>(Future<T> Function() action) async {
    if (_running) return null;
    _running = true;
    try {
      return await action();
    } finally {
      _running = false;
    }
  }
}

/// Runs [action] once at a time and keeps a submit/loading flag in sync for UI.
Future<T?> runGuardedAsync<T>(
  State state, {
  required bool Function() isSubmitting,
  required void Function(bool value) setSubmitting,
  required Future<T> Function() action,
}) async {
  if (isSubmitting()) return null;
  setSubmitting(true);
  try {
    return await action();
  } finally {
    if (state.mounted) setSubmitting(false);
  }
}
