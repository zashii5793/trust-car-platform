// Unit tests for VehicleOcrMatcher
//
// Covers:
//   findMaker:
//     - Exact Japanese name match
//     - Exact English name match
//     - Partial match: OCR text contains maker name
//     - Partial match: maker name contains OCR text
//     - Exact match wins over earlier partial-match candidate
//     - No match → null
//     - Empty ocrText → null
//     - Empty list → null
//   findMaker Edge Cases:
//     - Case insensitive (TOYOTA matches Toyota/トヨタ entry)
//     - Multiple partial matches → first partial match returned
//
//   findModel:
//     - Exact Japanese name match
//     - Exact English name match
//     - Partial match when OCR contains model name
//     - Exact match wins over earlier partial-match candidate
//     - No match → null
//     - Empty ocrModelName → null
//     - Model with null nameEn → still matches by Japanese name
//   findModel Edge Cases:
//     - Case insensitive matching
//     - nameEn is null, OCR is Japanese → still matches

import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/models/vehicle_master.dart';
import 'package:trust_car_platform/screens/vehicle/vehicle_ocr_matcher.dart';

// ---------------------------------------------------------------------------
// Test fixture helpers
// ---------------------------------------------------------------------------

VehicleMaker _maker(String id, String name, String nameEn) => VehicleMaker(
      id: id,
      name: name,
      nameEn: nameEn,
      country: 'JP',
    );

VehicleModel _model(String id, String name, {String? nameEn}) => VehicleModel(
      id: id,
      makerId: 'maker-1',
      name: name,
      nameEn: nameEn,
    );

// Standard maker list used across most findMaker tests.
final _makers = [
  _maker('1', 'トヨタ', 'Toyota'),
  _maker('2', 'ホンダ', 'Honda'),
  _maker('3', 'ニッサン', 'Nissan'),
];

