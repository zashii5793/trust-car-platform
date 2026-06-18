// ShowcaseDetailScreen Widget Tests
//
// 投稿詳細＋コメントスレッドの描画と、コメント投稿/削除の導線を検証する。
// PopularAccessoriesService は FakeFirebaseFirestore で差し替える。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/models/accessory_showcase.dart';
import 'package:trust_car_platform/screens/accessories/showcase_detail_screen.dart';
import 'package:trust_car_platform/services/popular_accessories_service.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late PopularAccessoriesService service;

  final showcase = AccessoryShowcase(
    id: 'sc-1',
    userId: 'owner',
    category: AccessoryCategory.electronics,
    itemName: 'Vantrue N2 Pro',
    brand: 'Vantrue',
    rating: 5,
    review: '夜間も鮮明で取り付けも簡単でした。',
    createdAt: DateTime(2026, 1, 1),
  );

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    service = PopularAccessoriesService(firestore: firestore);
    await firestore
        .collection('accessory_showcases')
        .doc('sc-1')
        .set(showcase.toMap());
  });

  Future<void> seedComment(String id, String userId, String content) async {
    await firestore
        .collection('accessory_showcases')
        .doc('sc-1')
        .collection('comments')
        .doc(id)
        .set({
      'showcaseId': 'sc-1',
      'userId': userId,
      'content': content,
      'createdAt': Timestamp.fromDate(DateTime(2026, 1, 2)),
    });
  }

  Widget buildUnderTest({String currentUserId = 'viewer'}) {
    return MaterialApp(
      home: ShowcaseDetailScreen(
        showcase: showcase,
        service: service,
        currentUserId: currentUserId,
      ),
    );
  }

  testWidgets('投稿のアイテム名とレビューが表示される', (tester) async {
    await tester.pumpWidget(buildUnderTest());
    await tester.pumpAndSettle();

    expect(find.text('Vantrue N2 Pro'), findsWidgets);
    expect(find.text('夜間も鮮明で取り付けも簡単でした。'), findsOneWidget);
  });

  testWidgets('既存コメントが表示される', (tester) async {
    await seedComment('c1', 'someone', '私も使っています！');
    await tester.pumpWidget(buildUnderTest());
    await tester.pumpAndSettle();

    expect(find.text('私も使っています！'), findsOneWidget);
  });

  testWidgets('コメント件数がヘッダーに表示される', (tester) async {
    await seedComment('c1', 'a', 'コメント1');
    await seedComment('c2', 'b', 'コメント2');
    await tester.pumpWidget(buildUnderTest());
    await tester.pumpAndSettle();

    expect(find.text('コメント (2)'), findsOneWidget);
  });

  testWidgets('コメントがない場合は空メッセージを表示', (tester) async {
    await tester.pumpWidget(buildUnderTest());
    await tester.pumpAndSettle();

    expect(find.textContaining('まだコメントがありません'), findsOneWidget);
  });

  testWidgets('コメントを投稿すると一覧に追加される', (tester) async {
    await tester.pumpWidget(buildUnderTest(currentUserId: 'viewer'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('showcase_comment_input')),
      'とても参考になりました',
    );
    await tester.tap(find.byKey(const Key('showcase_comment_send')));
    await tester.pumpAndSettle();

    expect(find.text('とても参考になりました'), findsOneWidget);

    // Firestore にも保存されている
    final snap = await firestore
        .collection('accessory_showcases')
        .doc('sc-1')
        .collection('comments')
        .get();
    expect(snap.docs, hasLength(1));
    expect(snap.docs.first.data()['userId'], 'viewer');
  });

  testWidgets('自分のコメントには削除ボタンが表示される', (tester) async {
    await seedComment('mine', 'viewer', '自分のコメント');
    await tester.pumpWidget(buildUnderTest(currentUserId: 'viewer'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('delete_comment_mine')), findsOneWidget);
  });

  testWidgets('他人のコメントには削除ボタンが表示されない', (tester) async {
    await seedComment('theirs', 'other', '他人のコメント');
    await tester.pumpWidget(buildUnderTest(currentUserId: 'viewer'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('delete_comment_theirs')), findsNothing);
  });
}
