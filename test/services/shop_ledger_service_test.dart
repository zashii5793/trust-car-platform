import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/core/error/app_error.dart';
import 'package:trust_car_platform/models/shop_ledger.dart';
import 'package:trust_car_platform/services/ledger_csv_import.dart';
import 'package:trust_car_platform/services/shop_ledger_service.dart';

/// 店の顧客台帳。
///
/// **何千人の顧客を持つ店で使う。** 全件読みやページングの取りこぼしは、
/// 少ない件数のテストでは見えないので、ページ境界を必ず跨がせて確かめる。
void main() {
  late FakeFirebaseFirestore firestore;
  late ShopLedgerService service;
  final today = DateTime(2026, 9, 27);
  const shopId = 'shop-1';

  setUp(() {
    firestore = FakeFirebaseFirestore();
    service = ShopLedgerService(firestore: firestore, now: () => today);
  });

  Future<LedgerCustomer> addCustomer(
    String name, {
    String? kana,
    LedgerCustomerKind kind = LedgerCustomerKind.individual,
    String? externalId,
    String shop = shopId,
  }) async {
    final r = await service.createCustomer(
      shopId: shop,
      kind: kind,
      name: name,
      nameKana: kana,
      externalId: externalId,
    );
    return r.valueOrNull!;
  }

  group('createCustomer', () {
    test('台帳に登録され、検索キーが入る', () async {
      final c = await addCustomer('山田太郎', kana: 'ヤマダタロウ');
      final doc =
          await firestore.collection('shops/$shopId/customers').doc(c.id).get();
      expect(doc.exists, isTrue);
      expect(doc.data()!['searchKey'], 'やまだたろう');
      expect(doc.data()!['isLinked'], isFalse);
    });

    test('顧客番号が同じなら、やり直しても1件のまま', () async {
      await addCustomer('山田太郎', externalId: 'A-001');
      await addCustomer('山田太郎（更新）', externalId: 'A-001');
      final snap = await firestore.collection('shops/$shopId/customers').get();
      expect(snap.docs, hasLength(1));
      expect(snap.docs.single.data()['name'], '山田太郎（更新）');
    });

    group('Edge Cases', () {
      test('名前が空なら登録しない', () async {
        final r = await service.createCustomer(
          shopId: shopId,
          kind: LedgerCustomerKind.individual,
          name: '   ',
        );
        expect(r.isFailure, isTrue);
        expect(r.errorOrNull, isA<ValidationError>());
      });

      test('名前が101文字なら登録しない', () async {
        final r = await service.createCustomer(
          shopId: shopId,
          kind: LedgerCustomerKind.individual,
          name: 'あ' * 101,
        );
        expect(r.isFailure, isTrue);
      });

      test('顧客番号の / はIDに使わない', () {
        expect(ShopLedgerService.idForExternal('c', 'A/01 2'), 'c_A_01_2');
      });
    });
  });

  group('listCustomers — ページング', () {
    test('45件を20件ずつ読むと、取りこぼし・重複なく3ページで終わる', () async {
      for (var i = 0; i < 45; i++) {
        // フリガナ順に並ぶよう、番号をゼロ埋めする
        await addCustomer('顧客$i', kana: 'こきゃく${i.toString().padLeft(2, '0')}');
      }

      final seen = <String>[];
      Object? cursor;
      var pages = 0;
      var hasMore = true;
      while (hasMore) {
        final r = await service.listCustomers(shopId: shopId, cursor: cursor);
        final page = r.valueOrNull!;
        seen.addAll(page.items.map((c) => c.id));
        cursor = page.cursor;
        hasMore = page.hasMore;
        pages++;
      }

      expect(pages, 3);
      expect(seen, hasLength(45));
      expect(seen.toSet(), hasLength(45));
    });

    test('1ページ目は20件で、続きがあると分かる', () async {
      for (var i = 0; i < 21; i++) {
        await addCustomer('顧客$i');
      }
      final page = (await service.listCustomers(shopId: shopId)).valueOrNull!;
      expect(page.items, hasLength(20));
      expect(page.hasMore, isTrue);
    });

    test('ちょうど20件なら続きは無い', () async {
      for (var i = 0; i < 20; i++) {
        await addCustomer('顧客$i');
      }
      final page = (await service.listCustomers(shopId: shopId)).valueOrNull!;
      expect(page.items, hasLength(20));
      expect(page.hasMore, isFalse);
    });

    test('フリガナ順に並ぶ', () async {
      await addCustomer('渡辺', kana: 'ワタナベ');
      await addCustomer('青木', kana: 'アオキ');
      await addCustomer('佐藤', kana: 'サトウ');
      final page = (await service.listCustomers(shopId: shopId)).valueOrNull!;
      expect(page.items.map((c) => c.name), ['青木', '佐藤', '渡辺']);
    });

    test('他の店の顧客は混ざらない', () async {
      await addCustomer('自店の客');
      await addCustomer('他店の客', shop: 'shop-2');
      final page = (await service.listCustomers(shopId: shopId)).valueOrNull!;
      expect(page.items.map((c) => c.name), ['自店の客']);
    });

    group('Edge Cases', () {
      test('顧客がいなければ空で、続きも無い', () async {
        final page = (await service.listCustomers(shopId: shopId)).valueOrNull!;
        expect(page.items, isEmpty);
        expect(page.hasMore, isFalse);
      });
    });
  });

  group('listCustomers — 検索', () {
    setUp(() async {
      await addCustomer('山田太郎', kana: 'ヤマダタロウ');
      await addCustomer('山本花子', kana: 'ヤマモトハナコ');
      await addCustomer('田中一郎', kana: 'タナカイチロウ');
    });

    test('フリガナの前方一致で引ける（カタカナで入れても、ひらがなでも）', () async {
      final a = (await service.listCustomers(shopId: shopId, search: 'ヤマ'))
          .valueOrNull!;
      final b = (await service.listCustomers(shopId: shopId, search: 'やま'))
          .valueOrNull!;
      expect(a.items.map((c) => c.name), ['山田太郎', '山本花子']);
      expect(b.items.map((c) => c.name), a.items.map((c) => c.name));
    });

    test('半角カナでも引ける', () async {
      final r = (await service.listCustomers(shopId: shopId, search: 'ﾀﾅｶ'))
          .valueOrNull!;
      expect(r.items.map((c) => c.name), ['田中一郎']);
    });

    group('Edge Cases', () {
      test('空白だけの検索は、検索しないのと同じ', () async {
        final r = (await service.listCustomers(shopId: shopId, search: '  '))
            .valueOrNull!;
        expect(r.items, hasLength(3));
      });

      test('当たらなければ空', () async {
        final r = (await service.listCustomers(shopId: shopId, search: 'ん'))
            .valueOrNull!;
        expect(r.items, isEmpty);
      });
    });
  });

  group('counts', () {
    test('総数・個人・法人・アプリ利用中を数える', () async {
      await addCustomer('個人A');
      await addCustomer('個人B');
      await addCustomer('法人A', kind: LedgerCustomerKind.corporate);
      await firestore
          .collection('shops/$shopId/customers')
          .doc('linked')
          .set({'name': 'アプリの人', 'kind': 'individual', 'isLinked': true});

      final c = (await service.counts(shopId)).valueOrNull!;
      expect(c.total, 4);
      expect(c.individual, 3);
      expect(c.corporate, 1);
      expect(c.linked, 1);
    });

    group('Edge Cases', () {
      test('顧客がいなければ全部0', () async {
        final c = (await service.counts(shopId)).valueOrNull!;
        expect(c.total, 0);
        expect(c.linked, 0);
      });
    });
  });

  group('saveVehicle と顧客の要約値', () {
    test('車両を足すと、台数と次の車検が顧客に入る', () async {
      final c = await addCustomer('法人A', kind: LedgerCustomerKind.corporate);
      await service.saveVehicle(
        shopId: shopId,
        customerId: c.id,
        maker: 'トヨタ',
        model: 'ハイエース',
        plate: '品川 400 さ 12-34',
        inspectionExpiry: DateTime(2027, 2, 1),
      );
      await service.saveVehicle(
        shopId: shopId,
        customerId: c.id,
        maker: '日産',
        model: 'キャラバン',
        inspectionExpiry: DateTime(2026, 11, 10),
        lastVisitAt: DateTime(2026, 5, 1),
      );

      final after =
          (await service.getCustomer(shopId: shopId, customerId: c.id))
              .valueOrNull!;
      expect(after.vehicleCount, 2);
      expect(after.nextInspectionAt, DateTime(2026, 11, 10));
      expect(after.lastVisitAt, DateTime(2026, 5, 1));
    });

    test('車両を消すと、要約値も作り直される', () async {
      final c = await addCustomer('山田');
      final v = (await service.saveVehicle(
        shopId: shopId,
        customerId: c.id,
        maker: 'MINI',
        model: 'クーパー',
        inspectionExpiry: DateTime(2026, 12, 1),
      ))
          .valueOrNull!;
      await service.deleteVehicle(shopId: shopId, vehicle: v);

      final after =
          (await service.getCustomer(shopId: shopId, customerId: c.id))
              .valueOrNull!;
      expect(after.vehicleCount, 0);
      expect(after.nextInspectionAt, isNull);
    });

    test('更新しても登録日は変わらない', () async {
      final c = await addCustomer('山田');
      final v = (await service.saveVehicle(
        shopId: shopId,
        customerId: c.id,
        maker: 'MINI',
        model: 'クーパー',
      ))
          .valueOrNull!;
      final later = ShopLedgerService(
        firestore: firestore,
        now: () => DateTime(2027, 1, 1),
      );
      final v2 = (await later.saveVehicle(
        shopId: shopId,
        customerId: c.id,
        vehicleId: v.id,
        maker: 'MINI',
        model: 'クーパーS',
      ))
          .valueOrNull!;
      expect(v2.createdAt, today);
      expect(v2.updatedAt, DateTime(2027, 1, 1));
    });

    group('Edge Cases', () {
      test('存在しない顧客には車両を足せない', () async {
        final r = await service.saveVehicle(
          shopId: shopId,
          customerId: 'nope',
          maker: 'トヨタ',
          model: 'プリウス',
        );
        expect(r.errorOrNull, isA<NotFoundError>());
      });

      test('メーカーか車種が空なら足せない', () async {
        final c = await addCustomer('山田');
        final r = await service.saveVehicle(
          shopId: shopId,
          customerId: c.id,
          maker: 'トヨタ',
          model: ' ',
        );
        expect(r.errorOrNull, isA<ValidationError>());
      });
    });
  });

  group('listVehiclesByInspection', () {
    test('顧客をまたいで、満了日の近い順に並ぶ。切れた車検は出ない', () async {
      final a = await addCustomer('A');
      final b = await addCustomer('B');
      Future<void> add(String cid, String model, DateTime exp) =>
          service.saveVehicle(
            shopId: shopId,
            customerId: cid,
            maker: 'トヨタ',
            model: model,
            inspectionExpiry: exp,
          );
      await add(a.id, '遠い', DateTime(2027, 5, 1));
      await add(b.id, '近い', DateTime(2026, 10, 1));
      await add(a.id, '切れた', DateTime(2026, 9, 1));

      final page = (await service.listVehiclesByInspection(
        shopId: shopId,
        from: today,
      ))
          .valueOrNull!;
      expect(page.items.map((v) => v.model), ['近い', '遠い']);
      expect(page.items.first.customerName, 'B');
    });
  });

  group('findVehiclesByPlateNumber', () {
    test('末尾4桁で引ける（書き方が違っても）', () async {
      final c = await addCustomer('山田');
      await service.saveVehicle(
        shopId: shopId,
        customerId: c.id,
        maker: 'トヨタ',
        model: 'プリウス',
        plate: '品川 300 あ 12-34',
      );
      final r = (await service.findVehiclesByPlateNumber(
        shopId: shopId,
        number: '１２３４',
      ))
          .valueOrNull!;
      expect(r.map((v) => v.model), ['プリウス']);
    });

    group('Edge Cases', () {
      test('数字の無い入力では何も返さない', () async {
        final r = (await service.findVehiclesByPlateNumber(
          shopId: shopId,
          number: 'あ',
        ))
            .valueOrNull!;
        expect(r, isEmpty);
      });
    });
  });

  group('listLapsedCustomers', () {
    test('基準日より前に最後に来た人を、古い順に。来店記録の無い人は出さない', () async {
      final old = await addCustomer('昔の客');
      final older = await addCustomer('もっと昔の客');
      final recent = await addCustomer('最近の客');
      await addCustomer('来店記録なし');
      Future<void> visit(String cid, DateTime at) => service.saveVehicle(
            shopId: shopId,
            customerId: cid,
            maker: 'ホンダ',
            model: 'N-BOX',
            lastVisitAt: at,
          );
      await visit(old.id, DateTime(2025, 3, 1));
      await visit(older.id, DateTime(2024, 1, 1));
      await visit(recent.id, DateTime(2026, 8, 1));

      final page = (await service.listLapsedCustomers(
        shopId: shopId,
        since: DateTime(2025, 9, 27),
      ))
          .valueOrNull!;
      expect(page.items.map((c) => c.name), ['もっと昔の客', '昔の客']);
    });
  });

  group('updateCustomer', () {
    test('名前を変えると、車両に写した名前も揃う', () async {
      final c = await addCustomer('旧社名', kind: LedgerCustomerKind.corporate);
      await service.saveVehicle(
        shopId: shopId,
        customerId: c.id,
        maker: 'トヨタ',
        model: 'ハイエース',
      );
      await service.updateCustomer(
        shopId: shopId,
        customer: c.copyWith(name: '新社名'),
      );
      final v = (await service.vehiclesOf(shopId: shopId, customerId: c.id))
          .valueOrNull!;
      expect(v.single.customerName, '新社名');
    });

    test('更新しても、車両から計算した値は消えない', () async {
      final c = await addCustomer('山田');
      await service.saveVehicle(
        shopId: shopId,
        customerId: c.id,
        maker: 'トヨタ',
        model: 'プリウス',
        inspectionExpiry: DateTime(2027, 1, 1),
      );
      // 画面が持っている古い顧客（台数0）で更新しても、台数は1のまま
      await service.updateCustomer(
        shopId: shopId,
        customer: c.copyWith(phone: '090-0000-0000'),
      );
      final after =
          (await service.getCustomer(shopId: shopId, customerId: c.id))
              .valueOrNull!;
      expect(after.vehicleCount, 1);
      expect(after.phone, '090-0000-0000');
    });

    group('Edge Cases', () {
      test('名前を空にはできない', () async {
        final c = await addCustomer('山田');
        final r = await service.updateCustomer(
          shopId: shopId,
          customer: c.copyWith(name: ''),
        );
        expect(r.errorOrNull, isA<ValidationError>());
      });
    });
  });

  group('deleteCustomer', () {
    test('顧客を消すと、その顧客の車両も消える。他の顧客の車両は残る', () async {
      final a = await addCustomer('A');
      final b = await addCustomer('B');
      await service.saveVehicle(
          shopId: shopId, customerId: a.id, maker: 'x', model: 'a1');
      await service.saveVehicle(
          shopId: shopId, customerId: a.id, maker: 'x', model: 'a2');
      await service.saveVehicle(
          shopId: shopId, customerId: b.id, maker: 'x', model: 'b1');

      await service.deleteCustomer(shopId: shopId, customerId: a.id);

      final vehicles =
          await firestore.collection('shops/$shopId/customer_vehicles').get();
      expect(vehicles.docs.map((d) => d.data()['model']), ['b1']);
      final got = await service.getCustomer(shopId: shopId, customerId: a.id);
      expect(got.errorOrNull, isA<NotFoundError>());
    });

    group('Edge Cases', () {
      test('存在しない顧客を消しても失敗しない', () async {
        final r =
            await service.deleteCustomer(shopId: shopId, customerId: 'nope');
        expect(r.isSuccess, isTrue);
      });
    });
  });

  group('importPlan — CSV 取込', () {
    const header = [
      '顧客番号',
      '顧客名',
      'フリガナ',
      '登録番号',
      'メーカー',
      '車名',
      '車検満了日',
      '最終入庫日'
    ];
    final cols = guessColumns(header);

    LedgerImportPlan plan(List<List<String>> rows) =>
        buildImportPlan(rows, cols);

    test('顧客と車両が台帳に入り、要約値も計算される', () async {
      final r = await service.importPlan(
        shopId: shopId,
        plan: plan([
          [
            'C001',
            'サンプル運輸',
            'サンプルウンユ',
            '品川400さ1',
            'トヨタ',
            'ハイエース',
            '2027/1/10',
            '2026/3/1'
          ],
          [
            'C001',
            'サンプル運輸',
            'サンプルウンユ',
            '品川400さ2',
            'トヨタ',
            'ハイエース',
            '2026/11/5',
            '2026/6/1'
          ],
        ]),
      );
      final result = r.valueOrNull!;
      expect(result.createdCustomers, 1);
      expect(result.vehicles, 2);

      final page = (await service.listCustomers(shopId: shopId)).valueOrNull!;
      final c = page.items.single;
      expect(c.vehicleCount, 2);
      expect(c.nextInspectionAt, DateTime(2026, 11, 5));
      expect(c.lastVisitAt, DateTime(2026, 6, 1));
      expect(c.source, LedgerSource.csv);
    });

    test('同じ CSV を2回取り込んでも、二重にならない', () async {
      final rows = [
        ['C001', '山田', 'ヤマダ', '品川300あ1234', 'MINI', 'クーパー', '', ''],
      ];
      await service.importPlan(shopId: shopId, plan: plan(rows));
      final second =
          (await service.importPlan(shopId: shopId, plan: plan(rows)))
              .valueOrNull!;
      expect(second.createdCustomers, 0);
      expect(second.updatedCustomers, 1);

      final customers =
          await firestore.collection('shops/$shopId/customers').get();
      final vehicles =
          await firestore.collection('shops/$shopId/customer_vehicles').get();
      expect(customers.docs, hasLength(1));
      expect(vehicles.docs, hasLength(1));
    });

    test('取り直しても、店が手で入れたメモ・アプリとのつながり・登録日は消えない', () async {
      final rows = [
        ['C001', '山田', 'ヤマダ', '', 'MINI', 'クーパー', '', ''],
      ];
      await service.importPlan(shopId: shopId, plan: plan(rows));
      final id = ShopLedgerService.idForExternal('c', 'C001');
      await firestore.doc('shops/$shopId/customers/$id').update({
        'note': '奥様が窓口',
        'linkedUserId': 'app-user-1',
        'isLinked': true,
      });

      final later = ShopLedgerService(
        firestore: firestore,
        now: () => DateTime(2027, 1, 1),
      );
      await later.importPlan(shopId: shopId, plan: plan(rows));

      final c = (await service.getCustomer(shopId: shopId, customerId: id))
          .valueOrNull!;
      expect(c.note, '奥様が窓口');
      expect(c.linkedUserId, 'app-user-1');
      expect(c.createdAt, today);
      expect(c.updatedAt, DateTime(2027, 1, 1));
    });

    test('取込の前から手で足してあった車両は残り、台数に数えられる', () async {
      await service.importPlan(
        shopId: shopId,
        plan: plan([
          ['C001', '山田', 'ヤマダ', '品川300あ1', 'MINI', 'クーパー', '', ''],
        ]),
      );
      final id = ShopLedgerService.idForExternal('c', 'C001');
      await service.saveVehicle(
        shopId: shopId,
        customerId: id,
        maker: 'ホンダ',
        model: 'スーパーカブ',
      );
      await service.importPlan(
        shopId: shopId,
        plan: plan([
          ['C001', '山田', 'ヤマダ', '品川300あ1', 'MINI', 'クーパー', '', ''],
        ]),
      );
      final c = (await service.getCustomer(shopId: shopId, customerId: id))
          .valueOrNull!;
      expect(c.vehicleCount, 2);
    });

    test('車が別の顧客に移ったら、移る前の顧客の台数も減る', () async {
      await service.importPlan(
        shopId: shopId,
        plan: plan([
          ['C001', '父', 'チチ', '品川300あ1', 'トヨタ', 'プリウス', '', ''],
        ]),
      );
      await service.importPlan(
        shopId: shopId,
        plan: plan([
          ['C002', '子', 'コ', '品川300あ1', 'トヨタ', 'プリウス', '', ''],
        ]),
      );
      final father = (await service.getCustomer(
        shopId: shopId,
        customerId: ShopLedgerService.idForExternal('c', 'C001'),
      ))
          .valueOrNull!;
      final child = (await service.getCustomer(
        shopId: shopId,
        customerId: ShopLedgerService.idForExternal('c', 'C002'),
      ))
          .valueOrNull!;
      expect(father.vehicleCount, 0);
      expect(child.vehicleCount, 1);
    });

    test('1バッチ（400件）を超える取込でも全部入り、進み具合が届く', () async {
      final rows = [
        for (var i = 0; i < 450; i++)
          ['C$i', '顧客$i', 'コキャク', '', '', '', '', ''],
      ];
      final progress = <int>[];
      final r = await service.importPlan(
        shopId: shopId,
        plan: plan(rows),
        onProgress: (done, total) => progress.add(done),
      );
      expect(r.valueOrNull!.createdCustomers, 450);
      final counts = (await service.counts(shopId)).valueOrNull!;
      expect(counts.total, 450);
      expect(progress.first, 0);
      expect(progress.last, 450);
    });

    group('Edge Cases', () {
      test('空の計画なら何もしない', () async {
        final r = await service.importPlan(
          shopId: shopId,
          plan: plan(const []),
        );
        expect(r.valueOrNull!.createdCustomers, 0);
      });
    });
  });
}
