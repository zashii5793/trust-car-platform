import 'package:flutter_test/flutter_test.dart';

import '../../tool/check_test_assertions.dart' as checker;

/// tool/check_test_assertions.dart（確かめの無いテストを拾う道具）のテスト。
///
/// 2026-09-20 に integration_test/year_of_use_app_test.dart が「All tests passed」
/// のままログイン画面を撮っていた（Issue #203）。手順がすべて if で囲われていて、
/// expect が1つも無かった。この道具はそういうテストを CI で止める。
///
/// ここのテストの入力は「テストファイルの中身」を文字列で持つ。中身に書く
/// test( / expect( は検査対象の文字列であって、このファイル自身のテストではない。
void main() {
  List<checker.Finding> find(String source, {Set<String> helpers = const {}}) =>
      checker.findAssertionFreeTests(
        source,
        path: 'x_test.dart',
        sharedHelpers: helpers,
      );

  group('確かめの有無', () {
    test('expect が無い test を拾う', () {
      const src = '''
void main() {
  test('何もしない', () {
    final a = 1 + 1;
    print(a);
  });
}
''';
      final found = find(src);
      expect(found, hasLength(1));
      expect(found.single.line, 2);
      expect(found.single.kind, 'test');
      expect(found.single.name, contains('何もしない'));
    });

    test('expect がある test は拾わない', () {
      const src = '''
void main() {
  test('足し算', () {
    expect(1 + 1, 2);
  });
}
''';
      expect(find(src), isEmpty);
    });

    test('testWidgets も対象にする', () {
      const src = '''
void main() {
  testWidgets('描画だけ', (tester) async {
    await tester.pumpWidget(const SizedBox());
  });
}
''';
      final found = find(src);
      expect(found, hasLength(1));
      expect(found.single.kind, 'testWidgets');
    });

    for (final call in [
      'expectLater(f(), completes)',
      'verify(mock.save()).called(1)',
      'verifyNever(mock.save())',
      'verifyInOrder([mock.a(), mock.b()])',
      "fail('来てはいけない')",
      'assert(x > 0)',
      'expectNoOverflow(tester)',
      '_expectShown(tester)',
      'robot.expectLoggedIn()',
    ]) {
      test('$call を確かめとして数える', () {
        final src = '''
void main() {
  test('t', () async {
    $call;
  });
}
''';
        expect(find(src), isEmpty);
      });
    }

    test('同じファイルの、expect を持つ補助関数の呼び出しは確かめとして数える', () {
      const src = '''
Future<void> _checkHome(WidgetTester tester) async {
  expect(find.text('ホーム'), findsOneWidget);
}

void main() {
  testWidgets('ホームが出る', (tester) async {
    await _checkHome(tester);
  });
}
''';
      expect(find(src), isEmpty);
    });

    test('補助関数の補助関数（2段）でも辿る', () {
      const src = '''
void _inner() { expect(1, 1); }
void _outer() => _inner();

void main() {
  test('t', () { _outer(); });
}
''';
      expect(find(src), isEmpty);
    });

    test('expect を持たない補助関数を呼ぶだけでは確かめにならない', () {
      const src = '''
Future<void> _tapAll(WidgetTester tester) async {
  await tester.tap(find.byType(ElevatedButton));
}

void main() {
  testWidgets('押すだけ', (tester) async {
    await _tapAll(tester);
  });
}
''';
      expect(find(src), hasLength(1));
    });

    test('ほかのファイルの補助関数（公開名）は sharedHelpers で数える', () {
      const src = '''
void main() {
  testWidgets('t', (tester) async {
    await pumpAndCheckLayout(tester);
  });
}
''';
      expect(find(src), hasLength(1));
      expect(find(src, helpers: {'pumpAndCheckLayout'}), isEmpty);
    });

    test('collectHelperNames は expect を持つ公開関数の名前だけを返す', () {
      const src = '''
Future<void> pumpAndCheckLayout(WidgetTester t) async {
  expect(t.takeException(), isNull);
}
Widget buildApp() => const SizedBox();
void _privateCheck() { expect(1, 1); }
''';
      expect(checker.collectHelperNames(src), {'pumpAndCheckLayout'});
    });

    test('複数のテストのうち、確かめの無いものだけを拾う', () {
      const src = '''
void main() {
  group('g', () {
    test('a', () { expect(1, 1); });
    test('b', () { print(1); });
    test('c', () { expect(2, 2); });
  });
}
''';
      final found = find(src);
      expect(found.map((f) => f.line), [4]);
    });
  });

  group('Edge Cases', () {
    test('コメントの中の expect は数えない', () {
      const src = '''
void main() {
  test('t', () {
    // expect(1, 1);
    /* expect(2, 2); /* 入れ子 */ expect(3, 3); */
    print(1);
  });
}
''';
      expect(find(src), hasLength(1));
    });

    test('文字列の中の expect は数えない', () {
      const src = r'''
void main() {
  test('expect(1, 1) という名前', () {
    print('expect(1, 1)');
    print("""
expect(2, 2)
""");
    print(r'expect(3, 3)');
  });
}
''';
      expect(find(src), hasLength(1));
    });

    test('文字列や補間の中の括弧で範囲がずれない', () {
      const src = r'''
void main() {
  test('a', () {
    final m = {'k': 1};
    print('(((${m['k']}){{');
    print("}}) ${'}'}");
  });
  test('b', () {
    expect(1, 1);
  });
}
''';
      final found = find(src);
      expect(found.map((f) => f.name), [contains("'a'")]);
    });

    test('メソッド呼び出しの .test( や test という名前の関数宣言は対象外', () {
      const src = '''
void test2() {}
void main() {
  final r = RegExp('a');
  r.test('x');
  attest('y', () {});
}
''';
      expect(find(src), isEmpty);
    });

    test('関数参照を渡す test（本体が見えない）は拾う', () {
      // 本体が別の場所にあると確かめの有無を判断できない。無難に倒して拾う
      const src = '''
void _body() {}
void main() {
  test('t', _body);
}
''';
      expect(find(src), hasLength(1));
    });

    test('expected や verifyLater のような変数名・別名だけでは数えない', () {
      const src = '''
void main() {
  test('t', () {
    final expected = 1;
    final verified = expected;
    print(verified);
  });
}
''';
      expect(find(src), hasLength(1));
    });

    test('空のファイルや test の無いファイルでも落ちない', () {
      expect(find(''), isEmpty);
      expect(find('void main() {}'), isEmpty);
    });

    test('閉じていない文字列や括弧があっても落ちない', () {
      expect(
          () => find("void main() { test('t', () { print('a"), returnsNormally);
    });
  });
}
