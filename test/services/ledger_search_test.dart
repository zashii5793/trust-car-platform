import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/models/shop_ledger.dart';
import 'package:trust_car_platform/services/ledger_csv_import.dart';
import 'package:trust_car_platform/services/shop_ledger_service.dart';

/// 顧客台帳の検索（2026-10-08 使用感テスト #3・#4）。
///
/// 電話で聞いた名前を漢字で入れる・名だけ分かる・ナンバーは末尾2桁だけ
/// 覚えている、で見つからず「いません」と出て、すぐ下の「新しい顧客として
/// 追加」から二重に登録してしまう。
void main() {
  late FakeFirebaseFirestore fs;
  late ShopLedgerService service;
  final today = DateTime(2026, 10, 9);
  const shop = 's1';

  setUp(() {
    fs = FakeFirebaseFirestore();
    service = ShopLedgerService(firestore: fs, now: () => today);
  });

  Future<LedgerCustomer> add(String name,
      {String? kana, String? phone, String? contact}) async {
    return (await service.createCustomer(
      shopId: shop,
      kind: LedgerCustomerKind.individual,
      name: name,
      nameKana: kana,
      phone: phone,
      contactPerson: contact,
    ))
        .valueOrNull!;
  }

  Future<List<String>> search(String q) async =>
      (await service.listCustomers(shopId: shop, search: q))
          .valueOrNull!
          .items
          .map((c) => c.name)
          .toList();

  group('顧客の検索', () {
    setUp(() async {
      await add('青木 昭', kana: 'アオキ アキラ');
      await add('青木 和也', kana: 'アオキ カズヤ', phone: '086-123-4567');
      await add('青木 節子', kana: 'アオキ セツコ');
      await add('山田 和也', kana: 'ヤマダ カズヤ');
      await add('青山 一郎', kana: 'アオヤマ イチロウ');
    });

    test('漢字の姓で、その姓の人が全員出る（フリガナ順）', () async {
      expect(await search('青木'), ['青木 昭', '青木 和也', '青木 節子']);
    });

    test('漢字の名だけでも出る', () async {
      expect(await search('和也'), ['青木 和也', '山田 和也']);
    });

    test('名のフリガナだけでも出る', () async {
      expect(await search('カズヤ'), ['青木 和也', '山田 和也']);
    });

    test('姓名を続けたフリガナ（前方一致）は今まで通り', () async {
      expect(await search('あおきか'), ['青木 和也']);
      expect(await search('アオ'), hasLength(4));
    });

    test('電話番号（の先頭）でも出る', () async {
      expect(await search('086-123'), ['青木 和也']);
      expect(await search('0861234567'), ['青木 和也']);
    });

    test('いま登録した顧客が、漢字の名前ですぐ出る', () async {
      await add('検証 一郎', kana: 'ケンショウ イチロウ');
      expect(await search('検証'), ['検証 一郎']);
    });

    test('名簿（CSV）から入れた顧客も漢字で出る', () async {
      await service.importPlan(
        shopId: shop,
        plan: buildImportPlan([
          ['C1', '吉備 太郎', 'キビ タロウ', '086-999-0000'],
        ], guessColumns(['顧客番号', '顧客名', 'フリガナ', '電話番号'])),
      );
      expect(await search('吉備'), ['吉備 太郎']);
      expect(await search('タロウ'), ['吉備 太郎']);
      expect(await search('0869990'), ['吉備 太郎']);
    });

    group('Edge Cases', () {
      test('上限より長い入力でも、当たる人だけを返す', () async {
        await add('あ' * 30, kana: null);
        await add('${'あ' * 25}い', kana: null);
        expect(await search('あ' * 26), ['あ' * 30]);
      });

      test('名前を変えたら、新しい名前で出て古い名前では出ない', () async {
        final c = (await service.listCustomers(shopId: shop, search: '青山'))
            .valueOrNull!
            .items
            .single;
        await service.updateCustomer(
          shopId: shop,
          customer: c.copyWith(name: '緑川 一郎', nameKana: 'ミドリカワ イチロウ'),
        );
        expect(await search('緑川'), ['緑川 一郎']);
        expect(await search('青山'), isEmpty);
      });

      test('当たらなければ空', () async {
        expect(await search('ん'), isEmpty);
      });
    });
  });

  group('よく似た顧客（見つからないとき）', () {
    setUp(() async {
      await add('青木 昭', kana: 'アオキ アキラ');
      await add('青木 和也', kana: 'アオキ カズヤ');
    });

    test('入れた言葉の先頭を短くして、近い人を出す', () async {
      final r = (await service.similarCustomers(shopId: shop, search: '青木和男'))
          .valueOrNull!;
      expect(r.map((c) => c.name), ['青木 和也']);
      final r2 =
          (await service.similarCustomers(shopId: shop, search: 'アオキハナコ'))
              .valueOrNull!;
      expect(r2.map((c) => c.name), ['青木 昭', '青木 和也']);
    });

    group('Edge Cases', () {
      test('空・1文字では探さない（全員が似ていることになる）', () async {
        expect(
            (await service.similarCustomers(shopId: shop, search: ''))
                .valueOrNull,
            isEmpty);
        expect(
            (await service.similarCustomers(shopId: shop, search: 'ア'))
                .valueOrNull,
            isEmpty);
      });

      test('最初の1文字すら合わなければ空', () async {
        expect(
            (await service.similarCustomers(shopId: shop, search: 'んんん'))
                .valueOrNull,
            isEmpty);
      });
    });
  });

  group('ナンバー末尾（2〜4桁）', () {
    late LedgerCustomer c;
    setUp(() async {
      c = await add('山田 太郎', kana: 'ヤマダ タロウ');
      for (final plate in [
        '岡山 300 あ 63-35',
        '岡山 500 さ 12-35',
        '倉敷 300 た 63-36',
        '岡山 480 え ・・・5',
      ]) {
        await service.saveVehicle(
          shopId: shop,
          customerId: c.id,
          maker: 'トヨタ',
          model: plate,
          plate: plate,
        );
      }
    });

    Future<List<String>> plates(String q) async =>
        ((await service.findVehiclesByPlateNumber(shopId: shop, number: q))
            .valueOrNull!
            .map((v) => v.plate!)
            .toList())
          ..sort();

    test('末尾2桁で、その2桁で終わる車が全部出る', () async {
      expect(await plates('35'), ['岡山 300 あ 63-35', '岡山 500 さ 12-35']);
    });

    test('末尾3桁・4桁でも出る（区切りや全角があっても）', () async {
      expect(await plates('335'), ['岡山 300 あ 63-35']);
      expect(await plates('63-35'), ['岡山 300 あ 63-35']);
      expect(await plates('６３３５'), ['岡山 300 あ 63-35']);
    });

    group('Edge Cases', () {
      test('1桁は、番号がその1桁の車だけ（末尾1桁では探さない）', () async {
        expect(await plates('5'), ['岡山 480 え ・・・5']);
      });

      test('数字の無い入力では何も返さない', () async {
        expect(await plates('あ'), isEmpty);
      });

      test('件数の上限を指定できる', () async {
        final r = (await service.findVehiclesByPlateNumber(
                shopId: shop, number: '35', limit: 1))
            .valueOrNull!;
        expect(r, hasLength(1));
      });
    });
  });

  group('既存データの移行（ensureSearchFields）', () {
    Future<void> legacyCustomer(String id, String name, String kana) =>
        fs.collection('shops/$shop/customers').doc(id).set({
          'kind': 'individual',
          'name': name,
          'nameKana': kana,
          'searchKey': LedgerSearch.nameKey(kana),
          'isLinked': false,
          'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
          'updatedAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
        });
    Future<void> legacyVehicle(String id, String plate) =>
        fs.collection('shops/$shop/customer_vehicles').doc(id).set({
          'customerId': 'c_old',
          'customerName': '青木 昭',
          'maker': 'トヨタ',
          'model': 'プリウス',
          'plate': plate,
          'plateKey': LedgerSearch.plateKey(plate),
          'plateNumber': LedgerSearch.plateNumber(plate),
          'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
          'updatedAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
        });

    test('検索用の項目の無い顧客・車に書き足し、漢字・2桁で引けるようにする', () async {
      await legacyCustomer('c_old', '青木 昭', 'アオキ アキラ');
      await legacyVehicle('v_old', '岡山 300 あ 63-35');
      expect(await search('青木'), isEmpty);

      final r = (await service.ensureSearchFields(shop)).valueOrNull!;
      expect(r, 2);
      expect(await search('青木'), ['青木 昭']);
      expect(
          (await service.findVehiclesByPlateNumber(shopId: shop, number: '35'))
              .valueOrNull!
              .single
              .id,
          'v_old');
    });

    test('更新日時は動かさない（「最近の更新」に混ざらない）', () async {
      await legacyCustomer('c_old', '青木 昭', 'アオキ アキラ');
      await service.ensureSearchFields(shop);
      final d = await fs.doc('shops/$shop/customers/c_old').get();
      expect(
          (d.data()!['updatedAt'] as Timestamp).toDate(), DateTime(2026, 1, 1));
    });

    group('Edge Cases', () {
      test('揃っていれば何も書かない（2回目は 0 件）', () async {
        await legacyCustomer('c_old', '青木 昭', 'アオキ アキラ');
        await add('青木 和也', kana: 'アオキ カズヤ');
        expect((await service.ensureSearchFields(shop)).valueOrNull, 1);
        expect((await service.ensureSearchFields(shop)).valueOrNull, 0);
      });

      test('台帳が空でも失敗しない', () async {
        expect((await service.ensureSearchFields(shop)).valueOrNull, 0);
      });

      test('店IDが空なら失敗を返す', () async {
        expect((await service.ensureSearchFields('')).isFailure, isTrue);
      });
    });
  });
}
