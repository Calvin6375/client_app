import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pretium/core/providers/auth_providers.dart';
import 'package:pretium/core/providers/service_providers.dart';
import 'package:pretium/models/notification_model.dart';

final notificationsProvider = StreamProvider<List<NotificationModel>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(const []);
  return ref.watch(notificationServiceProvider).getNotificationsStream(user.uid);
});
