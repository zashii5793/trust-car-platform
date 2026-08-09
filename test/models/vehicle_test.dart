// Vehicle Model Tests
//
// Coverage:
//   - FuelType / DriveType / TransmissionType enums
//   - VoluntaryInsurance
//   - Vehicle construction and basic getters
//   - displayName / fullDisplayName
//   - daysUntilInspection / isInspectionDueSoon / isInspectionExpired
//   - daysUntilInsuranceExpiry / isInsuranceDueSoon
//   - toMap / copyWith / equality
//   - Edge cases (null dates, boundary thresholds, special chars)

import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:trust_car_platform/models/vehicle.dart';

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

Vehicle _make({
  String id = 'v1',
  String userId = 'u1',
  String maker = 'Toyota',
  String model = 'Prius',
  int year = 2020,
  String grade = 'S',
  int mileage = 30000,
  DateTime? inspectionExpiryDate,
  DateTime? insuranceExpiryDate,
  FuelType? fuelType,
  DriveType? driveType,
  TransmissionType? transmissionType,
  VoluntaryInsurance? voluntaryInsurance,
}) {
  return Vehicle(
    id: id,
    userId: userId,
    maker: maker,
    model: model,
    year: year,
    grade: grade,
    mileage: mileage,
    createdAt: DateTime(2024, 1, 1),
    updatedAt: DateTime(2024, 1, 1),
    inspectionExpiryDate: inspectionExpiryDate,
    insuranceExpiryDate: insuranceExpiryDate,
    fuelType: fuelType,
    driveType: driveType,
    transmissionType: transmissionType,
    voluntaryInsurance: voluntaryInsurance,
  );
}

