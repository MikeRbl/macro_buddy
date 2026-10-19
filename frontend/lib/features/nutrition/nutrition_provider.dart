import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/models/nutrition.dart';
import '../auth/auth_controller.dart';

class NutritionState {
  const NutritionState({
    this.date,
    this.log,
    this.loading = false,
    this.error,
  });

  final String? date;
  final NutritionLog? log;
  final bool loading;
  final String? error;

  NutritionState copyWith({
    String? date,
    NutritionLog? log,
    bool? loading,
    String? error,
    bool clearError = false,
  }) {
    return NutritionState(
      date: date ?? this.date,
      log: log ?? this.log,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

final nutritionProvider =
    NotifierProvider<NutritionController, NutritionState>(
  NutritionController.new,
);

/// Historial de los últimos `days` días (inclusive) para el dashboard.
/// `NutritionLog` directo del backend; el propio rango ya existe en la API.
final nutritionHistoryProvider =
    FutureProvider.family<List<NutritionLog>, int>((ref, days) async {
  final token = ref.watch(authControllerProvider.select((s) => s.token));
  if (token == null || days <= 0) return const [];
  final today = DateTime.now();
  String key(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
  final from = key(today.subtract(Duration(days: days - 1)));
  final to = key(today);
  final list = await ref
      .read(apiClientProvider)
      .fetchNutritionRange(token: token, from: from, to: to);
  return list
      .whereType<Map<String, dynamic>>()
      .map(NutritionLog.fromJson)
      .toList();
});
class NutritionController extends Notifier<NutritionState> {
  @override
  NutritionState build() {
    final token = ref.watch(authControllerProvider.select((s) => s.token));
    if (token == null) return NutritionState(date: nutritionToday());
    // Carga diferida: sin side-effects durante el build.
    Future.microtask(() => loadDay(nutritionToday()));
    return NutritionState(loading: true, date: nutritionToday());
  }

  ApiClient get _api => ref.read(apiClientProvider);

  Future<void> loadDay(String date) async {
    final token = ref.read(authControllerProvider).token;
    if (token == null) return;
    state = state.copyWith(date: date, loading: true, clearError: true);
    try {
      final json = await _api.fetchNutrition(token: token, date: date);
      final log = NutritionLog.fromJson(json);
      // Ignora respuestas de un día anterior si el usuario ya cambió de día.
      if (state.date == date) {
        state = state.copyWith(log: log, loading: false);
      }
    } on ApiException catch (e) {
      state = state.copyWith(loading: false, error: e.message);
    } catch (_) {
      state = state.copyWith(loading: false, error: 'Error al cargar la nutrición.');
    }
  }

  Future<bool> addItems(List<Map<String, dynamic>> items) async {
    final token = ref.read(authControllerProvider).token;
    if (token == null || items.isEmpty) return false;
    final date = state.date ?? nutritionToday();
    try {
      final json = await _api.addNutritionItems(token: token, items: items, date: date);
      if (state.date == date) {
        state = state.copyWith(log: NutritionLog.fromJson(json));
      }
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(error: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(error: 'No se pudo registrar el alimento.');
      return false;
    }
  }

  /// Actualiza un ítem: gramos, macros y hora del registro. El backend
  /// recalcula los totales del día.
  Future<bool> updateItem(
    NutritionItem item,
    double grams, {
    required double calories,
    required double protein,
    required double carbs,
    required double fats,
    String? time,
    String? label,
  }) async {
    final token = ref.read(authControllerProvider).token;
    final date = state.date;
    if (token == null || date == null) return false;
    try {
      final body = item.toRequest(itemId: item.id)
        ..['quantity_g'] = grams
        ..['calories'] = calories
        ..['protein'] = protein
        ..['carbs'] = carbs
        ..['fats'] = fats
        ..['time'] = time
        ..['label'] = label;
      final json = await _api.patchNutritionItem(token: token, body: body..['date'] = date);
      if (state.date == date) {
        state = state.copyWith(log: NutritionLog.fromJson(json));
      }
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(error: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(error: 'No se pudo actualizar el alimento.');
      return false;
    }
  }

  Future<bool> deleteItem(NutritionItem item) async {
    final token = ref.read(authControllerProvider).token;
    final date = state.date;
    if (token == null || date == null) return false;
    try {
      await _api.deleteNutritionItem(token: token, date: date, itemId: item.id);
      await loadDay(date);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(error: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(error: 'No se pudo eliminar el alimento.');
      return false;
    }
  }
}
