import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Configuración de la conexión con el backend.
///
/// Prioridad al arrancar:
/// 1. URL guardada desde el diálogo "Servidor" del login.
/// 2. `--dart-define=API_BASE_URL=...` (útil para compilar un APK fijo).
/// 3. `http://localhost:3000`.
///
/// El diálogo acepta la IP sola (`192.168.1.10`) o la URL completa
/// (`http://192.168.1.10:3000`).
abstract final class ApiConfig {
  static const String _dartDefine = String.fromEnvironment('API_BASE_URL');
  static const String _kFallback = 'http://localhost:3000';
  static const String _storageKey = 'server_base_url';

  static String get defaultBaseUrl {
    final define = _dartDefine.trim();
    return define.isEmpty ? _kFallback : define;
  }

  static String _baseUrl = defaultBaseUrl;

  /// URL activa. `load()` o `setBaseUrl()` la fijan.
  static String get baseUrl => _baseUrl;

  /// Carga la URL persistida. Se llama una vez antes de `runApp`.
  static Future<void> load() async {
    WidgetsFlutterBinding.ensureInitialized();
    final prefs = await SharedPreferences.getInstance();
    final persisted = prefs.getString(_storageKey)?.trim() ?? '';
    _baseUrl = persisted.isEmpty
        ? defaultBaseUrl
        : (normalizeServer(persisted) ?? defaultBaseUrl);
  }

  /// Valida, guarda y aplica la URL del servidor.
  ///
  /// Devuelve `false` si la entrada no es una URL utilizable.
  static Future<bool> setBaseUrl(String raw) async {
    final clean = normalizeServer(raw);
    if (clean == null) return false;
    _baseUrl = clean;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, clean);
    return true;
  }

  /// Vuelve a la URL por defecto (localhost o el `--dart-define`).
  static Future<void> resetBaseUrl() async {
    _baseUrl = defaultBaseUrl;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }

  /// Normaliza la entrada del usuario:
  /// - `192.168.1.10` → `http://192.168.1.10:3000`
  /// - `192.168.1.10:8080` → `http://192.168.1.10:8080`
  /// - `http://192.168.1.10` → `http://192.168.1.10:3000`
  /// - `http://192.168.1.10:3000/` → `http://192.168.1.10:3000`
  ///
  /// Devuelve `null` si no hay un host válido.
  static String? normalizeServer(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return null;
    if (!s.contains('://')) s = 'http://$s';

    final uri = Uri.tryParse(s);
    if (uri == null || uri.host.isEmpty) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;

    // El backend local vive en 3000; si escriben solo la IP se completa.
    if (!uri.hasPort && uri.scheme == 'http') {
      s = uri.replace(port: 3000).toString();
    }

    // Un slash final en la raíz rompe la concatenación de rutas del API.
    if (s.endsWith('/') && (uri.path.isEmpty || uri.path == '/')) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }
}
