import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:trust_car_platform/models/maintenance_record.dart';

void main() {
  group('MaintenanceRecord', () {
    group('MaintenanceType', () {
      test('全てのMaintenanceTypeが正しい表示名を持つ', () {
        expect(MaintenanceType.repair.displayName, '修理');
        expect(MaintenanceType.legalInspection12.displayName, '12ヶ月点検');
        expect(MaintenanceType.legalInspection24.displayName, '24ヶ月点検');
        expect(MaintenanceType.carInspection.displayName, '車検');
        expect(MaintenanceType.oilChange.displayName, 'オイル交換');
        expect(MaintenanceType.tireChange.displayName, 'タイヤ交換');
        expect(MaintenanceType.partsReplacement.displayName, '部品交換');
      });

      test('fromStringで文字列からMaintenanceTypeを取得できる', () {
        expect(MaintenanceType.fromString('repair'), MaintenanceType.repair);
        expect(MaintenanceType.fromString('oilChange'), MaintenanceType.oilChange);
        expect(MaintenanceType.fromString('legalInspection12'), MaintenanceType.legalInspection12);
        expect(MaintenanceType.fromString('invalid'), MaintenanceType.repair); // デフォルト
        expect(MaintenanceType.fromString(null), MaintenanceType.repair); // null
      });

      test('fromIndexで数値からMaintenanceTypeを取得できる（後方互換性）', () {
        expect(MaintenanceType.fromIndex(0), MaintenanceType.repair);
        expect(MaintenanceType.fromIndex(-1), MaintenanceType.repair); // 範囲外
        expect(MaintenanceType.fromIndex(100), MaintenanceType.repair); // 範囲外
        expect(MaintenanceType.fromIndex(null), MaintenanceType.repair); // null
      });

      test('groupedTypesでカテゴリ別にグループ化される', () {
        final groups = MaintenanceType.groupedTypes;
        expect(groups.containsKey('点検・車検'), true);
        expect(groups.containsKey('オイル関連'), true);
        expect(groups['点検・車検'], contains(MaintenanceType.carInspection));
        expect(groups['オイル関連'], contains(MaintenanceType.oilChange));
      });

      test('isPeriodicMaintenanceで定期交換タイプを判定', () {
        expect(MaintenanceType.oilChange.isPeriodicMaintenance, true);
        expect(MaintenanceType.tireRotation.isPeriodicMaintenance, true);
        expect(MaintenanceType.repair.isPeriodicMaintenance, false);
        expect(MaintenanceType.carInspection.isPeriodicMaintenance, false);
      });

      test('isLegalInspectionで法定点検タイプを判定', () {
        expect(MaintenanceType.legalInspection12.isLegalInspection, true);
        expect(MaintenanceType.legalInspection24.isLegalInspection, true);
        expect(MaintenanceType.carInspection.isLegalInspection, true);
        expect(MaintenanceType.oilChange.isLegalInspection, false);
      });
    });

    group('MaintenanceRecord constructor', () {
      test('必須フィールドでMaintenanceRecordを生成できる', () {
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
        expect(record.typeDisplayName, '修理');
      });

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
        expect(record.partNumber, null);
        expect(record.partManufacturer, null);
      });

      test('Phase 1.5追加フィールドを設定できる', () {
        final nextDate = DateTime.now().add(const Duration(days: 180));
        final record = MaintenanceRecord(
          id: 'record1',
          vehicleId: 'vehicle1',
          userId: 'user1',
          type: MaintenanceType.oilChange,
          title: 'オイル交換',
          cost: 5000,
          date: DateTime.now(),
          createdAt: DateTime.now(),
          partNumber: 'E250',
          partManufacturer: "WAKO'S",
          nextReplacementMileage: 55000,
          nextReplacementDate: nextDate,
        );

        expect(record.partNumber, 'E250');
        expect(record.partManufacturer, "WAKO'S");
        expect(record.nextReplacementMileage, 55000);
        expect(record.nextReplacementDate, nextDate);
      });
    });

    group('toMap', () {
      test('MaintenanceRecordをMapに変換できる', () {
        final now = DateTime.now();
        final record = MaintenanceRecord(
          id: 'record1',
          vehicleId: 'vehicle1',
          userId: 'user1',
          type: MaintenanceType.oilChange,
          title: 'オイル交換',
          description: '定期交換',
          cost: 5000,
          shopName: 'カーショップA',
          date: now,
          mileageAtService: 50000,
          imageUrls: ['url1', 'url2'],
          createdAt: now,
          partNumber: 'E250',
          partManufacturer: "WAKO'S",
        );

        final map = record.toMap();

        expect(map['vehicleId'], 'vehicle1');
        expect(map['userId'], 'user1');
        expect(map['type'], 'oilChange'); // 文字列で保存（新形式）
        expect(map['title'], 'オイル交換');
        expect(map['description'], '定期交換');
        expect(map['cost'], 5000);
        expect(map['shopName'], 'カーショップA');
        expect(map['mileageAtService'], 50000);
        expect(map['imageUrls'], ['url1', 'url2']);
        expect(map['date'], isA<Timestamp>());
        expect(map['createdAt'], isA<Timestamp>());
        expect(map['partNumber'], 'E250');
        expect(map['partManufacturer'], "WAKO'S");
      });
    });

    group('copyWith', () {
      test('一部フィールドを変更したコピーを作成できる', () {
        final now = DateTime.now();
        final record = MaintenanceRecord(
          id: 'record1',
          vehicleId: 'vehicle1',
          userId: 'user1',
          type: MaintenanceType.repair,
          title: 'Test',
          cost: 1000,
          date: now,
          createdAt: now,
        );

        final copied = record.copyWith(
          title: 'Updated Title',
          cost: 2000,
          partNumber: 'ABC123',
        );

        expect(copied.id, 'record1');
        expect(copied.title, 'Updated Title');
        expect(copied.cost, 2000);
        expect(copied.partNumber, 'ABC123');
        expect(copied.type, MaintenanceType.repair);
      });
    });

    group('typeIcon and typeColor', () {
      test('アイコンと色が取得できる', () {
        final record = MaintenanceRecord(
          id: 'record1',
          vehicleId: 'vehicle1',
          userId: 'user1',
          type: MaintenanceType.oilChange,
          title: 'Test',
          cost: 1000,
          date: DateTime.now(),
          createdAt: DateTime.now(),
        );

        expect(record.typeIcon, isNotNull);
        expect(record.typeColor, isNotNull);
      });
    });

    group('isReplacementDueSoon', () {
      test('次回交換日が30日以内の場合trueを返す', () {
        final record = MaintenanceRecord(
          id: 'record1',
          vehicleId: 'vehicle1',
          userId: 'user1',
          type: MaintenanceType.oilChange,
          title: 'Test',
          cost: 1000,
          date: DateTime.now(),
          createdAt: DateTime.now(),
          nextReplacementDate: DateTime.now().add(const Duration(days: 15)),
        );

        expect(record.isReplacementDueSoon, true);
      });

      test('次回交換日が30日より先の場合falseを返す', () {
        final record = MaintenanceRecord(
          id: 'record1',
          vehicleId: 'vehicle1',
          userId: 'user1',
          type: MaintenanceType.oilChange,
          title: 'Test',
          cost: 1000,
          date: DateTime.now(),
          createdAt: DateTime.now(),
          nextReplacementDate: DateTime.now().add(const Duration(days: 60)),
        );

        expect(record.isReplacementDueSoon, false);
      });

      test('次回交換日が未設定の場合falseを返す', () {
        final record = MaintenanceRecord(
          id: 'record1',
          vehicleId: 'vehicle1',
          userId: 'user1',
          type: MaintenanceType.oilChange,
          title: 'Test',
          cost: 1000,
          date: DateTime.now(),
          createdAt: DateTime.now(),
        );

        expect(record.isReplacementDueSoon, false);
      });
    });
  });
}
