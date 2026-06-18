// NewsletterListScreen Widget Tests
//
// Coverage:
//   AppBar:
//     1. Shows 'ニュースレター管理' title
//     2. Shows '新規作成' FAB
//   Empty state:
//     3. Shows 'ニュースレターがありません' when list is empty
//   List state:
//     4. Shows newsletter title
//     5. Shows status badge for draft ('下書き')
//     6. Shows status badge for sent ('送信済み')
//     7. Draft shows '配信' button
//     8. Sent newsletter shows recipient count
//   Send flow:
//     9. Tapping 配信 shows confirmation dialog
//    10. Tapping キャンセル dismisses dialog
//    11. Tapping 配信する calls sendNewsletter
//   Error state:
//    12. Shows error message and retry

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/core/di/injection.dart';
import 'package:trust_car_platform/core/di/service_locator.dart';
import 'package:trust_car_platform/core/error/app_error.dart';
import 'package:trust_car_platform/core/result/result.dart';
import 'package:trust_car_platform/models/newsletter.dart';
import 'package:trust_car_platform/screens/newsletter/newsletter_list_screen.dart';
import 'package:trust_car_platform/services/newsletter_service.dart';

// ---------------------------------------------------------------------------
// Mock
// ---------------------------------------------------------------------------

class _MockNewsletterService implements NewsletterService {
  final List<Newsletter> newsletters;
  final AppError? loadError;
  bool sendCalled = false;
  String? sentId;

  _MockNewsletterService({this.newsletters = const [], this.loadError});

  @override
  Future<Result<List<Newsletter>, AppError>> getMyNewsletters(
      String authorId) async {
    if (loadError != null) return Result.failure(loadError!);
    return Result.success(newsletters);
  }

