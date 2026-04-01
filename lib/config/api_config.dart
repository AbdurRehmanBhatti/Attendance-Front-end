class ApiConfig {
  ApiConfig._();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.100.46:5054',
    // defaultValue: 'https://attendance-backend-ahcgbkb8hafeg9ep.centralus-01.azurewebsites.net',
  );
}
