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
  static VehicleMaker? findMaker(
      List<VehicleMaker> makers, String ocrText) {
    if (ocrText.isEmpty) return null;
    final lowerText = ocrText.toLowerCase();

    // Pass 1: exact match.
    for (final maker in makers) {
      if (maker.name.toLowerCase() == lowerText ||
          maker.nameEn.toLowerCase() == lowerText) {
        return maker;
      }
    }

    // Pass 2: partial / contains match.
    for (final maker in makers) {
      if (maker.name.toLowerCase().contains(lowerText) ||
          maker.nameEn.toLowerCase().contains(lowerText) ||
          lowerText.contains(maker.name.toLowerCase()) ||
          lowerText.contains(maker.nameEn.toLowerCase())) {
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
    final lowerText = ocrModelName.toLowerCase();

    // Pass 1: exact match.
    for (final model in models) {
      if (model.name.toLowerCase() == lowerText ||
          model.nameEn?.toLowerCase() == lowerText) {
        return model;
      }
    }

    // Pass 2: partial / contains match.
    for (final model in models) {
      if (model.name.toLowerCase().contains(lowerText) ||
          (model.nameEn?.toLowerCase().contains(lowerText) ?? false) ||
          lowerText.contains(model.name.toLowerCase())) {
        return model;
      }
    }

    return null;
  }
}
