import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/services/invoice_ocr_service.dart';
import 'package:trust_car_platform/models/maintenance_record.dart';

void main() {
  group('InvoiceData', () {
    test('全フィールドがnullの場合、hasMaintenanceInfoはfalseを返す', () {
      final data = InvoiceData();
      expect(data.hasMaintenanceInfo, false);
    });

    test('dateがある場合、hasMaintenanceInfoはtrueを返す', () {
      final data = InvoiceData(date: DateTime(2024, 1, 15));
      expect(data.hasMaintenanceInfo, true);
    });

    test('totalAmountがある場合、hasMaintenanceInfoはtrueを返す', () {
      final data = InvoiceData(totalAmount: 25000);
      expect(data.hasMaintenanceInfo, true);
    });

    test('itemsがある場合、hasMaintenanceInfoはtrueを返す', () {
      final data = InvoiceData(
        items: [InvoiceItem(name: 'オイル交換', amount: 5000)],
      );
      expect(data.hasMaintenanceInfo, true);
    });

    test('confidenceScoreが正しく計算される（全項目null）', () {
      final data = InvoiceData();
      expect(data.confidenceScore, 0.0);
    });

    test('confidenceScoreが正しく計算される（一部項目あり）', () {
      final data = InvoiceData(
        date: DateTime(2024, 1, 15),
        totalAmount: 25000,
        shopName: 'オートバックス',
        items: [InvoiceItem(name: 'オイル交換', amount: 5000)],
      );
      // 4項目 / 10項目 = 0.4
      expect(data.confidenceScore, 0.4);
    });

    test('confidenceScoreが正しく計算される（全項目あり）', () {
      final data = InvoiceData(
        date: DateTime(2024, 1, 15),
        totalAmount: 25000,
        taxAmount: 2273,
        subtotalAmount: 22727,
        shopName: 'オートバックス',
        shopAddress: '東京都品川区',
        shopPhone: '03-1234-5678',
        invoiceNumber: 'INV-001',
        items: [InvoiceItem(name: 'オイル交換', amount: 5000)],
        mileage: 50000,
      );
      expect(data.confidenceScore, 1.0);
    });
  });

  group('InvoiceData.estimatedMaintenanceType', () {
    test('オイル交換を含む場合、oilChangeを返す', () {
      final data = InvoiceData(
        items: [InvoiceItem(name: 'エンジンオイル交換', amount: 5000)],
      );
      expect(data.estimatedMaintenanceType, MaintenanceType.oilChange);
    });

    test('車検を含む場合、carInspectionを返す', () {
      final data = InvoiceData(
        items: [InvoiceItem(name: '車検整備一式', amount: 80000)],
      );
      expect(data.estimatedMaintenanceType, MaintenanceType.carInspection);
    });

    test('タイヤ交換を含む場合、tireChangeを返す', () {
      final data = InvoiceData(
        items: [InvoiceItem(name: 'スタッドレスタイヤ交換', amount: 15000)],
      );
      expect(data.estimatedMaintenanceType, MaintenanceType.tireChange);
    });

    test('ブレーキパッドを含む場合、brakePadChangeを返す', () {
      final data = InvoiceData(
        items: [InvoiceItem(name: 'フロントブレーキパッド交換', amount: 20000)],
      );
      expect(data.estimatedMaintenanceType, MaintenanceType.brakePadChange);
    });

    test('バッテリーを含む場合、batteryChangeを返す', () {
      final data = InvoiceData(
        items: [InvoiceItem(name: 'バッテリー交換', amount: 15000)],
      );
      expect(data.estimatedMaintenanceType, MaintenanceType.batteryChange);
    });

    test('12ヶ月点検を含む場合、legalInspection12を返す', () {
      final data = InvoiceData(
        items: [InvoiceItem(name: '12ヶ月点検', amount: 15000)],
      );
      expect(data.estimatedMaintenanceType, MaintenanceType.legalInspection12);
    });

    test('修理を含む場合、repairを返す', () {
      final data = InvoiceData(
        items: [InvoiceItem(name: 'バンパー修理', amount: 50000)],
      );
      expect(data.estimatedMaintenanceType, MaintenanceType.repair);
    });

    test('洗車を含む場合、washingを返す', () {
      final data = InvoiceData(
        items: [InvoiceItem(name: '手洗い洗車', amount: 3000)],
      );
      expect(data.estimatedMaintenanceType, MaintenanceType.washing);
    });

    test('itemsが空の場合、nullを返す', () {
      final data = InvoiceData();
      expect(data.estimatedMaintenanceType, null);
    });

    test('該当しない場合、otherを返す', () {
      final data = InvoiceData(
        items: [InvoiceItem(name: 'その他作業', amount: 10000)],
      );
      expect(data.estimatedMaintenanceType, MaintenanceType.other);
    });
  });

  group('InvoiceItem', () {
    test('正しく初期化される', () {
      final item = InvoiceItem(
        name: 'オイル交換',
        quantity: 1,
        unitPrice: 5000,
        amount: 5000,
        partNumber: 'OIL-001',
      );

      expect(item.name, 'オイル交換');
      expect(item.quantity, 1);
      expect(item.unitPrice, 5000);
      expect(item.amount, 5000);
      expect(item.partNumber, 'OIL-001');
    });

    test('toStringが正しくフォーマットされる', () {
      final item = InvoiceItem(name: 'オイル交換', amount: 5000);
      expect(item.toString(), 'InvoiceItem(オイル交換: ¥5000)');
    });
  });

  group('InvoiceData toString', () {
    test('toStringが正しくフォーマットされる', () {
      final data = InvoiceData(
        date: DateTime(2024, 1, 15),
        totalAmount: 25000,
        shopName: 'オートバックス',
        items: [InvoiceItem(name: 'オイル交換', amount: 5000)],
      );
      final str = data.toString();
      expect(str.contains('totalAmount: 25000'), true);
      expect(str.contains('shopName: オートバックス'), true);
      expect(str.contains('items: 1件'), true);
      expect(str.contains('confidenceScore:'), true);
    });
  });
}
