import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';
import '../models/exercise.dart';

final exercisesProvider = FutureProvider<List<Exercise>>((ref) {
  return ref.watch(apiClientProvider).fetchExercises();
});
