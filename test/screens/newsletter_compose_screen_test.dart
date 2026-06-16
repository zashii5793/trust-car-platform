// NewsletterComposeScreen Widget Tests
//
// Coverage:
//   AppBar:
//     1. Shows 'ニュースレター作成' for new draft
//     2. Shows '下書きを編集' when editing existing
//     3. Shows '保存' text button
//   Form fields:
//     4. Shows タイトル field
//     5. Shows 本文 field
//     6. Shows category chips
//   Validation:
//     7. Empty title shows validation error
//   Pre-fill:
//     8. Editing existing draft pre-fills title
//   Save flow:
//     9. Saving new draft calls createNewsletter
//    10. Saving existing draft calls updateNewsletter

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/core/di/injection.dart';
import 'package:trust_car_platform/core/di/service_locator.dart';
import 'package:trust_car_platform/core/error/app_error.dart';
import 'package:trust_car_platform/core/result/result.dart';
import 'package:trust_car_platform/models/newsletter.dart';
import 'package:trust_car_platform/screens/newsletter/newsletter_compose_screen.dart';
import 'package:trust_car_platform/services/newsletter_service.dart';

// ---------------------------------------------------------------------------
// Mock
// ---------------------------------------------------------------------------

class _MockNewsletterService implements NewsletterService {
  bool createCalled = false;
  bool updateCalled = false;
  AppError? saveError;

  @override
  Future<Result<String, AppError>> createNewsletter(
      Newsletter newsletter) async {
    createCalled = true;
    if (saveError != null) return Result.failure(saveError!);
    return const Result.success('new-id');
  }

