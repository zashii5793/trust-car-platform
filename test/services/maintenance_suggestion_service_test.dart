import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/models/maintenance_suggestion.dart';
import 'package:trust_car_platform/models/maintenance_record.dart';
import 'package:trust_car_platform/models/vehicle.dart';
import 'package:trust_car_platform/services/maintenance_schedule_service.dart';

Vehicle _makeVehicle({int mileage = 0, FuelType? fuelType}) => Vehicle(
      id: 'v1',
      userId: 'u1',
      maker: 'トヨタ',
      model: 'プリウス',
      year: 2020,
      grade: 'S',
      mileage: mileage,
      fuelType: fuelType,
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
    );

MaintenanceRecord _makeRecord(MaintenanceType type, {int mileage = 0}) =>
    MaintenanceRecord(
      id: 'r1',
      vehicleId: 'v1',
      userId: 'u1',
      type: type,
      title: type.displayName,
      date: DateTime(2024),
      cost: 3000,
      mileageAtService: mileage,
      createdAt: DateTime(2024),
    );

void main() {
  late MaintenanceScheduleService service;

  setUp(() {
    service = const MaintenanceScheduleService();
  });

  group('generateSuggestionsForVehicle', () {
    group('基本動作', () {
      test('空の整備記録でも提案を返す', () {
        final vehicle = _makeVehicle(mileage: 15000);
        final result = service.generateSuggestionsForVehicle(vehicle, []);
        expect(result, isNotEmpty);
      });

      test('全提案は MaintenanceSuggestion 型を返す', () {
        final vehicle = _makeVehicle(mileage: 5000);
        final result = service.generateSuggestionsForVehicle(vehicle, []);
        expect(result, everyElement(isA<MaintenanceSuggestion>()));
      });

      test('提案は緊急度降順（urgency.index 昇順）でソートされている', () {
        final vehicle = _makeVehicle(mileage: 9500);
        final result = service.generateSuggestionsForVehicle(vehicle, []);
        expect(result, isNotEmpty);
        for (int i = 0; i < result.length - 1; i++) {
          expect(
            result[i].urgency.index <= result[i + 1].urgency.index,
            isTrue,
            reason: 'Urgency should be non-increasing',
          );
        }
      });

      test('reason フィールドは空文字でない', () {
        final vehicle = _makeVehicle(mileage: 12000);
        final result = service.generateSuggestionsForVehicle(vehicle, []);
        for (final s in result) {
          expect(s.reason, isNotEmpty);
        }
      });

      test('title フィールドは空文字でない', () {
        final vehicle = _makeVehicle(mileage: 8000);
        final result = service.generateSuggestionsForVehicle(vehicle, []);
        for (final s in result) {
          expect(s.title, isNotEmpty);
        }
      });
    });

    group('燃料タイプ別', () {
      test('ガソリン車: オイル交換提案を含む', () {
        final vehicle =
            _makeVehicle(mileage: 4500, fuelType: FuelType.gasoline);
        final result = service.generateSuggestionsForVehicle(vehicle, []);
        expect(result.any((s) => s.type == MaintenanceType.oilChange), isTrue,
            reason: 'Gasoline should suggest oil change');
      });

      test('EV: オイル交換提案を含まない', () {
        final vehicle =
            _makeVehicle(mileage: 9000, fuelType: FuelType.electric);
        final result = service.generateSuggestionsForVehicle(vehicle, []);
        expect(result.any((s) => s.type == MaintenanceType.oilChange), isFalse,
            reason: 'EV should not suggest oil change');
      });

      test('EV: タイヤローテーション提案を含む', () {
        final vehicle =
            _makeVehicle(mileage: 9500, fuelType: FuelType.electric);
        final result = service.generateSuggestionsForVehicle(vehicle, []);
        expect(
          result.any((s) => s.type == MaintenanceType.tireRotation),
          isTrue,
          reason: 'EV should suggest tire rotation',
        );
      });

      test('ハイブリッド: オイル交換は 10,000km インターバル、9500km で remaining=500', () {
        final vehicle = _makeVehicle(mileage: 9500, fuelType: FuelType.hybrid);
        final result = service.generateSuggestionsForVehicle(vehicle, []);
        final oil =
            result.firstWhere((s) => s.type == MaintenanceType.oilChange);
        expect(oil.remainingKm, equals(500));
        // remaining=500 <= 500 → high
        expect(oil.urgency, equals(SuggestionUrgency.high));
      });

      test('fuelType が null はガソリン扱い（デフォルト）', () {
        final vehicle = _makeVehicle(mileage: 4500, fuelType: null);
        final result = service.generateSuggestionsForVehicle(vehicle, []);
        expect(result.any((s) => s.type == MaintenanceType.oilChange), isTrue);
      });
    });

    group('緊急度判定', () {
      test('残り 500km 以下: urgency = high', () {
        // Gasoline 5000km interval: at 4600, next at 5000, remaining = 400
        final vehicle =
            _makeVehicle(mileage: 4600, fuelType: FuelType.gasoline);
        final result = service.generateSuggestionsForVehicle(vehicle, []);
        final oilSugg =
            result.firstWhere((s) => s.type == MaintenanceType.oilChange);
        expect(oilSugg.urgency, equals(SuggestionUrgency.high));
        expect(oilSugg.remainingKm, equals(400));
      });

      test('残り 501〜2000km: urgency = medium', () {
        // At 9100km, oil change next at 10000 → remaining = 900
        final vehicle =
            _makeVehicle(mileage: 9100, fuelType: FuelType.gasoline);
        final result = service.generateSuggestionsForVehicle(vehicle, []);
        final oilSugg =
            result.firstWhere((s) => s.type == MaintenanceType.oilChange);
        expect(oilSugg.urgency, equals(SuggestionUrgency.medium));
        expect(oilSugg.remainingKm, equals(900));
      });

      test('残り 2001km 超: urgency = low', () {
        final vehicle =
            _makeVehicle(mileage: 1000, fuelType: FuelType.gasoline);
        final result = service.generateSuggestionsForVehicle(vehicle, []);
        final oilSugg =
            result.firstWhere((s) => s.type == MaintenanceType.oilChange);
        // next at 5000, remaining = 4000
        expect(oilSugg.urgency, equals(SuggestionUrgency.low));
        expect(oilSugg.remainingKm, greaterThan(2000));
      });

      test('タイヤローテーション(EV) at 9600km: urgency = high (remaining=400)', () {
        // EV tire rotation 10000km interval: next at 10000, remaining = 400
        final vehicle =
            _makeVehicle(mileage: 9600, fuelType: FuelType.electric);
        final result = service.generateSuggestionsForVehicle(vehicle, []);
        final tire =
            result.firstWhere((s) => s.type == MaintenanceType.tireRotation);
        expect(tire.urgency, equals(SuggestionUrgency.high));
        expect(tire.remainingKm, equals(400));
      });
    });

    group('reason 文字列', () {
      test('high urgency 提案の reason は km を含む', () {
        final vehicle =
            _makeVehicle(mileage: 4600, fuelType: FuelType.gasoline);
        final result = service.generateSuggestionsForVehicle(vehicle, []);
        final high =
            result.where((s) => s.urgency == SuggestionUrgency.high).toList();
        for (final s in high) {
          expect(s.reason, isNotEmpty);
          expect(s.reason.contains('km'), isTrue);
        }
      });

      test('通常提案の reason は残り km を含む', () {
        final vehicle =
            _makeVehicle(mileage: 1000, fuelType: FuelType.gasoline);
        final result = service.generateSuggestionsForVehicle(vehicle, []);
        expect(result, isNotEmpty);
        expect(result.first.reason.contains('km'), isTrue);
      });
    });

    group('Edge Cases', () {
      test('走行距離 0km: 提案を返す（remainingKm > 0）', () {
        final vehicle = _makeVehicle(mileage: 0);
        final result = service.generateSuggestionsForVehicle(vehicle, []);
        expect(result, isNotEmpty);
        for (final s in result) {
          expect(s.remainingKm, isNotNull);
          expect(s.remainingKm! > 0, isTrue);
        }
      });

      test('走行距離がインターバルの倍数: 次のインターバルを推奨', () {
        // At 5000km, gasoline oil change next due at 10000
        final vehicle =
            _makeVehicle(mileage: 5000, fuelType: FuelType.gasoline);
        final result = service.generateSuggestionsForVehicle(vehicle, []);
        final oil =
            result.firstWhere((s) => s.type == MaintenanceType.oilChange);
        expect(oil.remainingKm, equals(5000));
        expect(oil.urgency, equals(SuggestionUrgency.low));
      });

      test('非常に高い走行距離: 適切な次インターバルを計算', () {
        final vehicle =
            _makeVehicle(mileage: 200000, fuelType: FuelType.gasoline);
        final result = service.generateSuggestionsForVehicle(vehicle, []);
        expect(result, isNotEmpty);
        for (final s in result) {
          expect(s.remainingKm, isNotNull);
        }
      });

      test('空の整備記録リスト: クラッシュしない', () {
        final vehicle = _makeVehicle(mileage: 10000);
        expect(
          () => service.generateSuggestionsForVehicle(vehicle, []),
          returnsNormally,
        );
      });

      test('同じタイプの整備記録が複数あっても提案は重複しない', () {
        final vehicle =
            _makeVehicle(mileage: 9000, fuelType: FuelType.gasoline);
        final records = List<MaintenanceRecord>.generate(
          5,
          (i) =>
              _makeRecord(MaintenanceType.oilChange, mileage: 1000 * (i + 1)),
        );
        final result = service.generateSuggestionsForVehicle(vehicle, records);
        final oilCount =
            result.where((s) => s.type == MaintenanceType.oilChange).length;
        expect(oilCount, equals(1), reason: 'Should not duplicate suggestions');
      });
    });
  });
}
