import 'package:flutter_test/flutter_test.dart';
import 'package:reciclai_mobile/config.dart';

void main() {
  test('usa la URL del emulador Android por defecto si no se pasa --dart-define', () {
    expect(AppConfig.apiBaseUrl, 'http://10.0.2.2:8000');
  });

  test('apiKey queda vacio si no se pasa --dart-define', () {
    expect(AppConfig.apiKey, isEmpty);
  });
}
