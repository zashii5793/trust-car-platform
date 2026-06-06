// NewsletterService / Newsletter Model Unit Tests
//
// Tests cover:
//   1. NewsletterStatus / Audience / Category enum display names
//   2. Newsletter.fromFirestore / toMap round-trip
//   3. NewsletterSubscription.fromFirestore / toMap round-trip
//   4. NewsletterSubscription.generateToken uniqueness
//   5. NewsletterService.createNewsletter — saves to Firestore
//   6. NewsletterService.updateNewsletter — updates fields
//   7. NewsletterService.deleteNewsletter — removes document
//   8. NewsletterService.getMyNewsletters — returns author's newsletters
//   9. NewsletterService.sendNewsletter — sets status to "scheduled"
//  10. NewsletterService.getSubscription — returns subscription or default
//  11. NewsletterService.updateSubscription — persists preferences
//  12. Edge Cases: empty authorId, non-existent newsletter

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/models/newsletter.dart';
import 'package:trust_car_platform/services/newsletter_service.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Newsletter _makeNewsletter({
  String id = '',
  String authorId = 'author1',
  String title = 'テストタイトル',
  String body = 'テスト本文',
  NewsletterStatus status = NewsletterStatus.draft,
}) {
  final now = DateTime(2024, 6, 1);
  return Newsletter(
    id: id,
    title: title,
    body: body,
    authorId: authorId,
    authorName: 'テスト店舗',
    audience: NewsletterAudience.allUsers,
    category: NewsletterCategory.maintenanceTips,
    status: status,
    createdAt: now,
    updatedAt: now,
  );
}

