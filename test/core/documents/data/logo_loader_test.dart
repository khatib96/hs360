import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:hs360/core/documents/data/logo_loader.dart';

void main() {
  Uint8List pngBytes({int width = 32, int height = 32}) {
    return Uint8List.fromList(
      img.encodePng(img.Image(width: width, height: height)),
    );
  }

  group('NetworkLogoLoader', () {
    test('returns null for empty url', () async {
      final loader = NetworkLogoLoader(
        client: MockClient((_) async {
          throw Exception('should not fetch');
        }),
      );
      expect(await loader.loadValidated(null), isNull);
      expect(await loader.loadValidated('  '), isNull);
    });

    test('rejects non-https url', () async {
      final loader = NetworkLogoLoader(
        client: MockClient((_) async {
          throw Exception('should not fetch');
        }),
      );
      await expectLater(
        loader.loadValidated('http://example.com/logo.png'),
        throwsA(
          isA<LogoLoadException>().having(
            (e) => e.code,
            'code',
            NetworkLogoLoader.invalidUrl,
          ),
        ),
      );
    });

    test('accepts valid png with mime parameters', () async {
      final bytes = pngBytes();
      final loader = NetworkLogoLoader(
        client: MockClient(
          (_) async => http.Response.bytes(
            bytes,
            200,
            headers: {'content-type': 'image/png; charset=binary'},
          ),
        ),
      );
      final result = await loader.loadValidated('https://example.com/logo.png');
      expect(result, bytes);
    });

    test('rejects wrong mime type', () async {
      final loader = NetworkLogoLoader(
        client: MockClient(
          (_) async => http.Response.bytes(
            pngBytes(),
            200,
            headers: {'content-type': 'image/webp'},
          ),
        ),
      );
      await expectLater(
        loader.loadValidated('https://example.com/logo.webp'),
        throwsA(
          isA<LogoLoadException>().having(
            (e) => e.code,
            'code',
            NetworkLogoLoader.unsupportedFormat,
          ),
        ),
      );
    });

    test('rejects when magic bytes do not match mime', () async {
      final loader = NetworkLogoLoader(
        client: MockClient(
          (_) async => http.Response.bytes(
            Uint8List.fromList([0, 1, 2, 3, 4, 5]),
            200,
            headers: {'content-type': 'image/png'},
          ),
        ),
      );
      await expectLater(
        loader.loadValidated('https://example.com/logo.png'),
        throwsA(
          isA<LogoLoadException>().having(
            (e) => e.code,
            'code',
            NetworkLogoLoader.unsupportedFormat,
          ),
        ),
      );
    });

    test('rejects download larger than 512KB', () async {
      final loader = NetworkLogoLoader(
        client: _StreamingClient(
          bytes: List<int>.filled(512 * 1024 + 1, 0xFF),
          contentType: 'image/png',
        ),
      );
      await expectLater(
        loader.loadValidated('https://example.com/big.png'),
        throwsA(
          isA<LogoLoadException>().having(
            (e) => e.code,
            'code',
            NetworkLogoLoader.tooLarge,
          ),
        ),
      );
    });

    test('rejects dimensions above max side', () async {
      final bytes = pngBytes(width: 4097, height: 10);
      final loader = NetworkLogoLoader(
        client: MockClient(
          (_) async => http.Response.bytes(
            bytes,
            200,
            headers: {'content-type': 'image/png'},
          ),
        ),
      );
      await expectLater(
        loader.loadValidated('https://example.com/huge.png'),
        throwsA(
          isA<LogoLoadException>().having(
            (e) => e.code,
            'code',
            NetworkLogoLoader.invalidDimensions,
          ),
        ),
      );
    });

    test('rejects total pixels above 16MP', () async {
      final bytes = pngBytes(width: 5000, height: 4000);
      final loader = NetworkLogoLoader(
        maxSide: 5000,
        client: MockClient(
          (_) async => http.Response.bytes(
            bytes,
            200,
            headers: {'content-type': 'image/png'},
          ),
        ),
      );
      await expectLater(
        loader.loadValidated('https://example.com/huge.png'),
        throwsA(
          isA<LogoLoadException>().having(
            (e) => e.code,
            'code',
            NetworkLogoLoader.invalidDimensions,
          ),
        ),
      );
    });

    test('follows https redirects up to max 5', () async {
      var calls = 0;
      final bytes = pngBytes();
      final loader = NetworkLogoLoader(
        client: MockClient((request) async {
          calls++;
          if (request.url.path == '/logo.png') {
            return http.Response(
              '',
              302,
              headers: {'location': 'https://example.com/final.png'},
            );
          }
          return http.Response.bytes(
            bytes,
            200,
            headers: {'content-type': 'image/png'},
          );
        }),
      );
      final result = await loader.loadValidated('https://example.com/logo.png');
      expect(result, bytes);
      expect(calls, 2);
    });

    test('rejects http redirect target', () async {
      final loader = NetworkLogoLoader(
        client: MockClient(
          (_) async => http.Response(
            '',
            302,
            headers: {'location': 'http://example.com/logo.png'},
          ),
        ),
      );
      await expectLater(
        loader.loadValidated('https://example.com/start.png'),
        throwsA(
          isA<LogoLoadException>().having(
            (e) => e.code,
            'code',
            NetworkLogoLoader.invalidUrl,
          ),
        ),
      );
    });

    test('rejects more than 5 redirects', () async {
      var calls = 0;
      final loader = NetworkLogoLoader(
        client: MockClient((_) async {
          calls++;
          return http.Response(
            '',
            302,
            headers: {'location': 'https://example.com/loop.png'},
          );
        }),
      );
      await expectLater(
        loader.loadValidated('https://example.com/loop.png'),
        throwsA(
          isA<LogoLoadException>().having(
            (e) => e.code,
            'code',
            NetworkLogoLoader.fetchFailed,
          ),
        ),
      );
      expect(calls, greaterThan(5));
    });

    test('uses injectable client', () async {
      final jpeg = Uint8List.fromList(
        img.encodeJpg(img.Image(width: 16, height: 16)),
      );
      final client = MockClient(
        (_) async => http.Response.bytes(
          jpeg,
          200,
          headers: {'content-type': 'image/jpeg'},
        ),
      );
      final loader = NetworkLogoLoader(client: client);
      final result = await loader.loadValidated('https://example.com/logo.jpg');
      expect(result, jpeg);
    });
  });
}

class _StreamingClient extends http.BaseClient {
  _StreamingClient({required this.bytes, required this.contentType});

  final List<int> bytes;
  final String contentType;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(
      Stream<List<int>>.value(bytes),
      200,
      headers: {'content-type': contentType},
    );
  }
}
