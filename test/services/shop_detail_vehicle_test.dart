// Which car a shop-sent maintenance detail belongs to (usability test
// 2026-10-09, shop #9 / #15).
//
// The shop picks the car from its own ledger when composing the detail. The
// ledger does not know the user's app vehicle IDs, so the detail carries the
// plate and the car name; the user's app matches them to preselect the car.

import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/models/vehicle.dart';
import 'package:trust_car_platform/services/inquiry_maintenance_importer.dart';

Vehicle _car(String id, String maker, String model, {String? plate}) {
  final t = DateTime(2025);
  return Vehicle(
    id: id,
    userId: 'u1',
    maker: maker,
    model: model,
    year: 2020,
    grade: '',
    mileage: 10000,
    createdAt: t,
    updatedAt: t,
    licensePlate: plate,
  );
}

InquiryMaintenancePayload _payload({
  String? vehicleId,
  String? plate,
  String? label,
}) =>
    InquiryMaintenancePayload(
      typeKey: 'oilChange',
      title: 'オイル交換',
      date: DateTime(2026, 10, 8),
      cost: 16500,
      vehicleId: vehicleId,
      licensePlate: plate,
      vehicleLabel: label,
    );

void main() {
  final cars = [
    _car('a', 'Honda', 'N-BOX', plate: '岡山 580 あ 11-11'),
    _car('b', 'Mazda', 'CX-5', plate: '岡山 300 さ 22-22'),
    _car('c', 'Toyota', 'Prius'),
    _car('d', 'Toyota', 'Hiace', plate: '岡山 400 な 44-44'),
  ];

  group('InquiryMaintenancePayload — 車', () {
    test('車の項目が toMap/fromMap で往復する', () {
      final p = InquiryMaintenancePayload.fromMap(_payload(
        plate: '岡山 400 な 44-44',
        label: 'トヨタ ハイエース',
      ).toMap()
        ..['ledgerVehicleId'] = 'lv1');
      expect(p.licensePlate, '岡山 400 な 44-44');
      expect(p.vehicleLabel, 'トヨタ ハイエース');
      expect(p.ledgerVehicleId, 'lv1');
    });

    test('車の項目が無い古い明細も読める', () {
      final p = InquiryMaintenancePayload.fromMap(const {
        'typeKey': 'oilChange',
        'title': 'オイル交換',
        'cost': 5500,
      });
      expect(p.vehicleLabel, isNull);
      expect(p.licensePlate, isNull);
      expect(p.vehicleId, isNull);
    });

    test('金額は桁区切りで出す', () {
      expect(formatYen(16500), '¥16,500');
      expect(formatYen(0), '¥0');
      expect(_payload().summary, contains('¥16,500'));
    });
  });

  group('suggestImportVehicleId', () {
    test('アプリの車の ID が付いていればその車', () {
      expect(
        suggestImportVehicleId(
            payload: _payload(vehicleId: 'b'), vehicles: cars),
        'b',
      );
    });

    test('ナンバーが一致する車（空白・ハイフン・全角の違いは無視）', () {
      expect(
        suggestImportVehicleId(
          payload: _payload(plate: '岡山400な4444'),
          vehicles: cars,
        ),
        'd',
      );
      expect(
        suggestImportVehicleId(
          payload: _payload(plate: '岡山　４００　な　４４－４４'),
          vehicles: cars,
        ),
        'd',
      );
    });

    test('ナンバーが無ければ車名が1台だけ一致する車', () {
      expect(
        suggestImportVehicleId(
          payload: _payload(label: 'toyota hiace'),
          vehicles: cars,
        ),
        'd',
      );
    });

    group('Edge Cases', () {
      test('車の指定が無ければ null', () {
        expect(suggestImportVehicleId(payload: _payload(), vehicles: cars),
            isNull);
      });

      test('車が0台なら null', () {
        expect(
          suggestImportVehicleId(
              payload: _payload(vehicleId: 'a'), vehicles: const []),
          isNull,
        );
      });

      test('手放した・消した車の ID（手元に無い）は使わず、ナンバーで探す', () {
        expect(
          suggestImportVehicleId(
            payload: _payload(vehicleId: 'deleted', plate: '岡山 580 あ 11-11'),
            vehicles: cars,
          ),
          'a',
        );
      });

      test('車名が2台以上に当たるときは決めない', () {
        final twins = [
          ...cars,
          _car('e', 'Toyota', 'Hiace'),
        ];
        expect(
          suggestImportVehicleId(
            payload: _payload(label: 'Toyota Hiace'),
            vehicles: twins,
          ),
          isNull,
        );
      });

      test('空のナンバー・空の車名は一致に使わない', () {
        expect(
          suggestImportVehicleId(
            payload: _payload(plate: '', label: ''),
            vehicles: [_car('x', '', '')],
          ),
          isNull,
        );
      });
    });
  });

  group('buildMaintenanceRecordFromPayload — 元のメッセージ', () {
    test('sourceMessageId が記録に残る', () {
      final r = buildMaintenanceRecordFromPayload(
        payload: _payload(),
        vehicleId: 'd',
        userId: 'u1',
        inquiryId: 'inq1',
        sourceMessageId: 'm1',
      );
      expect(r.sourceMessageId, 'm1');
      expect(r.toMap()['sourceMessageId'], 'm1');
    });
  });
}
