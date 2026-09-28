import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/models/shop_ledger.dart';

void main() {
  group('LedgerSearch.nameKey', () {
    test('カタカナ・ひらがな・半角カナが同じキーになる', () {
      final a = LedgerSearch.nameKey('ヤマダ タロウ');
      final b = LedgerSearch.nameKey('やまだ　たろう');
      final c = LedgerSearch.nameKey('ﾔﾏﾀﾞ ﾀﾛｳ');
      expect(a, 'やまだたろう');
      expect(b, a);
      expect(c, a);
    });

    test('半角カナの半濁点を結合する', () {
      expect(LedgerSearch.nameKey('ﾊﾟｰﾂ'), 'ぱーつ');
    });

    test('全角英字は半角の小文字になる', () {
      expect(LedgerSearch.nameKey('ＴＡＫＡＹＡ'), 'takaya');
    });

    group('Edge Cases', () {
      test('空文字は空文字', () {
        expect(LedgerSearch.nameKey(''), '');
      });

      test('空白だけなら空文字', () {
        expect(LedgerSearch.nameKey(' 　 '), '');
      });
    });
  });

  group('LedgerSearch.plateKey / plateNumber', () {
    test('区切りと全角の揺れを揃える', () {
      expect(LedgerSearch.plateKey('品川 300 あ 12-34'), '品川300あ1234');
      expect(LedgerSearch.plateKey('品川３００あ１２－３４'), '品川300あ1234');
    });

    test('末尾の番号だけを取り出す', () {
      expect(LedgerSearch.plateNumber('品川 300 あ 12-34'), '1234');
      expect(LedgerSearch.plateNumber('12-34'), '1234');
      expect(LedgerSearch.plateNumber('１２ー３４'), '1234');
    });

    group('Edge Cases', () {
      test('数字が無ければ null', () {
        expect(LedgerSearch.plateNumber('品川あ'), isNull);
        expect(LedgerSearch.plateNumber(''), isNull);
      });

      test('1桁の番号（・・・1）も引ける', () {
        expect(LedgerSearch.plateNumber('品川 300 あ ・・・1'), '1');
      });
    });
  });

  group('LedgerCustomerSummary.of', () {
    final today = DateTime(2026, 9, 27);
    LedgerVehicle v(String id, {DateTime? exp, DateTime? visit}) =>
        LedgerVehicle(
          id: id,
          customerId: 'c1',
          customerName: '山田',
          maker: 'トヨタ',
          model: 'ハイエース',
          inspectionExpiry: exp,
          lastVisitAt: visit,
          createdAt: today,
          updatedAt: today,
        );

    test('次の車検は、まだ来ていない満了日のうち最も近いもの', () {
      final s = LedgerCustomerSummary.of([
        v('a', exp: DateTime(2027, 3, 1)),
        v('b', exp: DateTime(2026, 11, 5)),
        v('c', exp: DateTime(2026, 8, 1)), // 切れている
      ], today: today);
      expect(s.vehicleCount, 3);
      expect(s.nextInspectionAt, DateTime(2026, 11, 5));
    });

    test('最終来店は、車両のうち最も新しい日', () {
      final s = LedgerCustomerSummary.of([
        v('a', visit: DateTime(2026, 1, 1)),
        v('b', visit: DateTime(2026, 6, 1)),
      ], today: today);
      expect(s.lastVisitAt, DateTime(2026, 6, 1));
    });

    test('今日が満了日の車検は、次の車検に数える', () {
      final s = LedgerCustomerSummary.of(
        [v('a', exp: DateTime(2026, 9, 27))],
        today: DateTime(2026, 9, 27, 15),
      );
      expect(s.nextInspectionAt, DateTime(2026, 9, 27));
    });

    group('Edge Cases', () {
      test('車両が無ければ0台・日付なし', () {
        final s = LedgerCustomerSummary.of(const [], today: today);
        expect(s.vehicleCount, 0);
        expect(s.nextInspectionAt, isNull);
        expect(s.lastVisitAt, isNull);
      });

      test('全部切れていれば次の車検は null', () {
        final s = LedgerCustomerSummary.of(
          [v('a', exp: DateTime(2025, 1, 1))],
          today: today,
        );
        expect(s.nextInspectionAt, isNull);
      });
    });
  });

  group('LedgerCustomer', () {
    test('検索キーはフリガナを優先する', () {
      final c = LedgerCustomer(
        id: 'c1',
        kind: LedgerCustomerKind.individual,
        name: '山田太郎',
        nameKana: 'ヤマダタロウ',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      expect(c.searchKey, 'やまだたろう');
    });

    test('フリガナが空欄なら、名前から検索キーを作る', () {
      // 画面のフォームは、未入力でも空文字を渡してくる
      final c = LedgerCustomer(
        id: 'c1',
        kind: LedgerCustomerKind.individual,
        name: 'タカヤ',
        nameKana: '',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      expect(c.searchKey, 'たかや');
    });

    test('toMap → fromMap で同じ内容に戻る', () {
      final c = LedgerCustomer(
        id: 'c1',
        kind: LedgerCustomerKind.corporate,
        name: '株式会社サンプル運輸',
        nameKana: 'サンプルウンユ',
        contactPerson: '総務 佐藤',
        phone: '03-0000-0000',
        vehicleCount: 12,
        nextInspectionAt: DateTime(2026, 12, 1),
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 2, 1),
      );
      final back = LedgerCustomer.fromMap('c1', c.toMap());
      expect(back.kind, LedgerCustomerKind.corporate);
      expect(back.name, c.name);
      expect(back.contactPerson, '総務 佐藤');
      expect(back.vehicleCount, 12);
      expect(back.nextInspectionAt, DateTime(2026, 12, 1));
      expect(back.isLinked, isFalse);
    });

    group('Edge Cases', () {
      test('空白だけの任意項目は保存しない', () {
        final c = LedgerCustomer(
          id: 'c1',
          kind: LedgerCustomerKind.individual,
          name: '山田',
          phone: '   ',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        );
        expect(c.toMap()['phone'], isNull);
      });

      test('知らない区分は個人として読む', () {
        final c =
            LedgerCustomer.fromMap('c1', {'kind': 'unknown', 'name': 'x'});
        expect(c.kind, LedgerCustomerKind.individual);
      });
    });
  });
}
