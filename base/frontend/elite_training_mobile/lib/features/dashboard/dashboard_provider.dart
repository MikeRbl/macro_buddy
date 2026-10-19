import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/models/workout_session.dart';
import '../auth/auth_controller.dart';

final dashboardProvider = FutureProvider<List<WorkoutSession>>((ref) async {
  final token = ref.watch(authControllerProvider.select((s) => s.token));
  if (token == null) return [];
  final items = await ref.read(apiClientProvider).fetchUserWorkouts(token: token);
  return items
      .map((e) => WorkoutSession.fromJson(e as Map<String, dynamic>))
      .toList();
});

final userWorkoutsProvider = FutureProvider<List<WorkoutSession>>((ref) async {
  final sessions = await ref.watch(dashboardProvider.future);
  return sessions;
});
