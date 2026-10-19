import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Configuración viva de la conexión con el backend.
///
/// Prioridad en `load()`:
/// 1. `--dart-define=API_BASE_URL=...` (CI / APK física).
/// 2. URL persistida en `SharedPreferences` (elegida en el diálogo
///    "Servidor" de la pantalla de login).
/// 3. Localhost (dev local).
abstract final class ApiConfig {
  static const String _dartDefine = String.fromEnvironment('API_BASE_URL');
  static const String _kDefault = 'http://localhost:3000';
  static const String _storageKey = 'server_base_url';

  static String _baseUrl = _kDefault;
  static bool _loaded = false;

  /// URL activa. `.load()` o `setBaseUrl()` la fijan.
  static String get baseUrl => _baseUrl;

  /// `true` si ya se ejecutó `load()`.
  static bool get isLoaded => _loaded;

  /// Debe llamarse una sola vez antes de `runApp` (con
  /// `WidgetsFlutterBinding.ensureInitialized()` de por medio).
  static Future<void> load() async {
    WidgetsFlutterBinding.ensureInitialized();
    final dartDefine = _dartDefine.trim();
    if (dartDefine.isNotEmpty) {
      _baseUrl = dartDefine;
      _loaded = true;
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final persisted = prefs.getString(_storageKey)?.trim() ?? '';
    _baseUrl = persisted.isEmpty ? _kDefault : persisted;
    _loaded = true;
  }

  /// Cambia y persiste la URL del servidor (elegida en runtime).
  ///
  /// Acepta solo la IP (`192.168.100.19`) y la normaliza a
  /// `http://192.168.100.19:3000`; también acepta una URL completa
  /// (`http://192.168.100.19:8080`) o `localhost`.
  static Future<void> setBaseUrl(String url) async {
    final clean = normalizeServer(url);
    _baseUrl = clean;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, _baseUrl);
  }

  /// `192.168.1.4` → `http://192.168.1.4:3000`.
  /// `mi-host` → `http://mi-host:3000`. URL con esquema/puerto → intacta.
  static String normalizeServer(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return _kDefault;
    if (!s.toLowerCase().startsWith('http://') &&
        !s.toLowerCase().startsWith('https://')) {
      s = 'http://$s';
    }
    // Descarta basura que no sea host[:puerto][/ruta].
    final uri = Uri.tryParse(s);
    if (uri == null || uri.host.isEmpty) return _kDefault;
    final m = RegExp(
      r'^(https?://[^/\s:]+)(?::(\d+))?(/.*)?$',
      caseSensitive: false,
    ).firstMatch(s);
    if (m != null && m.group(2) == null) {
      // Sin puerto declarado: el backend fijo en 3000.
      s = '${m.group(1)}:3000${m.group(3) ?? ''}';
    }
    return s;
  }
}
