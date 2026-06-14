import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/core/utils/insurance_templates.dart';

void main() {
  group('insuranceTemplates', () {
    test('3種類のテンプレートが定義されている', () {
      expect(insuranceTemplates.length, 3);
      expect(insuranceTemplates.map((t) => t.name),
          containsAll(['手厚い', '標準', '最小']));
    });

    test('全テンプレートで対人・対物が無制限（最低限の安心ライン）', () {
      for (final t in insuranceTemplates) {
        expect(t.bodilyInjuryLimit, '無制限', reason: t.name);
        expect(t.propertyDamageLimit, '無制限', reason: t.name);
      }
    });

    test('「手厚い」は車両保険一般型で特約が最も多い', () {
      final t = insuranceTemplates.firstWhere((t) => t.name == '手厚い');
      expect(t.hasVehicleInsurance, isTrue);
      expect(t.vehicleInsuranceType, '一般');
      expect(t.specialClauses, contains('弁護士費用特約'));
      expect(t.specialClauses.length, greaterThanOrEqualTo(3));
    });

    test('「最小」は車両保険なし・型は null', () {
      final t = insuranceTemplates.firstWhere((t) => t.name == '最小');
      expect(t.hasVehicleInsurance, isFalse);
      expect(t.vehicleInsuranceType, isNull);
    });

    test('車両保険ありのテンプレートは型が設定されている', () {
      for (final t in insuranceTemplates.where((t) => t.hasVehicleInsurance)) {
        expect(t.vehicleInsuranceType, isNotNull, reason: t.name);
      }
    });
  });
}
