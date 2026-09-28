// 顧客台帳の CSV 取込画面。
//
// 整備管理ソフトの書き出し（Windows の Shift_JIS）をそのまま選んで、
// 台帳に入るところまでを見る。ファイル選択は差し替えている。

import 'dart:convert';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:trust_car_platform/models/shop_ledger.dart';
import 'package:trust_car_platform/screens/shop/ledger/ledger_csv_import_screen.dart';
import 'package:trust_car_platform/services/shop_ledger_service.dart';

const _shopId = 'shop_1';

/// 整備管理ソフト風の CSV を CP932 で書き出したもの（Python の cp932 で作成）。
///
/// ```
/// 顧客番号,顧客名,ﾌﾘｶﾞﾅ,登録番号,メーカー,車名,車検有効期限
/// C001,㈱サンプル運輸,ｻﾝﾌﾟﾙｳﾝﾕ,品川400さ1,トヨタ,ハイエース,R8.11.5
/// C001,㈱サンプル運輸,ｻﾝﾌﾟﾙｳﾝﾕ,品川400さ2,トヨタ,ハイエース,2027/1/10
/// C002,髙橋一郎,ﾀｶﾊｼｲﾁﾛｳ,品川300あ1234,MINI,クーパー,2026/2/30
/// ```
///
/// 最後の行の満了日（2月30日）は、わざと読めない日付にしてある。
const _cp932Csv = <int>[
  0x8C,
  0xDA,
  0x8B,
  0x71,
  0x94,
  0xD4,
  0x8D,
  0x86,
  0x2C,
  0x8C,
  0xDA,
  0x8B,
  0x71,
  0x96,
  0xBC,
  0x2C,
  0xCC,
  0xD8,
  0xB6,
  0xDE,
  0xC5,
  0x2C,
  0x93,
  0x6F,
  0x98,
  0x5E,
  0x94,
  0xD4,
  0x8D,
  0x86,
  0x2C,
  0x83,
  0x81,
  0x81,
  0x5B,
  0x83,
  0x4A,
  0x81,
  0x5B,
  0x2C,
  0x8E,
  0xD4,
  0x96,
  0xBC,
  0x2C,
  0x8E,
  0xD4,
  0x8C,
  0x9F,
  0x97,
  0x4C,
  0x8C,
  0xF8,
  0x8A,
  0xFA,
  0x8C,
  0xC0,
  0x0D,
  0x0A,
  0x43,
  0x30,
  0x30,
  0x31,
  0x2C,
  0x87,
  0x8A,
  0x83,
  0x54,
  0x83,
  0x93,
  0x83,
  0x76,
  0x83,
  0x8B,
  0x89,
  0x5E,
  0x97,
  0x41,
  0x2C,
  0xBB,
  0xDD,
  0xCC,
  0xDF,
  0xD9,
  0xB3,
  0xDD,
  0xD5,
  0x2C,
  0x95,
  0x69,
  0x90,
  0xEC,
  0x34,
  0x30,
  0x30,
  0x82,
  0xB3,
  0x31,
  0x2C,
  0x83,
  0x67,
  0x83,
  0x88,
  0x83,
  0x5E,
  0x2C,
  0x83,
  0x6E,
  0x83,
  0x43,
  0x83,
  0x47,
  0x81,
  0x5B,
  0x83,
  0x58,
  0x2C,
  0x52,
  0x38,
  0x2E,
  0x31,
  0x31,
  0x2E,
  0x35,
  0x0D,
  0x0A,
  0x43,
  0x30,
  0x30,
  0x31,
  0x2C,
  0x87,
  0x8A,
  0x83,
  0x54,
  0x83,
  0x93,
  0x83,
  0x76,
  0x83,
  0x8B,
  0x89,
  0x5E,
  0x97,
  0x41,
  0x2C,
  0xBB,
  0xDD,
  0xCC,
  0xDF,
  0xD9,
  0xB3,
  0xDD,
  0xD5,
  0x2C,
  0x95,
  0x69,
  0x90,
  0xEC,
  0x34,
  0x30,
  0x30,
  0x82,
  0xB3,
  0x32,
  0x2C,
  0x83,
  0x67,
  0x83,
  0x88,
  0x83,
  0x5E,
  0x2C,
  0x83,
  0x6E,
  0x83,
  0x43,
  0x83,
  0x47,
  0x81,
  0x5B,
  0x83,
  0x58,
  0x2C,
  0x32,
  0x30,
  0x32,
  0x37,
  0x2F,
  0x31,
  0x2F,
  0x31,
  0x30,
  0x0D,
  0x0A,
  0x43,
  0x30,
  0x30,
  0x32,
  0x2C,
  0xEE,
  0xE0,
  0x8B,
  0xB4,
  0x88,
  0xEA,
  0x98,
  0x59,
  0x2C,
  0xC0,
  0xB6,
  0xCA,
  0xBC,
  0xB2,
  0xC1,
  0xDB,
  0xB3,
  0x2C,
  0x95,
  0x69,
  0x90,
  0xEC,
  0x33,
  0x30,
  0x30,
  0x82,
  0xA0,
  0x31,
  0x32,
  0x33,
  0x34,
  0x2C,
  0x4D,
  0x49,
  0x4E,
  0x49,
  0x2C,
  0x83,
  0x4E,
  0x81,
  0x5B,
  0x83,
  0x70,
  0x81,
  0x5B,
  0x2C,
  0x32,
  0x30,
  0x32,
  0x36,
  0x2F,
  0x32,
  0x2F,
  0x33,
  0x30,
  0x0D,
  0x0A
];

