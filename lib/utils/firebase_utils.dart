import 'package:firebase_core/firebase_core.dart';

bool isFirebaseInitialized() {
  try {
    return Firebase.apps.isNotEmpty;
  } catch (_) {
    return false;
  }
}
