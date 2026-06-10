import '../../models/vehicle_master.dart';

/// Pure-function helpers for matching OCR-extracted text against master data.
///
/// Both methods use a two-pass strategy:
///   1. Exact match (case-insensitive) — avoids false positives from partial
///      matches when a shorter name is a substring of a longer one.
///   2. Partial / contains match — fallback for abbreviated or garbled OCR.
class VehicleOcrMatcher {
  // Private constructor — only static methods are exposed.
  const VehicleOcrMatcher._();

  /// Returns the first [VehicleMaker] whose [VehicleMaker.name] or
  /// [VehicleMaker.nameEn] matches [ocrText], or `null` if none match.
  ///
  /// Prefer exact match first to avoid false partial matches.
  static VehicleMaker? findMaker(List<VehicleMaker> makers, String ocrText) {
    if (ocrText.isEmpty) return null;
    final normalizedText = _normalize(ocrText);
    // Whitespace/symbol-only OCR text normalizes to empty; `contains('')`
    // is always true, so bail out to avoid matching the first maker.
    if (normalizedText.isEmpty) return null;

    // Pass 1: exact match.
    for (final maker in makers) {
      if (_normalize(maker.name) == normalizedText ||
          _normalize(maker.nameEn) == normalizedText) {
        return maker;
      }
    }

    // Pass 2: partial / contains match.
    for (final maker in makers) {
      if (_normalize(maker.name).contains(normalizedText) ||
          _normalize(maker.nameEn).contains(normalizedText) ||
          normalizedText.contains(_normalize(maker.name)) ||
          normalizedText.contains(_normalize(maker.nameEn))) {
        return maker;
      }
    }

    return null;
  }

  /// Returns the first [VehicleModel] whose [VehicleModel.name] or
  /// [VehicleModel.nameEn] matches [ocrModelName], or `null` if none match.
  ///
  /// Prefer exact match first to avoid false partial matches.
  static VehicleModel? findModel(
      List<VehicleModel> models, String ocrModelName) {
    if (ocrModelName.isEmpty) return null;
    final normalizedText = _normalize(ocrModelName);
    // Whitespace/symbol-only OCR text normalizes to empty; `contains('')`
    // is always true, so bail out to avoid matching the first model.
    if (normalizedText.isEmpty) return null;

    // Pass 1: exact match.
    for (final model in models) {
      if (_normalize(model.name) == normalizedText ||
          (model.nameEn != null ? _normalize(model.nameEn!) : null) ==
              normalizedText) {
        return model;
      }
    }

    // Pass 2: partial / contains match.
    for (final model in models) {
      if (_normalize(model.name).contains(normalizedText) ||
          (model.nameEn != null
              ? _normalize(model.nameEn!).contains(normalizedText)
              : false) ||
          normalizedText.contains(_normalize(model.name))) {
        return model;
      }
    }

    return null;
  }

  /// Normalises OCR text for robust Japanese matching:
  /// - Full-width ASCII (！-～, U+FF01..U+FF5E) → half-width (U+0021..U+007E)
  /// - Ideographic space (U+3000) → ASCII space
  /// Then lowercases and trims whitespace.
  static String _normalize(String text) {
    final buffer = StringBuffer();
    for (final codeUnit in text.codeUnits) {
      if (codeUnit >= 0xFF01 && codeUnit <= 0xFF5E) {
        // Full-width ASCII variants → corresponding half-width character
        buffer.writeCharCode(codeUnit - 0xFEE0);
      } else if (codeUnit == 0x3000) {
        // Ideographic space → regular space
        buffer.writeCharCode(0x0020);
      } else {
        buffer.writeCharCode(codeUnit);
      }
    }
    return buffer.toString().toLowerCase().trim();
  }
}
