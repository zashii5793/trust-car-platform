import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/models/shop_ledger.dart';
import 'package:trust_car_platform/services/ledger_csv_export.dart';
import 'package:trust_car_platform/services/ledger_csv_import.dart';
import 'package:trust_car_platform/services/shop_ledger_service.dart';

/// 台帳の書き出しと、車検案内の宛名（2026-09-29 プロダクト評価 #8・#2）。
///
/// - 全件の書き出しは、**書き出した CSV をそのまま取り込み直して元に戻る**こと
/// - 車検案内は、**同じ満了日の案内を二度出さない**こと
void main() {
  late FakeFirebaseFirestore firestore;
  late ShopLedgerService service;
  final today = DateTime(2026, 9, 27);
  const shopId = 'shop-1';
  const otherShop = 'shop-2';

  setUp(() {
    firestore = FakeFirebaseFirestore();
    service = ShopLedgerService(firestore: firestore, now: () => today);
  });

  Future<LedgerCustomer> addCustomer(
    String name, {
    String shop = shopId,
    String? kana,
    String? phone,
    String? postalCode,
    String? address = '東京都千代田区1-1',
    String? note,
    LedgerCustomerKind kind = LedgerCustomerKind.individual,
  }) async =>
      (await service.createCustomer(
        shopId: shop,
        kind: kind,
        name: name,
        nameKana: kana,
        phone: phone,
        postalCode: postalCode,
        address: address,
        note: note,
      ))
          .valueOrNull!;

  Future<LedgerVehicle> addVehicle(
    LedgerCustomer c, {
    String shop = shopId,
    String model = 'プリウス',
    String? plate,
    DateTime? expiry,
    DateTime? lastVisitAt,
  }) async =>
      (await service.saveVehicle(
        shopId: shop,
        customerId: c.id,
        maker: 'トヨタ',
        model: model,
        plate: plate,
        inspectionExpiry: expiry,
        lastVisitAt: lastVisitAt,
      ))
          .valueOrNull!;

  Future<LedgerExportData> exportOf(String shop) async =>
      (await service.exportAll(shopId: shop)).valueOrNull!;

  /// 書き出した CSV を、取込の画面と同じ手順で取り込む。
  Future<void> reimport(String csv, String shop) async {
    final rows = parseCsv(csv);
    final plan = buildImportPlan(rows.sublist(1), guessColumns(rows.first));
    expect(plan.problems, isEmpty);
    final r = await service.importPlan(shopId: shop, plan: plan);
    expect(r.isSuccess, isTrue);
  }

  /// 比べる項目だけを取り出す（IDや登録日は店が変われば変わってよい）。
  List<String> customerRows(LedgerExportData d) => [
        for (final c in d.customers)
          [
            c.kind.name,
            c.name,
            c.nameKana,
            c.phone,
            c.postalCode,
            c.address,
            c.vehicleCount,
            c.nextInspectionAt,
            c.lastVisitAt,
          ].join('|'),
      ]..sort();

  List<String> vehicleRows(LedgerExportData d) => [
        for (final v in d.vehicles)
          [
            v.customerName,
            v.maker,
            v.model,
            v.plate,
            v.inspectionExpiry,
            v.lastVisitAt,
          ].join('|'),
      ]..sort();

  group('exportAll — 台帳の全件', () {
    test('1ページ（20件）を超えても全員分を返す。他の店の顧客は入らない', () async {
      for (var i = 0; i < 45; i++) {
        final c = await addCustomer('顧客$i');
        if (i.isEven) await addVehicle(c, model: '車$i');
      }
      await addCustomer('よその客', shop: otherShop);

      final d = await exportOf(shopId);
      expect(d.customers, hasLength(45));
      expect(d.vehicles, hasLength(23));
      expect(d.customers.map((c) => c.name), isNot(contains('よその客')));
    });

    group('Edge Cases', () {
      test('顧客のいない店なら空', () async {
        final d = await exportOf('no-such-shop');
        expect(d.customers, isEmpty);
        expect(d.vehicles, isEmpty);
      });
    });
  });

  group('書き出し → 取り込み直し（往復）', () {
    /// 手で登録した顧客・CSV で入れた顧客・車の無い顧客を混ぜた台帳。
    Future<void> seed() async {
      final manual = await addCustomer('山田太郎',
          kana: 'ヤマダタロウ',
          phone: '090-1111-2222',
          postalCode: '100-0001',
          note: '平日は夕方以降');
      await addVehicle(manual,
          plate: '品川300あ1234',
          expiry: DateTime(2026, 11, 5),
          lastVisitAt: DateTime(2026, 5, 1));
      await addVehicle(manual, model: 'アクア');
      await addCustomer('青木花子', kana: 'アオキハナコ');

      final cols =
          guessColumns(['顧客番号', '顧客名', '法人区分', '登録番号', 'メーカー', '車名', '車検満了日']);
      await service.importPlan(
        shopId: shopId,
        plan: buildImportPlan([
          ['A001', 'サンプル運輸', '法人', '品川400さ1', 'トヨタ', 'ハイエース', '2027/1/10'],
          ['A001', 'サンプル運輸', '法人', '品川400さ2', '日産', 'キャラバン', ''],
        ], cols),
      );
    }

    test('別の店に取り込むと、顧客と車両が同じ中身で入る', () async {
      await seed();
      final before = await exportOf(shopId);
      final csv = buildLedgerCsv(
          customers: before.customers, vehicles: before.vehicles);

      await reimport(csv, otherShop);

      final after = await exportOf(otherShop);
      expect(after.customers, hasLength(3));
      expect(after.vehicles, hasLength(4));
      expect(customerRows(after), customerRows(before));
      expect(vehicleRows(after), vehicleRows(before));
    });

    test('同じ店に取り込み直しても、二重にならず中身も変わらない（手で入れた顧客も）', () async {
      await seed();
      final before = await exportOf(shopId);
      final csv = buildLedgerCsv(
          customers: before.customers, vehicles: before.vehicles);

      await reimport(csv, shopId);
      final once = await exportOf(shopId);
      expect(once.customers, hasLength(3));
      expect(once.vehicles, hasLength(4));
      expect(customerRows(once), customerRows(before));
      expect(vehicleRows(once), vehicleRows(before));
      // 取込は手で入れたメモを消さない
      expect(
          once.customers.firstWhere((c) => c.name == '山田太郎').note, '平日は夕方以降');

      // 2回目の往復でも増えない（1回目で顧客番号が書き換わっていない）
      await reimport(
        buildLedgerCsv(customers: once.customers, vehicles: once.vehicles),
        shopId,
      );
      final twice = await exportOf(shopId);
      expect(twice.customers, hasLength(3));
      expect(twice.vehicles, hasLength(4));
    });
  });

  group('inspectionNoticeTargets — 車検案内の宛名', () {
    final to = DateTime(2026, 11, 27);

    Future<InspectionNoticeList> targets({
      bool excludeNoticed = true,
      bool excludeLinked = true,
    }) async =>
        (await service.inspectionNoticeTargets(
          shopId: shopId,
          from: today,
          to: to,
          excludeNoticed: excludeNoticed,
          excludeLinked: excludeLinked,
        ))
            .valueOrNull!;

    test('満了日が期間内（両端を含む）の車だけ、近い順に。住所などは顧客から', () async {
      final c = await addCustomer('山田', postalCode: '100-0001');
      await addVehicle(c, model: '昨日切れた', expiry: DateTime(2026, 9, 26));
      await addVehicle(c, model: '今日', expiry: DateTime(2026, 9, 27));
      await addVehicle(c, model: '最終日', expiry: DateTime(2026, 11, 27));
      await addVehicle(c, model: '翌日', expiry: DateTime(2026, 11, 28));
      await addVehicle(c, model: '満了日なし');

      final r = await targets();
      expect(r.targets.map((t) => t.vehicle.model), ['今日', '最終日']);
      expect(r.targets.first.customer.postalCode, '100-0001');
      expect(r.targets.first.customer.address, '東京都千代田区1-1');
    });

    test('アプリを使っている客は、既定では除く（アプリに案内が届く）', () async {
      final c = await addCustomer('アプリの人');
      await addVehicle(c, expiry: DateTime(2026, 10, 1));
      await firestore
          .doc('shops/$shopId/customers/${c.id}')
          .update({'linkedUserId': 'u1', 'isLinked': true});

      final r = await targets();
      expect(r.targets, isEmpty);
      expect(r.linked, 1);
      expect((await targets(excludeLinked: false)).targets, hasLength(1));
    });

    test('住所の無い客は除き、その台数を返す（はがきが出せない）', () async {
      final c = await addCustomer('住所なし', address: null);
      await addVehicle(c, expiry: DateTime(2026, 10, 1));

      final r = await targets();
      expect(r.targets, isEmpty);
      expect(r.withoutAddress, 1);
    });

    group('Edge Cases', () {
      test('台帳が空なら空', () async {
        final r = await targets();
        expect(r.targets, isEmpty);
        expect(r.withoutAddress, 0);
      });

      test('期間の終わりが始まりより前なら空', () async {
        final c = await addCustomer('山田');
        await addVehicle(c, expiry: DateTime(2026, 10, 1));
        final r = (await service.inspectionNoticeTargets(
          shopId: shopId,
          from: to,
          to: today,
        ))
            .valueOrNull!;
        expect(r.targets, isEmpty);
      });

      test('他の店の車は入らない', () async {
        final c = await addCustomer('よそ', shop: otherShop);
        await addVehicle(c, shop: otherShop, expiry: DateTime(2026, 10, 1));
        expect((await targets()).targets, isEmpty);
      });
    });
  });

  group('appInspectionNoticeTargets — アプリへの車検案内', () {
    final to = DateTime(2026, 11, 27);

    Future<InspectionNoticeList> targets() async =>
        (await service.appInspectionNoticeTargets(
          shopId: shopId,
          from: today,
          to: to,
        ))
            .valueOrNull!;

    Future<void> link(LedgerCustomer c, String uid) => firestore
        .doc('shops/$shopId/customers/${c.id}')
        .update({'linkedUserId': uid, 'isLinked': true});

    test('期間内で、アプリとつながっている客の車だけ。住所は要らない', () async {
      final app = await addCustomer('アプリの人', address: null);
      await link(app, 'u1');
      await addVehicle(app, model: '近い', expiry: DateTime(2026, 10, 1));
      await addVehicle(app, model: '遠い', expiry: DateTime(2027, 3, 1));
      final paper = await addCustomer('はがきの人');
      await addVehicle(paper, model: 'はがき', expiry: DateTime(2026, 10, 2));

      final r = await targets();
      expect(r.targets.map((t) => t.vehicle.model), ['近い']);
      expect(r.targets.single.customer.linkedUserId, 'u1');
      expect(r.notLinked, 1);
    });

    test('はがきで案内済みの車は送らない（同じ「案内した日」を見る）', () async {
      final c = await addCustomer('アプリの人');
      await link(c, 'u1');
      final v = await addVehicle(c, expiry: DateTime(2026, 10, 1));
      await service.markInspectionNoticed(shopId: shopId, vehicles: [v]);

      final r = await targets();
      expect(r.targets, isEmpty);
      expect(r.alreadyNoticed, 1);
    });

    group('Edge Cases', () {
      test('台帳が空なら空', () async {
        final r = await targets();
        expect(r.targets, isEmpty);
        expect(r.notLinked, 0);
      });

      test('期間の終わりが始まりより前なら空', () async {
        final c = await addCustomer('アプリの人');
        await link(c, 'u1');
        await addVehicle(c, expiry: DateTime(2026, 10, 1));
        final r = (await service.appInspectionNoticeTargets(
          shopId: shopId,
          from: to,
          to: today,
        ))
            .valueOrNull!;
        expect(r.targets, isEmpty);
      });

      test('他の店の車は入らない', () async {
        final c = await addCustomer('よそ', shop: otherShop);
        await firestore
            .doc('shops/$otherShop/customers/${c.id}')
            .update({'linkedUserId': 'u1', 'isLinked': true});
        await addVehicle(c, shop: otherShop, expiry: DateTime(2026, 10, 1));
        expect((await targets()).targets, isEmpty);
      });
    });
  });

  group('markInspectionNoticed — 案内した日の記録', () {
    Future<InspectionNoticeList> targets({bool excludeNoticed = true}) async =>
        (await service.inspectionNoticeTargets(
          shopId: shopId,
          from: today,
          to: DateTime(2026, 12, 31),
          excludeNoticed: excludeNoticed,
        ))
            .valueOrNull!;

    test('記録した車は、同じ満了日のあいだは次の書き出しに出ない', () async {
      final c = await addCustomer('山田');
      final v = await addVehicle(c, expiry: DateTime(2026, 10, 1));

      final r =
          await service.markInspectionNoticed(shopId: shopId, vehicles: [v]);
      expect(r.valueOrNull, 1);

      final doc =
          (await firestore.doc('shops/$shopId/customer_vehicles/${v.id}').get())
              .data()!;
      final saved = LedgerVehicle.fromMap(v.id, doc);
      expect(saved.inspectionNoticeAt, today);
      expect(saved.inspectionNoticeExpiry, DateTime(2026, 10, 1));
      expect(saved.isNoticedForCurrentExpiry, isTrue);

      final after = await targets();
      expect(after.targets, isEmpty);
      expect(after.alreadyNoticed, 1);
      // 除かない指定なら出る（出し直したいとき）
      expect((await targets(excludeNoticed: false)).targets, hasLength(1));
    });

    test('車両を直しても、名簿を取り込み直しても、案内した日は消えない', () async {
      final cols = guessColumns(['顧客番号', '顧客名', '住所', '登録番号', '車名', '車検満了日']);
      final rows = [
        ['A1', '山田', '東京都', '品川300あ1', 'プリウス', '2026/10/1'],
      ];
      await service.importPlan(
          shopId: shopId, plan: buildImportPlan(rows, cols));
      final v = (await targets()).targets.single.vehicle;
      await service.markInspectionNoticed(shopId: shopId, vehicles: [v]);

      await service.saveVehicle(
        shopId: shopId,
        customerId: v.customerId,
        vehicleId: v.id,
        maker: v.maker,
        model: v.model,
        plate: v.plate,
        inspectionExpiry: v.inspectionExpiry,
        lastMileage: 50000,
      );
      await service.importPlan(
          shopId: shopId, plan: buildImportPlan(rows, cols));

      expect((await targets()).targets, isEmpty);
    });

    test('車検を通して満了日が進むと、次の満了日の案内の対象に戻る', () async {
      final c = await addCustomer('山田');
      final v = await addVehicle(c, expiry: DateTime(2026, 10, 1));
      await service.markInspectionNoticed(shopId: shopId, vehicles: [v]);

      await service.saveVehicle(
        shopId: shopId,
        customerId: c.id,
        vehicleId: v.id,
        maker: v.maker,
        model: v.model,
        inspectionExpiry: DateTime(2026, 12, 1),
      );

      final r = await targets();
      expect(r.targets, hasLength(1));
      // 前に案内した日は残っている（いつ案内したかは消さない）
      expect(r.targets.single.vehicle.inspectionNoticeAt, today);
    });

    group('Edge Cases', () {
      test('空のリストなら何もしない', () async {
        final r =
            await service.markInspectionNoticed(shopId: shopId, vehicles: []);
        expect(r.valueOrNull, 0);
      });

      test('消された車があれば失敗を返す', () async {
        final c = await addCustomer('山田');
        final v = await addVehicle(c, expiry: DateTime(2026, 10, 1));
        await service.deleteVehicle(shopId: shopId, vehicle: v);

        final r =
            await service.markInspectionNoticed(shopId: shopId, vehicles: [v]);
        expect(r.isFailure, isTrue);
      });

      test('満了日の無い車は、満了日なしとして記録する', () async {
        final c = await addCustomer('山田');
        final v = await addVehicle(c);
        final r =
            await service.markInspectionNoticed(shopId: shopId, vehicles: [v]);
        expect(r.valueOrNull, 1);
        final saved = LedgerVehicle.fromMap(
            v.id,
            (await firestore
                    .doc('shops/$shopId/customer_vehicles/${v.id}')
                    .get())
                .data()!);
        expect(saved.inspectionNoticeAt, today);
        expect(saved.inspectionNoticeExpiry, isNull);
        expect(saved.isNoticedForCurrentExpiry, isFalse);
      });
    });
  });
}