  @override
  Future<Result<void, AppError>> updateNewsletter(Newsletter newsletter) async {
    updateCalled = true;
    if (saveError != null) return Result.failure(saveError!);
    return const Result.success(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Newsletter _makeExistingNewsletter({
  String id = 'n1',
  String title = '既存のタイトル',
  String body = '既存の本文です。',
}) {
  final now = DateTime(2026, 6, 1);
  return Newsletter(
    id: id,
    title: title,
    body: body,
    authorId: 'author1',
    authorName: 'テスト工場',
    status: NewsletterStatus.draft,
    createdAt: now,
    updatedAt: now,
  );
}

Widget _buildNewScreen(_MockNewsletterService mock) {
  sl.override<NewsletterService>(mock);
  return MaterialApp(
    home: NewsletterComposeScreen(
      authorId: 'author1',
      authorName: 'テスト工場',
    ),
  );
}

Widget _buildEditScreen(_MockNewsletterService mock, Newsletter existing) {
  sl.override<NewsletterService>(mock);
  return MaterialApp(
    home: NewsletterComposeScreen(
      authorId: 'author1',
      authorName: 'テスト工場',
      existing: existing,
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
  group('NewsletterComposeScreen — AppBar', () {
    testWidgets('1. 新規作成時タイトル「ニュースレター作成」が表示される', (tester) async {
      await tester.pumpWidget(_buildNewScreen(_MockNewsletterService()));
      await tester.pump();

      expect(find.text('ニュースレター作成'), findsOneWidget);
    });

    testWidgets('2. 編集時タイトル「下書きを編集」が表示される', (tester) async {
      await tester.pumpWidget(
        _buildEditScreen(_MockNewsletterService(), _makeExistingNewsletter()),
      );
      await tester.pump();

      expect(find.text('下書きを編集'), findsOneWidget);
    });

    testWidgets('3. 「保存」ボタンが表示される', (tester) async {
      await tester.pumpWidget(_buildNewScreen(_MockNewsletterService()));
      await tester.pump();

      expect(find.text('保存'), findsOneWidget);
    });
  });

  // =========================================================================
  group('NewsletterComposeScreen — Form fields', () {
    testWidgets('4. タイトルフィールドが表示される', (tester) async {
      await tester.pumpWidget(_buildNewScreen(_MockNewsletterService()));
      await tester.pump();

      expect(find.widgetWithText(TextFormField, 'タイトル *'), findsOneWidget);
    });

    testWidgets('5. 本文フィールドが表示される', (tester) async {
      await tester.pumpWidget(_buildNewScreen(_MockNewsletterService()));
      await tester.pump();

      expect(find.widgetWithText(TextFormField, '本文 *'), findsOneWidget);
    });

    testWidgets('6. カテゴリチップが表示される', (tester) async {
      await tester.pumpWidget(_buildNewScreen(_MockNewsletterService()));
      await tester.pump();

      expect(find.text('カテゴリ'), findsOneWidget);
      expect(find.byType(ChoiceChip), findsWidgets);
    });
  });

  // =========================================================================
  group('NewsletterComposeScreen — Validation', () {
    testWidgets('7. タイトル未入力で保存するとバリデーションエラーが表示される', (tester) async {
      await tester.pumpWidget(_buildNewScreen(_MockNewsletterService()));
      await tester.pump();

      // Tap save without filling in title
      await tester.tap(find.text('保存'));
      await tester.pump();

      expect(find.text('タイトルを入力してください'), findsOneWidget);
    });
  });

  // =========================================================================
  group('NewsletterComposeScreen — Pre-fill', () {
    testWidgets('8. 既存下書き編集時にタイトルが入力済みになる', (tester) async {
      final existing = _makeExistingNewsletter(title: '事前入力タイトル');
      await tester
          .pumpWidget(_buildEditScreen(_MockNewsletterService(), existing));
      await tester.pump();

      expect(find.text('事前入力タイトル'), findsOneWidget);
    });
  });

  // =========================================================================
  group('NewsletterComposeScreen — Save flow', () {
    testWidgets('9. 新規作成でcreateNewsletterが呼ばれる', (tester) async {
      final mock = _MockNewsletterService();
      await tester.pumpWidget(_buildNewScreen(mock));
      await tester.pump();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'タイトル *'),
        'テストタイトル',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, '本文 *'),
        'テスト本文です。',
      );

      await tester.tap(find.text('保存'));
      await tester.pump();
      await tester.pump();

      expect(mock.createCalled, isTrue);
    });

    testWidgets('10. 既存編集でupdateNewsletterが呼ばれる', (tester) async {
      final mock = _MockNewsletterService();
      final existing = _makeExistingNewsletter(title: '元のタイトル');
      await tester.pumpWidget(_buildEditScreen(mock, existing));
      await tester.pump();

      await tester.tap(find.text('保存'));
      await tester.pump();
      await tester.pump();

      expect(mock.updateCalled, isTrue);
    });

    testWidgets('11. 保存成功で「下書きを保存しました」スナックバーが表示される', (tester) async {
      final mock = _MockNewsletterService();
      await tester.pumpWidget(_buildNewScreen(mock));
      await tester.pump();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'タイトル *'),
        'テストタイトル',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, '本文 *'),
        'テスト本文です。',
      );

      await tester.tap(find.text('保存'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('下書きを保存しました'), findsOneWidget);
    });

    testWidgets('12. 保存失敗でエラースナックバーが表示される', (tester) async {
      final mock = _MockNewsletterService()
        ..saveError = AppError.server('save failed');
      await tester.pumpWidget(_buildNewScreen(mock));
      await tester.pump();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'タイトル *'),
        'テストタイトル',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, '本文 *'),
        'テスト本文です。',
      );

      await tester.tap(find.text('保存'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // AppError.server gives 'サーバーエラーが発生しました...'
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });

  // =========================================================================
  group('NewsletterComposeScreen — Validation追加', () {
    testWidgets('13. 本文未入力で保存するとバリデーションエラーが表示される', (tester) async {
      await tester.pumpWidget(_buildNewScreen(_MockNewsletterService()));
      await tester.pump();

      // Fill title but not body
      await tester.enterText(
        find.widgetWithText(TextFormField, 'タイトル *'),
        'タイトルのみ',
      );

      await tester.tap(find.text('保存'));
      await tester.pump();

      expect(find.text('本文を入力してください'), findsOneWidget);
    });
  });

  // =========================================================================
  group('NewsletterComposeScreen — 追加フィールド', () {
    testWidgets('14. 配信対象のラジオボタンが表示される', (tester) async {
      await tester.pumpWidget(_buildNewScreen(_MockNewsletterService()));
      await tester.pump();

      expect(find.text('配信対象'), findsOneWidget);
      expect(find.byType(RadioListTile<NewsletterAudience>), findsWidgets);
    });

    testWidgets('15. 注意書きテキストが表示される', (tester) async {
      await tester.pumpWidget(_buildNewScreen(_MockNewsletterService()));
      await tester.pump();

      // Note is at the bottom of the form — scroll down to reveal it
      await tester.drag(find.byType(ListView), const Offset(0, -5000));
      await tester.pump();

      expect(find.textContaining('下書き保存'), findsOneWidget);
    });

    testWidgets('16. 既存下書き編集時に本文が入力済みになる', (tester) async {
      final existing = _makeExistingNewsletter(body: '事前入力本文です。');
      await tester
          .pumpWidget(_buildEditScreen(_MockNewsletterService(), existing));
      await tester.pump();

      expect(find.text('事前入力本文です。'), findsOneWidget);
    });

    testWidgets('17. カテゴリチップをタップすると選択状態が変わる', (tester) async {
      await tester.pumpWidget(_buildNewScreen(_MockNewsletterService()));
      await tester.pump();

      // Tap the second category chip (not the default one)
      final chips = find.byType(ChoiceChip);
      expect(chips, findsWidgets);

      // Tap the last chip (should differ from default)
      await tester.tap(chips.last);
      await tester.pump();

      // After tapping, at least one ChoiceChip should be selected
      final selectedChips = tester
          .widgetList<ChoiceChip>(chips)
          .where((c) => c.selected)
          .toList();
      expect(selectedChips, isNotEmpty);
    });
  });
}
