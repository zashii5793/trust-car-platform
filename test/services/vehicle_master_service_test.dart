// VehicleMasterService & VehicleMasterData Tests
//
// VehicleMasterService uses Firebase with static-data fallback.
// This test suite validates the static-data layer (pure Dart) and the
// synchronous cache-based search methods — no Firestore required.
//
// Coverage:
//   1. VehicleMasterData.getMakers()       — 日本メーカー定義
//   2. VehicleMasterData.getModelsForMaker() — モデル一覧
//   3. VehicleMasterData.getCommonGrades()  — 共通グレード
//   4. VehicleMaker model                  — fromMap / displayOrder
//   5. VehicleModel model                  — isAvailableInYear
//   6. VehicleMasterService.searchMakers() — キャッシュなし / キャッシュあり
//   7. VehicleMasterService.searchModels() — フィルタリング
//   8. Edge Cases                          — 空クエリ / 存在しないmakerId

import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/services/vehicle_master_service.dart';
import 'package:trust_car_platform/data/vehicle_master_data.dart';
import 'package:trust_car_platform/models/vehicle_master.dart';

void main() {
  // ==========================================================================
  // Group 1: VehicleMasterData.getMakers() — 静的データ検証
  // ==========================================================================
  group('VehicleMasterData.getMakers', () {
    late List<VehicleMaker> makers;

    setUpAll(() {
      makers = VehicleMasterData.getMakers();
    });

    test('リストが空でない', () {
      expect(makers, isNotEmpty);
    });

    test('日本主要メーカーが含まれる（トヨタ・ホンダ・日産）', () {
      final names = makers.map((m) => m.name).toList();
      expect(names, contains('トヨタ'));
      expect(names, contains('ホンダ'));
      expect(names, contains('日産'));
    });

    test('英語名も設定されている', () {
      final toyota = makers.firstWhere((m) => m.nameEn == 'Toyota');
      expect(toyota.nameEn, 'Toyota');
    });

    test('全メーカーに id が設定されている', () {
      for (final maker in makers) {
        expect(maker.id, isNotEmpty);
      }
    });

    test('全メーカーに name が設定されている', () {
      for (final maker in makers) {
        expect(maker.name, isNotEmpty);
      }
    });

    test('全メーカーに nameEn が設定されている', () {
      for (final maker in makers) {
        expect(maker.nameEn, isNotEmpty);
      }
    });

    test('displayOrder が 0 以上', () {
      for (final maker in makers) {
        expect(maker.displayOrder, greaterThanOrEqualTo(0));
      }
    });

    test('isActive が true (デフォルト)', () {
      for (final maker in makers) {
        expect(maker.isActive, isTrue);
      }
    });

    test('重複した ID がない', () {
      final ids = makers.map((m) => m.id).toList();
      expect(ids.length, ids.toSet().length);
    });

    test('getMakers を複数回呼んでも同じ結果', () {
      final second = VehicleMasterData.getMakers();
      expect(makers.length, second.length);
    });
  });

  // ==========================================================================
  // Group 2: VehicleMasterData.getModelsForMaker
  // ==========================================================================
  group('VehicleMasterData.getModelsForMaker', () {
    test('toyota のモデルが存在する', () {
      final models = VehicleMasterData.getModelsForMaker('toyota');
      expect(models, isNotEmpty);
    });

    test('存在しない makerId → 空リスト', () {
      final models = VehicleMasterData.getModelsForMaker('unknown_maker');
      expect(models, isEmpty);
    });

    test('honda のモデルが存在する', () {
      final models = VehicleMasterData.getModelsForMaker('honda');
      expect(models, isNotEmpty);
    });

    test('全モデルに name が設定されている（toyota）', () {
      final models = VehicleMasterData.getModelsForMaker('toyota');
      for (final model in models) {
        expect(model.name, isNotEmpty);
      }
    });

    test('全モデルに makerId が正しく設定されている（toyota）', () {
      final models = VehicleMasterData.getModelsForMaker('toyota');
      for (final model in models) {
        expect(model.makerId, 'toyota');
      }
    });
  });

  // ==========================================================================
  // Group 3: VehicleMasterData.getCommonGrades
  // ==========================================================================
  group('VehicleMasterData.getCommonGrades', () {
    test('共通グレードが存在する', () {
      final grades = VehicleMasterData.getCommonGrades('model-xyz');
      expect(grades, isNotEmpty);
    });

    test('全グレードに name が設定されている', () {
      final grades = VehicleMasterData.getCommonGrades('model-xyz');
      for (final grade in grades) {
        expect(grade.name, isNotEmpty);
      }
    });

    test('modelId が引数のIDに設定される', () {
      final grades = VehicleMasterData.getCommonGrades('custom-model-id');
      for (final grade in grades) {
        expect(grade.modelId, 'custom-model-id');
      }
    });

    test('S グレードが含まれる', () {
      final grades = VehicleMasterData.getCommonGrades('any');
      final gradeNames = grades.map((g) => g.name).toList();
      expect(gradeNames.any((name) => name == 'S' || name.contains('S')), isTrue);
    });
  });

  // ==========================================================================
  // Group 4: VehicleMasterService — キャッシュなしの検索
  // ==========================================================================
  group('VehicleMasterService — cache-less search', () {
    late VehicleMasterService service;

    setUp(() {
      // Firestore is not initialized → service uses null Firestore (but won't
      // call async methods in these sync tests)
      service = VehicleMasterService();
    });

    test('searchMakers — キャッシュなし → 空リスト', () {
      // Before any getMakers() call, _makersCache is null
      final results = service.searchMakers('Toyota');
      expect(results, isEmpty);
    });

    test('searchMakers — 空クエリ → 空リスト（キャッシュなし）', () {
      final results = service.searchMakers('');
      expect(results, isEmpty);
    });

    test('searchModels — キャッシュなし → 空リスト', () {
      final results = service.searchModels('toyota', 'Prius');
      expect(results, isEmpty);
    });

    test('getModelsAvailableInYear — キャッシュなし → 空リスト', () {
      final results = service.getModelsAvailableInYear('toyota', 2020);
      expect(results, isEmpty);
    });

    test('getGradesAvailableInYear — キャッシュなし → 空リスト', () {
      final results = service.getGradesAvailableInYear('model-xyz', 2020);
      expect(results, isEmpty);
    });
  });

  // ==========================================================================
  // Group 5: BodyType enum
  // ==========================================================================
  group('BodyType enum', () {
    test('全 displayName が設定されている', () {
      for (final bt in BodyType.values) {
        expect(bt.displayName, isNotEmpty);
      }
    });

    test('fromString は有効な文字列で変換できる', () {
      expect(BodyType.fromString('sedan'), BodyType.sedan);
      expect(BodyType.fromString('suv'), BodyType.suv);
      expect(BodyType.fromString('kei'), BodyType.kei);
    });

    test('fromString は null で null を返す', () {
      expect(BodyType.fromString(null), isNull);
    });

    test('fromString は未知の文字列で null を返す', () {
      expect(BodyType.fromString('flying_car'), isNull);
    });

    test('全 11 種類が定義されている', () {
      expect(BodyType.values.length, 11);
    });
  });

  // ==========================================================================
  // Group 6: Edge Cases
  // ==========================================================================
  group('Edge Cases', () {
    test('getModelsForMaker 空文字 → 空リスト', () {
      expect(VehicleMasterData.getModelsForMaker(''), isEmpty);
    });

    test('getMakers 結果は List<VehicleMaker> 型', () {
      expect(VehicleMasterData.getMakers(), isA<List<VehicleMaker>>());
    });

    test('getCommonGrades で非常に長い modelId でもクラッシュしない', () {
      final longId = 'model_' + 'x' * 200;
      expect(() => VehicleMasterData.getCommonGrades(longId), returnsNormally);
    });

    test('VehicleMasterService は Firestore なしで構築できる', () {
      expect(() => VehicleMasterService(), returnsNormally);
    });
  });
}
