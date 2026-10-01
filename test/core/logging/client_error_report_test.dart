// ウェブ版の不具合1件分（client_errors に書く中身）。
//
// 誰でも書ける場所に置くので、**入力値・メール・電話・住所を持ち込まない**こと、
// 長さがルールの上限を超えないことをここで確かめる。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/core/logging/client_error_report.dart';

void main() {
  final now = DateTime.utc(2026, 9, 30, 12);

  ClientErrorReport build({
    Object error = 'boom',
    StackTrace? stackTrace,
    String source = ClientErrorReport.sourceFlutter,
    String buildId = 'a1b2c3d',
    Uri? url,
    String? userAgent = 'Mozilla/5.0',
    String? uid = 'user1',
  }) {
    return ClientErrorReport.from(
      error: error,
      stackTrace: stackTrace,
      source: source,
      buildId: buildId,
      url: url ?? Uri.parse('https://trust-car-platform.web.app/'),
      userAgent: userAgent,
      uid: uid,
    );
  }

  group('ClientErrorReport.from', () {
    test('エラーの文字列がメッセージになる', () {
      final r = build(error: StateError('壊れた'));
      expect(r.message, 'Bad state: 壊れた');
    });

    test('メッセージは1行目だけを使う（FlutterError の診断本文を持ち込まない）', () {
      final r =
          build(error: 'A RenderFlex overflowed\nThe widget was: Text("山田太郎")');
      expect(r.message, 'A RenderFlex overflowed');
    });

    test('スタックは行ごとに保持される', () {
      final r = build(stackTrace: StackTrace.fromString('#0 a\n#1 b\n#2 c'));
      expect(r.stack, '#0 a\n#1 b\n#2 c');
    });

    test('URL はパスだけを残し、クエリは落とす', () {
      final r = build(
        url: Uri.parse('https://trust-car-platform.web.app/shop?token=secret'),
      );
      expect(r.path, '/shop');
    });

    test('ハッシュ形式のルートはクエリを落として残す', () {
      final r = build(
        url: Uri.parse(
          'https://trust-car-platform.web.app/#/vehicles?email=a@b.jp',
        ),
      );
      expect(r.path, '/#/vehicles');
    });

    test('ビルド識別子・userAgent・uid・発生源が入る', () {
      final r = build(source: ClientErrorReport.sourceZone);
      expect(r.buildId, 'a1b2c3d');
      expect(r.userAgent, 'Mozilla/5.0');
      expect(r.uid, 'user1');
      expect(r.source, 'zone');
    });
  });

  group('個人情報を持ち込まない', () {
    test('メールアドレスは伏せる', () {
      final r = build(error: 'user taro.yamada@example.co.jp not found');
      expect(r.message, 'user [email] not found');
    });

    test('電話番号は伏せる', () {
      final r = build(error: 'invalid 090-1234-5678 / 0312345678');
      expect(r.message, 'invalid [number] / [number]');
    });

    test('郵便番号は伏せる', () {
      final r = build(error: 'zip 123-4567 invalid');
      expect(r.message, 'zip [number] invalid');
    });

    test('スタックの中のメールも伏せる', () {
      final r = build(stackTrace: StackTrace.fromString('#0 x a@b.jp'));
      expect(r.stack, '#0 x [email]');
    });

    test('短い数字（行番号・件数）は残す', () {
      final r = build(error: 'RangeError: index 12 out of 3');
      expect(r.message, 'RangeError: index 12 out of 3');
    });
  });

  group('toMap', () {
    test('ルールが許す項目だけを持つ', () {
      final map = build().toMap(now: now);
      expect(
        map.keys.toSet(),
        {
          'message',
          'stack',
          'source',
          'buildId',
          'path',
          'userAgent',
          'uid',
          'platform',
          'createdAt',
          'expireAt',
        },
      );
      expect(map['platform'], 'web');
      expect(map['createdAt'], FieldValue.serverTimestamp());
    });

    test('expireAt は保存期間ぶん先（TTL ポリシー用）', () {
      final map = build().toMap(now: now);
      expect(
        (map['expireAt'] as Timestamp).toDate().toUtc(),
        now.add(ClientErrorReport.retention),
      );
    });
  });

  group('Edge Cases', () {
    test('空のエラーは (empty) にする（ルールは空文字を弾く）', () {
      expect(build(error: '').message, '(empty)');
      expect(build(error: '   \n  ').message, '(empty)');
    });

    test('スタックが無ければ空文字', () {
      expect(build(stackTrace: null).stack, '');
    });

    test('メッセージは上限で切る', () {
      final r = build(error: 'あ' * (ClientErrorReport.maxMessageLength + 50));
      expect(r.message.length, ClientErrorReport.maxMessageLength);
    });

    test('スタックは先頭の行数だけ残す', () {
      final lines = List.generate(100, (i) => '#$i frame');
      final r = build(stackTrace: StackTrace.fromString(lines.join('\n')));
      expect(r.stack.split('\n').length, ClientErrorReport.maxStackLines);
      expect(r.stack.split('\n').first, '#0 frame');
    });

    test('スタックは文字数の上限でも切る', () {
      final longLine = 'x' * 1000;
      final r = build(
        stackTrace: StackTrace.fromString(List.filled(20, longLine).join('\n')),
      );
      expect(
          r.stack.length, lessThanOrEqualTo(ClientErrorReport.maxStackLength));
    });

    test('userAgent は上限で切り、空なら null', () {
      final long = build(userAgent: 'u' * 1000);
      expect(long.userAgent!.length, ClientErrorReport.maxUserAgentLength);
      expect(build(userAgent: '').userAgent, isNull);
      expect(build(userAgent: null).userAgent, isNull);
    });

    test('パスは上限で切り、空なら /', () {
      final long = build(
        url: Uri.parse('https://x.example/${'p' * 1000}'),
      );
      expect(long.path.length, ClientErrorReport.maxPathLength);
      expect(build(url: Uri.parse('https://x.example')).path, '/');
    });

    test('ビルド識別子が空（flutter run）でも unknown で送れる', () {
      expect(build(buildId: '').buildId, 'unknown');
      expect(
        build(buildId: 'b' * 100).buildId.length,
        ClientErrorReport.maxBuildIdLength,
      );
    });

    test('未ログインなら uid は null、空文字も null', () {
      expect(build(uid: null).uid, isNull);
      expect(build(uid: '').uid, isNull);
      expect(build(uid: null).toMap(now: now)['uid'], isNull);
    });

    test('toString が例外を投げるエラーでも作れる', () {
      final r = build(error: _ThrowingToString());
      expect(r.message, isNotEmpty);
    });
  });
}

class _ThrowingToString {
  @override
  String toString() => throw StateError('toString failed');
}
