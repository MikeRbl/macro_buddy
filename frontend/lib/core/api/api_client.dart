import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/exercise.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Siempre lee la config viva: el usuario puede cambiar de servidor
  /// en runtime desde la pantalla de login (diálogo "Servidor").
  Uri _uri(String path) => Uri.parse('${ApiConfig.baseUrl}$path');

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) async {
    http.Response res;
    try {
      res = await _client
          .post(
            _uri(path),
            headers: {
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const ApiException(
        'No se pudo conectar con el servidor. Verifica tu conexión.',
      );
    }

    final Map<String, dynamic> decoded;
    try {
      decoded = res.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw const ApiException('Respuesta inválida del servidor.');
    }

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException(
        decoded['error'] as String? ?? 'Error (${res.statusCode})',
        statusCode: res.statusCode,
      );
    }
    return decoded;
  }

  Future<List<dynamic>> _getList(String path, {String? token}) async {
    http.Response res;
    try {
      res = await _client
          .get(
            _uri(path),
            headers: {if (token != null) 'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const ApiException(
        'No se pudo conectar con el servidor. Verifica tu conexión.',
      );
    }

    final List<dynamic> decoded;
    try {
      decoded = jsonDecode(res.body) as List<dynamic>;
    } catch (_) {
      throw const ApiException('Respuesta inválida del servidor.');
    }

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException('Error (${res.statusCode})');
    }
    return decoded;
  }

  Future<Map<String, dynamic>> register({
    required String fullName,
    required String username,
    required String email,
    required String password,
    double? weight,
    double? height,
    String? gender,
  }) {
    return _post('/api/auth/register', {
      'full_name': fullName,
      'username': username,
      'email': email,
      'password': password,
      'weight': weight,
      'height': height,
      'gender': gender,
    });
  }

  Future<Map<String, dynamic>> login({
    required String identifier,
    required String password,
  }) {
    return _post('/api/auth/login', {
      'identifier': identifier,
      'password': password,
    });
  }

  Future<Map<String, dynamic>> _patch(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) async {
    http.Response res;
    try {
      res = await _client
          .patch(
            _uri(path),
            headers: {
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const ApiException(
        'No se pudo conectar con el servidor. Verifica tu conexión.',
      );
    }

    final Map<String, dynamic> decoded;
    try {
      decoded = res.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw const ApiException('Respuesta inválida del servidor.');
    }

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException(
        decoded['error'] as String? ?? 'Error (${res.statusCode})',
        statusCode: res.statusCode,
      );
    }
    return decoded;
  }

  Future<List<Exercise>> fetchExercises() async {
    http.Response res;
    try {
      res = await _client
          .get(_uri('/api/exercises'))
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const ApiException(
        'No se pudo conectar con el servidor. Verifica tu conexión.',
      );
    }

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException('Error al cargar ejercicios (${res.statusCode}).');
    }

    final List<dynamic> decoded;
    try {
      decoded = jsonDecode(res.body) as List<dynamic>;
    } catch (_) {
      throw const ApiException('Respuesta inválida del servidor.');
    }
    return decoded
        .map((e) => Exercise.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> updateProfile({
    required String token,
    required String fullName,
    required String username,
    double? weight,
    double? bodyFat,
    double? height,
    String? gender,
    String? currentPassword,
    String? newPassword,
    double? targetCalories,
    double? targetProtein,
    double? targetCarbs,
    double? targetFats,
  }) {
    return _patch('/api/auth/profile', {
      'full_name': fullName,
      'username': username,
      'weight': weight,
      'bodyFat': bodyFat,
      'height': height,
      'gender': gender,
      'currentPassword': currentPassword,
      'newPassword': newPassword,
      'targetCalories': targetCalories,
      'targetProtein': targetProtein,
      'targetCarbs': targetCarbs,
      'targetFats': targetFats,
    }, token: token);
  }

  /// Vínculo del profesional: activa/desactiva el modo guiado.
  /// Con el modo activo el backend bloquea (403) la edición de macros.
  Future<Map<String, dynamic>> setGuidedMode({
    required String token,
    required bool guided,
  }) {
    return _patch('/api/auth/profile', {
      'isGuidedMode': guided,
    }, token: token);
  }

Future<Map<String, dynamic>> createWorkout({
    required String token,
    required String name,
    required List<Map<String, dynamic>> exercises,
  }) {
    return _post(
      '/api/workouts',
      {'name': name, 'exercises': exercises},
      token: token,
    );
  }

  Future<List<dynamic>> fetchWorkouts({required String token}) {
    return _getList('/api/workouts', token: token);
  }

  Future<Map<String, dynamic>> createUserWorkout({
    required String token,
    int? duration,
    String? note,
    required List<Map<String, dynamic>> sets,
  }) {
    return _post('/api/user_workouts', {
      'duration': duration,
      'note': note,
      'sets': sets,
    }, token: token);
  }

  Future<Map<String, dynamic>> _put(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) async {
    http.Response res;
    try {
      res = await _client
          .put(
            _uri(path),
            headers: {
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const ApiException(
        'No se pudo conectar con el servidor. Verifica tu conexión.',
      );
    }

    final Map<String, dynamic> decoded;
    try {
      decoded = res.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw const ApiException('Respuesta inválida del servidor.');
    }

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException(
        decoded['error'] as String? ?? 'Error (${res.statusCode})',
        statusCode: res.statusCode,
      );
    }
    return decoded;
  }

  Future<Map<String, dynamic>> put(
    String path, {
    required Map<String, dynamic> body,
    String? token,
  }) {
    return _put(path, body, token: token);
  }

  Future<Map<String, dynamic>> reorderWorkouts({
    required String token,
    required List<String> workoutIds,
  }) {
    return _put(
      '/api/workouts/reorder',
      {'workoutIds': workoutIds},
      token: token,
    );
  }

  Future<List<dynamic>> fetchUserWorkouts({required String token}) {
    return _getList('/api/user_workouts', token: token);
  }

  Future<Map<String, dynamic>> fetchNutrition({
    required String token,
    String? date,
  }) async {
    final path = date == null ? '/api/nutrition' : '/api/nutrition?date=$date';
    final res = await _client.get(
      _uri(path),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw const ApiException('No se pudo cargar la nutrición.');
    }
    try {
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw const ApiException('Respuesta inválida del servidor.');
    }
  }

  Future<List<dynamic>> fetchNutritionRange({
    required String token,
    required String from,
    required String to,
  }) async {
    final res = await _client.get(
      _uri('/api/nutrition?from=$from&to=$to'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw const ApiException('No se pudo cargar la nutrición.');
    }
    try {
      return jsonDecode(res.body) as List<dynamic>;
    } catch (_) {
      throw const ApiException('Respuesta inválida del servidor.');
    }
  }

  Future<Map<String, dynamic>> addNutritionItems({
    required String token,
    required List<Map<String, dynamic>> items,
    String? date,
  }) {
    return _post('/api/nutrition', {
      'items': items,
      'date': ?date,
    }, token: token);
  }

  Future<Map<String, dynamic>> patchNutritionItem({
    required Map<String, dynamic> body,
    required String token,
  }) async {
    http.Response res;
    try {
      res = await _client
          .patch(
            _uri('/api/nutrition'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const ApiException(
        'No se pudo conectar con el servidor. Verifica tu conexión.',
      );
    }
    final decoded = jsonDecode(res.body.isEmpty ? '{}' : res.body);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException(
        decoded is Map<String, dynamic>
            ? decoded['error'] as String? ?? 'Error (${res.statusCode})'
            : 'Error (${res.statusCode})',
      );
    }
    return decoded as Map<String, dynamic>;
  }

  Future<void> deleteNutritionItem({
    required String token,
    required String date,
    required String itemId,
  }) async {
    final res = await _client.delete(
      _uri('/api/nutrition?date=$date&itemId=$itemId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw const ApiException('No se pudo eliminar el alimento.');
    }
  }
}
