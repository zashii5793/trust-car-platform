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

  // 2026-10-08 usability test: "青木" found 1 of many, "和也" / "カズヤ"
  // (given name) and a customer just registered by kanji found nothing,
  // and the screen then pushed "新しい顧客として追加" (duplicates).
  group('LedgerSearch.customerKeys', () {
    List<String> keys({
      String name = '青木 和也',
      String? kana = 'アオキ カズヤ',
      String? contact,
      String? phone,
    }) =>
        LedgerSearch.customerKeys(
          name: name,
          nameKana: kana,
          contactPerson: contact,
          phone: phone,
        );

    test('姓・名それぞれと、続けた形の、漢字とフリガナの前方一致を持つ', () {
      final k = keys();
      for (final q in ['青', '青木', '青木和', '青木和也', '和', '和也']) {
        expect(k, contains(LedgerSearch.nameKey(q)), reason: q);
      }
      for (final q in ['あお', 'あおき', 'あおきか', 'あおきかずや', 'かず', 'かずや']) {
        expect(k, contains(q), reason: q);
      }
      expect(k, isNot(contains('木')));
      expect(k, isNot(contains('ずや')));
    });

    test('法人の担当者名と、電話番号（数字だけ）でも引ける', () {
      final k = keys(
        name: '株式会社 吉備商事',
        kana: 'キビショウジ',
        contact: '配送 七郎',
        phone: '086-123-4567',
      );
      expect(k, contains('吉備'));
      expect(k, contains('七郎'));
      expect(k, contains('0861234'));
      expect(k, contains('0861234567'));
    });

    group('Edge Cases', () {
      test('フリガナが無くても名前で引ける。空の部分は入れない', () {
        final k = keys(name: '検証 一郎', kana: null);
        expect(k, contains('検証'));
        expect(k, contains('一郎'));
        expect(k, isNot(contains('')));
      });

      test('長い名前は先頭から上限の長さまで', () {
        final k = keys(name: 'あ' * 50, kana: null);
        expect(k.map((e) => e.length).reduce((a, b) => a > b ? a : b),
            LedgerSearch.maxPrefixLength);
      });

      test('区切りの多い長い名前でも、ルールの上限（200個）を超えない', () {
        final long = List.generate(12, (i) => '${'かきくけこ' * 4}$i').join(' ');
        final k = keys(name: long, kana: long, contact: long, phone: '0' * 30);
        expect(k.length, lessThanOrEqualTo(LedgerSearch.maxKeys));
        expect(LedgerSearch.maxKeys, 200);
      });

      test('同じキーは1つにまとめる', () {
        final k = keys(name: 'やまだ', kana: 'ヤマダ');
        expect(k.toSet().length, k.length);
      });
    });
  });

  group('LedgerSearch.queryKey', () {
    test('名前はそのまま正規化、電話番号らしい入力は数字だけにする', () {
      expect(LedgerSearch.queryKey('アオキ カズヤ'), 'あおきかずや');
      expect(LedgerSearch.queryKey('086-123'), '086123');
      expect(LedgerSearch.queryKey('０８６１２３'), '086123');
    });

    test('電話番号らしいのは、数字（と区切り）だけで5桁以上のとき', () {
      expect(LedgerSearch.isPhoneQuery('086-12'), isTrue);
      expect(LedgerSearch.isPhoneQuery('6335'), isFalse);
      expect(LedgerSearch.isPhoneQuery('品川300あ1234'), isFalse);
    });
  });

  group('LedgerSearch.plateTails', () {
    test('末尾の番号の、下2〜4桁を持つ', () {
      expect(LedgerSearch.plateTails('岡山 300 あ 63-35'),
          unorderedEquals(['35', '335', '6335']));
    });

    group('Edge Cases', () {
      test('番号が2桁以下なら、その番号だけ', () {
        expect(LedgerSearch.plateTails('岡山 300 あ ・・-12'), ['12']);
        expect(LedgerSearch.plateTails('岡山 300 あ ・・・5'), ['5']);
      });

      test('番号が無ければ空', () {
        expect(LedgerSearch.plateTails('岡山 あ'), isEmpty);
        expect(LedgerSearch.plateTails(''), isEmpty);
      });
    });
  });

  group('検索用の項目を文書に持たせる', () {
    test('顧客の toMap に searchKeys と版がある', () {
      final m = LedgerCustomer(
        id: 'c1',
        kind: LedgerCustomerKind.individual,
        name: '青木 和也',
        nameKana: 'アオキ カズヤ',
        phone: '090-1111-2222',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ).toMap();
      expect(m['searchKeys'], contains('和也'));
      expect(m['searchKeys'], contains('0901111'));
      expect(m['searchVersion'], LedgerSearch.version);
    });

    test('車の toMap に plateTails と版がある', () {
      final m = LedgerVehicle(
        id: 'v1',
        customerId: 'c1',
        customerName: 'x',
        plate: '岡山 300 あ 63-35',
        maker: 'トヨタ',
        model: 'プリウス',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ).toMap();
      expect(m['plateTails'], contains('35'));
      expect(m['searchVersion'], LedgerSearch.version);
    });
  });
}
