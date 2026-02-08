import 'dart:typed_data';
import 'dart:io' as io;
import 'package:image/image.dart' as img;
import '../core/result/result.dart';
import '../core/error/app_error.dart';

/// Image processing service for validation and compression
class ImageProcessingService {
  /// Maximum file size (10MB)
  static const int maxFileSizeBytes = 10 * 1024 * 1024;

  /// Maximum dimension (2000px)
  static const int maxDimension = 2000;

  /// JPEG quality for compression (0-100)
  static const int jpegQuality = 85;

  /// Target max file size after compression (500KB)
  static const int targetCompressedSize = 500 * 1024;

  /// Allowed MIME types
  static const List<String> allowedMimeTypes = [
    'image/jpeg',
    'image/jpg',
    'image/png',
    'image/webp',
  ];

  /// Validate image bytes before upload
  /// Returns error if validation fails
  Result<void, AppError> validateImage(Uint8List bytes) {
    // Check file size
    if (bytes.isEmpty) {
      return Result.failure(
        ValidationError('画像データが空です'),
      );
    }

    if (bytes.length > maxFileSizeBytes) {
      final sizeMb = (bytes.length / 1024 / 1024).toStringAsFixed(1);
      return Result.failure(
        ValidationError('画像サイズが大きすぎます（${sizeMb}MB）。10MB以下にしてください'),
      );
    }

    // Check MIME type by magic bytes
    final mimeType = _detectMimeType(bytes);
    if (mimeType == null) {
      return Result.failure(
        ValidationError('画像形式を判別できません'),
      );
    }

    if (!allowedMimeTypes.contains(mimeType)) {
      return Result.failure(
        ValidationError('対応していない画像形式です。JPEG、PNG、WebPをご使用ください'),
      );
    }

    return const Result.success(null);
  }

  /// Validate image file before upload
  Future<Result<void, AppError>> validateImageFile(io.File file) async {
    try {
      final bytes = await file.readAsBytes();
      return validateImage(bytes);
    } catch (e) {
      return Result.failure(
        ServerError('画像ファイルの読み込みに失敗しました: $e'),
      );
    }
  }

  /// Compress image bytes for upload
  /// Resizes to max dimension and compresses to JPEG
  Future<Result<Uint8List, AppError>> compressImage(Uint8List bytes) async {
    try {
      // Decode image
      final image = img.decodeImage(bytes);
      if (image == null) {
        return Result.failure(
          ValidationError('画像のデコードに失敗しました'),
        );
      }

      // Resize if necessary
      img.Image resized = image;
      if (image.width > maxDimension || image.height > maxDimension) {
        if (image.width > image.height) {
          resized = img.copyResize(image, width: maxDimension);
        } else {
          resized = img.copyResize(image, height: maxDimension);
        }
      }

      // Encode as JPEG with quality
      final compressed = img.encodeJpg(resized, quality: jpegQuality);
      final compressedBytes = Uint8List.fromList(compressed);

      // If still too large, reduce quality further
      if (compressedBytes.length > targetCompressedSize) {
        final reducedQuality = img.encodeJpg(resized, quality: 70);
        return Result.success(Uint8List.fromList(reducedQuality));
      }

      return Result.success(compressedBytes);
    } catch (e) {
      return Result.failure(
        ServerError('画像の圧縮に失敗しました: $e'),
      );
    }
  }

  /// Compress image file for upload
  Future<Result<Uint8List, AppError>> compressImageFile(io.File file) async {
    try {
      final bytes = await file.readAsBytes();
      return compressImage(bytes);
    } catch (e) {
      return Result.failure(
        ServerError('画像ファイルの読み込みに失敗しました: $e'),
      );
    }
  }

  /// Validate and compress image in one step
  Future<Result<Uint8List, AppError>> processImage(Uint8List bytes) async {
    // Validate first
    final validationResult = validateImage(bytes);
    if (validationResult.isFailure) {
      return Result.failure(validationResult.errorOrNull!);
    }

    // Then compress
    return compressImage(bytes);
  }

  /// Validate and compress image file in one step
  Future<Result<Uint8List, AppError>> processImageFile(io.File file) async {
    try {
      final bytes = await file.readAsBytes();
      return processImage(bytes);
    } catch (e) {
      return Result.failure(
        ServerError('画像ファイルの読み込みに失敗しました: $e'),
      );
    }
  }

  /// Detect MIME type from magic bytes
  String? _detectMimeType(Uint8List bytes) {
    if (bytes.length < 12) return null;

    // JPEG: FF D8 FF
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
      return 'image/jpeg';
    }

    // PNG: 89 50 4E 47 0D 0A 1A 0A
    if (bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0D &&
        bytes[5] == 0x0A &&
        bytes[6] == 0x1A &&
        bytes[7] == 0x0A) {
      return 'image/png';
    }

    // WebP: RIFF....WEBP
    if (bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return 'image/webp';
    }

    return null;
  }

  /// Get image dimensions without fully decoding
  Result<({int width, int height}), AppError> getImageDimensions(Uint8List bytes) {
    try {
      final image = img.decodeImage(bytes);
      if (image == null) {
        return Result.failure(
          ValidationError('画像のデコードに失敗しました'),
        );
      }
      return Result.success((width: image.width, height: image.height));
    } catch (e) {
      return Result.failure(
        ServerError('画像サイズの取得に失敗しました: $e'),
      );
    }
  }
}
