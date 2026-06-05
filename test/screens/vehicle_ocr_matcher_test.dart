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
        final result =
            VehicleOcrMatcher.findMaker(_makers, 'フォルクスワーゲン');
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
  });
}
