import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

import '../../config/api_config.dart';

class FoodApiException implements Exception {
  const FoodApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  /// Sin conexión o timeout: la app sigue funcionando con lo local.
  bool get isNetwork => statusCode == null;

  @override
  String toString() => message;
}

typedef SyncPage = ({
  List<Map<String, dynamic>> items,
  int nextSince,
  bool hasMore,
});

/// Endpoints del catálogo en el backend de MacroBuddy (`/api/foods/*`).
class FoodApi {
  FoodApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('${ApiConfig.baseUrl}$path').replace(queryParameters: query);

  Map<String, String> _headers(String token) => {
    'Authorization': 'Bearer $token',
    'Accept': 'application/json',
  };

  Future<http.Response> _get(Uri uri, String token) async {
    try {
      return await _client
          .get(uri, headers: _headers(token))
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      throw const FoodApiException('Sin conexión con el servidor.');
    }
  }

  Object? _decode(http.Response res) {
    try {
      return res.body.isEmpty ? null : jsonDecode(res.body);
    } catch (_) {
      throw FoodApiException(
        'Respuesta inválida del servidor.',
        statusCode: res.statusCode,
      );
    }
  }

  Never _fail(http.Response res) {
    final body = _decode(res);
    final message = body is Map && body['error'] is String
        ? body['error'] as String
        : 'Error del servidor (${res.statusCode}).';
    throw FoodApiException(message, statusCode: res.statusCode);
  }

  Future<SyncPage> sync({
    required String token,
    required int since,
    int limit = 1000,
  }) async {
    final res = await _get(
      _uri('/api/foods/sync', {'since': '$since', 'limit': '$limit'}),
      token,
    );
    if (res.statusCode != 200) _fail(res);
    final body = _decode(res) as Map<String, dynamic>;
    return (
      items: ((body['items'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList(),
      nextSince: (body['nextSince'] as num?)?.toInt() ?? since,
      hasMore: body['hasMore'] == true,
    );
  }

  /// `null` si el servidor no lo tiene (404).
  Future<Map<String, dynamic>?> byBarcode({
    required String token,
    required String barcode,
  }) async {
    final res = await _get(_uri('/api/foods/barcode/$barcode'), token);
    if (res.statusCode == 404) return null;
    if (res.statusCode != 200) _fail(res);
    return _decode(res) as Map<String, dynamic>;
  }

  /// Búsqueda en todo el catálogo del servidor (incluye lo que no viene
  /// en la copia local por tamaño).
  Future<List<Map<String, dynamic>>> search({
    required String token,
    required String query,
  }) async {
    final res = await _get(_uri('/api/foods/search', {'q': query}), token);
    if (res.statusCode != 200) _fail(res);
    return ((_decode(res) as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  /// Envía un producto a verificación. Los macros van por 100 g/ml.
  Future<Map<String, dynamic>> contribute({
    required String token,
    required String clientId,
    required String name,
    String? brand,
    String? barcode,
    required double kcal,
    required double protein,
    required double carbs,
    required double fat,
    String baseUnit = 'g',
    double? servingG,
    String? servingLabel,
    List<XFile> photos = const [],
  }) async {
    final req = http.MultipartRequest('POST', _uri('/api/foods/contributions'))
      ..headers.addAll(_headers(token))
      ..fields.addAll({
        'client_id': clientId,
        'name': name,
        'brand': ?brand,
        'barcode': ?barcode,
        'kcal': '$kcal',
        'protein': '$protein',
        'carbs': '$carbs',
        'fat': '$fat',
        'base_unit': baseUnit,
        if (servingG != null) 'serving_g': '$servingG',
        'serving_label': ?servingLabel,
      });
    for (final photo in photos.take(3)) {
      req.files.add(
        http.MultipartFile.fromBytes(
          'photos',
          await photo.readAsBytes(),
          filename: photo.name,
          contentType: MediaType('image', _imageSubtype(photo.name)),
        ),
      );
    }
    http.Response res;
    try {
      res = await http.Response.fromStream(
        await _client.send(req).timeout(const Duration(seconds: 60)),
      );
    } catch (_) {
      throw const FoodApiException('Sin conexión con el servidor.');
    }
    if (res.statusCode != 201) _fail(res);
    return _decode(res) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> myContributions({
    required String token,
  }) async {
    final res = await _get(_uri('/api/foods/contributions'), token);
    if (res.statusCode != 200) _fail(res);
    return ((_decode(res) as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  static String _imageSubtype(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'png';
    if (lower.endsWith('.heic')) return 'heic';
    if (lower.endsWith('.webp')) return 'webp';
    return 'jpeg';
  }
}
