// 店の顧客台帳の画面（docs/SHOP_CRM_DESIGN_2026-09-27.md §5）。
//
// 何千人の顧客を持つ店で使う。ここで確かめたいのは、
// **件数が合っていること・続きが読めること・探せること・登録できること**。

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:trust_car_platform/models/shop_ledger.dart';
import 'package:trust_car_platform/screens/shop/ledger/customer_ledger_screen.dart';
import 'package:trust_car_platform/services/shop_ledger_service.dart';

const _shopId = 'shop_1';
final _today = DateTime(2026, 9, 27);

Widget _build(ShopLedgerService service) {
  return MaterialApp(
    home: CustomerLedgerScreen(
      service: service,
      shopId: _shopId,
      shopName: 'テスト工場',
      today: _today,
    ),
  );
}

void main() {
  late FakeFirebaseFirestore fs;
  late ShopLedgerService service;

  setUp(() {
    fs = FakeFirebaseFirestore();
    service = ShopLedgerService(firestore: fs, now: () => _today);
  });

  Future<LedgerCustomer> add(String name, String kana,
      {LedgerCustomerKind kind = LedgerCustomerKind.individual}) async {
    return (await service.createCustomer(
      shopId: _shopId,
      kind: kind,
      name: name,
      nameKana: kana,
    ))
        .valueOrNull!;
  }

  testWidgets('顧客がいなければ、登録を促す案内が出る', (tester) async {
    await tester.pumpWidget(_build(service));
    await tester.pumpAndSettle();

    expect(find.text('まだ顧客が登録されていません'), findsOneWidget);
    expect(find.byKey(const Key('ledger_count_total')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('ledger_count_total'))).data,
      '0',
    );
  });

  testWidgets('件数と、フリガナ順の一覧が出る', (tester) async {
    await add('渡辺商事', 'ワタナベショウジ', kind: LedgerCustomerKind.corporate);
    await add('青木花子', 'アオキハナコ');

    await tester.pumpWidget(_build(service));
    await tester.pumpAndSettle();

    expect(
      tester.widget<Text>(find.byKey(const Key('ledger_count_total'))).data,
      '2',
    );
    final aoki = tester.getTopLeft(find.text('青木花子'));
    final watanabe = tester.getTopLeft(find.text('渡辺商事'));
    expect(aoki.dy, lessThan(watanabe.dy));
  });

  testWidgets('最初は20件だけ読み、続きは求められてから読む', (tester) async {
    // 一覧が全部画面に収まる高さにして、何件描かれたかを直接数える
    tester.view.physicalSize = const Size(800, 5000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    for (var i = 0; i < 25; i++) {
      final n = i.toString().padLeft(2, '0');
      await add('顧客$n', 'こきゃく$n');
    }

    await tester.pumpWidget(_build(service));
    await tester.pumpAndSettle();

    expect(find.text('顧客19'), findsOneWidget);
    expect(find.text('顧客20'), findsNothing);

    await tester.tap(find.byKey(const Key('ledger_load_more')));
    await tester.pumpAndSettle();

    expect(find.text('顧客24'), findsOneWidget);
    // 続きが無くなったら、ボタンは消える
    expect(find.byKey(const Key('ledger_load_more')), findsNothing);
  });

  testWidgets('下までスクロールすると、続きを自動で読む', (tester) async {
    for (var i = 0; i < 25; i++) {
      final n = i.toString().padLeft(2, '0');
      await add('顧客$n', 'こきゃく$n');
    }

    await tester.pumpWidget(_build(service));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('顧客24'),
      300,
      // タブも横にスクロールするので、一覧のスクロールを指定する
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('顧客24'), findsOneWidget);
  });

  testWidgets('フリガナで探せる（ひらがなで打っても）', (tester) async {
    await add('山田太郎', 'ヤマダタロウ');
    await add('田中一郎', 'タナカイチロウ');

    await tester.pumpWidget(_build(service));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('ledger_search')), 'やま');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('山田太郎'), findsOneWidget);
    expect(find.text('田中一郎'), findsNothing);
  });

  testWidgets('ナンバー末尾の番号で車から探せる', (tester) async {
    final c = await add('山田太郎', 'ヤマダタロウ');
    await service.saveVehicle(
      shopId: _shopId,
      customerId: c.id,
      maker: 'MINI',
      model: 'クーパー',
      plate: '品川 300 あ 12-34',
    );

    await tester.pumpWidget(_build(service));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('ledger_search')), '1234');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.textContaining('MINI クーパー'), findsOneWidget);
    expect(find.text('山田太郎'), findsOneWidget);
  });

  testWidgets('車検が近いタブは、顧客をまたいで満了日の近い順', (tester) async {
    final a = await add('A商店', 'エーショウテン');
    final b = await add('B運輸', 'ビーウンユ');
    await service.saveVehicle(
      shopId: _shopId,
      customerId: a.id,
      maker: 'トヨタ',
      model: 'プロボックス',
      inspectionExpiry: DateTime(2027, 3, 1),
    );
    await service.saveVehicle(
      shopId: _shopId,
      customerId: b.id,
      maker: 'トヨタ',
      model: 'ハイエース',
      inspectionExpiry: DateTime(2026, 10, 10),
    );

    await tester.pumpWidget(_build(service));
    await tester.pumpAndSettle();
    await tester.tap(find.text('車検が近い'));
    await tester.pumpAndSettle();

    final hiace = tester.getTopLeft(find.text('トヨタ ハイエース'));
    final probox = tester.getTopLeft(find.text('トヨタ プロボックス'));
    expect(hiace.dy, lessThan(probox.dy));
    expect(find.text('あと13日'), findsOneWidget);
  });

  testWidgets('顧客を追加すると、台帳に載り件数が増える', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_build(service));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('ledger_add_customer')));
    await tester.pumpAndSettle();

    // 名前が空のままでは保存できない
    await tester.tap(find.byKey(const Key('customer_save')));
    await tester.pumpAndSettle();
    expect(find.text('名前を入力してください'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('customer_name')), '佐藤次郎');
    await tester.enterText(find.byKey(const Key('customer_kana')), 'サトウジロウ');
    await tester.tap(find.byKey(const Key('customer_save')));
    await tester.pumpAndSettle();

    // 登録後は、その顧客の詳細が開く
    expect(find.text('車両（0台）'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('佐藤次郎'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('ledger_count_total'))).data,
      '1',
    );
  });

  testWidgets('車種別レポートへの協力は、既定でオフ。オンにすると店に記録される', (tester) async {
    await fs.collection('shops').doc(_shopId).set({'name': 'テスト工場'});
    await tester.pumpWidget(_build(service));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('ledger_more')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('車種別レポートへの協力'));
    await tester.pumpAndSettle();

    final sw = find.byKey(const Key('ledger_stats_switch'));
    expect(tester.widget<SwitchListTile>(sw).value, isFalse);
    await tester.tap(sw);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(sw).value, isTrue);

    final shop = await fs.collection('shops').doc(_shopId).get();
    expect(shop.data()!['allowsStatistics'], isTrue);
  });
}
