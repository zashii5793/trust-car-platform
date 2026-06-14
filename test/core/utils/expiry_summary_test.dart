import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/core/utils/expiry_summary.dart';
import 'package:trust_car_platform/core/utils/inspection_urgency.dart';
import 'package:trust_car_platform/models/vehicle.dart';

Vehicle _vehicle({
  DateTime? inspection,
  DateTime? compulsory,
  DateTime? voluntary,
}) {
  return Vehicle(
    id: 'v1',
    userId: 'u1',
    maker: 'トヨタ',
    model: 'プリウス',
    year: 2022,
    grade: 'G',
    mileage: 10000,
    createdAt: DateTime(2022),
    updatedAt: DateTime(2022),
    inspectionExpiryDate: inspection,
    insuranceExpiryDate: compulsory,
    voluntaryInsurance:
        voluntary == null ? null : VoluntaryInsurance(expiryDate: voluntary),
  );
}

void main() {
  final now = DateTime(2026, 6, 1);

  group('vehicleExpiryItems', () {
    test('全期限を soonest-first で返す', () {
      final v = _vehicle(
        inspection: DateTime(2026, 9, 1), // 92日後
        compulsory: DateTime(2026, 6, 20), // 19日後
        voluntary: DateTime(2026, 7, 10), // 39日後
      );
      final items = vehicleExpiryItems(v, now: now);

      expect(items.length, 3);
      expect(items[0].kind, ExpiryKind.compulsoryInsurance); // 最短
      expect(items[1].kind, ExpiryKind.voluntaryInsurance);
      expect(items[2].kind, ExpiryKind.inspection);
    });

    test('期限切れ（負日数）が最優先で先頭に来る', () {
      final v = _vehicle(
        inspection: DateTime(2026, 5, 1), // -31日（期限切れ）
        voluntary: DateTime(2026, 6, 10), // 9日後
      );
      final items = vehicleExpiryItems(v, now: now);
      expect(items.first.kind, ExpiryKind.inspection);
      expect(items.first.isOverdue, isTrue);
    });

    group('Edge Cases', () {
      test('期限未設定の項目は含めない', () {
        final v = _vehicle(voluntary: DateTime(2026, 7, 1));
        final items = vehicleExpiryItems(v, now: now);
        expect(items.length, 1);
        expect(items.first.kind, ExpiryKind.voluntaryInsurance);
      });

      test('全て未設定なら空・nextVehicleExpiry は null', () {
        final v = _vehicle();
        expect(vehicleExpiryItems(v, now: now), isEmpty);
        expect(nextVehicleExpiry(v, now: now), isNull);
      });

      test('urgency しきい値が車検と一貫している', () {
        final v = _vehicle(voluntary: DateTime(2026, 6, 5)); // 4日後
        final next = nextVehicleExpiry(v, now: now)!;
        expect(next.urgency, InspectionUrgency.critical);
      });
    });
  });

  group('summarizeFleetInsurance', () {
    test('期限切れ・間近・未登録を正しく数える', () {
      final vehicles = [
        _vehicle(voluntary: DateTime(2026, 5, 1)), // expired
        _vehicle(voluntary: DateTime(2026, 6, 20)), // 19日 → soon
        _vehicle(voluntary: DateTime(2026, 12, 1)), // 余裕
        _vehicle(), // missing
        _vehicle(), // missing
      ];
      final s = summarizeFleetInsurance(vehicles, now: now);

      expect(s.total, 5);
      expect(s.expired, 1);
      expect(s.expiringSoon, 1);
      expect(s.missing, 2);
      expect(s.needsAttention, 2);
    });

    group('Edge Cases', () {
      test('空リストは全て0', () {
        final s = summarizeFleetInsurance([], now: now);
        expect(s.total, 0);
        expect(s.needsAttention, 0);
        expect(s.missing, 0);
      });

      test('ちょうど30日後は expiringSoon に含む', () {
        final s = summarizeFleetInsurance(
          [_vehicle(voluntary: DateTime(2026, 7, 1))], // 30日後
          now: now,
        );
        expect(s.expiringSoon, 1);
        expect(s.expired, 0);
      });
    });
  });
}
