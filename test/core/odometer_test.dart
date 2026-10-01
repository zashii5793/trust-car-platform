// 走行距離（オドメーター）の連続性を見る。
//
// なぜ要るか:
//   このアプリの整備記録は、溜まって初めて価値が出る。売却時に「記録が
//   あるから安心」と言えるかどうかは、**数字が筋の通った並びになっているか**
//   にかかっている。オドメーターが行ったり来たりしている記録は、査定でも
//   次のオーナーでも信用されない。
//
//   2026-09-22 時点では、検査は画面ごとにバラバラに入っていた:
//     - 車両詳細の走行距離更新   逆行したら確認ダイアログ（押し切れば通る）
//     - 整備記録の追加           負値・200万km超・車両の現在距離超過を拒否
//     - 給油の追加               **検査なし**（前回値をヒント表示するだけ）
//     - マイルストーン検出       逆行を黙って読み飛ばす
//   給油と整備を突き合わせる仕組みは無かった。
//
//   ここに集めて、純粋な関数として固定する。

import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/core/utils/odometer.dart';

void main() {
  group('OdometerCheck.against — 直前の値との比較', () {
    test('増えていれば問題なし', () {
      final r = OdometerCheck.against(value: 12000, previous: 11000);
      expect(r.severity, OdometerIssue.none);
      expect(r.hasProblem, isFalse);
    });

    test('前回と同じなら問題なし（同日に2件入れることはある）', () {
      final r = OdometerCheck.against(value: 12000, previous: 12000);
      expect(r.severity, OdometerIssue.none);
    });

    test('前回より減っていれば逆行', () {
      final r = OdometerCheck.against(value: 11000, previous: 12000);
      expect(r.severity, OdometerIssue.wentBackwards);
      expect(r.message, contains('前回'));
    });

    test('比較相手が無ければ、値そのものだけを見る', () {
      expect(
        OdometerCheck.against(value: 12000, previous: null).severity,
        OdometerIssue.none,
      );
    });
  });

  group('OdometerCheck.against — 値そのものの妥当性', () {
    test('負の値は拒否', () {
      final r = OdometerCheck.against(value: -1, previous: null);
      expect(r.severity, OdometerIssue.outOfRange);
    });

    test('200万kmを超える値は拒否（桁の打ち間違い）', () {
      final r = OdometerCheck.against(value: 2000001, previous: null);
      expect(r.severity, OdometerIssue.outOfRange);
      expect(r.message, contains('桁'));
    });

    test('200万km ちょうどは通す', () {
      expect(
        OdometerCheck.against(value: 2000000, previous: null).severity,
        OdometerIssue.none,
      );
    });
  });

  group('OdometerCheck.against — 不自然な飛び', () {
    test('1日で2,000kmを超える増加は確認を促す', () {
      final r = OdometerCheck.against(
        value: 15000,
        previous: 12000,
        elapsed: const Duration(days: 1),
      );
      expect(r.severity, OdometerIssue.implausibleJump);
      expect(r.hasProblem, isTrue);
    });

    test('日数が経っていれば同じ増加でも問題にしない', () {
      final r = OdometerCheck.against(
        value: 15000,
        previous: 12000,
        elapsed: const Duration(days: 30),
      );
      expect(r.severity, OdometerIssue.none);
    });

    test('経過が分からなければ飛びは見ない', () {
      final r = OdometerCheck.against(value: 15000, previous: 12000);
      expect(r.severity, OdometerIssue.none);
    });

    group('Edge Cases', () {
      test('経過0日でも、増加が小さければ通す（同日の給油と整備）', () {
        final r = OdometerCheck.against(
          value: 12050,
          previous: 12000,
          elapsed: Duration.zero,
        );
        expect(r.severity, OdometerIssue.none);
      });

      test('経過0日で大きく飛べば確認を促す', () {
        final r = OdometerCheck.against(
          value: 20000,
          previous: 12000,
          elapsed: Duration.zero,
        );
        expect(r.severity, OdometerIssue.implausibleJump);
      });

      test('逆行と範囲外が重なったら、範囲外を先に言う', () {
        final r = OdometerCheck.against(value: -5, previous: 12000);
        expect(r.severity, OdometerIssue.outOfRange);
      });
    });
  });

  group('OdometerIssue の扱い', () {
    test('逆行と飛びは「止める」ではなく「確認させる」', () {
      // メーター交換や乗せ替えで実際に戻ることがある。拒否すると
      // 正しい記録が残せなくなるので、blocking にはしない。
      expect(OdometerIssue.wentBackwards.isBlocking, isFalse);
      expect(OdometerIssue.implausibleJump.isBlocking, isFalse);
    });

    test('範囲外は止める（桁の打ち間違い）', () {
      expect(OdometerIssue.outOfRange.isBlocking, isTrue);
    });
  });
}