// Standard model list used across most findModel tests.
final _models = [
  _model('1', 'プリウス', nameEn: 'Prius'),
  _model('2', 'アルファード', nameEn: 'Alphard'),
  _model('3', 'ヴォクシー', nameEn: 'Voxy'),
];

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('VehicleOcrMatcher', () {
    // =========================================================================
    group('findMaker', () {
      test('exact Japanese name → returns that maker', () {
        final result = VehicleOcrMatcher.findMaker(_makers, 'ホンダ');
        expect(result, isNotNull);
        expect(result!.id, '2');
      });

      test('exact English name → returns that maker', () {
        final result = VehicleOcrMatcher.findMaker(_makers, 'Honda');
        expect(result, isNotNull);
        expect(result!.id, '2');
      });

      test('OCR text contains maker name (partial) → returns maker', () {
        // OCR reads something like "トヨタ自動車" — the OCR text contains the
        // maker's Japanese name.
        final result = VehicleOcrMatcher.findMaker(_makers, 'トヨタ自動車株式会社');
        expect(result, isNotNull);
        expect(result!.id, '1');
      });

      test('maker name contains OCR text (partial) → returns maker', () {
        // OCR reads "Niss" which is contained in "Nissan".
        final result = VehicleOcrMatcher.findMaker(_makers, 'Niss');
        expect(result, isNotNull);
        expect(result!.id, '3');
      });

      test(
          'exact match wins over partial match '
          '(put partial-match candidate first in list)', () {
        // "Toyota Motor" partially matches トヨタ/Toyota (entry id=1).
        // "Toyota" exact-matches entry id=99 (added later in the list).
        // Exact match must win even though the partial candidate comes first.
        final makers = [
          _maker('partial', 'トヨタ自動車', 'Toyota Motor'),
          _maker('exact', 'トヨタ', 'Toyota'),
        ];
        final result = VehicleOcrMatcher.findMaker(makers, 'トヨタ');
        expect(result, isNotNull);
        expect(result!.id, 'exact');
      });

      test('no match → returns null', () {
        final result = VehicleOcrMatcher.findMaker(_makers, 'フォルクスワーゲン');
        expect(result, isNull);
      });

      test('empty string ocrText → returns null', () {
        final result = VehicleOcrMatcher.findMaker(_makers, '');
        expect(result, isNull);
      });

      test('empty list → returns null', () {
        final result = VehicleOcrMatcher.findMaker([], 'トヨタ');
        expect(result, isNull);
      });

      group('Edge Cases', () {
        test('case insensitive: TOYOTA matches トヨタ/Toyota', () {
          final result = VehicleOcrMatcher.findMaker(_makers, 'TOYOTA');
          expect(result, isNotNull);
          expect(result!.id, '1');
        });

        test('multiple partial matches → returns first partial match', () {
          // Both "Honda" and "Hond Motors" partially contain/are-contained-by
          // "Hond". The first entry in the list that matches should be returned.
          final makers = [
            _maker('a', 'ホンダ', 'Honda'),
            _maker('b', '本田', 'Hondamoto'),
          ];
          // "Hond" is contained in both "Honda" and "Hondamoto".
          final result = VehicleOcrMatcher.findMaker(makers, 'Hond');
          expect(result, isNotNull);
          expect(result!.id, 'a'); // first in list
        });
      });
    });

    // =========================================================================
    group('findModel', () {
      test('exact Japanese name match → returns that model', () {
        final result = VehicleOcrMatcher.findModel(_models, 'プリウス');
        expect(result, isNotNull);
        expect(result!.id, '1');
      });

      test('exact English name match → returns that model', () {
        final result = VehicleOcrMatcher.findModel(_models, 'Alphard');
        expect(result, isNotNull);
        expect(result!.id, '2');
      });

      test('partial match when OCR contains model name → returns model', () {
        // OCR text "ヴォクシーZS" contains the model name "ヴォクシー".
        final result = VehicleOcrMatcher.findModel(_models, 'ヴォクシーZS');
        expect(result, isNotNull);
        expect(result!.id, '3');
      });

      test('exact match wins over partial match', () {
        // "Prius Alpha" partially matches "Prius" (id=1).
        // "Prius" exact-matches the entry with id=exact (added last).
        final models = [
          _model('partial', 'プリウスα', nameEn: 'Prius Alpha'),
          _model('exact', 'プリウス', nameEn: 'Prius'),
        ];
        final result = VehicleOcrMatcher.findModel(models, 'Prius');
        expect(result, isNotNull);
        expect(result!.id, 'exact');
      });

      test('no match → returns null', () {
        final result = VehicleOcrMatcher.findModel(_models, 'カローラ');
        expect(result, isNull);
      });

      test('empty ocrModelName → returns null', () {
        final result = VehicleOcrMatcher.findModel(_models, '');
        expect(result, isNull);
      });

      test('model with null nameEn → still matches by Japanese name', () {
        final models = [
          _model('1', 'プリウス'), // nameEn is null
        ];
        final result = VehicleOcrMatcher.findModel(models, 'プリウス');
        expect(result, isNotNull);
        expect(result!.id, '1');
      });

      group('Edge Cases', () {
        test('case insensitive matching', () {
          final result = VehicleOcrMatcher.findModel(_models, 'PRIUS');
          expect(result, isNotNull);
          expect(result!.id, '1');
        });

        test('model nameEn is null, OCR is Japanese → still matches', () {
          final models = [
            _model('jp-only', 'アクア'), // no English name
          ];
          final result = VehicleOcrMatcher.findModel(models, 'アクア');
          expect(result, isNotNull);
          expect(result!.id, 'jp-only');
        });
      });
    });

    // =========================================================================
    group('normalization', () {
      test('全角英字 → 半角変換でマッチする (Ｔｏｙｏｔａ → Toyota)', () {
        // Full-width "Ｔｏｙｏｔａ" should normalize to "toyota" and match トヨタ/Toyota
        final result = VehicleOcrMatcher.findMaker(_makers, 'Ｔｏｙｏｔａ');
        expect(result, isNotNull);
        expect(result!.id, '1');
      });

      test('全角数字は正規化される (２０２４ → 2024)', () {
        // This tests the normalize function itself via model matching.
        // Create a model named "RAV4" and search with full-width "ＲＡＶ４"
        final models = [
          VehicleModel(
              id: 'rav4', makerId: 'toyota', name: 'RAV4', nameEn: 'RAV4'),
        ];
        final result = VehicleOcrMatcher.findModel(models, 'ＲＡＶ４');
        expect(result, isNotNull);
        expect(result!.id, 'rav4');
      });

      test('全角スペース（U+3000）は半角スペースとして扱う', () {
        final makers = [
          VehicleMaker(id: 'bmw', name: 'BMW', nameEn: 'BMW', country: 'DE'),
        ];
        // "ＢＭＷ　プレミアム" — full-width letters + ideographic space + trailing text
        // Should still match BMW via contains logic after normalization
        final result = VehicleOcrMatcher.findMaker(makers, 'ＢＭＷ　ジャパン');
        expect(result, isNotNull);
      });

      test('マスタデータ側も正規化される（マスタがＨＯＮＤＡの場合でもhondaでマッチ）', () {
        // If master data itself has full-width chars (shouldn't happen but defensive)
        final makers = [
          VehicleMaker(id: 'h', name: 'ホンダ', nameEn: 'ＨＯＮＤＡ', country: 'JP'),
        ];
        final result = VehicleOcrMatcher.findMaker(makers, 'Honda');
        expect(result, isNotNull);
        expect(result!.id, 'h');
      });

      group('Edge Cases', () {
        test('全角記号のみ → null', () {
          final result = VehicleOcrMatcher.findMaker(_makers, '　　　');
          // ideographic spaces only — after normalization becomes empty/spaces, no match
          expect(result, isNull);
        });
      });
    });

    // =========================================================================
    group('実車検証OCRパターン', () {
      // These tests use OCR text patterns actually seen on Japanese 車検証.

      test('「トヨタ」正確読み取り → マッチ', () {
        final result = VehicleOcrMatcher.findMaker(_makers, 'トヨタ');
        expect(result?.id, '1');
      });

      test('「プリウス」正確読み取り → マッチ', () {
        final result = VehicleOcrMatcher.findModel(_models, 'プリウス');
        expect(result?.id, '1');
      });

      test('前後に余分なスペースが入る「 トヨタ 」→ trimで正規化されマッチ', () {
        // _normalize() calls .trim() — leading/trailing spaces are removed
        final result = VehicleOcrMatcher.findMaker(_makers, ' トヨタ ');
        expect(result?.id, '1');
      });

      test('車名に型式が混入「プリウス ZVW50」→ 車名部分で部分マッチ', () {
        // OCR may pick up the grade code alongside the model name.
        // The model name "プリウス" is contained in "プリウス ZVW50".
        final result = VehicleOcrMatcher.findModel(_models, 'プリウス ZVW50');
        expect(result?.id, '1');
      });

      test('メーカー名に「株式会社」が混入 → 部分マッチで対応', () {
        // e.g. OCR reads "トヨタ自動車株式会社" from the vehicle certificate header
        final result = VehicleOcrMatcher.findMaker(_makers, 'トヨタ自動車株式会社');
        expect(result?.id, '1');
      });

      // --- Known gap: half-width katakana is NOT yet normalized ---
      // TODO: half-width katakana support (ﾄﾖﾀ → トヨタ) is a future enhancement.
      test('半角カタカナ「ﾄﾖﾀ」は現状マッチしない（既知の未対応パターン）', () {
        // This test DOCUMENTS a known gap. When half-width katakana normalization
        // is implemented, change expect to isNotNull.
        final result = VehicleOcrMatcher.findMaker(_makers, 'ﾄﾖﾀ');
        expect(result,
            isNull); // Known gap — half-width katakana not yet supported
      });
    });
  });
}
