import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/core/error/app_error.dart';
import 'package:trust_car_platform/models/maintenance_record.dart';
import 'package:trust_car_platform/models/vehicle.dart';
import 'package:trust_car_platform/services/shop_ledger_service.dart';
import 'package:trust_car_platform/services/vehicle_share_service.dart';

/// 初めて行く店に「この車のこれまで」を渡す。
///
/// **渡すものをユーザーが選べること**と、**取り消したら店から消えること**が
/// 肝心。選ばなかったもの（ナンバー・費用・連絡先）が写しに漏れていないかを
/// 必ず確かめる。
void main() {
  late FakeFirebaseFirestore fs;
  late VehicleShareService service;
  final now = DateTime(2026, 9, 27, 10);
  const owner = 'user-1';
  const shopId = 'shop-1';

  final vehicle = Vehicle(
    id: 'v1',
    userId: owner,
    maker: 'MINI',
    model: 'クーパー',
    year: 2019,
    grade: 'S',
    mileage: 48000,
    licensePlate: '品川 300 あ 12-34',
    inspectionExpiryDate: DateTime(2027, 4, 1),
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
  );

  MaintenanceRecord record(String id, DateTime date, int cost) =>
      MaintenanceRecord(
        id: id,
        vehicleId: 'v1',
        userId: owner,
        type: MaintenanceType.oilChange,
        title: 'オイル交換',
        cost: cost,
        date: date,
        mileageAtService: 40000,
        shopName: '前の店',
        createdAt: date,
      );

  setUp(() {
    fs = FakeFirebaseFirestore();
    service = VehicleShareService(firestore: fs, now: () => now);
  });

  Future<Map<String, dynamic>?> shareDoc() async =>
      (await fs.doc('shops/$shopId/shared_vehicles/v1').get()).data();

  group('share', () {
    test('選ばなければ、ナンバー・費用・連絡先は写しに入らない', () async {
      final r = await service.share(
        ownerId: owner,
        vehicle: vehicle,
        shopId: shopId,
        shopName: 'タカヤモーター',
        records: [record('r1', DateTime(2026, 5, 1), 5500)],
        days: 30,
      );
      expect(r.isSuccess, isTrue);

      final d = (await shareDoc())!;
      expect(d['plate'], isNull);
      expect(d['contactName'], isNull);
      expect(d['contactPhone'], isNull);
      expect(d['includesCosts'], isFalse);
      final rec = (d['records'] as List).single as Map;
      expect(rec.containsKey('cost'), isFalse);
      expect(rec['title'], 'オイル交換');
      expect(rec['type'], 'オイル交換');
    });

    test('選べば、ナンバー・費用・連絡先・一言が入る', () async {
      await service.share(
        ownerId: owner,
        vehicle: vehicle,
        shopId: shopId,
        shopName: 'タカヤモーター',
        records: [record('r1', DateTime(2026, 5, 1), 5500)],
        days: 30,
        includePlate: true,
        includeCosts: true,
        contactName: '山田',
        contactPhone: '090-0000-0000',
        message: '車検の見積もりをお願いします',
      );
      final d = (await shareDoc())!;
      expect(d['plate'], '品川 300 あ 12-34');
      expect(d['contactName'], '山田');
      expect(d['message'], '車検の見積もりをお願いします');
      expect(((d['records'] as List).single as Map)['cost'], 5500);
    });

    test('記録は新しい順に入る', () async {
      await service.share(
        ownerId: owner,
        vehicle: vehicle,
        shopId: shopId,
        shopName: 'タカヤモーター',
        records: [
          record('old', DateTime(2024, 1, 1), 1),
          record('new', DateTime(2026, 1, 1), 2),
        ],
        days: 30,
        includeCosts: true,
      );
      final recs = (await shareDoc())!['records'] as List;
      expect(recs.map((r) => (r as Map)['cost']), [2, 1]);
    });

    test('上限を超える記録は、新しい方から200件だけ入る', () async {
      final many = [
        for (var i = 0; i < 250; i++)
          record('r$i', DateTime(2000).add(Duration(days: i)), i),
      ];
      await service.share(
        ownerId: owner,
        vehicle: vehicle,
        shopId: shopId,
        shopName: 'タカヤモーター',
        records: many,
        days: 30,
        includeCosts: true,
      );
      final recs = (await shareDoc())!['records'] as List;
      expect(recs, hasLength(VehicleShareService.maxRecords));
      expect((recs.first as Map)['cost'], 249);
    });

    test('本人が「どこに渡しているか」を一覧できる', () async {
      await service.share(
        ownerId: owner,
        vehicle: vehicle,
        shopId: shopId,
        shopName: 'タカヤモーター',
        records: const [],
        days: 30,
      );
      final list = (await service.activeSharesOf(
        ownerId: owner,
        vehicleId: 'v1',
      ))
          .valueOrNull!;
      expect(list.single.shopName, 'タカヤモーター');
      expect(list.single.expiresAt, now.add(const Duration(days: 30)));
    });

    group('Edge Cases', () {
      test('他人の車は渡せない', () async {
        final r = await service.share(
          ownerId: 'someone-else',
          vehicle: vehicle,
          shopId: shopId,
          shopName: 'x',
          records: const [],
          days: 30,
        );
        expect(r.errorOrNull, isA<PermissionError>());
      });

      test('期間は1〜90日', () async {
        for (final days in [0, -1, 91]) {
          final r = await service.share(
            ownerId: owner,
            vehicle: vehicle,
            shopId: shopId,
            shopName: 'x',
            records: const [],
            days: days,
          );
          expect(r.errorOrNull, isA<ValidationError>(), reason: '$days日');
        }
      });

      test('店を選んでいなければ渡せない', () async {
        final r = await service.share(
          ownerId: owner,
          vehicle: vehicle,
          shopId: '',
          shopName: '',
          records: const [],
          days: 30,
        );
        expect(r.errorOrNull, isA<ValidationError>());
      });

      test('空白だけの連絡先は入れない', () async {
        await service.share(
          ownerId: owner,
          vehicle: vehicle,
          shopId: shopId,
          shopName: 'x',
          records: const [],
          days: 30,
          contactName: '   ',
        );
        expect((await shareDoc())!['contactName'], isNull);
      });
    });
  });

  group('revoke', () {
    test('取り消すと、店の写しも索引も消える', () async {
      await service.share(
        ownerId: owner,
        vehicle: vehicle,
        shopId: shopId,
        shopName: 'タカヤモーター',
        records: const [],
        days: 30,
      );
      await service.revoke(vehicleId: 'v1', shopId: shopId);

      expect(await shareDoc(), isNull);
      final list = (await service.activeSharesOf(
        ownerId: owner,
        vehicleId: 'v1',
      ))
          .valueOrNull!;
      expect(list, isEmpty);
    });
  });

  group('期限', () {
    test('期限が過ぎた写しは、店にも本人の一覧にも出ない', () async {
      await service.share(
        ownerId: owner,
        vehicle: vehicle,
        shopId: shopId,
        shopName: 'タカヤモーター',
        records: const [],
        days: 7,
      );
      final later = VehicleShareService(
        firestore: fs,
        now: () => now.add(const Duration(days: 7)),
      );
      expect((await later.sharesForShop(shopId)).valueOrNull, isEmpty);
      expect(
        (await later.activeSharesOf(ownerId: owner, vehicleId: 'v1'))
            .valueOrNull,
        isEmpty,
      );
    });
  });

  group('店の側', () {
    test('写しから台帳に登録すると、顧客と車両ができ、登録済みの印が付く', () async {
      await service.share(
        ownerId: owner,
        vehicle: vehicle,
        shopId: shopId,
        shopName: 'タカヤモーター',
        records: [record('r1', DateTime(2026, 5, 1), 5500)],
        days: 30,
        includePlate: true,
        contactName: '山田太郎',
      );
      final share = (await service.sharesForShop(shopId)).valueOrNull!.single;
      final ledger = ShopLedgerService(firestore: fs, now: () => now);

      final r = await service.importToLedger(ledger: ledger, share: share);
      final customerId = r.valueOrNull!;

      final c = (await ledger.getCustomer(
        shopId: shopId,
        customerId: customerId,
      ))
          .valueOrNull!;
      expect(c.name, '山田太郎');
      expect(c.vehicleCount, 1);
      expect(c.nextInspectionAt, DateTime(2027, 4, 1));
      // 他店での整備日は、この店の最終来店にしない
      expect(c.lastVisitAt, isNull);
      expect((await shareDoc())!['importedCustomerId'], customerId);
    });

    test('名前が渡されていなければ、推測せず「お名前未共有」で登録する', () async {
      await service.share(
        ownerId: owner,
        vehicle: vehicle,
        shopId: shopId,
        shopName: 'タカヤモーター',
        records: const [],
        days: 30,
      );
      final share = (await service.sharesForShop(shopId)).valueOrNull!.single;
      final ledger = ShopLedgerService(firestore: fs, now: () => now);
      final id = (await service.importToLedger(ledger: ledger, share: share))
          .valueOrNull!;
      final c = (await ledger.getCustomer(shopId: shopId, customerId: id))
          .valueOrNull!;
      expect(c.name, '（お名前未共有）');
    });

    test('開いたら既読が付く', () async {
      await service.share(
        ownerId: owner,
        vehicle: vehicle,
        shopId: shopId,
        shopName: 'タカヤモーター',
        records: const [],
        days: 30,
      );
      await service.markSeen(shopId: shopId, vehicleId: 'v1');
      expect((await shareDoc())!['seenAt'], isNotNull);
    });

    group('Edge Cases', () {
      test('写しが無い店では空', () async {
        expect((await service.sharesForShop('empty')).valueOrNull, isEmpty);
      });

      test('消えた写しに既読を付けても落ちない', () async {
        await service.markSeen(shopId: shopId, vehicleId: 'gone');
      });
    });
  });
}
