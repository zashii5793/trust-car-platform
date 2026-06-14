import 'dart:typed_data';
import 'package:image/image.dart' as img;
import '../core/error/app_error.dart';
import '../core/result/result.dart';

/// A rectangular region to be masked in an image.
class MaskRegion {
  final int left;
  final int top;
  final int width;
  final int height;

  const MaskRegion({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });
}

/// Applies an opaque black mask over specified regions in a JPEG/PNG image.
///
/// Privacy use case: hide vehicle license plate numbers before uploading
/// photos to the community SNS feed.
///
/// The service is a pure function (no Firestore / no side effects). The caller
/// is responsible for uploading the returned bytes via [ImageProcessingService].
class LicensePlateMaskingService {
  const LicensePlateMaskingService();

  /// Masks [left,top,width,height] in [imageBytes] with a solid black rectangle.
  ///
  /// If the region extends beyond the image boundaries it is clipped silently.
  Future<Result<Uint8List, AppError>> maskRegion({
    required Uint8List imageBytes,
    required int left,
    required int top,
    required int width,
    required int height,
  }) async {
    if (imageBytes.isEmpty) {
      return const Result.failure(
        AppError.validation('imageBytes must not be empty'),
      );
    }
    if (left < 0 || top < 0) {
      return const Result.failure(
        AppError.validation('left and top must be non-negative'),
      );
    }
    if (width <= 0 || height <= 0) {
      return const Result.failure(
        AppError.validation('width and height must be positive'),
      );
    }

    return maskMultipleRegions(
      imageBytes: imageBytes,
      regions: [MaskRegion(left: left, top: top, width: width, height: height)],
    );
  }

  /// Applies black masks over multiple regions in a single pass.
  Future<Result<Uint8List, AppError>> maskMultipleRegions({
    required Uint8List imageBytes,
    required List<MaskRegion> regions,
  }) async {
    if (imageBytes.isEmpty) {
      return const Result.failure(
        AppError.validation('imageBytes must not be empty'),
      );
    }

    try {
      final image = img.decodeImage(imageBytes);
      if (image == null) {
        return const Result.failure(
          AppError.validation('failed to decode image — unsupported format'),
        );
      }

      if (regions.isEmpty) {
        // No regions to mask — re-encode and return
        final encoded = img.encodePng(image);
        return Result.success(Uint8List.fromList(encoded));
      }

      // Fully opaque black mask color (RGBA)
      final black = img.ColorRgba8(0, 0, 0, 255);

      for (final region in regions) {
        // Clip region to image bounds
        final x1 = region.left.clamp(0, image.width - 1);
        final y1 = region.top.clamp(0, image.height - 1);
        final x2 = (region.left + region.width).clamp(0, image.width - 1);
        final y2 = (region.top + region.height).clamp(0, image.height - 1);

        img.fillRect(
          image,
          x1: x1,
          y1: y1,
          x2: x2,
          y2: y2,
          color: black,
          alphaBlend: false,
        );
      }

      final encoded = img.encodePng(image);
      return Result.success(Uint8List.fromList(encoded));
    } catch (e) {
      return Result.failure(AppError.unknown(e.toString(), originalError: e));
    }
  }
}
