// 台帳の顧客詳細。車両を足すと、一覧で使う要約値（台数・次の車検）も
// 変わる。画面から足したときにそこまで届いているかを見る。

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:trust_car_platform/models/shop_ledger.dart';
import 'package:trust_car_platform/screens/shop/ledger/customer_detail_screen.dart';
import 'package:trust_car_platform/services/shop_ledger_service.dart';

const _shopId = 'shop_1';
final _today = DateTime(2026, 9, 27);

void main() {
  late FakeFirebaseFirestore fs;
  late ShopLedgerService service;
  late LedgerCustomer customer;

  setUp(() async {
    fs = FakeFirebaseFirestore();
    service = ShopLedgerService(firestore: fs, now: () => _today);
    customer = (await service.createCustomer(
      shopId: _shopId,
      kind: LedgerCustomerKind.corporate,
      name: 'サンプル運輸',
      nameKana: 'サンプルウンユ',
      contactPerson: '総務 佐藤',
    ))
        .valueOrNull!;
  });

  /// 前の画面を1枚挟み、閉じたときの戻り値を受け取れるようにする。
  Future<List<Object?>> pumpDetail(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final results = <Object?>[];
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            results.add(await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (_) => CustomerDetailScreen(
                  service: service,
                  shopId: _shopId,
                  customerId: customer.id,
                  today: _today,
                ),
              ),
            ));
          },
          child: const Text('開く'),
        ),
      ),
    ));
    await tester.tap(find.text('開く'));
    await tester.pumpAndSettle();
    return results;
  }

  testWidgets('法人なら担当者が出る', (tester) async {
    await pumpDetail(tester);
    expect(find.text('総務 佐藤'), findsOneWidget);
    expect(find.text('車両（0台）'), findsOneWidget);
  });

  testWidgets('車両を足すと、一覧に出て顧客の台数も増える', (tester) async {
    final results = await pumpDetail(tester);

    await tester.tap(find.byKey(const Key('vehicle_add')));
    await tester.pumpAndSettle();

    // メーカー・車種が空なら保存できない
    await tester.tap(find.byKey(const Key('vehicle_save')));
    await tester.pumpAndSettle();
    expect(find.text('入力してください'), findsNWidgets(2));

    await tester.enterText(find.byKey(const Key('vehicle_maker')), 'トヨタ');
    await tester.enterText(find.byKey(const Key('vehicle_model')), 'ハイエース');
    await tester.enterText(
        find.byKey(const Key('vehicle_plate')), '品川 400 さ 12-34');
    await tester.tap(find.byKey(const Key('vehicle_save')));
    await tester.pumpAndSettle();

    expect(find.text('車両（1台）'), findsOneWidget);
    expect(find.text('トヨタ ハイエース'), findsOneWidget);

    final saved = (await service.getCustomer(
      shopId: _shopId,
      customerId: customer.id,
    ))
        .valueOrNull!;
    expect(saved.vehicleCount, 1);

    // 変更があったので、閉じると一覧に読み直しを頼む
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(results, [true]);
  });

  testWidgets('何も変えずに閉じたら、読み直しは頼まない', (tester) async {
    final results = await pumpDetail(tester);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(results, [false]);
  });

  testWidgets('顧客を削除すると、確認のうえ台帳から消える', (tester) async {
    final results = await pumpDetail(tester);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('顧客を削除'));
    await tester.pumpAndSettle();

    expect(find.text('この顧客を削除しますか？'), findsOneWidget);
    await tester.tap(find.byKey(const Key('customer_delete_confirm')));
    await tester.pumpAndSettle();

    expect(results, [true]);
    final got =
        await service.getCustomer(shopId: _shopId, customerId: customer.id);
    expect(got.isFailure, isTrue);
  });
}
