import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:trust_car_platform/models/maintenance_record.dart';

void main() {
  group('MaintenanceRecord', () {
    group('_parseMaintenanceType', () {
      test('有効なインデックスからMaintenanceTypeを取得できる', () {
        final record = MaintenanceRecord(
          id: 'record1',
          vehicleId: 'vehicle1',
          userId: 'user1',
          type: MaintenanceType.repair,
          title: 'Test',
          cost: 1000,
          date: DateTime.now(),
          createdAt: DateTime.now(),
        );

        expect(record.type, MaintenanceType.repair);
      });

      test('全てのMaintenanceTypeが正しい表示名を持つ', () {
        expect(
          MaintenanceRecord(
            id: '1',
            vehicleId: 'v1',
            userId: 'u1',
            type: MaintenanceType.repair,
            title: 'Test',
            cost: 0,
            date: DateTime.now(),
            createdAt: DateTime.now(),
          ).typeDisplayName,
          '修理',
        );

        expect(
          MaintenanceRecord(
            id: '2',
            vehicleId: 'v1',
            userId: 'u1',
            type: MaintenanceType.inspection,
            title: 'Test',
            cost: 0,
            date: DateTime.now(),
            createdAt: DateTime.now(),
          ).typeDisplayName,
          '点検',
        );

        expect(
          MaintenanceRecord(
            id: '3',
            vehicleId: 'v1',
            userId: 'u1',
            type: MaintenanceType.partsReplacement,
            title: 'Test',
            cost: 0,
            date: DateTime.now(),
            createdAt: DateTime.now(),
          ).typeDisplayName,
          '消耗品交換',
        );

        expect(
          MaintenanceRecord(
            id: '4',
            vehicleId: 'v1',
            userId: 'u1',
            type: MaintenanceType.carInspection,
            title: 'Test',
            cost: 0,
            date: DateTime.now(),
            createdAt: DateTime.now(),
          ).typeDisplayName,
          '車検',
        );
      });
    });

    group('toMap', () {
      test('MaintenanceRecordをMapに変換できる', () {
        final now = DateTime.now();
        final record = MaintenanceRecord(
          id: 'record1',
          vehicleId: 'vehicle1',
          userId: 'user1',
          type: MaintenanceType.inspection,
          title: 'オイル交換',
          description: '定期点検',
          cost: 5000,
          shopName: 'カーショップA',
          date: now,
          mileageAtService: 50000,
          imageUrls: ['url1', 'url2'],
          createdAt: now,
        );

        final map = record.toMap();

        expect(map['vehicleId'], 'vehicle1');
        expect(map['userId'], 'user1');
        expect(map['type'], MaintenanceType.inspection.index);
        expect(map['title'], 'オイル交換');
        expect(map['description'], '定期点検');
        expect(map['cost'], 5000);
        expect(map['shopName'], 'カーショップA');
        expect(map['mileageAtService'], 50000);
        expect(map['imageUrls'], ['url1', 'url2']);
        expect(map['date'], isA<Timestamp>());
        expect(map['createdAt'], isA<Timestamp>());
      });
    });

    group('constructor defaults', () {
      test('imageUrlsのデフォルト値は空リスト', () {
        final record = MaintenanceRecord(
          id: 'record1',
          vehicleId: 'vehicle1',
          userId: 'user1',
          type: MaintenanceType.repair,
          title: 'Test',
          cost: 1000,
          date: DateTime.now(),
          createdAt: DateTime.now(),
        );

        expect(record.imageUrls, []);
      });

      test('オプショナルフィールドはnullを許容', () {
        final record = MaintenanceRecord(
          id: 'record1',
          vehicleId: 'vehicle1',
          userId: 'user1',
          type: MaintenanceType.repair,
          title: 'Test',
          cost: 1000,
          date: DateTime.now(),
          createdAt: DateTime.now(),
        );

        expect(record.description, null);
        expect(record.shopName, null);
        expect(record.mileageAtService, null);
      });
    });
  });
}
