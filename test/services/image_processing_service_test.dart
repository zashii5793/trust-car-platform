import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/services/image_processing_service.dart';
import 'package:trust_car_platform/core/error/app_error.dart';

void main() {
  late ImageProcessingService service;

  setUp(() {
    service = ImageProcessingService();
  });

  group('ImageProcessingService', () {
    group('validateImage', () {
      test('returns failure for empty bytes', () {
        final result = service.validateImage(Uint8List(0));

        expect(result.isFailure, isTrue);
        expect(result.errorOrNull, isA<ValidationError>());
      });

      test('returns failure for oversized image', () {
        // Create bytes larger than 10MB
        final largeBytes = Uint8List(11 * 1024 * 1024);
        // Add JPEG magic bytes so it passes format check
        largeBytes[0] = 0xFF;
        largeBytes[1] = 0xD8;
        largeBytes[2] = 0xFF;

        final result = service.validateImage(largeBytes);

        // Size check happens before MIME type check
        expect(result.isFailure, isTrue);
        expect(result.errorOrNull, isA<ValidationError>());
      });

      test('returns failure for unknown format', () {
        // Random bytes that don't match any known format
        final unknownBytes = Uint8List.fromList([0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B]);

        final result = service.validateImage(unknownBytes);

        expect(result.isFailure, isTrue);
        expect(result.errorOrNull, isA<ValidationError>());
      });

      test('returns success for valid JPEG', () {
        // JPEG magic bytes: FF D8 FF
        final jpegBytes = Uint8List.fromList([
          0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46,
          0x49, 0x46, 0x00, 0x01, 0x01, 0x00, 0x00, 0x01,
        ]);

        final result = service.validateImage(jpegBytes);

        expect(result.isSuccess, isTrue);
      });

      test('returns success for valid PNG', () {
        // PNG magic bytes: 89 50 4E 47 0D 0A 1A 0A
        final pngBytes = Uint8List.fromList([
          0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
          0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
        ]);

        final result = service.validateImage(pngBytes);

        expect(result.isSuccess, isTrue);
      });

      test('returns success for valid WebP', () {
        // WebP magic bytes: RIFF....WEBP
        final webpBytes = Uint8List.fromList([
          0x52, 0x49, 0x46, 0x46, // RIFF
          0x00, 0x00, 0x00, 0x00, // size
          0x57, 0x45, 0x42, 0x50, // WEBP
          0x00, 0x00, 0x00, 0x00,
        ]);

        final result = service.validateImage(webpBytes);

        expect(result.isSuccess, isTrue);
      });
    });

    group('compressImage', () {
      test('returns failure for invalid image data', () async {
        final invalidBytes = Uint8List.fromList([0x00, 0x01, 0x02, 0x03]);

        final result = await service.compressImage(invalidBytes);

        expect(result.isFailure, isTrue);
        // Can be ValidationError or ServerError depending on decode stage
        expect(result.errorOrNull, isA<AppError>());
      });

      // Note: Testing actual compression requires a valid image file
      // which would need to be included as a test asset
    });

    group('processImage', () {
      test('returns failure for empty bytes', () async {
        final result = await service.processImage(Uint8List(0));

        expect(result.isFailure, isTrue);
        expect(result.errorOrNull, isA<ValidationError>());
      });

      test('returns failure for invalid format', () async {
        final invalidBytes = Uint8List.fromList([0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B]);

        final result = await service.processImage(invalidBytes);

        expect(result.isFailure, isTrue);
      });
    });

    group('getImageDimensions', () {
      test('returns failure for invalid image data', () {
        final invalidBytes = Uint8List.fromList([0x00, 0x01, 0x02, 0x03]);

        final result = service.getImageDimensions(invalidBytes);

        expect(result.isFailure, isTrue);
      });
    });

    group('constants', () {
      test('has correct max file size', () {
        expect(ImageProcessingService.maxFileSizeBytes, equals(10 * 1024 * 1024));
      });

      test('has correct max dimension', () {
        expect(ImageProcessingService.maxDimension, equals(2000));
      });

      test('has correct jpeg quality', () {
        expect(ImageProcessingService.jpegQuality, equals(85));
      });

      test('has correct target compressed size', () {
        expect(ImageProcessingService.targetCompressedSize, equals(500 * 1024));
      });

      test('has correct allowed mime types', () {
        expect(ImageProcessingService.allowedMimeTypes, contains('image/jpeg'));
        expect(ImageProcessingService.allowedMimeTypes, contains('image/png'));
        expect(ImageProcessingService.allowedMimeTypes, contains('image/webp'));
      });
    });
  });
}
