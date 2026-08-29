class AppConfig {
  const AppConfig._();

  static const apiKey = String.fromEnvironment('RECICLAI_API_KEY');
  static const apiBaseUrl = String.fromEnvironment(
    'RECICLAI_API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );
}
