import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../core/error/app_error.dart';
import '../core/result/result.dart';
import 'license_plate_masking_service.dart';

/// A single recognised text line together with its bounding box, decoupled
/// from ML Kit's own types so the plate heuristic can be unit-tested without
/// the (platform-only) ML Kit plugin.
class RecognizedTextLine {
  final String text;
  final int left;
  final int top;
  final int width;
  final int height;

  const RecognizedTextLine({
    required this.text,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });
}

/// Detects candidate Japanese license-plate regions in a vehicle photo using
/// on-device OCR (ML Kit text recognition).
///
/// The detector is intentionally permissive: it returns every box that *looks*
/// like a plate component so the user can confirm / adjust them before the
/// [LicensePlateMaskingService] obscures them. Detection never leaves the
/// device and the recognised text is never logged (it is personal data).
class LicensePlateDetectionService {
  const LicensePlateDetectionService();

  /// Runs OCR on [imageFile] and returns candidate plate regions.
  ///
  /// Returns an empty list (success) when no plate-like text is found — the
  /// user can still add a region manually. Failures are reserved for actual
  /// OCR errors.
  Future<Result<List<MaskRegion>, AppError>> detectFromImage(
    File imageFile,
  ) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.japanese);
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final recognized = await recognizer.processImage(inputImage);

      final lines = <RecognizedTextLine>[];
      for (final block in recognized.blocks) {
        for (final line in block.lines) {
          final box = line.boundingBox;
          lines.add(RecognizedTextLine(
            text: line.text,
            left: box.left.round(),
            top: box.top.round(),
            width: box.width.round(),
            height: box.height.round(),
          ));
        }
      }

      return Result.success(findPlateRegions(lines));
    } catch (e) {
      // Fixed message — exception details could echo recognised plate text.
      return Result.failure(
        const AppError.unknown('ナンバープレートの検出中にエラーが発生しました。'),
      );
    } finally {
      await recognizer.close();
    }
  }

  /// Plate-component patterns. A Japanese plate is "<地名> <分類番号> <かな>
  /// <一連指定番号>" (e.g. "品川 300 あ 12-34"), often split across OCR lines.
  static final List<RegExp> _platePatterns = [
    // Whole plate on one line.
    RegExp(
        r'[一-龥ぁ-んァ-ヶ]{2,4}\s*\d{3}\s*[あ-んア-ン]\s*\d{1,4}([-−]\d{1,4})?'),
    // Region name + classification number (optionally trailing kana),
    // e.g. "品川 300" or "品川 300 あ". Short-line guard prevents addresses.
    RegExp(r'[一-龥]{2,4}\s*\d{2,3}'),
    // Hiragana + serial number, e.g. "あ 12-34" / "さ1234".
    RegExp(r'[あ-ん]\s*\d{1,4}[-−]\d{1,4}'),
    // Large serial number with a hyphen, e.g. "12-34".
    RegExp(r'^\D{0,2}\d{1,2}[-−]\d{1,2}$'),
  ];

  /// Pure heuristic that turns recognised text lines into candidate mask
  /// regions. Exposed for testing without the ML Kit dependency.
  @visibleForTesting
  List<MaskRegion> findPlateRegions(List<RecognizedTextLine> lines) {
    final regions = <MaskRegion>[];
    for (final line in lines) {
      if (line.width <= 0 || line.height <= 0) continue;

      // Plates are short. Skip long lines (addresses, descriptions) to avoid
      // masking unrelated text.
      final compact = line.text.replaceAll(RegExp(r'\s'), '');
      if (compact.isEmpty || compact.length > 10) continue;

      final isPlate = _platePatterns.any((p) => p.hasMatch(line.text.trim()));
      if (!isPlate) continue;

      regions.add(_withMargin(line));
    }
    return regions;
  }

  /// Expands a detected line slightly so the mask fully covers the characters
  /// even if the OCR box is tight. Coordinates are clamped to be non-negative;
  /// the masking service clips the right/bottom edges to the image bounds.
  MaskRegion _withMargin(RecognizedTextLine line) {
    final mx = (line.width * 0.1).round();
    final my = (line.height * 0.2).round();
    final left = (line.left - mx) < 0 ? 0 : (line.left - mx);
    final top = (line.top - my) < 0 ? 0 : (line.top - my);
    return MaskRegion(
      left: left,
      top: top,
      width: line.width + mx * 2,
      height: line.height + my * 2,
    );
  }
}
