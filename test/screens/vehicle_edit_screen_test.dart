// VehicleEditScreen tests
//
// Widget-level tests require Firebase + provider setup (use integration tests).
// This file covers the business logic around master data resolution:
// - _initMasterSelections fallback behavior
// - _onFieldChanged change detection with nullable master objects
// - _updateVehicle uses fallback to widget.vehicle values when master not found

import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/models/vehicle.dart';
import 'package:trust_car_platform/models/vehicle_master.dart';

void main() {
  group('VehicleEditScreen — master data resolution logic', () {
    // ---------------------------------------------------------------------------
    // Helper: build a Vehicle with known maker/model/grade names
    // ---------------------------------------------------------------------------
    Vehicle _makeVehicle({
      String maker = 'トヨタ',
      String model = 'プリウス',
      String grade = 'Z',
    }) {
      return Vehicle(
        id: 'test-id',
        userId: 'user-1',
        maker: maker,
        model: model,
        year: 2023,
        grade: grade,
        mileage: 10000,
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );
    }

    // ---------------------------------------------------------------------------
    // Simulate the maker-lookup logic extracted from _initMasterSelections
    // ---------------------------------------------------------------------------
    VehicleMaker? _resolveMaker(List<VehicleMaker> masters, String vehicleMakerName) {
      try {
        return masters.firstWhere(
          (m) => m.name == vehicleMakerName ||
              m.nameEn.toLowerCase() == vehicleMakerName.toLowerCase(),
          orElse: () => masters.firstWhere(
            (m) => m.id == vehicleMakerName.toLowerCase(),
            orElse: () => throw StateError('not found'),
          ),
        );
      } catch (_) {
        return null;
      }
    }

    VehicleModel? _resolveModel(List<VehicleModel> masters, String vehicleModelName) {
      try {
        return masters.firstWhere(
          (m) => m.name == vehicleModelName ||
              (m.nameEn?.toLowerCase() == vehicleModelName.toLowerCase()),
        );
      } catch (_) {
        return null;
      }
    }

    VehicleGrade? _resolveGrade(List<VehicleGrade> masters, String modelId, String gradeName) {
      try {
        return masters.firstWhere((g) => g.name == gradeName);
      } catch (_) {
        // カスタムグレードとして作成
        if (gradeName.isNotEmpty) {
          return VehicleGrade(
            id: 'custom_$gradeName',
            modelId: modelId,
            name: gradeName,
          );
        }
        return null;
      }
    }

    // Simulate the save-path fallback: use selected or fall back to widget.vehicle
    String _effectiveMaker(VehicleMaker? selected, Vehicle vehicle) =>
        selected?.name ?? vehicle.maker;
    String _effectiveModel(VehicleModel? selected, Vehicle vehicle) =>
        selected?.name ?? vehicle.model;
    String _effectiveGrade(VehicleGrade? selected, Vehicle vehicle) =>
        selected?.name ?? vehicle.grade;

    // ---------------------------------------------------------------------------
    // Test data
    // ---------------------------------------------------------------------------
    final toyotaMaker = VehicleMaker(
      id: 'toyota',
      name: 'トヨタ',
      nameEn: 'Toyota',
      country: 'JP',
      displayOrder: 1,
    );
    final priusModel = VehicleModel(
      id: 'toyota_prius',
      makerId: 'toyota',
      name: 'プリウス',
      nameEn: 'Prius',
      displayOrder: 1,
    );
    final gradeZ = VehicleGrade(
      id: 'grade_z',
      modelId: 'toyota_prius',
      name: 'Z',
    );

    final makers = [toyotaMaker];
    final models = [priusModel];
    final grades = [gradeZ];

    // ---------------------------------------------------------------------------
    // メーカー逆引きテスト
    // ---------------------------------------------------------------------------
    group('メーカー逆引き', () {
      test('日本語名で一致する', () {
        final result = _resolveMaker(makers, 'トヨタ');
        expect(result?.id, equals('toyota'));
      });

      test('英語名（大文字小文字無視）で一致する', () {
        final result = _resolveMaker(makers, 'toyota');
        expect(result?.id, equals('toyota'));
        final result2 = _resolveMaker(makers, 'TOYOTA');
        expect(result2?.id, equals('toyota'));
      });

      test('マスタにない名前はnullを返す（クラッシュしない）', () {
        final result = _resolveMaker(makers, 'フェラーリ');
        expect(result, isNull);
      });

      test('空文字はnullを返す', () {
        final result = _resolveMaker(makers, '');
        expect(result, isNull);
      });
    });

    // ---------------------------------------------------------------------------
    // 車種逆引きテスト
    // ---------------------------------------------------------------------------
    group('車種逆引き', () {
      test('日本語名で一致する', () {
        final result = _resolveModel(models, 'プリウス');
        expect(result?.id, equals('toyota_prius'));
      });

      test('英語名で一致する', () {
        final result = _resolveModel(models, 'prius');
        expect(result?.id, equals('toyota_prius'));
      });

      test('マスタにない車種はnullを返す', () {
        final result = _resolveModel(models, 'カローラ');
        expect(result, isNull);
      });
    });

    // ---------------------------------------------------------------------------
    // グレード逆引きテスト
    // ---------------------------------------------------------------------------
    group('グレード逆引き', () {
      test('マスタに存在するグレードを返す', () {
        final result = _resolveGrade(grades, 'toyota_prius', 'Z');
        expect(result?.id, equals('grade_z'));
        expect(result?.name, equals('Z'));
      });

      test('マスタにないグレードはカスタムGradeオブジェクトを作成する', () {
        final result = _resolveGrade(grades, 'toyota_prius', 'Sport Edition');
        expect(result, isNotNull);
        expect(result?.name, equals('Sport Edition'));
        expect(result?.id, startsWith('custom_'));
        expect(result?.modelId, equals('toyota_prius'));
      });

      test('空文字のグレードはnullを返す', () {
        final result = _resolveGrade(grades, 'toyota_prius', '');
        expect(result, isNull);
      });
    });

    // ---------------------------------------------------------------------------
    // 保存時フォールバックテスト（最重要）
    // ---------------------------------------------------------------------------
    group('保存時フォールバック（マスタ逆引き失敗時に既存値を維持）', () {
      test('逆引き成功時は選択されたマスタ名を使う', () {
        final vehicle = _makeVehicle(maker: 'トヨタ', model: 'プリウス', grade: 'Z');
        expect(_effectiveMaker(toyotaMaker, vehicle), equals('トヨタ'));
        expect(_effectiveModel(priusModel, vehicle), equals('プリウス'));
        expect(_effectiveGrade(gradeZ, vehicle), equals('Z'));
      });

      test('メーカー逆引き失敗時（null）は既存vehicle.makerを維持', () {
        final vehicle = _makeVehicle(maker: 'フェラーリ');
        expect(_effectiveMaker(null, vehicle), equals('フェラーリ'));
      });

      test('車種逆引き失敗時（null）は既存vehicle.modelを維持', () {
        final vehicle = _makeVehicle(model: 'テスタロッサ');
        expect(_effectiveModel(null, vehicle), equals('テスタロッサ'));
      });

      test('グレード逆引き失敗時（null）は既存vehicle.gradeを維持', () {
        final vehicle = _makeVehicle(grade: 'Special Edition');
        expect(_effectiveGrade(null, vehicle), equals('Special Edition'));
      });

      test('既登録車両を何も変えずに保存しても値が失われない', () {
        final vehicle = _makeVehicle(maker: 'トヨタ', model: 'プリウス', grade: 'Z');
        // 逆引き成功ケース
        expect(_effectiveMaker(toyotaMaker, vehicle), equals('トヨタ'));
        expect(_effectiveModel(priusModel, vehicle), equals('プリウス'));
        expect(_effectiveGrade(gradeZ, vehicle), equals('Z'));
      });
    });

    // ---------------------------------------------------------------------------
    // 変更検知ロジックのテスト
    // ---------------------------------------------------------------------------
    group('変更検知（_onFieldChanged相当）', () {
      bool _hasChanged({
        VehicleMaker? selectedMaker,
        VehicleModel? selectedModel,
        VehicleGrade? selectedGrade,
        required Vehicle vehicle,
      }) {
        return (_effectiveMaker(selectedMaker, vehicle)) != vehicle.maker ||
            (_effectiveModel(selectedModel, vehicle)) != vehicle.model ||
            (_effectiveGrade(selectedGrade, vehicle)) != vehicle.grade;
      }

      test('何も変更しない場合はchanged=false', () {
        final vehicle = _makeVehicle();
        // 逆引き成功で同じ値がセットされた場合
        final changed = _hasChanged(
          selectedMaker: toyotaMaker,
          selectedModel: priusModel,
          selectedGrade: gradeZ,
          vehicle: vehicle,
        );
        expect(changed, isFalse);
      });

      test('別メーカーに変更するとchanged=true', () {
        final vehicle = _makeVehicle(maker: 'トヨタ');
        final hondaMaker = VehicleMaker(
          id: 'honda', name: 'ホンダ', nameEn: 'Honda', country: 'JP', displayOrder: 2,
        );
        final changed = _hasChanged(
          selectedMaker: hondaMaker,
          vehicle: vehicle,
        );
        expect(changed, isTrue);
      });

      test('マスタ逆引き失敗（全null）でも既存値で比較するのでchanged=false', () {
        final vehicle = _makeVehicle();
        // 全null → フォールバックで vehicle の値が使われる → 変更なし
        final changed = _hasChanged(
          selectedMaker: null,
          selectedModel: null,
          selectedGrade: null,
          vehicle: vehicle,
        );
        expect(changed, isFalse);
      });
    });
  });
}
