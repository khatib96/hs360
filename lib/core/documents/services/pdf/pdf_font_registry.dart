import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../domain/document_render_result.dart';
import '../../domain/effective_language.dart';
import '../document_render_dto.dart';

/// Loads bundled Noto fonts for Arabic/English PDF rendering.
class PdfFontRegistry {
  PdfFontRegistry._();

  static pw.Font? _regularLatin;
  static pw.Font? _boldLatin;
  static pw.Font? _regularArabic;
  static pw.Font? _boldArabic;
  static Uint8List? _regularLatinBytes;
  static Uint8List? _boldLatinBytes;
  static Uint8List? _regularArabicBytes;
  static Uint8List? _boldArabicBytes;

  static Future<void> ensureLoaded() async {
    if (_regularLatin != null) return;
    try {
      await initializeDateFormatting('en');
      await initializeDateFormatting('ar');
      final regularLatinData = await rootBundle.load(
        'assets/fonts/noto/NotoSans-Regular.ttf',
      );
      final boldLatinData = await rootBundle.load(
        'assets/fonts/noto/NotoSans-Bold.ttf',
      );
      final regularArabicData = await rootBundle.load(
        'assets/fonts/noto/NotoSansArabic-Regular.ttf',
      );
      final boldArabicData = await rootBundle.load(
        'assets/fonts/noto/NotoSansArabic-Bold.ttf',
      );

      _regularLatinBytes = Uint8List.fromList(
        regularLatinData.buffer.asUint8List(),
      );
      _boldLatinBytes = Uint8List.fromList(boldLatinData.buffer.asUint8List());
      _regularArabicBytes = Uint8List.fromList(
        regularArabicData.buffer.asUint8List(),
      );
      _boldArabicBytes = Uint8List.fromList(
        boldArabicData.buffer.asUint8List(),
      );

      _installFonts(
        regularLatin: ByteData.sublistView(_regularLatinBytes!),
        boldLatin: ByteData.sublistView(_boldLatinBytes!),
        regularArabic: ByteData.sublistView(_regularArabicBytes!),
        boldArabic: ByteData.sublistView(_boldArabicBytes!),
      );
    } catch (e) {
      throw DocumentRenderException(
        DocumentRenderException.fontLoadFailed,
        technicalDetail: e.toString(),
      );
    }
  }

  static Future<PdfFontTransferBundle> exportForIsolate() async {
    await ensureLoaded();
    return PdfFontTransferBundle(
      regularLatin: TransferableTypedData.fromList([_regularLatinBytes!]),
      boldLatin: TransferableTypedData.fromList([_boldLatinBytes!]),
      regularArabic: TransferableTypedData.fromList([_regularArabicBytes!]),
      boldArabic: TransferableTypedData.fromList([_boldArabicBytes!]),
    );
  }

  static void installFromBundle(PdfFontTransferBundle bundle) {
    _installFonts(
      regularLatin: ByteData.view(bundle.regularLatin.materialize()),
      boldLatin: ByteData.view(bundle.boldLatin.materialize()),
      regularArabic: ByteData.view(bundle.regularArabic.materialize()),
      boldArabic: ByteData.view(bundle.boldArabic.materialize()),
    );
  }

  static void _installFonts({
    required ByteData regularLatin,
    required ByteData boldLatin,
    required ByteData regularArabic,
    required ByteData boldArabic,
  }) {
    _regularLatin = pw.Font.ttf(regularLatin);
    _boldLatin = pw.Font.ttf(boldLatin);
    _regularArabic = pw.Font.ttf(regularArabic);
    _boldArabic = pw.Font.ttf(boldArabic);
  }

  static pw.TextStyle textStyle({
    required String languageCode,
    double fontSize = 10,
    bool bold = false,
  }) {
    final useArabic = fontLocaleFor(languageCode) == 'ar';
    final font = bold
        ? (useArabic ? _boldArabic : _boldLatin)
        : (useArabic ? _regularArabic : _regularLatin);
    final fallback = useArabic ? _regularLatin : _regularArabic;
    return pw.TextStyle(
      font: font,
      fontFallback: fallback != null ? [fallback] : const [],
      fontSize: fontSize,
    );
  }

  static pw.ThemeData theme(String languageCode) {
    final useArabic = fontLocaleFor(languageCode) == 'ar';
    final fallback = useArabic ? _regularLatin : _regularArabic;
    return pw.ThemeData.withFont(
      base: useArabic ? _regularArabic : _regularLatin,
      bold: useArabic ? _boldArabic : _boldLatin,
      fontFallback: fallback != null ? [fallback] : const [],
    );
  }
}
