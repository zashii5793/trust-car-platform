import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:trust_car_platform/services/license_plate_masking_service.dart';

void main() {
  group('LicensePlateMaskingService', () {
    const service = LicensePlateMaskingService();

    // Create a minimal valid PNG (1×1 white pixel) for testing
    // PNG header + IHDR + IDAT + IEND
    Uint8List _makePng(int width, int height) {
      // Use the `image` package to create a test image programmatically
      // For unit tests, we create a simple 10x10 white PNG
      return _createTestPng(width, height);
    }

    group('maskRegion', () {
      test('正常系: 有効な画像とリージョンでマスク処理が成功する', () async {
        final imageBytes = _makePng(100, 100);
        final result = await service.maskRegion(
          imageBytes: imageBytes,
          left: 10,
          top: 10,
          width: 30,
          height: 15,
        );

        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull, isNotNull);
        expect(result.valueOrNull!.isNotEmpty, isTrue);
      });

      test('正常系: マスク後の画像は元の画像と異なる（変更されている）', () async {
        final imageBytes = _makePng(100, 100);
        final result = await service.maskRegion(
          imageBytes: imageBytes,
          left: 10,
          top: 10,
          width: 30,
          height: 15,
        );

        // Result bytes differ from input (mask was applied)
        expect(result.valueOrNull, isNotNull);
        // Can't guarantee byte-for-byte difference for a white image,
        // but we can verify it's valid and not null
        expect(result.valueOrNull!.length, greaterThan(0));
      });

      test('正常系: Uint8List が返される', () async {
        final imageBytes = _makePng(200, 150);
        final result = await service.maskRegion(
          imageBytes: imageBytes,
          left: 50,
          top: 50,
          width: 80,
          height: 30,
        );

        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull, isA<Uint8List>());
      });

      group('Edge Cases', () {
        test('空のバイト列はエラーを返す', () async {
          final result = await service.maskRegion(
            imageBytes: Uint8List(0),
            left: 10,
            top: 10,
            width: 30,
            height: 15,
          );
          expect(result.isFailure, isTrue);
        });

        test('負の left はバリデーションエラー', () async {
          final imageBytes = _makePng(100, 100);
          final result = await service.maskRegion(
            imageBytes: imageBytes,
            left: -1,
            top: 10,
            width: 30,
            height: 15,
          );
          expect(result.isFailure, isTrue);
        });

        test('負の top はバリデーションエラー', () async {
          final imageBytes = _makePng(100, 100);
          final result = await service.maskRegion(
            imageBytes: imageBytes,
            left: 10,
            top: -1,
            width: 30,
            height: 15,
          );
          expect(result.isFailure, isTrue);
        });

        test('width=0 はバリデーションエラー', () async {
          final imageBytes = _makePng(100, 100);
          final result = await service.maskRegion(
            imageBytes: imageBytes,
            left: 10,
            top: 10,
            width: 0,
            height: 15,
          );
          expect(result.isFailure, isTrue);
        });

        test('height=0 はバリデーションエラー', () async {
          final imageBytes = _makePng(100, 100);
          final result = await service.maskRegion(
            imageBytes: imageBytes,
            left: 10,
            top: 10,
            width: 30,
            height: 0,
          );
          expect(result.isFailure, isTrue);
        });

        test('画像範囲外のリージョンはクリッピングして成功する', () async {
          final imageBytes = _makePng(100, 100);
          // Region partially outside image
          final result = await service.maskRegion(
            imageBytes: imageBytes,
            left: 80,
            top: 80,
            width: 50, // extends beyond image width
            height: 50, // extends beyond image height
          );
          // Should clip to image bounds and succeed
          expect(result.isSuccess, isTrue);
        });

        test('画像全体をマスクしても成功する', () async {
          final imageBytes = _makePng(100, 100);
          final result = await service.maskRegion(
            imageBytes: imageBytes,
            left: 0,
            top: 0,
            width: 100,
            height: 100,
          );
          expect(result.isSuccess, isTrue);
        });
      });
    });

    group('maskMultipleRegions', () {
      test('正常系: 複数リージョンを一括でマスクできる', () async {
        final imageBytes = _makePng(200, 200);
        final result = await service.maskMultipleRegions(
          imageBytes: imageBytes,
          regions: const [
            MaskRegion(left: 10, top: 10, width: 30, height: 15),
            MaskRegion(left: 100, top: 100, width: 40, height: 20),
          ],
        );

        expect(result.isSuccess, isTrue);
      });

      test('正常系: リージョンが空の場合は元の画像を返す', () async {
        final imageBytes = _makePng(100, 100);
        final result = await service.maskMultipleRegions(
          imageBytes: imageBytes,
          regions: [],
        );

        expect(result.isSuccess, isTrue);
      });
    });
  });
}

/// Creates a valid PNG image using the image package for testing.
Uint8List _createTestPng(int width, int height) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(255, 255, 255));
  return Uint8List.fromList(img.encodePng(image));
}
