import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/models/shop_ledger.dart';
import 'package:trust_car_platform/services/ledger_csv_import.dart';

/// 整備管理ソフトの CSV を読み解く部分。
///
/// **取込で1年ずれた車検満了日は、空欄より害が大きい**（案内の時期が
/// まるごと狂う）。日付は「読めないものは読まない」ことまで確かめる。
void main() {
  group('parseCsv', () {
    test('引用符の中のカンマ・改行・二重引用符を扱う', () {
      const csv = '名前,住所,備考\r\n'
          '"山田, 太郎","東京都\n千代田区","「""至急""」"\r\n';
      final rows = parseCsv(csv);
      expect(rows, [
        ['名前', '住所', '備考'],
        ['山田, 太郎', '東京都\n千代田区', '「"至急"」'],
      ]);
    });

    test('先頭の BOM を落とす（Excel の CSV UTF-8）', () {
      final rows = parseCsv('﻿顧客名\n山田\n');
      expect(rows.first.first, '顧客名');
    });

    group('Edge Cases', () {
      test('空文字なら行なし', () {
        expect(parseCsv(''), isEmpty);
      });

      test('空行は捨てる', () {
        expect(parseCsv('a,b\n\n1,2\n\n'), [
          ['a', 'b'],
          ['1', '2'],
        ]);
      });

      test('最後に改行が無くても最終行を読む', () {
        expect(parseCsv('a\n1'), [
          ['a'],
          ['1'],
        ]);
      });

      test('空の列を保つ', () {
        expect(parseCsv('a,,c\n'), [
          ['a', '', 'c'],
        ]);
      });
    });
  });

  group('parseLedgerDate', () {
    test('西暦のいろいろな書き方', () {
      final want = DateTime(2026, 9, 27);
      for (final s in [
        '2026/09/27',
        '2026/9/27',
        '2026-09-27',
        '2026.9.27',
        '20260927',
        '2026年9月27日',
        '２０２６／９／２７',
      ]) {
        expect(parseLedgerDate(s), want, reason: s);
      }
    });

    test('和暦（令和・平成・昭和、略号も）', () {
      expect(parseLedgerDate('令和8年9月27日'), DateTime(2026, 9, 27));
      expect(parseLedgerDate('R8.9.27'), DateTime(2026, 9, 27));
      expect(parseLedgerDate('R08/09/27'), DateTime(2026, 9, 27));
      expect(parseLedgerDate('H30.1.5'), DateTime(2018, 1, 5));
      expect(parseLedgerDate('平成31年4月30日'), DateTime(2019, 4, 30));
      expect(parseLedgerDate('令和元年5月1日'), DateTime(2019, 5, 1));
      expect(parseLedgerDate('S60.1.1'), DateTime(1985, 1, 1));
    });

    group('Edge Cases', () {
      test('空・null は null', () {
        expect(parseLedgerDate(null), isNull);
        expect(parseLedgerDate(''), isNull);
        expect(parseLedgerDate('  '), isNull);
      });

      test('存在しない日付は null（2月30日を3月2日にしない）', () {
        expect(parseLedgerDate('2026/2/30'), isNull);
        expect(parseLedgerDate('2026/13/1'), isNull);
      });

      test('元号の無い2桁の年は、世紀を決められないので null', () {
        expect(parseLedgerDate('26/9/27'), isNull);
      });

      test('日付でない文字は null', () {
        expect(parseLedgerDate('未定'), isNull);
      });
    });
  });

  group('parseLedgerYear', () {
    test('西暦・年月・和暦を西暦の年にする', () {
      expect(parseLedgerYear('2019'), 2019);
      expect(parseLedgerYear('2019/04'), 2019);
      expect(parseLedgerYear('H31'), 2019);
      expect(parseLedgerYear('平成31年4月'), 2019);
      expect(parseLedgerYear('R1'), 2019);
      expect(parseLedgerYear('令和元年'), 2019);
    });

    group('Edge Cases', () {
      test('ありえない年は null', () {
        expect(parseLedgerYear('1234'), isNull);
        expect(parseLedgerYear(''), isNull);
        expect(parseLedgerYear(null), isNull);
      });
    });
  });

  group('guessColumns', () {
    test('よくある列名を当てる（表記の揺れも）', () {
      final cols = guessColumns([
        'お客様コード',
        '氏名',
        'ﾌﾘｶﾞﾅ',
        'TEL',
        '登録番号',
        'メーカー名',
        '車名',
        '型式',
        '車検有効期限',
        '最終入庫日',
      ]);
      expect(cols[LedgerImportField.customerExternalId], 0);
      expect(cols[LedgerImportField.customerName], 1);
      expect(cols[LedgerImportField.customerKana], 2);
      expect(cols[LedgerImportField.phone], 3);
      expect(cols[LedgerImportField.plate], 4);
      expect(cols[LedgerImportField.maker], 5);
      expect(cols[LedgerImportField.model], 6);
      expect(cols[LedgerImportField.modelCode], 7);
      expect(cols[LedgerImportField.inspectionExpiry], 8);
      expect(cols[LedgerImportField.lastVisitAt], 9);
    });

    test('1つの列を2つの項目に当てない', () {
      final cols = guessColumns(['車検満了日', '車検日']);
      expect(cols[LedgerImportField.inspectionExpiry], 0);
      expect(cols.values.toSet(), hasLength(cols.length));
    });

    group('Edge Cases', () {
      test('当たらない列名なら空', () {
        expect(guessColumns(['foo', 'bar']), isEmpty);
      });
    });
  });

  group('buildImportPlan', () {
    const header = [
      '顧客番号',
      '顧客名',
      'フリガナ',
      '電話番号',
      '登録番号',
      'メーカー',
      '車名',
      '車検満了日'
    ];
    final cols = guessColumns(header);

    test('同じ顧客番号の行は、1人の顧客の複数台にまとまる', () {
      final plan = buildImportPlan([
        [
          'C001',
          '株式会社サンプル運輸',
          'サンプルウンユ',
          '03-0000-0000',
          '品川400さ1',
          'トヨタ',
          'ハイエース',
          '2027/1/10'
        ],
        [
          'C001',
          '株式会社サンプル運輸',
          'サンプルウンユ',
          '03-0000-0000',
          '品川400さ2',
          'トヨタ',
          'ハイエース',
          '2026/11/5'
        ],
        [
          'C002',
          '山田太郎',
          'ヤマダタロウ',
          '090-0000-0000',
          '品川300あ1234',
          'MINI',
          'クーパー',
          'R8.12.1'
        ],
      ], cols);

      expect(plan.customers, hasLength(2));
      expect(plan.vehicleCount, 3);
      final corp = plan.customers.firstWhere((c) => c.externalId == 'C001');
      expect(corp.kind, LedgerCustomerKind.corporate); // 「株式会社」で判断
      expect(corp.vehicles, hasLength(2));
      final yamada = plan.customers.firstWhere((c) => c.externalId == 'C002');
      expect(yamada.kind, LedgerCustomerKind.individual);
      expect(yamada.vehicles.single.inspectionExpiry, DateTime(2026, 12, 1));
      expect(plan.problems, isEmpty);
    });

    test('顧客番号が無ければ、名前＋電話で同じ人とみなす', () {
      final noId = guessColumns(['顧客名', '電話番号', '車名']);
      final plan = buildImportPlan([
        ['山田太郎', '090-1111-2222', 'プリウス'],
        ['山田太郎', '090-1111-2222', 'アクア'],
        ['山田太郎', '090-9999-9999', 'ノート'], // 同姓同名の別人
      ], noId);
      expect(plan.customers, hasLength(2));
    });

    test('読めない日付は、何行目かを添えて知らせ、空欄で取り込む', () {
      final plan = buildImportPlan([
        ['C001', '山田', 'ヤマダ', '', '', 'トヨタ', 'プリウス', '2026/2/30'],
      ], cols);
      expect(plan.vehicleCount, 1);
      expect(plan.customers.single.vehicles.single.inspectionExpiry, isNull);
      expect(plan.problems.single.line, 2);
      expect(plan.problems.single.message, contains('2026/2/30'));
    });

    group('Edge Cases', () {
      test('顧客名が空の行は取り込まず、知らせる', () {
        final plan = buildImportPlan([
          ['C001', '', '', '', '', 'トヨタ', 'プリウス', ''],
        ], cols);
        expect(plan.customers, isEmpty);
        expect(plan.problems.single.message, contains('顧客名'));
      });

      test('車の列が全部空なら、顧客だけ取り込む', () {
        final plan = buildImportPlan([
          ['C001', '山田', 'ヤマダ', '', '', '', '', ''],
        ], cols);
        expect(plan.customers, hasLength(1));
        expect(plan.vehicleCount, 0);
        expect(plan.problems, isEmpty);
      });

      test('ナンバーはあるのに車名が無ければ、車両は取り込まず知らせる', () {
        final plan = buildImportPlan([
          ['C001', '山田', 'ヤマダ', '', '品川300あ1', '', '', ''],
        ], cols);
        expect(plan.vehicleCount, 0);
        expect(plan.problems.single.message, contains('車名'));
      });

      test('列が足りない行でも落ちない', () {
        final plan = buildImportPlan([
          ['C001', '山田'],
        ], cols);
        expect(plan.customers, hasLength(1));
      });

      test('行が無ければ空の計画', () {
        final plan = buildImportPlan(const [], cols);
        expect(plan.customers, isEmpty);
        expect(plan.rowCount, 0);
      });
    });
  });

  group('buildHistoryPlan', () {
    final cols = guessHistoryColumns(['伝票日付', '顧客コード', '作業区分', '税込金額']);

    test('列名の揺れを当て、金額の書き方の揺れを読む', () {
      final plan = buildHistoryPlan([
        ['R8.3.1', 'C001', '車検', '¥120,000'],
        ['2026/4/1', 'C001', 'オイル交換', '5,500円'],
        ['2026/5/1', 'C001', '', '\\3,000'], // Shift_JIS の円記号は \ になる
      ], cols);
      expect(plan.problems, isEmpty);
      expect(plan.rows.map((r) => r.total), [120000, 5500, 3000]);
      expect(plan.rows.first.date, DateTime(2026, 3, 1));
      // 作業内容が空なら「整備」
      expect(plan.rows.last.type, '整備');
    });

    group('Edge Cases', () {
      test('日付・金額が読めない行、車の手がかりが無い行は、理由つきで外す', () {
        final plan = buildHistoryPlan([
          ['', 'C001', '車検', '100'],
          ['2026/2/30', 'C001', '車検', '100'],
          ['2026/3/1', 'C001', '車検', 'サービス'],
          ['2026/3/1', '', '車検', '100'],
        ], cols);
        expect(plan.rows, isEmpty);
        expect(plan.problems.map((p) => p.line), [2, 3, 4, 5]);
      });

      test('マイナスの金額（返品・値引き伝票）は取り込まない', () {
        final plan = buildHistoryPlan([
          ['2026/3/1', 'C001', '値引き', '-1,000'],
        ], cols);
        expect(plan.rows, isEmpty);
      });
    });
  });
}