void main() {
  late FakeFirebaseFirestore fs;
  late ShopLedgerService service;

  setUp(() {
    fs = FakeFirebaseFirestore();
    service =
        ShopLedgerService(firestore: fs, now: () => DateTime(2026, 9, 27));
  });

  Future<List<Object?>> pump(WidgetTester tester, PickedCsvFile? file) async {
    tester.view.physicalSize = const Size(900, 3200);
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
                builder: (_) => LedgerCsvImportScreen(
                  service: service,
                  shopId: _shopId,
                  pickFile: () async => file,
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

  testWidgets('Shift_JIS の CSV を選ぶと、列が当たり、人数と台数が出る', (tester) async {
    await pump(tester, const PickedCsvFile('顧客.csv', _cp932Csv));

    await tester.tap(find.byKey(const Key('csv_pick')));
    await tester.pumpAndSettle();

    expect(
      tester.widget<Text>(find.byKey(const Key('csv_file_summary'))).data,
      contains('Shift_JIS'),
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('csv_plan_summary'))).data,
      '顧客 2人・車両 3台 を取り込みます。',
    );
    // 読めない満了日は、行番号つきで知らせる
    expect(find.byKey(const Key('csv_problem_count')), findsOneWidget);
    expect(find.textContaining('4行目'), findsOneWidget);
    // 拡張文字も化けずに読めている
    expect(find.text('㈱サンプル運輸'), findsWidgets);
  });

  testWidgets('取り込むと台帳に入り、閉じると一覧に読み直しを頼む', (tester) async {
    final results =
        await pump(tester, const PickedCsvFile('顧客.csv', _cp932Csv));

    await tester.tap(find.byKey(const Key('csv_pick')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('csv_import_run')));
    await tester.pumpAndSettle();

    expect(
      tester.widget<Text>(find.byKey(const Key('csv_import_result'))).data,
      '新しい顧客 2人・更新 0人・車両 3台',
    );

    final page = (await service.listCustomers(shopId: _shopId)).valueOrNull!;
    final corp = page.items.firstWhere((c) => c.name == '㈱サンプル運輸');
    expect(corp.kind, LedgerCustomerKind.corporate);
    expect(corp.vehicleCount, 2);
    expect(corp.nextInspectionAt, DateTime(2026, 11, 5));
    // 半角カナのフリガナでも、ひらがなで引ける
    final found = (await service.listCustomers(shopId: _shopId, search: 'たかはし'))
        .valueOrNull!;
    expect(found.items.single.name, '髙橋一郎');

    await tester.tap(find.byKey(const Key('csv_import_done')));
    await tester.pumpAndSettle();
    expect(results, [true]);
  });

  testWidgets('顧客名の列を外すと、取り込めない', (tester) async {
    await pump(tester, const PickedCsvFile('顧客.csv', _cp932Csv));
    await tester.tap(find.byKey(const Key('csv_pick')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('csv_col_customerName')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('（使わない）').last);
    await tester.pumpAndSettle();

    expect(find.text('「顧客名」の列を選んでください。'), findsOneWidget);
    final button = tester.widget<ButtonStyleButton>(find.ancestor(
      of: find.text('取り込む'),
      matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
    ));
    expect(button.onPressed, isNull);
  });

  group('Edge Cases', () {
    testWidgets('見出しだけのファイルは、理由を出して止める', (tester) async {
      await pump(
        tester,
        PickedCsvFile('空.csv', utf8.encode('顧客名,車名\n')),
      );
      await tester.tap(find.byKey(const Key('csv_pick')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('csv_import_error')), findsOneWidget);
      expect(find.byKey(const Key('csv_import_run')), findsNothing);
    });

    testWidgets('ファイルを選ばずに戻ったら、何も起きない', (tester) async {
      await pump(tester, null);
      await tester.tap(find.byKey(const Key('csv_pick')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('csv_file_summary')), findsNothing);
      expect(find.byKey(const Key('csv_import_error')), findsNothing);
    });
  });

  group('整備履歴', () {
    testWidgets('名簿のあとに伝票を取り込むと、台帳の車に紐づいて入る', (tester) async {
      // 先に名簿
      await pump(tester, const PickedCsvFile('顧客.csv', _cp932Csv));
      await tester.tap(find.byKey(const Key('csv_pick')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('csv_import_run')));
      await tester.pumpAndSettle();

      // 次に整備履歴（UTF-8）
      const history = '伝票番号,作業日,登録番号,作業内容,合計金額\n'
          'S1,2026/3/1,品川400さ1,車検,"120,000"\n'
          'S2,2026/4/1,品川300あ1234,オイル交換,5500\n'
          'S3,2026/4/2,品川999ん9,オイル交換,5500\n';
      await tester.pumpWidget(const SizedBox());
      await pump(tester, PickedCsvFile('履歴.csv', utf8.encode(history)));

      await tester.tap(find.text('整備履歴'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('csv_pick')));
      await tester.pumpAndSettle();

      expect(
        tester.widget<Text>(find.byKey(const Key('csv_history_summary'))).data,
        '伝票 3件 を取り込みます。',
      );

      await tester.tap(find.byKey(const Key('csv_history_run')));
      await tester.pumpAndSettle();

      expect(
        tester.widget<Text>(find.byKey(const Key('csv_history_result'))).data,
        '伝票 2件',
      );
      // 台帳に無いナンバーの伝票は、何行目かを出す
      expect(find.textContaining('4行目'), findsOneWidget);

      final recs = await fs.collection('shops/$_shopId/service_records').get();
      expect(recs.docs, hasLength(2));
    });
  });
}
