abstract final class ApiConfig {
  /// Base URL of the Macrobuddy backend.
  /// Local dev: http://localhost:3000 (emulador Android: http://10.0.2.2:3000)
  /// Override with: --dart-define=API_BASE_URL=...
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000',
  );
}