  @override
  Future<Result<void, AppError>> sendNewsletter(String newsletterId) async {
    sendCalled = true;
    sentId = newsletterId;
    return const Result.success(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Newsletter _makeNewsletter({
  String id = 'n1',
  String title = 'テストニュースレター',
  String body = '本文です。',
  NewsletterStatus status = NewsletterStatus.draft,
  int recipientCount = 0,
  DateTime? sentAt,
}) {
  final now = DateTime(2026, 5, 1);
  return Newsletter(
    id: id,
    title: title,
    body: body,
    authorId: 'author1',
    authorName: 'テスト工場',
    status: status,
    recipientCount: recipientCount,
    createdAt: now,
    updatedAt: now,
    sentAt: sentAt,
  );
}

Widget _buildScreen(_MockNewsletterService mock) {
  sl.override<NewsletterService>(mock);
  return MaterialApp(
    home: NewsletterListScreen(
      authorId: 'author1',
      authorName: 'テスト工場',
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  tearDown(() {
    Injection.reset();
  });

  // =========================================================================
  group('NewsletterListScreen — AppBar', () {
    testWidgets('1. タイトル「ニュースレター管理」が表示される', (tester) async {
      await tester.pumpWidget(_buildScreen(_MockNewsletterService()));
      await tester.pump();
      await tester.pump();

      expect(find.text('ニュースレター管理'), findsOneWidget);
    });

    testWidgets('2. 「新規作成」FABが表示される', (tester) async {
      await tester.pumpWidget(_buildScreen(_MockNewsletterService()));
      await tester.pump();
      await tester.pump();

      expect(find.text('新規作成'), findsOneWidget);
    });
  });

  // =========================================================================
  group('NewsletterListScreen — Empty state', () {
    testWidgets('3. 空のメッセージが表示される', (tester) async {
      await tester.pumpWidget(_buildScreen(_MockNewsletterService()));
      await tester.pump();
      await tester.pump();

      expect(find.text('ニュースレターがありません'), findsOneWidget);
    });
  });

  // =========================================================================
  group('NewsletterListScreen — List state', () {
    final newsletters = [
      _makeNewsletter(
        id: 'n1',
        title: '6月のお知らせ',
        status: NewsletterStatus.draft,
      ),
      _makeNewsletter(
        id: 'n2',
        title: '5月のお知らせ',
        status: NewsletterStatus.sent,
        recipientCount: 42,
        sentAt: DateTime(2026, 5, 1),
      ),
    ];

    testWidgets('4. ニュースレタータイトルが表示される', (tester) async {
      await tester.pumpWidget(
          _buildScreen(_MockNewsletterService(newsletters: newsletters)));
      await tester.pump();
      await tester.pump();

      expect(find.text('6月のお知らせ'), findsOneWidget);
      expect(find.text('5月のお知らせ'), findsOneWidget);
    });

    testWidgets('5. 下書きのステータスバッジが表示される', (tester) async {
      await tester.pumpWidget(
          _buildScreen(_MockNewsletterService(newsletters: newsletters)));
      await tester.pump();
      await tester.pump();

      expect(find.text('下書き'), findsOneWidget);
    });

    testWidgets('6. 送信済みのステータスバッジが表示される', (tester) async {
      await tester.pumpWidget(
          _buildScreen(_MockNewsletterService(newsletters: newsletters)));
      await tester.pump();
      await tester.pump();

      expect(find.text('配信済み'), findsOneWidget);
    });

    testWidgets('7. 下書きには配信ボタンが表示される', (tester) async {
      await tester.pumpWidget(
        _buildScreen(_MockNewsletterService(newsletters: [newsletters[0]])),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('配信'), findsOneWidget);
    });

    testWidgets('8. 送信済みには受信者数が表示される', (tester) async {
      await tester.pumpWidget(
        _buildScreen(_MockNewsletterService(newsletters: [newsletters[1]])),
      );
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('42名に配信済み'), findsOneWidget);
    });
  });

  // =========================================================================
  group('NewsletterListScreen — Send flow', () {
    final draftNewsletter = _makeNewsletter(
      id: 'n-draft',
      title: '送信テスト',
      status: NewsletterStatus.draft,
    );

    testWidgets('9. 配信ボタンタップで確認ダイアログが表示される', (tester) async {
      await tester.pumpWidget(
        _buildScreen(_MockNewsletterService(newsletters: [draftNewsletter])),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('配信'));
      await tester.pumpAndSettle();

      expect(find.text('ニュースレターを配信'), findsOneWidget);
    });

    testWidgets('10. キャンセルでダイアログが閉じる', (tester) async {
      await tester.pumpWidget(
        _buildScreen(_MockNewsletterService(newsletters: [draftNewsletter])),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('配信'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('キャンセル'));
      await tester.pumpAndSettle();

      expect(find.text('ニュースレターを配信'), findsNothing);
    });

    testWidgets('11. 配信するをタップするとsendNewsletterが呼ばれる', (tester) async {
      final mock = _MockNewsletterService(newsletters: [draftNewsletter]);
      await tester.pumpWidget(_buildScreen(mock));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('配信'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('配信する'));
      await tester.pumpAndSettle();

      expect(mock.sendCalled, isTrue);
      expect(mock.sentId, 'n-draft');
    });
  });

  // =========================================================================
  group('NewsletterListScreen — Error state', () {
    testWidgets('12. エラー時は再試行ボタンが表示される', (tester) async {
      final mock = _MockNewsletterService(
        loadError: AppError.server('load failed'),
      );
      await tester.pumpWidget(_buildScreen(mock));
      await tester.pump();
      await tester.pump();

      expect(find.text('再試行'), findsOneWidget);
    });
  });

  // =========================================================================
  group('NewsletterListScreen — Card details', () {
    testWidgets('13. ニュースレターの本文が表示される', (tester) async {
      final nl = _makeNewsletter(body: '6月のお知らせ本文です。');
      await tester
          .pumpWidget(_buildScreen(_MockNewsletterService(newsletters: [nl])));
      await tester.pump();
      await tester.pump();

      expect(find.text('6月のお知らせ本文です。'), findsOneWidget);
    });

    testWidgets('14. カテゴリバッジが表示される', (tester) async {
      final nl = _makeNewsletter(
        id: 'n1',
        title: 'カテゴリテスト',
      );
      await tester
          .pumpWidget(_buildScreen(_MockNewsletterService(newsletters: [nl])));
      await tester.pump();
      await tester.pump();

      // Default category is maintenanceTips → '整備・メンテナンス情報'
      expect(
        find.text(NewsletterCategory.maintenanceTips.displayName),
        findsOneWidget,
      );
    });

    testWidgets('15. 作成日が表示される', (tester) async {
      final nl = _makeNewsletter(id: 'n1', title: '日付テスト');
      await tester
          .pumpWidget(_buildScreen(_MockNewsletterService(newsletters: [nl])));
      await tester.pump();
      await tester.pump();

      // createdAt = DateTime(2026, 5, 1) → '2026/05/01'
      expect(find.textContaining('2026/05/01'), findsOneWidget);
    });

    testWidgets('16. 送信済みのsentAtが表示される', (tester) async {
      final nl = _makeNewsletter(
        id: 'n1',
        title: '送信日テスト',
        status: NewsletterStatus.sent,
        sentAt: DateTime(2026, 5, 15),
        recipientCount: 10,
      );
      await tester
          .pumpWidget(_buildScreen(_MockNewsletterService(newsletters: [nl])));
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('2026/05/15'), findsOneWidget);
    });

    testWidgets('17. 下書きに編集ボタンが表示される', (tester) async {
      final nl = _makeNewsletter(
        id: 'n1',
        title: '編集テスト',
        status: NewsletterStatus.draft,
      );
      await tester
          .pumpWidget(_buildScreen(_MockNewsletterService(newsletters: [nl])));
      await tester.pump();
      await tester.pump();

      expect(find.text('編集'), findsOneWidget);
    });

    testWidgets('18. 下書きに削除ボタンが表示される', (tester) async {
      final nl = _makeNewsletter(
        id: 'n1',
        title: '削除テスト',
        status: NewsletterStatus.draft,
      );
      await tester
          .pumpWidget(_buildScreen(_MockNewsletterService(newsletters: [nl])));
      await tester.pump();
      await tester.pump();

      expect(find.text('削除'), findsOneWidget);
    });
  });

  // =========================================================================
  group('NewsletterListScreen — Empty state details', () {
    testWidgets('19. 空状態の説明文が表示される', (tester) async {
      await tester.pumpWidget(_buildScreen(_MockNewsletterService()));
      await tester.pump();
      await tester.pump();

      expect(
        find.textContaining('新規作成'),
        findsWidgets,
      );
    });
  });

  // =========================================================================
  group('NewsletterListScreen — Send dialog details', () {
    testWidgets('20. 配信確認ダイアログにオーディエンスが表示される', (tester) async {
      final nl = _makeNewsletter(
        id: 'n-dialog',
        title: 'オーディエンステスト',
        status: NewsletterStatus.draft,
      );
      await tester
          .pumpWidget(_buildScreen(_MockNewsletterService(newsletters: [nl])));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('配信'));
      await tester.pumpAndSettle();

      // Default audience is allUsers → '全ユーザー'
      expect(find.textContaining('全ユーザー'), findsOneWidget);
    });
  });
}
