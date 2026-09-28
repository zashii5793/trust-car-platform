import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/gen_policy_texts.dart' as gen;

/// アプリ内の規約・プライバシーポリシーが、Web 版（正本）と同じか。
///
/// 2026-09-29 まで、アプリ内の文面は手で写していて、規約第12条（退会後の
/// データ）とプライバシーポリシーの章の構成が Web 版とずれていた。
/// 落ちたら web/*.html を直したあとで `dart run tool/gen_policy_texts.dart`。
void main() {
  test('アプリ内の文面（生成物）が web/*.html から作ったものと同じ', () {
    final generated = File(gen.outputPath).readAsStringSync();
    final fresh = gen.generate();
    String squash(String s) => s.replaceAll(RegExp(r'\s+'), '');
    expect(
      squash(generated),
      squash(fresh),
      reason:
          'web/*.html が変わっています。dart run tool/gen_policy_texts.dart で作り直してください',
    );
  });

  test('退会後のデータの扱いが、実装（猶予なしの削除）と合っている', () {
    final terms =
        gen.parsePolicyHtml(File('web/terms.html').readAsStringSync());
    final withdrawal = terms.sections.firstWhere((s) => s.title.contains('退会'));
    expect(withdrawal.content, contains('猶予期間はありません'));
    expect(withdrawal.content, isNot(contains('30日間はデータが保持')));
  });

  test('web/ と docs/web/ の規約・ポリシーは同じ内容', () {
    for (final name in ['terms.html', 'privacy.html']) {
      expect(
        File('docs/web/$name').readAsStringSync(),
        File('web/$name').readAsStringSync(),
        reason: name,
      );
    }
  });
}