void main() {
  // -------------------------------------------------------------------------
  // FuelType enum
  // -------------------------------------------------------------------------
  group('FuelType', () {
    test('fromString は有効な文字列からFuelTypeを返す', () {
      expect(FuelType.fromString('gasoline'), FuelType.gasoline);
      expect(FuelType.fromString('hybrid'), FuelType.hybrid);
      expect(FuelType.fromString('electric'), FuelType.electric);
    });

    test('fromString は null を受け取ると null を返す', () {
      expect(FuelType.fromString(null), isNull);
    });

    test('fromString は未知の文字列で null を返す', () {
      expect(FuelType.fromString('unknown_fuel'), isNull);
    });

    test('displayName が日本語で返る', () {
      expect(FuelType.gasoline.displayName, 'ガソリン');
      expect(FuelType.hybrid.displayName, 'ハイブリッド');
      expect(FuelType.electric.displayName, '電気');
      expect(FuelType.phev.displayName, 'プラグインハイブリッド');
      expect(FuelType.hydrogen.displayName, '水素');
    });
  });

  // -------------------------------------------------------------------------
  // DriveType enum
  // -------------------------------------------------------------------------
  group('DriveType', () {
    test('fromString は有効な文字列からDriveTypeを返す', () {
      expect(DriveType.fromString('ff'), DriveType.ff);
      expect(DriveType.fromString('fourWd'), DriveType.fourWd);
    });

    test('fromString は null・未知文字列で null を返す', () {
      expect(DriveType.fromString(null), isNull);
      expect(DriveType.fromString('rwd'), isNull);
    });

    test('displayName が全種類定義されている', () {
      for (final dt in DriveType.values) {
        expect(dt.displayName, isNotEmpty);
      }
    });
  });

  // -------------------------------------------------------------------------
  // TransmissionType enum
  // -------------------------------------------------------------------------
  group('TransmissionType', () {
    test('fromString は有効な文字列から変換できる', () {
      expect(TransmissionType.fromString('at'), TransmissionType.at);
      expect(TransmissionType.fromString('mt'), TransmissionType.mt);
      expect(TransmissionType.fromString('cvt'), TransmissionType.cvt);
    });

    test('fromString は null・未知文字列で null を返す', () {
      expect(TransmissionType.fromString(null), isNull);
      expect(TransmissionType.fromString('torque_converter'), isNull);
    });
  });

  // -------------------------------------------------------------------------
  // VoluntaryInsurance
  // -------------------------------------------------------------------------
  group('VoluntaryInsurance', () {
    test('fromMap(null) でインスタンスが生成される（全フィールドnull）', () {
      final ins = VoluntaryInsurance.fromMap(null);
      expect(ins.companyName, isNull);
      expect(ins.expiryDate, isNull);
    });

    test('toMap / fromMap ラウンドトリップ', () {
      final expiry = DateTime(2025, 12, 31);
      final ins = VoluntaryInsurance(
        companyName: '損保ジャパン',
        policyNumber: 'POL-1234',
        expiryDate: expiry,
        coverageType: '対人・対物無制限',
      );

      final map = ins.toMap();
      expect(map['companyName'], '損保ジャパン');
      expect(map['policyNumber'], 'POL-1234');
      expect(map['expiryDate'], isA<Timestamp>());

      final restored = VoluntaryInsurance.fromMap(map);
      expect(restored.companyName, '損保ジャパン');
      expect(restored.policyNumber, 'POL-1234');
    });

    test('isExpired は期限切れのとき true を返す', () {
      final ins = VoluntaryInsurance(
        expiryDate: DateTime.now().subtract(const Duration(days: 1)),
      );
      expect(ins.isExpired, isTrue);
    });

    test('isExpired は有効期限内のとき false を返す', () {
      final ins = VoluntaryInsurance(
        expiryDate: DateTime.now().add(const Duration(days: 60)),
      );
      expect(ins.isExpired, isFalse);
    });

    test('isExpiringSoon は30日以内で true を返す', () {
      final ins = VoluntaryInsurance(
        expiryDate: DateTime.now().add(const Duration(days: 15)),
      );
      expect(ins.isExpiringSoon, isTrue);
    });

    test('isExpiringSoon は expiryDate が null のとき false を返す', () {
      const ins = VoluntaryInsurance();
      expect(ins.isExpiringSoon, isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // LeaseInfo
  // -------------------------------------------------------------------------
  group('LeaseInfo', () {
    test('fromMap(null) でインスタンスが生成される（全フィールドnull）', () {
      final lease = LeaseInfo.fromMap(null);
      expect(lease.lessorName, isNull);
      expect(lease.monthlyFee, isNull);
      expect(lease.contractEndDate, isNull);
      expect(lease.hasAnyValue, isFalse);
    });

    test('toMap / fromMap ラウンドトリップ', () {
      final lease = LeaseInfo(
        lessorName: '○○オートリース',
        monthlyFee: 45000,
        contractStartDate: DateTime(2024, 4, 1),
        contractEndDate: DateTime(2027, 3, 31),
        maintenancePackDetails: 'オイル交換・タイヤローテーション込み',
      );

      final map = lease.toMap();
      expect(map['lessorName'], '○○オートリース');
      expect(map['monthlyFee'], 45000);
      expect(map['contractEndDate'], isA<Timestamp>());

      final restored = LeaseInfo.fromMap(map);
      expect(restored.lessorName, '○○オートリース');
      expect(restored.monthlyFee, 45000);
      expect(restored.maintenancePackDetails, 'オイル交換・タイヤローテーション込み');
      expect(restored.contractEndDate, DateTime(2027, 3, 31));
    });

    test('hasAnyValue は1フィールドでも入力があれば true', () {
      expect(const LeaseInfo(lessorName: 'A社').hasAnyValue, isTrue);
      expect(const LeaseInfo(monthlyFee: 30000).hasAnyValue, isTrue);
      expect(const LeaseInfo().hasAnyValue, isFalse);
    });

    test('isExpiringSoon は60日以内で true', () {
      final lease = LeaseInfo(
        contractEndDate: DateTime.now().add(const Duration(days: 30)),
      );
      expect(lease.isExpiringSoon, isTrue);
    });

    test('isExpiringSoon は61日以上先で false', () {
      final lease = LeaseInfo(
        contractEndDate: DateTime.now().add(const Duration(days: 90)),
      );
      expect(lease.isExpiringSoon, isFalse);
    });

    test('Vehicle.daysUntilLeaseExpiry はリース情報なしのとき null', () {
      expect(_make().daysUntilLeaseExpiry, isNull);
    });

    test('Vehicle の toMap に leaseInfo が含まれラウンドトリップできる', () {
      final v = _make().copyWith(
        leaseInfo: LeaseInfo(
          lessorName: 'B社リース',
          monthlyFee: 52000,
          contractEndDate: DateTime(2026, 12, 31),
        ),
      );

      final map = v.toMap();
      expect(map['leaseInfo'], isNotNull);
      expect(map['leaseInfo']['lessorName'], 'B社リース');

      final restored = LeaseInfo.fromMap(map['leaseInfo']);
      expect(restored.monthlyFee, 52000);
    });
  });

  // -------------------------------------------------------------------------
  // Vehicle — construction
  // -------------------------------------------------------------------------
  group('Vehicle.construction', () {
    test('正常なデータからVehicleを生成できる', () {
      final v = _make(maker: 'Honda', model: 'Fit', year: 2022);
      expect(v.maker, 'Honda');
      expect(v.model, 'Fit');
      expect(v.year, 2022);
    });

    test('imageUrl が null の場合も正常に生成できる', () {
      expect(_make().imageUrl, isNull);
    });

    test('すべてのオプションフィールドがnullでも生成できる', () {
      final v = _make();
      expect(v.licensePlate, isNull);
      expect(v.vinNumber, isNull);
      expect(v.fuelType, isNull);
      expect(v.driveType, isNull);
    });
  });

  // -------------------------------------------------------------------------
  // displayName / fullDisplayName
  // -------------------------------------------------------------------------
  group('Vehicle.displayName', () {
    test('displayName は "maker model" 形式', () {
      expect(_make(maker: 'Mazda', model: 'CX-5').displayName, 'Mazda CX-5');
    });

    test('fullDisplayName はグレードあり→ "maker model grade"', () {
      expect(
        _make(maker: 'Subaru', model: 'Impreza', grade: 'Sport')
            .fullDisplayName,
        'Subaru Impreza Sport',
      );
    });

    test('fullDisplayName はグレードなし（空文字）→ "maker model"', () {
      expect(
        _make(maker: 'Nissan', model: 'Note', grade: '').fullDisplayName,
        'Nissan Note',
      );
    });
  });

  // -------------------------------------------------------------------------
  // daysUntilInspection / isInspectionDueSoon / isInspectionExpired
  // -------------------------------------------------------------------------
  group('Vehicle.inspection', () {
    test('inspectionExpiryDate が null のとき daysUntilInspection は null', () {
      expect(_make().daysUntilInspection, isNull);
    });

    test('inspectionExpiryDate が null のとき isInspectionDueSoon は false', () {
      expect(_make().isInspectionDueSoon, isFalse);
    });

    test('inspectionExpiryDate が null のとき isInspectionExpired は false', () {
      expect(_make().isInspectionExpired, isFalse);
    });

    test('車検まで200日のとき isInspectionDueSoon は false', () {
      final v = _make(
        inspectionExpiryDate: DateTime.now().add(const Duration(days: 200)),
      );
      expect(v.isInspectionDueSoon, isFalse);
    });

    test('車検まで15日のとき isInspectionDueSoon は true', () {
      final v = _make(
        inspectionExpiryDate: DateTime.now().add(const Duration(days: 15)),
      );
      expect(v.isInspectionDueSoon, isTrue);
    });

    test('車検まで30日ちょうどのとき isInspectionDueSoon は true（境界値）', () {
      final v = _make(
        inspectionExpiryDate: DateTime.now().add(const Duration(days: 30)),
      );
      expect(v.isInspectionDueSoon, isTrue);
    });

    test('車検まで31日のとき isInspectionDueSoon は false（境界値外）', () {
      final v = _make(
        inspectionExpiryDate:
            DateTime.now().add(const Duration(days: 31, hours: 12)),
      );
      expect(v.isInspectionDueSoon, isFalse);
    });

    test('車検が昨日切れたとき isInspectionExpired は true', () {
      final v = _make(
        inspectionExpiryDate: DateTime.now().subtract(const Duration(days: 1)),
      );
      expect(v.isInspectionExpired, isTrue);
    });

    test('車検が切れているとき isInspectionDueSoon は false', () {
      final v = _make(
        inspectionExpiryDate: DateTime.now().subtract(const Duration(days: 5)),
      );
      expect(v.isInspectionDueSoon, isFalse);
    });

    test('車検まで0日（当日）のとき isInspectionDueSoon は true', () {
      final v = _make(
        inspectionExpiryDate: DateTime.now(),
      );
      expect(v.isInspectionDueSoon, isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // daysUntilInsuranceExpiry / isInsuranceDueSoon
  // -------------------------------------------------------------------------
  group('Vehicle.insurance', () {
    test('insuranceExpiryDate が null のとき daysUntilInsuranceExpiry は null', () {
      expect(_make().daysUntilInsuranceExpiry, isNull);
    });

    test('isInsuranceDueSoon は null 日付で false', () {
      expect(_make().isInsuranceDueSoon, isFalse);
    });

    test('自賠責まで10日のとき isInsuranceDueSoon は true', () {
      final v = _make(
        insuranceExpiryDate: DateTime.now().add(const Duration(days: 10)),
      );
      expect(v.isInsuranceDueSoon, isTrue);
    });

    test('自賠責まで60日のとき isInsuranceDueSoon は false', () {
      final v = _make(
        insuranceExpiryDate: DateTime.now().add(const Duration(days: 60)),
      );
      expect(v.isInsuranceDueSoon, isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // toMap
  // -------------------------------------------------------------------------
  group('Vehicle.toMap', () {
    test('基本フィールドが正しくマップに変換される', () {
      final map = _make(maker: 'Toyota', mileage: 50000).toMap();
      expect(map['maker'], 'Toyota');
      expect(map['mileage'], 50000);
      expect(map['createdAt'], isA<Timestamp>());
      expect(map['updatedAt'], isA<Timestamp>());
    });

    test('fuelType がマップに文字列として保存される', () {
      expect(_make(fuelType: FuelType.hybrid).toMap()['fuelType'], 'hybrid');
    });

    test('driveType が null のとき マップの driveType は null', () {
      expect(_make().toMap()['driveType'], isNull);
    });

    test('transmissionType が文字列として保存される', () {
      expect(
        _make(transmissionType: TransmissionType.mt)
            .toMap()['transmissionType'],
        'mt',
      );
    });
  });

  // -------------------------------------------------------------------------
  // copyWith
  // -------------------------------------------------------------------------
  group('Vehicle.copyWith', () {
    test('mileage を変更できる', () {
      final copy = _make(mileage: 10000).copyWith(mileage: 20000);
      expect(copy.mileage, 20000);
    });

    test('他のフィールドは維持される', () {
      final original = _make(maker: 'Toyota');
      final copy = original.copyWith(mileage: 99999);
      expect(copy.maker, 'Toyota');
      expect(copy.id, original.id);
    });

    test('imageUrl を更新できる', () {
      final copy = _make().copyWith(imageUrl: 'https://example.com/car.jpg');
      expect(copy.imageUrl, 'https://example.com/car.jpg');
    });

    test('コピーは元オブジェクトを変更しない（不変性）', () {
      final original = _make(mileage: 5000);
      original.copyWith(mileage: 99999);
      expect(original.mileage, 5000);
    });

    test('fuelType を変更できる', () {
      final copy = _make(fuelType: FuelType.gasoline)
          .copyWith(fuelType: FuelType.electric);
      expect(copy.fuelType, FuelType.electric);
    });
  });

  // -------------------------------------------------------------------------
  // Equality
  // -------------------------------------------------------------------------
  group('Vehicle.equality', () {
    test('同じ id なら等しい', () {
      final a = _make(id: 'same');
      final b = _make(id: 'same', maker: 'Honda');
      expect(a, equals(b));
    });

    test('異なる id なら等しくない', () {
      expect(_make(id: 'a1'), isNot(equals(_make(id: 'b1'))));
    });

    test('hashCode が id ベース', () {
      final a = _make(id: 'x');
      final b = _make(id: 'x');
      expect(a.hashCode, b.hashCode);
    });
  });

  // -------------------------------------------------------------------------
  // Edge Cases
  // -------------------------------------------------------------------------
  group('Edge Cases', () {
    test('走行距離 0 でも正常に生成できる', () {
      expect(_make(mileage: 0).mileage, 0);
    });

    test('走行距離が非常に大きい値（999,999km）でもクラッシュしない', () {
      expect(_make(mileage: 999999).mileage, 999999);
    });

    test('maker / model が特殊文字（スラッシュ・スペース含む）でも生成できる', () {
      final v = _make(maker: 'Alfa Romeo', model: 'Giulia GTAm');
      expect(v.displayName, 'Alfa Romeo Giulia GTAm');
    });

    test('year が 1900 という古い年でもクラッシュしない', () {
      expect(_make(year: 1900).year, 1900);
    });

    test('grade が全角スペースのみのとき fullDisplayName で余分なスペースが入る', () {
      // 実際の挙動を文書化するテスト
      final v = _make(grade: '　');
      expect(v.fullDisplayName, isNotEmpty);
    });
  });

  // -------------------------------------------------------------------------
  // VehicleUseCategory（用途区分・車検サイクル）
  // -------------------------------------------------------------------------
  group('VehicleUseCategory', () {
    test('自家用乗用車: 初回3年・以降2年', () {
      expect(VehicleUseCategory.privatePassenger.firstInspectionYears, 3);
      expect(VehicleUseCategory.privatePassenger.inspectionCycleYears, 2);
    });

    test('貨物車（1・4ナンバー）: 初回2年・以降1年（毎年車検）', () {
      expect(VehicleUseCategory.cargo.firstInspectionYears, 2);
      expect(VehicleUseCategory.cargo.inspectionCycleYears, 1);
    });

    test('軽貨物: 初回2年・以降2年', () {
      expect(VehicleUseCategory.keiCargo.firstInspectionYears, 2);
      expect(VehicleUseCategory.keiCargo.inspectionCycleYears, 2);
    });

    test('事業用・大型貨物: 初回1年・以降1年', () {
      expect(VehicleUseCategory.commercial.firstInspectionYears, 1);
      expect(VehicleUseCategory.commercial.inspectionCycleYears, 1);
    });

    test('displayName が日本語', () {
      expect(VehicleUseCategory.privatePassenger.displayName, contains('乗用'));
      expect(VehicleUseCategory.cargo.displayName, contains('貨物'));
    });

    test('fromString は有効な文字列から enum を返す', () {
      expect(VehicleUseCategory.fromString('cargo'), VehicleUseCategory.cargo);
      expect(VehicleUseCategory.fromString('privatePassenger'),
          VehicleUseCategory.privatePassenger);
    });

    test('fromString は null/不正文字列で null を返す', () {
      expect(VehicleUseCategory.fromString(null), isNull);
      expect(VehicleUseCategory.fromString('invalid'), isNull);
      expect(VehicleUseCategory.fromString(''), isNull);
    });
  });

  group('Vehicle.useCategory と次回車検日計算', () {
    Vehicle makeWithCategory({
      VehicleUseCategory? useCategory,
      DateTime? inspectionExpiryDate,
    }) {
      return Vehicle(
        id: 'v1',
        userId: 'u1',
        maker: 'Toyota',
        model: 'Hiace',
        year: 2022,
        grade: 'DX',
        mileage: 50000,
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
        useCategory: useCategory,
        inspectionExpiryDate: inspectionExpiryDate,
      );
    }

    test('useCategory 未設定（null）の場合は自家用乗用車として扱う', () {
      final v = makeWithCategory(useCategory: null);
      expect(v.effectiveUseCategory, VehicleUseCategory.privatePassenger);
    });

    test('貨物車の次回車検推奨日 = 現在の満了日 + 1年', () {
      final v = makeWithCategory(
        useCategory: VehicleUseCategory.cargo,
        inspectionExpiryDate: DateTime(2026, 8, 1),
      );
      expect(v.suggestedNextInspectionDate, DateTime(2027, 8, 1));
    });

    test('自家用乗用車の次回車検推奨日 = 現在の満了日 + 2年', () {
      final v = makeWithCategory(
        useCategory: VehicleUseCategory.privatePassenger,
        inspectionExpiryDate: DateTime(2026, 8, 1),
      );
      expect(v.suggestedNextInspectionDate, DateTime(2028, 8, 1));
    });

    test('車検満了日が未設定なら次回推奨日は null', () {
      final v = makeWithCategory(
        useCategory: VehicleUseCategory.cargo,
        inspectionExpiryDate: null,
      );
      expect(v.suggestedNextInspectionDate, isNull);
    });

    test('toMap に useCategory が含まれる', () {
      final v = makeWithCategory(useCategory: VehicleUseCategory.cargo);
      expect(v.toMap()['useCategory'], 'cargo');
    });

    test('toMap で useCategory が null の場合は null が入る', () {
      final v = makeWithCategory(useCategory: null);
      expect(v.toMap()['useCategory'], isNull);
    });

    test('toMap に schemaVersion が含まれる（マイグレーション基盤）', () {
      final v = makeWithCategory(useCategory: VehicleUseCategory.cargo);
      expect(v.toMap()['schemaVersion'], Vehicle.schemaVersion);
    });

    test('copyWith で useCategory を変更できる', () {
      final v = makeWithCategory(useCategory: VehicleUseCategory.cargo);
      final copied =
          v.copyWith(useCategory: VehicleUseCategory.privatePassenger);
      expect(copied.useCategory, VehicleUseCategory.privatePassenger);
    });

    group('Edge Cases', () {
      test('うるう年2/29満了の貨物車 +1年は2/28（Dartの日付正規化に従い3/1）', () {
        final v = makeWithCategory(
          useCategory: VehicleUseCategory.cargo,
          inspectionExpiryDate: DateTime(2028, 2, 29),
        );
        // DateTime(2029, 2, 29) は 2029-03-01 に正規化される
        expect(v.suggestedNextInspectionDate, DateTime(2029, 3, 1));
      });

      test('過去の満了日でも計算できる（期限切れ車両の更新時）', () {
        final v = makeWithCategory(
          useCategory: VehicleUseCategory.cargo,
          inspectionExpiryDate: DateTime(2020, 1, 1),
        );
        expect(v.suggestedNextInspectionDate, DateTime(2021, 1, 1));
      });
    });
  });
}
