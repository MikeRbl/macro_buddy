import 'package:flutter_test/flutter_test.dart';

import 'package:macrobuddy/core/config/api_config.dart';

void main() {
  group('ApiConfig.normalizeServer', () {
    test('agrega esquema y puerto a una IP sola', () {
      expect(
        ApiConfig.normalizeServer('192.168.1.10'),
        'http://192.168.1.10:3000',
      );
    });

    test('respeta un puerto explícito', () {
      expect(
        ApiConfig.normalizeServer('192.168.1.10:8080'),
        'http://192.168.1.10:8080',
      );
    });

    test('agrega el puerto si la URL no lo declara', () {
      expect(
        ApiConfig.normalizeServer('http://192.168.1.10'),
        'http://192.168.1.10:3000',
      );
    });

    test('quita el slash final de la raíz', () {
      expect(
        ApiConfig.normalizeServer('http://192.168.1.10:3000/'),
        'http://192.168.1.10:3000',
      );
    });

    test('no toca una URL https sin puerto', () {
      expect(
        ApiConfig.normalizeServer('https://example.com'),
        'https://example.com',
      );
    });

    test('normaliza localhost', () {
      expect(ApiConfig.normalizeServer('localhost'), 'http://localhost:3000');
    });

    test('rechaza entradas sin host o con esquema inválido', () {
      expect(ApiConfig.normalizeServer(''), isNull);
      expect(ApiConfig.normalizeServer('http://'), isNull);
      expect(ApiConfig.normalizeServer('ftp://example.com'), isNull);
    });
  });
}
