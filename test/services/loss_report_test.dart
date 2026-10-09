import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/services/ledger_csv_import.dart';
import 'package:trust_car_platform/services/shop_ledger_service.dart';

/// 車検の取りこぼしを数える（2026-09-29 プロダクト評価 #1）。
///
/// 店の経営の数字（車検の粗利）に直結する。**取込が止まっていると
/// 悪く見える**ので、古いときは率を出さないことまで確かめる。
void main() {
  late FakeFirebaseFirestore fs;
  final today = DateTime(2026, 9, 29);
  const shop = 's1';

  ShopLedgerService at(DateTime now) =>
      ShopLedgerService(firestore: fs, now: () => now);

  setUp(() => fs = FakeFirebaseFirestore());

  Future<void> roster(List<List<String>> rows) async {
    const header = ['顧客番号', '顧客名', '車両番号', 'メーカー', '車名', '車検満了日'];
    await at(today).importPlan(
      shopId: shop,
      plan: buildImportPlan(rows, guessColumns(header)),
    );
  }

  Future<void> history(List<List<String>> rows, {DateTime? importedAt}) async {
    const header = ['伝票番号', '作業日', '車両番号', '作業内容', '合計金額'];
    await at(importedAt ?? today).importHistory(
      shopId: shop,
      plan: buildHistoryPlan(rows, guessHistoryColumns(header)),
    );
  }

  test('満了日を過ぎて車検の入庫が無い車を、取りこぼしとして数える', () async {
    await roster([
      ['C1', '入庫した人', 'V1', 'トヨタ', 'プリウス', '2026/5/10'],
      ['C2', '来なかった人', 'V2', 'ホンダ', 'N-BOX', '2026/5/20'],
      ['C3', '来なかった人2', 'V3', 'MINI', 'クーパー', '2026/8/1'],
      ['C4', 'まだ先の人', 'V4', '日産', 'ノート', '2026/12/1'],
    ]);
    await history([
      // 満了の少し前に車検で入庫
      ['S1', '2026/4/20', 'V1', '車検整備', '120000'],
      // 来なかった人2 はオイル交換だけ（車検ではない）
      ['S2', '2026/7/1', 'V3', 'オイル交換', '5500'],
    ]);

    final r = (await at(today).lossReport(shopId: shop)).valueOrNull!;
    expect(r.expired, 3); // まだ先の人は数えない
    expect(r.lost, 2);
    expect(r.rate, closeTo(2 / 3, 1e-9));
    expect(r.lostVehicles.map((v) => v.customerName), ['来なかった人2', '来なかった人']);
    expect(r.isStale, isFalse);

    final may = r.months.firstWhere((m) => m.month == DateTime(2026, 5));
    expect(may.returned, 1);
    expect(may.lost, 1);
    expect(may.rate, 0.5);
  });

  test('「継続検査」など言い方が違っても車検の入庫とみなす', () async {
    await roster([
      ['C1', 'A', 'V1', 'トヨタ', 'プリウス', '2026/6/1'],
    ]);
    await history([
      ['S1', '2026/5/25', 'V1', '継続検査', '98000'],
    ]);
    final r = (await at(today).lossReport(shopId: shop)).valueOrNull!;
    expect(r.lost, 0);
  });

  test('満了日より60日より前の車検は、今回の入庫とみなさない（前回の車検）', () async {
    await roster([
      ['C1', 'A', 'V1', 'トヨタ', 'プリウス', '2026/6/1'],
    ]);
    await history([
      ['S1', '2026/3/1', 'V1', '車検', '98000'],
    ]);
    final r = (await at(today).lossReport(shopId: shop)).valueOrNull!;
    expect(r.lost, 1);
  });

  group('Edge Cases', () {
    test('整備履歴を一度も取り込んでいなければ「古い」（率を出さない）', () async {
      await roster([
        ['C1', 'A', 'V1', 'トヨタ', 'プリウス', '2026/6/1'],
      ]);
      final r = (await at(today).lossReport(shopId: shop)).valueOrNull!;
      expect(r.isStale, isTrue);
      expect(r.lastImportAt, isNull);
    });

    test('最後の取込が30日より前なら「古い」', () async {
      await roster([
        ['C1', 'A', 'V1', 'トヨタ', 'プリウス', '2026/6/1'],
      ]);
      await history([
        ['S1', '2026/5/25', 'V1', '車検', '98000'],
      ], importedAt: DateTime(2026, 8, 1));
      final r = (await at(today).lossReport(shopId: shop)).valueOrNull!;
      expect(r.isStale, isTrue);
      expect(r.lastImportAt, DateTime(2026, 8, 1));
    });

    test('満了した車が無ければ率は null（0% と言わない）', () async {
      await roster([
        ['C1', 'A', 'V1', 'トヨタ', 'プリウス', '2027/6/1'],
      ]);
      final r = (await at(today).lossReport(shopId: shop)).valueOrNull!;
      expect(r.expired, 0);
      expect(r.rate, isNull);
      expect(r.months, hasLength(12));
    });

    test('12か月より前に満了した車は数えない', () async {
      await roster([
        ['C1', 'A', 'V1', 'トヨタ', 'プリウス', '2025/8/31'],
      ]);
      final r = (await at(today).lossReport(shopId: shop)).valueOrNull!;
      expect(r.expired, 0);
    });
  });

  // 2026-10-08 usability test: the roster is re-imported after each
  // inspection, so the expiry moves two years ahead and the car used to
  // drop out of both the numerator and the denominator. Every month then
  // read "39 / 39" (all lost).
  group('名簿を取り直して満了日が進んだ車', () {
    test('車検で入庫した車は、前の満了日の月に「入庫した」として数える', () async {
      await roster([
        ['C1', '入庫した人', 'V1', 'トヨタ', 'プリウス', '2026/5/10'],
        ['C2', '来なかった人', 'V2', 'ホンダ', 'N-BOX', '2026/5/20'],
      ]);
      await history([
        ['S1', '2026/4/20', 'V1', '車検整備', '120000'],
      ]);
      // After the inspection the roster was re-imported (V1 moved 2 years).
      await roster([
        ['C1', '入庫した人', 'V1', 'トヨタ', 'プリウス', '2028/5/10'],
        ['C2', '来なかった人', 'V2', 'ホンダ', 'N-BOX', '2026/5/20'],
      ]);

      final r = (await at(today).lossReport(shopId: shop)).valueOrNull!;
      expect(r.expired, 2);
      expect(r.lost, 1);
      final may = r.months.firstWhere((m) => m.month == DateTime(2026, 5));
      expect(may.returned, 1);
      expect(may.lost, 1);
      expect(r.lostVehicles.map((v) => v.customerName), ['来なかった人']);
    });

    test('1年車検の車（満了日が1年進んだ）も、前の満了日の月に数える', () async {
      await roster([
        ['C1', 'トラック', 'V1', 'いすゞ', 'エルフ', '2026/3/15'],
      ]);
      await history([
        ['S1', '2026/3/1', 'V1', '継続検査', '80000'],
      ]);
      await roster([
        ['C1', 'トラック', 'V1', 'いすゞ', 'エルフ', '2027/3/15'],
      ]);
      final r = (await at(today).lossReport(shopId: shop)).valueOrNull!;
      final mar = r.months.firstWhere((m) => m.month == DateTime(2026, 3));
      expect(mar.returned, 1);
      expect(r.lost, 0);
    });

    test('これから満了する車を早めに車検した分は、まだ数えない', () async {
      await roster([
        ['C1', 'A', 'V1', 'トヨタ', 'プリウス', '2026/10/20'],
      ]);
      await history([
        ['S1', '2026/9/10', 'V1', '車検', '98000'],
      ]);
      await roster([
        ['C1', 'A', 'V1', 'トヨタ', 'プリウス', '2028/10/20'],
      ]);
      final r = (await at(today).lossReport(shopId: shop)).valueOrNull!;
      expect(r.expired, 0);
    });
  });

  group('読み取りを減らす（車に最後の車検日を持たせる）', () {
    String vid(String ext) => ShopLedgerService.idForExternal('v', ext);

    test('整備履歴の取込で、車検の伝票の日付を車の lastInspectionAt に書く', () async {
      await roster([
        ['C1', 'A', 'V1', 'トヨタ', 'プリウス', '2026/5/10'],
        ['C2', 'B', 'V2', 'ホンダ', 'N-BOX', '2026/5/20'],
      ]);
      await history([
        ['S1', '2026/4/20', 'V1', '車検整備', '120000'],
        ['S2', '2024/4/22', 'V1', '車検整備', '110000'],
        ['S3', '2026/7/1', 'V2', 'オイル交換', '5500'],
      ]);
      final v1 =
          await fs.doc('shops/$shop/customer_vehicles/${vid('V1')}').get();
      final v2 =
          await fs.doc('shops/$shop/customer_vehicles/${vid('V2')}').get();
      expect((v1.data()!['lastInspectionAt'] as Timestamp).toDate(),
          DateTime(2026, 4, 20));
      // "None" is written too, so the report never re-reads its records.
      expect(v2.data()!.containsKey('lastInspectionAt'), isTrue);
      expect(v2.data()!['lastInspectionAt'], isNull);
    });

    test('取込をやり直して古い伝票だけが来ても、新しい車検日を戻さない', () async {
      await roster([
        ['C1', 'A', 'V1', 'トヨタ', 'プリウス', '2026/5/10'],
      ]);
      await history([
        ['S1', '2026/4/20', 'V1', '車検', '120000'],
      ]);
      await history([
        ['S0', '2024/4/22', 'V1', '車検', '110000'],
      ]);
      final v1 =
          await fs.doc('shops/$shop/customer_vehicles/${vid('V1')}').get();
      expect((v1.data()!['lastInspectionAt'] as Timestamp).toDate(),
          DateTime(2026, 4, 20));
    });

    test('名簿を取り直しても lastInspectionAt は消えない', () async {
      await roster([
        ['C1', 'A', 'V1', 'トヨタ', 'プリウス', '2026/5/10'],
      ]);
      await history([
        ['S1', '2026/4/20', 'V1', '車検', '120000'],
      ]);
      await roster([
        ['C1', 'A', 'V1', 'トヨタ', 'プリウス', '2028/5/10'],
      ]);
      final v1 =
          await fs.doc('shops/$shop/customer_vehicles/${vid('V1')}').get();
      expect(v1.data()!['lastInspectionAt'], isA<Timestamp>());
    });

    test('車に lastInspectionAt があれば、伝票は読み直さない（車の値を正とする）', () async {
      await roster([
        ['C1', 'A', 'V1', 'トヨタ', 'プリウス', '2026/5/10'],
      ]);
      await history([
        ['S1', '2026/1/5', 'V1', 'オイル交換', '5000'],
      ]);
      // An inspection record that bypassed the import (vehicle still null).
      await fs.collection('shops/$shop/service_records').doc('x').set({
        'customerVehicleId': vid('V1'),
        'date': Timestamp.fromDate(DateTime(2026, 4, 30)),
        'type': '車検',
        'totalCost': 1,
        'updatedAt': Timestamp.fromDate(today),
      });
      final r = (await at(today).lossReport(shopId: shop)).valueOrNull!;
      expect(r.lost, 1);
    });
  });

  group('移行（lastInspectionAt の無い、これまでの車）', () {
    Future<void> legacyVehicle(String id, DateTime expiry) =>
        fs.collection('shops/$shop/customer_vehicles').doc(id).set({
          'customerId': 'c_$id',
          'customerName': id,
          'maker': 'トヨタ',
          'model': 'プリウス',
          'inspectionExpiry': Timestamp.fromDate(expiry),
          'createdAt': Timestamp.fromDate(today),
          'updatedAt': Timestamp.fromDate(today),
        });
    Future<void> legacyRecord(
            String id, String vid, DateTime date, String type) =>
        fs.collection('shops/$shop/service_records').doc(id).set({
          'customerVehicleId': vid,
          'customerId': 'c_$vid',
          'date': Timestamp.fromDate(date),
          'type': type,
          'totalCost': 1000,
          'source': 'csv',
          'updatedAt':
              Timestamp.fromDate(today.subtract(const Duration(days: 3))),
        });

    test('lastInspectionAt の無い車は、その車の伝票を読んで判定する', () async {
      await legacyVehicle('v_a', DateTime(2026, 5, 10));
      await legacyVehicle('v_b', DateTime(2026, 6, 10));
      await legacyRecord('r1', 'v_a', DateTime(2026, 4, 20), '車検');
      await legacyRecord('r2', 'v_b', DateTime(2026, 6, 1), 'オイル交換');
      final r = (await at(today).lossReport(shopId: shop)).valueOrNull!;
      expect(r.expired, 2);
      expect(r.lost, 1);
      expect(r.lostVehicles.single.id, 'v_b');
    });

    test('次の整備履歴の取込で、取込に出てこない車の lastInspectionAt も埋める', () async {
      await legacyVehicle('v_a', DateTime(2026, 5, 10));
      await legacyVehicle('v_b', DateTime(2026, 6, 10));
      await legacyRecord('r1', 'v_a', DateTime(2026, 4, 20), '車検');
      await roster([
        ['C1', 'B', 'V1', 'トヨタ', 'プリウス', '2026/5/10'],
      ]);
      await history([
        ['S1', '2026/9/1', 'V1', 'オイル交換', '5000'],
      ]);
      final a = await fs.doc('shops/$shop/customer_vehicles/v_a').get();
      expect((a.data()!['lastInspectionAt'] as Timestamp).toDate(),
          DateTime(2026, 4, 20));
      final b = await fs.doc('shops/$shop/customer_vehicles/v_b').get();
      expect(b.data()!.containsKey('lastInspectionAt'), isTrue);
      expect(b.data()!['lastInspectionAt'], isNull);
    });
  });

  group('最後の取込（lastImportAt）', () {
    test('updatedAt の無い伝票しか無くても、作業日から「取り込まれている」と分かる', () async {
      await fs.collection('shops/$shop/service_records').doc('m1').set({
        'customerVehicleId': 'v1',
        'date': Timestamp.fromDate(DateTime(2026, 9, 25)),
        'type': '車検',
        'totalCost': 1,
        'source': 'manual',
      });
      final r = (await at(today).lossReport(shopId: shop)).valueOrNull!;
      expect(r.lastImportAt, DateTime(2026, 9, 25));
      expect(r.isStale, isFalse);
    });

    test('updatedAt が文字列や数値で入っていても落ちずに日付として読む', () async {
      await fs.collection('shops/$shop/service_records').doc('m1').set({
        'customerVehicleId': 'v1',
        'date': Timestamp.fromDate(DateTime(2026, 8, 1)),
        'type': 'オイル交換',
        'totalCost': 1,
        'updatedAt': '2026-09-27T10:00:00.000',
      });
      final res = await at(today).lossReport(shopId: shop);
      expect(res.isSuccess, isTrue);
      expect(res.valueOrNull!.lastImportAt, DateTime(2026, 9, 27, 10));
      expect(res.valueOrNull!.isStale, isFalse);
    });

    test('updatedAt が数値（ミリ秒）でも日付として読む', () async {
      await fs.collection('shops/$shop/service_records').doc('m2').set({
        'customerVehicleId': 'v1',
        'date': Timestamp.fromDate(DateTime(2026, 8, 2)),
        'type': 'オイル交換',
        'totalCost': 1,
        'updatedAt': DateTime(2026, 9, 20).millisecondsSinceEpoch,
      });
      final res = await at(today).lossReport(shopId: shop);
      expect(res.valueOrNull!.lastImportAt, DateTime(2026, 9, 20));
    });

    test('作業日が未来（入力ミス）の伝票で「新しい」と言わない', () async {
      await fs.collection('shops/$shop/service_records').doc('m3').set({
        'customerVehicleId': 'v1',
        'date': Timestamp.fromDate(DateTime(2062, 8, 2)),
        'type': 'オイル交換',
        'totalCost': 1,
      });
      final r = (await at(today).lossReport(shopId: shop)).valueOrNull!;
      expect(r.lastImportAt, isNull);
      expect(r.isStale, isTrue);
    });

    test('店IDが空なら読まずに失敗を返す', () async {
      final r = await at(today).lossReport(shopId: '');
      expect(r.isFailure, isTrue);
    });

    test('期間が0か月なら失敗を返す', () async {
      final r = await at(today).lossReport(shopId: shop, months: 0);
      expect(r.isFailure, isTrue);
    });
  });
}
