import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/services/shop_ledger_service.dart';

/// Vehicles written before `lastInspectionAt` existed (2026-10-09) made the
/// loss report count every car as lost until the next history import:
/// cars that came back had their expiry moved two years on, so only the
/// new fields can place them in the month they were due. Opening the
/// ledger now fills the fields from the records already stored.
void main() {
  late FakeFirebaseFirestore fs;
  late ShopLedgerService service;
  final today = DateTime(2026, 10, 9);
  const shop = 's1';

  setUp(() {
    fs = FakeFirebaseFirestore();
    service = ShopLedgerService(firestore: fs, now: () => today);
  });

  Future<void> legacyVehicle(String id, DateTime expiry) =>
      fs.collection('shops/$shop/customer_vehicles').doc(id).set({
        'customerId': 'c1',
        'customerName': '青木 昭',
        'maker': 'トヨタ',
        'model': 'プリウス',
        'inspectionExpiry': Timestamp.fromDate(expiry),
        'createdAt': Timestamp.fromDate(DateTime(2025, 1, 1)),
        'updatedAt': Timestamp.fromDate(DateTime(2025, 1, 1)),
      });

  Future<void> record(String vehicleId, DateTime date, String type) =>
      fs.collection('shops/$shop/service_records').add({
        'customerId': 'c1',
        'customerVehicleId': vehicleId,
        'date': Timestamp.fromDate(date),
        'type': type,
        'source': 'csv',
        'updatedAt': Timestamp.fromDate(DateTime(2026, 10, 4)),
      });

  group('ensureInspectionFields', () {
    test('入庫して満了日が進んだ古い車を、取りこぼしから外す', () async {
      // Came back in August for the inspection due 2026-08-20; the
      // expiry moved on to 2028.
      await legacyVehicle('v_back', DateTime(2028, 8, 20));
      await record('v_back', DateTime(2026, 8, 1), '車検');
      // Expired in July and never came back.
      await legacyVehicle('v_lost', DateTime(2026, 7, 10));

      final before = (await service.lossReport(shopId: shop)).valueOrNull!;
      expect(before.lostVehicles.map((v) => v.id), ['v_lost']);
      final augBefore = before.months.firstWhere((m) => m.month.month == 8);
      expect(augBefore.returned, 0);

      final r = (await service.ensureInspectionFields(shop)).valueOrNull!;
      expect(r, 2);

      final after = (await service.lossReport(shopId: shop)).valueOrNull!;
      expect(after.lostVehicles.map((v) => v.id), ['v_lost']);
      final aug = after.months.firstWhere((m) => m.month.month == 8);
      expect(aug.returned, 1);
    });

    test('車検の記録が無い車にも「無い」と書き、二度と読まない', () async {
      await legacyVehicle('v1', DateTime(2027, 3, 1));
      await record('v1', DateTime(2026, 5, 1), 'オイル交換');
      expect((await service.ensureInspectionFields(shop)).valueOrNull, 1);
      final d = await fs.doc('shops/$shop/customer_vehicles/v1').get();
      expect(d.data()!.containsKey('lastInspectionAt'), isTrue);
      expect(d.data()!['lastInspectionAt'], isNull);
      expect((await service.ensureInspectionFields(shop)).valueOrNull, 0);
    });

    test('車も伝票も多い店では伝票を区切って全部読み、後ろの方の車検も拾う', () async {
      for (var i = 0; i < 301; i++) {
        await legacyVehicle(
            'v${i.toString().padLeft(3, '0')}', DateTime(2028, 3, 1));
      }
      for (var i = 0; i < 1001; i++) {
        await fs
            .collection('shops/$shop/service_records')
            .doc('r${i.toString().padLeft(4, '0')}')
            .set({
          'customerVehicleId': 'v000',
          'date':
              Timestamp.fromDate(DateTime(2023, 1, 1).add(Duration(days: i))),
          'type': 'オイル交換',
        });
      }
      // The newest record: on the second page.
      await fs.collection('shops/$shop/service_records').doc('zz_last').set({
        'customerVehicleId': 'v300',
        'date': Timestamp.fromDate(DateTime(2026, 3, 5)),
        'type': '車検（継続検査）',
      });

      final r = await service.ensureInspectionFields(shop);
      expect(r.valueOrNull, 301);
      final d = await fs.doc('shops/$shop/customer_vehicles/v300').get();
      expect((d.data()!['lastInspectionAt'] as Timestamp).toDate(),
          DateTime(2026, 3, 5));
    });

    group('Edge Cases', () {
      test('項目のある車は書き換えない（更新日時も動かさない）', () async {
        await fs.collection('shops/$shop/customer_vehicles').doc('v_new').set({
          'customerId': 'c1',
          'customerName': '青木 昭',
          'maker': 'トヨタ',
          'model': 'プリウス',
          'lastInspectionAt': Timestamp.fromDate(DateTime(2026, 6, 1)),
          'lastInspectionDueAt': Timestamp.fromDate(DateTime(2026, 6, 20)),
          'createdAt': Timestamp.fromDate(DateTime(2025, 1, 1)),
          'updatedAt': Timestamp.fromDate(DateTime(2025, 1, 1)),
        });
        expect((await service.ensureInspectionFields(shop)).valueOrNull, 0);
        final d = await fs.doc('shops/$shop/customer_vehicles/v_new').get();
        expect((d.data()!['lastInspectionAt'] as Timestamp).toDate(),
            DateTime(2026, 6, 1));
        expect((d.data()!['updatedAt'] as Timestamp).toDate(),
            DateTime(2025, 1, 1));
      });

      test('台帳が空でも失敗しない', () async {
        expect((await service.ensureInspectionFields(shop)).valueOrNull, 0);
      });

      test('店IDが空なら失敗を返す', () async {
        expect((await service.ensureInspectionFields('')).isFailure, isTrue);
      });
    });
  });
}
