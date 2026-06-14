// InspectionUrgency Unit Tests
//
// Maps days-until-inspection to a visual urgency level used by the
// home dashboard "次の車検" chip.

import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/core/utils/inspection_urgency.dart';

void main() {
  group('inspectionUrgencyForDays', () {
    test('null → none（車検日未設定）', () {
      expect(inspectionUrgencyForDays(null), InspectionUrgency.none);
    });

    test('31日以上 → normal', () {
      expect(inspectionUrgencyForDays(31), InspectionUrgency.normal);
      expect(inspectionUrgencyForDays(365), InspectionUrgency.normal);
    });

    test('30日以内 → warning', () {
      expect(inspectionUrgencyForDays(30), InspectionUrgency.warning);
      expect(inspectionUrgencyForDays(8), InspectionUrgency.warning);
    });

    test('7日以内 → critical', () {
      expect(inspectionUrgencyForDays(7), InspectionUrgency.critical);
      expect(inspectionUrgencyForDays(1), InspectionUrgency.critical);
    });

    group('Edge Cases', () {
      test('0日（当日） → critical', () {
        expect(inspectionUrgencyForDays(0), InspectionUrgency.critical);
      });

      test('負値（期限超過） → critical', () {
        expect(inspectionUrgencyForDays(-1), InspectionUrgency.critical);
        expect(inspectionUrgencyForDays(-100), InspectionUrgency.critical);
      });

      test('境界値: 7/8日で critical/warning が切り替わる', () {
        expect(inspectionUrgencyForDays(7), InspectionUrgency.critical);
        expect(inspectionUrgencyForDays(8), InspectionUrgency.warning);
      });

      test('境界値: 30/31日で warning/normal が切り替わる', () {
        expect(inspectionUrgencyForDays(30), InspectionUrgency.warning);
        expect(inspectionUrgencyForDays(31), InspectionUrgency.normal);
      });

      test('巨大値 → normal', () {
        expect(inspectionUrgencyForDays(999999), InspectionUrgency.normal);
      });
    });
  });
}
