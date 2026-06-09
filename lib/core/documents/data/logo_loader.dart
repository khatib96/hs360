import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

/// Loads and validates tenant logo bytes for PDF rendering.
abstract class LogoLoader {
  Future<Uint8List?> loadValidated(String? url);
}

class NetworkLogoLoader implements LogoLoader {
  NetworkLogoLoader({
    http.Client? client,
    this.maxBytes = 512 * 1024,
    this.maxSide = 4096,
    this.maxTotalPixels = 16_777_216,
    this.maxRedirects = 5,
    this.timeout = const Duration(seconds: 5),
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final int maxBytes;
  final int maxSide;
  final int maxTotalPixels;
  final int maxRedirects;
  final Duration timeout;

  static const invalidUrl = 'logo_invalid_url';
  static const tooLarge = 'logo_too_large';
  static const invalidDimensions = 'logo_invalid_dimensions';
  static const unsupportedFormat = 'logo_unsupported_format';
  static const fetchFailed = 'logo_fetch_failed';

  static const _allowedMimeTypes = {'image/png', 'image/jpeg'};

  @override
  Future<Uint8List?> loadValidated(String? url) async {
    if (url == null || url.trim().isEmpty) return null;
    final trimmed = url.trim();
    if (!_isHttps(trimmed)) {
      throw const LogoLoadException(invalidUrl);
    }

    late final Uint8List bytes;
    try {
      bytes = await _download(Uri.parse(trimmed)).timeout(timeout);
    } on LogoLoadException {
      rethrow;
    } on TimeoutException {
      throw const LogoLoadException(fetchFailed);
    } catch (_) {
      throw const LogoLoadException(fetchFailed);
    }
    _validateMagicBytes(bytes);
    _validateDimensions(bytes);
    return bytes;
  }

  Future<Uint8List> _download(Uri uri, {int redirectCount = 0}) async {
    if (!_isHttps(uri.toString())) {
      throw const LogoLoadException(invalidUrl);
    }
    if (redirectCount > maxRedirects) {
      throw const LogoLoadException(fetchFailed);
    }

    final request = http.Request('GET', uri);
    final streamed = await _client.send(request);

    final statusCode = streamed.statusCode;
    if (statusCode >= 300 && statusCode < 400) {
      final location = streamed.headers['location'];
      if (location == null || location.trim().isEmpty) {
        await streamed.stream.drain<void>();
        throw const LogoLoadException(fetchFailed);
      }
      await streamed.stream.drain<void>();
      return _download(
        uri.resolve(location.trim()),
        redirectCount: redirectCount + 1,
      );
    }

    if (statusCode != 200) {
      await streamed.stream.drain<void>();
      throw const LogoLoadException(fetchFailed);
    }

    final mime = _normalizeMime(streamed.headers['content-type']);
    if (mime == null || !_allowedMimeTypes.contains(mime)) {
      await streamed.stream.drain<void>();
      throw const LogoLoadException(unsupportedFormat);
    }

    final builder = BytesBuilder(copy: false);
    try {
      await for (final chunk in streamed.stream) {
        builder.add(chunk);
        if (builder.length > maxBytes) {
          throw const LogoLoadException(tooLarge);
        }
      }
    } on LogoLoadException {
      rethrow;
    } catch (_) {
      throw const LogoLoadException(fetchFailed);
    }

    if (builder.isEmpty) {
      throw const LogoLoadException(unsupportedFormat);
    }

    return Uint8List.fromList(builder.takeBytes());
  }

  static bool _isHttps(String value) =>
      value.toLowerCase().startsWith('https://');

  static String? _normalizeMime(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final base = raw.split(';').first.trim().toLowerCase();
    return base.isEmpty ? null : base;
  }

  void _validateMagicBytes(Uint8List bytes) {
    final isPng = _looksLikePng(bytes);
    final isJpeg = _looksLikeJpeg(bytes);
    if (!isPng && !isJpeg) {
      throw const LogoLoadException(unsupportedFormat);
    }
  }

  void _validateDimensions(Uint8List bytes) {
    final decoder = img.findDecoderForData(bytes);
    final info = decoder?.startDecode(bytes);
    if (info == null) {
      throw const LogoLoadException(unsupportedFormat);
    }

    if (info.width > maxSide || info.height > maxSide) {
      throw const LogoLoadException(invalidDimensions);
    }

    final totalPixels = info.width * info.height;
    if (totalPixels > maxTotalPixels) {
      throw const LogoLoadException(invalidDimensions);
    }
  }

  bool _looksLikePng(Uint8List bytes) =>
      bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47;

  bool _looksLikeJpeg(Uint8List bytes) =>
      bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8;
}

class LogoLoadException implements Exception {
  const LogoLoadException(this.code);

  final String code;

  @override
  String toString() => 'LogoLoadException($code)';
}
