// VoluntaryInsurance — enriched fields (personal + corporate/fleet) tests

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/models/vehicle.dart';

void main() {
  group('VoluntaryInsurance — enriched', () {
    VoluntaryInsurance personalSample() => VoluntaryInsurance(
          companyName: 'サンプル損保',
          policyNumber: 'POL-123',
          expiryDate: DateTime(2027, 3, 31),
          contractStartDate: DateTime(2026, 4, 1),
          annualPremium: 68000,
          paymentMethod: '年払',
          contractType: InsuranceContractType.nonFleet,
          usagePurpose: '日常・レジャー',
          namedInsured: '山田太郎',
          nonFleetGrade: 16,
          accidentCoefficientPeriod: 0,
          bodilyInjuryLimit: '無制限',
          propertyDamageLimit: '無制限',
          personalInjuryAmount: '3000万円',
          passengerInjuryAmount: '1000万円',
          hasVehicleInsurance: true,
          vehicleInsuranceType: '車対車+A',
          vehicleInsuranceAmount: 1200000,
          vehicleInsuranceDeductible: '5-10万円',
          driverScope: '家族限定',
          driverAgeCondition: '26歳以上',
          specialClauses: const ['弁護士費用特約', 'ロードサービス'],
        );

    test('全フィールドが toMap/fromMap で往復する（個人）', () {
      final restored = VoluntaryInsurance.fromMap(personalSample().toMap());

      expect(restored.companyName, 'サンプル損保');
      expect(restored.contractStartDate, DateTime(2026, 4, 1));
      expect(restored.annualPremium, 68000);
      expect(restored.paymentMethod, '年払');
      expect(restored.contractType, InsuranceContractType.nonFleet);
      expect(restored.usagePurpose, '日常・レジャー');
      expect(restored.namedInsured, '山田太郎');
      expect(restored.nonFleetGrade, 16);
      expect(restored.accidentCoefficientPeriod, 0);
      expect(restored.bodilyInjuryLimit, '無制限');
      expect(restored.propertyDamageLimit, '無制限');
      expect(restored.personalInjuryAmount, '3000万円');
      expect(restored.passengerInjuryAmount, '1000万円');
      expect(restored.hasVehicleInsurance, true);
      expect(restored.vehicleInsuranceType, '車対車+A');
      expect(restored.vehicleInsuranceAmount, 1200000);
      expect(restored.vehicleInsuranceDeductible, '5-10万円');
      expect(restored.driverScope, '家族限定');
      expect(restored.driverAgeCondition, '26歳以上');
      expect(restored.specialClauses, ['弁護士費用特約', 'ロードサービス']);
    });

    test('法人フリート契約のフィールドが往復する', () {
      final corporate = VoluntaryInsurance(
        companyName: '法人損保',
        contractType: InsuranceContractType.fleet,
        fleetDiscountRate: 55.0,
        usagePurpose: '業務用',
        namedInsured: '株式会社サンプル',
        bodilyInjuryLimit: '無制限',
        propertyDamageLimit: '無制限',
        driverScope: '限定なし',
        driverAgeCondition: '全年齢',
      );
      final restored = VoluntaryInsurance.fromMap(corporate.toMap());

      expect(restored.isFleetContract, isTrue);
      expect(restored.contractType, InsuranceContractType.fleet);
      expect(restored.fleetDiscountRate, 55.0);
      expect(restored.usagePurpose, '業務用');
      expect(restored.namedInsured, '株式会社サンプル');
      expect(restored.driverScope, '限定なし');
    });

    group('Edge Cases', () {
      test('null マップは空インスタンスになる', () {
        final v = VoluntaryInsurance.fromMap(null);
        expect(v.companyName, isNull);
        expect(v.specialClauses, isEmpty);
        expect(v.contractType, isNull);
        expect(v.isFleetContract, isFalse);
        expect(v.hasCoverageDetails, isFalse);
      });

      test('既存（旧形式）マップでも読み込める（後方互換）', () {
        // 旧バージョンが書いた 6 フィールドのみのドキュメント
        final v = VoluntaryInsurance.fromMap({
          'companyName': '旧損保',
          'policyNumber': 'OLD-1',
          'expiryDate': Timestamp.fromDate(DateTime(2026, 12, 31)),
          'coverageType': '対人対物',
          'agentName': '旧代理店',
          'agentPhone': '03-0000-0000',
        });
        expect(v.companyName, '旧損保');
        expect(v.coverageType, '対人対物');
        // 新フィールドは未設定
        expect(v.contractType, isNull);
        expect(v.specialClauses, isEmpty);
        expect(v.nonFleetGrade, isNull);
      });

      test('hasCoverageDetails は補償が1つでもあれば true', () {
        const v = VoluntaryInsurance(bodilyInjuryLimit: '無制限');
        expect(v.hasCoverageDetails, isTrue);
      });

      test('copyWith は指定フィールドのみ更新する', () {
        final base = personalSample();
        final updated = base.copyWith(annualPremium: 72000);
        expect(updated.annualPremium, 72000);
        expect(updated.companyName, 'サンプル損保'); // 据え置き
        expect(updated.specialClauses, base.specialClauses);
      });

      test('InsuranceContractType.fromString は不明値で null', () {
        expect(InsuranceContractType.fromString('unknown'), isNull);
        expect(InsuranceContractType.fromString(null), isNull);
        expect(InsuranceContractType.fromString('fleet'),
            InsuranceContractType.fleet);
      });
    });
  });
}
