import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/screens/notifications/social_notification_screen.dart';
import 'package:trust_car_platform/services/follow_service.dart';
import 'package:trust_car_platform/services/popular_accessories_service.dart';
import 'package:trust_car_platform/services/post_service.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late FollowService followService;
  late PopularAccessoriesService showcaseService;
  late PostService postService;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    followService = FollowService(firestore: firestore);
    showcaseService = PopularAccessoriesService(firestore: firestore);
    postService = PostService(firestore: firestore);
  });

  Widget buildScreen() => MaterialApp(
        home: SocialNotificationScreen(
          userId: 'me',
          followService: followService,
          showcaseService: showcaseService,
          postService: postService,
        ),
      );

  Future<void> seedNotification({
    String id = 'n1',
    String type = 'comment',
    String? showcaseId,
    String? postId,
    bool isRead = false,
  }) async {
    await firestore.collection('social_notifications').doc(id).set({
      'userId': 'me',
      'actorId': 'other',
      'actorDisplayName': 'タロウ',
      'type': type,
      if (showcaseId != null) 'showcaseId': showcaseId,
      if (postId != null) 'postId': postId,
      'commentId': 'c1',
      'previewText': 'いいコメント',
      'isRead': isRead,
      'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
    });
  }

  testWidgets('通知が一覧に表示される', (tester) async {
    await seedNotification(showcaseId: 'sc-1');
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.textContaining('タロウ'), findsOneWidget);
    expect(find.text('いいコメント'), findsOneWidget);
  });

  testWidgets('通知が無ければ空状態を表示する', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('通知はありません'), findsOneWidget);
  });

  testWidgets('タップで既読化し、対象が存在しなければ案内を表示する', (tester) async {
    // showcase 本体は seed しない → getShowcaseById は notFound。
    await seedNotification(showcaseId: 'missing-sc');
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('タロウ'));
    await tester.pumpAndSettle();

    // 既読化された。
    final doc =
        await firestore.collection('social_notifications').doc('n1').get();
    expect(doc.data()!['isRead'], isTrue);

    // 削除済みの案内 SnackBar が出る（画面遷移はしない）。
    expect(find.textContaining('削除された可能性'), findsOneWidget);
  });

  testWidgets('「すべて既読」で未読が既読になる', (tester) async {
    await seedNotification(id: 'n1', showcaseId: 'sc-1');
    await seedNotification(id: 'n2', postId: 'p1');
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.text('すべて既読'));
    await tester.pumpAndSettle();

    final snap = await firestore
        .collection('social_notifications')
        .where('isRead', isEqualTo: false)
        .get();
    expect(snap.docs, isEmpty);
  });
}
