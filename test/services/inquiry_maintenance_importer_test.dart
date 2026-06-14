// InquiryMaintenanceImporter — unit tests
//
// Covers the structured maintenance payload a shop attaches to an inquiry
// reply, and the pure converter that turns it into a user-owned
// MaintenanceRecord (pull model: the user confirms before persisting).

import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/models/maintenance_record.dart';
import 'package:trust_car_platform/services/inquiry_maintenance_importer.dart';

void main() {
  group('InquiryMaintenancePayload', () {
    InquiryMaintenancePayload sample() => InquiryMaintenancePayload(
          typeKey: 'oilChange',
          title: 'オイル交換',
          date: DateTime(2026, 5, 20),
          cost: 6600,
          mileageAtService: 32000,
          shopName: 'タカヤモーター',
          description: '0W-20 化学合成油',
          staffName: '山田',
          safetyStandardsCertificate: null,
          workItems: const [
            WorkItem(name: 'オイル交換作業', laborCost: 1500),
          ],
          parts: const [
            Part(
              partNumber: 'OIL-0W20',
              name: 'エンジンオイル',
              manufacturer: 'トヨタ',
              unitPrice: 1200,
              quantity: 4,
            ),
          ],
          partsCost: 4800,
          laborCost: 1500,
          miscCost: 300,
        );

    test('toMap/fromMap で往復しても主要フィールドが保持される', () {
      final original = sample();
      final restored = InquiryMaintenancePayload.fromMap(original.toMap());

      expect(restored.typeKey, 'oilChange');
      expect(restored.title, 'オイル交換');
      expect(restored.date, DateTime(2026, 5, 20));
      expect(restored.cost, 6600);
      expect(restored.mileageAtService, 32000);
      expect(restored.shopName, 'タカヤモーター');
      expect(restored.description, '0W-20 化学合成油');
      expect(restored.staffName, '山田');
      expect(restored.workItems.length, 1);
      expect(restored.workItems.first.name, 'オイル交換作業');
      expect(restored.workItems.first.laborCost, 1500);
      expect(restored.parts.length, 1);
      expect(restored.parts.first.name, 'エンジンオイル');
      expect(restored.parts.first.quantity, 4);
      expect(restored.partsCost, 4800);
      expect(restored.laborCost, 1500);
      expect(restored.miscCost, 300);
    });

    group('Edge Cases', () {
      test('空マップから生成してもクラッシュせず妥当なデフォルトになる', () {
        final p = InquiryMaintenancePayload.fromMap({});
        expect(p.typeKey, 'other');
        expect(p.title, '');
        expect(p.cost, 0);
        expect(p.mileageAtService, isNull);
        expect(p.workItems, isEmpty);
        expect(p.parts, isEmpty);
      });

      test('workItems/parts が無くても往復できる', () {
        final p = InquiryMaintenancePayload(
          typeKey: 'carInspection',
          title: '車検',
          date: DateTime(2026, 1, 1),
          cost: 80000,
        );
        final restored = InquiryMaintenancePayload.fromMap(p.toMap());
        expect(restored.workItems, isEmpty);
        expect(restored.parts, isEmpty);
        expect(restored.mileageAtService, isNull);
      });
    });
  });

  group('buildMaintenanceRecordFromPayload', () {
    InquiryMaintenancePayload payload({
      String typeKey = 'oilChange',
      String title = 'オイル交換',
      int cost = 6600,
      int? mileage = 32000,
    }) =>
        InquiryMaintenancePayload(
          typeKey: typeKey,
          title: title,
          date: DateTime(2026, 5, 20),
          cost: cost,
          mileageAtService: mileage,
          shopName: 'タカヤモーター',
          staffName: '山田',
          workItems: const [WorkItem(name: '作業', laborCost: 1500)],
          parts: const [
            Part(partNumber: 'P1', name: '部品', unitPrice: 1000, quantity: 2),
          ],
          partsCost: 2000,
          laborCost: 1500,
        );

    test('正常系: ユーザー所有の MaintenanceRecord に変換される', () {
      final record = buildMaintenanceRecordFromPayload(
        payload: payload(),
        vehicleId: 'v1',
        userId: 'user-1',
        inquiryId: 'inq-1',
        now: DateTime(2026, 6, 1),
      );

      expect(record.id, ''); // 新規（Firestore採番）
      expect(record.vehicleId, 'v1');
      // 所有者は工場ではなくユーザー（pull モデル）
      expect(record.userId, 'user-1');
      expect(record.type, MaintenanceType.oilChange);
      expect(record.title, 'オイル交換');
      expect(record.cost, 6600);
      expect(record.mileageAtService, 32000);
      expect(record.shopName, 'タカヤモーター');
      expect(record.staffName, '山田');
      expect(record.date, DateTime(2026, 5, 20));
      expect(record.createdAt, DateTime(2026, 6, 1));
      expect(record.workItems.length, 1);
      expect(record.parts.length, 1);
      expect(record.partsCost, 2000);
      expect(record.inquiryId, 'inq-1'); // トレーサビリティ
    });

    group('Edge Cases', () {
      test('未知のtypeKeyは repair にフォールバックする', () {
        final record = buildMaintenanceRecordFromPayload(
          payload: payload(typeKey: 'nonexistent_type'),
          vehicleId: 'v1',
          userId: 'user-1',
          inquiryId: 'inq-1',
        );
        expect(record.type, MaintenanceType.repair);
      });

      test('mileage が null でもそのまま null で変換される', () {
        final record = buildMaintenanceRecordFromPayload(
          payload: payload(mileage: null),
          vehicleId: 'v1',
          userId: 'user-1',
          inquiryId: 'inq-1',
        );
        expect(record.mileageAtService, isNull);
      });

      test('title が空なら既定タイトルが入る', () {
        final record = buildMaintenanceRecordFromPayload(
          payload: payload(title: ''),
          vehicleId: 'v1',
          userId: 'user-1',
          inquiryId: 'inq-1',
        );
        expect(record.title, '整備記録');
      });

      test('cost 0 でも変換できる', () {
        final record = buildMaintenanceRecordFromPayload(
          payload: payload(cost: 0),
          vehicleId: 'v1',
          userId: 'user-1',
          inquiryId: 'inq-1',
        );
        expect(record.cost, 0);
      });
    });
  });
}