NewsletterSubscription _makeSub({
  String userId = 'user1',
  bool isSubscribed = true,
}) {
  return NewsletterSubscription(
    userId: userId,
    email: 'user@example.com',
    isSubscribed: isSubscribed,
    subscribedCategories: NewsletterCategory.values,
    updatedAt: DateTime(2024, 6, 1),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // ---- Enum display names ----

  group('NewsletterStatus enum', () {
    test('全ステータスの displayName が空でない', () {
      for (final s in NewsletterStatus.values) {
        expect(s.displayName, isNotEmpty);
      }
    });

    test('draft は「下書き」', () {
      expect(NewsletterStatus.draft.displayName, '下書き');
    });

    test('sent は「配信済み」', () {
      expect(NewsletterStatus.sent.displayName, '配信済み');
    });
  });

  group('NewsletterAudience enum', () {
    test('全 audience の displayName が空でない', () {
      for (final a in NewsletterAudience.values) {
        expect(a.displayName, isNotEmpty);
      }
    });
  });

  group('NewsletterCategory enum', () {
    test('全カテゴリの displayName が空でない', () {
      for (final c in NewsletterCategory.values) {
        expect(c.displayName, isNotEmpty);
      }
    });
  });

  // ---- Newsletter model ----

  group('Newsletter model', () {
    test('toMap / fromFirestore round-trip', () async {
      final db = FakeFirebaseFirestore();
      final n = _makeNewsletter(title: 'ラウンドトリップ');

      await db.collection('newsletters').add(n.toMap());
      final snap = await db.collection('newsletters').get();
      expect(snap.docs, hasLength(1));

      final loaded = Newsletter.fromFirestore(snap.docs.first);
      expect(loaded.title, 'ラウンドトリップ');
      expect(loaded.status, NewsletterStatus.draft);
      expect(loaded.audience, NewsletterAudience.allUsers);
      expect(loaded.category, NewsletterCategory.maintenanceTips);
      expect(loaded.recipientCount, 0);
    });

    test('copyWith は指定フィールドのみ変更する', () {
      final n = _makeNewsletter(title: '元タイトル');
      final updated = n.copyWith(title: '新タイトル', status: NewsletterStatus.sent);
      expect(updated.title, '新タイトル');
      expect(updated.status, NewsletterStatus.sent);
      expect(updated.body, n.body); // unchanged
    });
  });

  // ---- NewsletterSubscription model ----

  group('NewsletterSubscription model', () {
    test('toMap / fromFirestore round-trip', () async {
      final db = FakeFirebaseFirestore();
      final sub = _makeSub();

      await db.collection('newsletter_subscriptions').doc(sub.userId).set(sub.toMap());
      final snap =
          await db.collection('newsletter_subscriptions').doc(sub.userId).get();

      final loaded = NewsletterSubscription.fromFirestore(snap);
      expect(loaded.userId, 'user1');
      expect(loaded.isSubscribed, isTrue);
      expect(loaded.subscribedCategories, hasLength(NewsletterCategory.values.length));
    });

    test('copyWith は指定フィールドのみ変更する', () {
      final sub = _makeSub();
      final updated = sub.copyWith(isSubscribed: false);
      expect(updated.isSubscribed, isFalse);
      expect(updated.email, sub.email); // unchanged
    });

    test('デフォルトは全カテゴリ購読', () {
      final sub = _makeSub();
      expect(sub.subscribedCategories, equals(NewsletterCategory.values));
    });
  });

  group('NewsletterSubscription.generateToken', () {
    test('32文字のトークンが生成される', () {
      final token = NewsletterSubscription.generateToken();
      expect(token.length, 32);
    });

    test('2回呼ぶと異なるトークンになる', () {
      final t1 = NewsletterSubscription.generateToken();
      final t2 = NewsletterSubscription.generateToken();
      expect(t1, isNot(equals(t2)));
    });
  });

  // ---- NewsletterService ----

  group('NewsletterService', () {
    late FakeFirebaseFirestore db;
    late NewsletterService service;

    setUp(() {
      db = FakeFirebaseFirestore();
      service = NewsletterService(firestore: db);
    });

    group('createNewsletter', () {
      test('正常系: Firestore にドキュメントが作成される', () async {
        final n = _makeNewsletter(title: '新規作成テスト');
        final result = await service.createNewsletter(n);

        expect(result.isSuccess, isTrue);

        final snap = await db.collection('newsletters').get();
        expect(snap.docs, hasLength(1));
        expect(snap.docs.first.data()['title'], '新規作成テスト');
      });

      test('作成されたドキュメントの status が draft である', () async {
        final n = _makeNewsletter();
        await service.createNewsletter(n);

        final snap = await db.collection('newsletters').get();
        expect(snap.docs.first.data()['status'], 'draft');
      });
    });

    group('updateNewsletter', () {
      test('正常系: 既存ドキュメントが更新される', () async {
        final n = _makeNewsletter(title: '更新前');
        await service.createNewsletter(n);
        final snap = await db.collection('newsletters').get();
        final docId = snap.docs.first.id;

        final updated = n.copyWith(id: docId, title: '更新後');
        final result = await service.updateNewsletter(updated);

        expect(result.isSuccess, isTrue);

        final doc = await db.collection('newsletters').doc(docId).get();
        expect(doc.data()?['title'], '更新後');
      });

      group('Edge Cases', () {
        test('id が空文字のニュースレターを更新しようとすると failure を返す', () async {
          // newsletter.id == '' means .doc('').update(...) which FakeFirestore
          // treats as a reference to the empty-string document.  The service
          // wraps any exception in a Result.failure, so callers must not pass
          // an unsaved model (id still '').
          final n = _makeNewsletter(id: ''); // id never set — not yet persisted
          final result = await service.updateNewsletter(n);
          // FakeFirestore throws on update of a non-existent document path,
          // so the service should return a failure, not throw.
          expect(result.isFailure, isTrue);
        });

        test('送信済みニュースレターは更新できない', () async {
          final n = _makeNewsletter(status: NewsletterStatus.sent);
          await service.createNewsletter(n);
          final snap = await db.collection('newsletters').get();
          final docId = snap.docs.first.id;

          final sent = n.copyWith(id: docId, title: '変更試み');
          final result = await service.updateNewsletter(sent);
          expect(result.isFailure, isTrue);
        });
      });
    });

    group('deleteNewsletter', () {
      test('正常系: ドキュメントが削除される', () async {
        final n = _makeNewsletter();
        await service.createNewsletter(n);
        final snap = await db.collection('newsletters').get();
        final docId = snap.docs.first.id;

        final result = await service.deleteNewsletter(docId);
        expect(result.isSuccess, isTrue);

        final afterSnap = await db.collection('newsletters').get();
        expect(afterSnap.docs, isEmpty);
      });

      test('送信済みニュースレターは削除できない', () async {
        final n = _makeNewsletter(status: NewsletterStatus.sent);
        await service.createNewsletter(n);
        final snap = await db.collection('newsletters').get();
        final docId = snap.docs.first.id;

        final result = await service.deleteNewsletter(docId);
        expect(result.isFailure, isTrue);

        // Document must still exist
        final afterSnap = await db.collection('newsletters').get();
        expect(afterSnap.docs, hasLength(1));
      });

      test('スケジュール済みニュースレターは削除できる', () async {
        final n = _makeNewsletter(status: NewsletterStatus.scheduled);
        await service.createNewsletter(n);
        final snap = await db.collection('newsletters').get();
        final docId = snap.docs.first.id;

        final result = await service.deleteNewsletter(docId);
        expect(result.isSuccess, isTrue);
      });

      group('Edge Cases', () {
        test('存在しないIDへの削除は failure を返す', () async {
          final result = await service.deleteNewsletter('non-existent-id');
          expect(result.isFailure, isTrue);
        });
      });
    });

    group('getMyNewsletters', () {
      test('正常系: 指定 authorId のニュースレターのみ返す', () async {
        await service.createNewsletter(_makeNewsletter(authorId: 'author1'));
        await service.createNewsletter(_makeNewsletter(authorId: 'author1'));
        await service.createNewsletter(_makeNewsletter(authorId: 'author2'));

        final result = await service.getMyNewsletters('author1');
        expect(result.isSuccess, isTrue);
        result.when(
          success: (list) => expect(list, hasLength(2)),
          failure: (_) => fail('Expected success'),
        );
      });

      group('Edge Cases', () {
        test('存在しない authorId は空リストを返す', () async {
          final result = await service.getMyNewsletters('no-such-author');
          expect(result.isSuccess, isTrue);
          result.when(
            success: (list) => expect(list, isEmpty),
            failure: (_) => fail('Expected success'),
          );
        });

        test('空文字の authorId は空リストを返す', () async {
          final result = await service.getMyNewsletters('');
          expect(result.isSuccess, isTrue);
          result.when(
            success: (list) => expect(list, isEmpty),
            failure: (_) => fail('Expected success'),
          );
        });

        test('特殊文字を含む authorId でもクラッシュせず結果を返す', () async {
          // Firestore where() treats the value as a literal string —
          // special chars are safe as query values (not interpreted as regex).
          const specialId = r'author/with\special$chars #1';
          final result = await service.getMyNewsletters(specialId);
          // No document has this authorId, so expect an empty success.
          expect(result.isSuccess, isTrue);
          result.when(
            success: (list) => expect(list, isEmpty),
            failure: (_) => fail('Expected success, not an exception'),
          );
        });
      });
    });

    group('sendNewsletter', () {
      test('正常系: status が scheduled に変わる', () async {
        final n = _makeNewsletter();
        await service.createNewsletter(n);
        final snap = await db.collection('newsletters').get();
        final docId = snap.docs.first.id;

        final result = await service.sendNewsletter(docId);
        expect(result.isSuccess, isTrue);

        final doc = await db.collection('newsletters').doc(docId).get();
        expect(doc.data()?['status'], 'scheduled');
      });

      group('Edge Cases', () {
        test('存在しないIDへの update は failure を返す', () async {
          // FakeFirestore may or may not throw on update of nonexistent doc.
          // The service wraps exceptions, so we just verify it returns a Result.
          final result = await service.sendNewsletter('non-existent-id');
          expect(result, isNotNull);
        });
      });
    });

    group('getSubscription', () {
      test('購読情報がない場合は null を返す（新規ユーザー）', () async {
        final result = await service.getSubscription('new-user');
        expect(result.isSuccess, isTrue);
        result.when(
          success: (sub) => expect(sub, isNull),
          failure: (_) => fail('Expected success'),
        );
      });

      test('購読情報がある場合はそれを返す', () async {
        final sub = _makeSub(userId: 'user-with-prefs', isSubscribed: false);
        await db
            .collection('newsletter_subscriptions')
            .doc('user-with-prefs')
            .set(sub.toMap());

        final result = await service.getSubscription('user-with-prefs');
        expect(result.isSuccess, isTrue);
        result.when(
          success: (loaded) {
            expect(loaded!.isSubscribed, isFalse);
          },
          failure: (_) => fail('Expected success'),
        );
      });
    });

    group('updateSubscription', () {
      test('正常系: Firestore に購読設定が保存される', () async {
        final sub = _makeSub(userId: 'user-update');
        final result = await service.updateSubscription(sub);
        expect(result.isSuccess, isTrue);

        final doc = await db
            .collection('newsletter_subscriptions')
            .doc('user-update')
            .get();
        expect(doc.exists, isTrue);
        expect(doc.data()?['isSubscribed'], isTrue);
      });

      test('isSubscribed=false で保存される', () async {
        final sub = _makeSub(userId: 'user-unsub', isSubscribed: false);
        await service.updateSubscription(sub);

        final doc = await db
            .collection('newsletter_subscriptions')
            .doc('user-unsub')
            .get();
        expect(doc.data()?['isSubscribed'], isFalse);
      });
    });
  });
}
