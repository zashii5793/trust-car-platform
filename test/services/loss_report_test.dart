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
}
