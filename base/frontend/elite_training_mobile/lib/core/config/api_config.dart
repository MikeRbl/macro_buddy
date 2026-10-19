abstract final class ApiConfig {
  /// Base URL of the Elite Training backend.
  /// Production: https://elte-training-backend.onrender.com
  /// Override with: --dart-define=API_BASE_URL=...
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://elte-training-backend.onrender.com',
  );
}
