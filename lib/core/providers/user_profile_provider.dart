import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pretium/core/providers/auth_providers.dart';
import 'package:pretium/core/providers/service_providers.dart';
import 'package:pretium/models/user_model.dart';

final userProfileProvider = StreamProvider<UserModel?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream<UserModel?>.value(null);
  return ref.watch(userRepositoryProvider).streamUserProfile(user.uid);
});
