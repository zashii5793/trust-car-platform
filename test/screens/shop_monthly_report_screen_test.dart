// ShopMonthlyReportScreen Widget Tests
//
// Coverage:
//   Loading state:
//     1. Shows loading indicator while fetching
//   No-report state:
//     2. Shows 'まだレポートがありません' when report is null
//     3. Shows '再読み込み' button when no report
//   Error state:
//     4. Shows error message on failure
//     5. Shows retry button on error
//   Report state:
//     6. Shows month header
//     7. Shows totalInquiries value
//     8. Shows newInquiries value
//     9. Shows resolvedInquiries value
//    10. Shows pageViews value
//    11. Shows searchAppearances value
//    12. Shows updatedAt date

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/core/di/injection.dart';
import 'package:trust_car_platform/core/di/service_locator.dart';
import 'package:trust_car_platform/core/error/app_error.dart';
import 'package:trust_car_platform/core/result/result.dart';
import 'package:trust_car_platform/models/shop_monthly_report.dart';
import 'package:trust_car_platform/screens/marketplace/shop_monthly_report_screen.dart';
import 'package:trust_car_platform/services/shop_service.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class _MockShopService implements ShopService {
  final ShopMonthlyReport? report;
  final AppError? error;

  _MockShopService({this.report, this.error});

  @override
  Future<Result<ShopMonthlyReport?, AppError>> getMonthlyReport(
      String shopId) async {
    if (error != null) return Result.failure(error!);
    return Result.success(report);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

ShopMonthlyReport _makeReport({
  String month = '2026-05',
  int totalInquiries = 42,
  int newInquiries = 7,
  int resolvedInquiries = 5,
  int pageViews = 120,
  int searchAppearances = 300,
  DateTime? updatedAt,
}) {
  return ShopMonthlyReport(
    shopId: 'shop1',
    month: month,
    totalInquiries: totalInquiries,
    newInquiries: newInquiries,
    resolvedInquiries: resolvedInquiries,
    pageViews: pageViews,
    searchAppearances: searchAppearances,
    updatedAt: updatedAt ?? DateTime(2026, 6, 1),
  );
}

Widget _buildScreen(_MockShopService mock) {
  sl.override<ShopService>(mock);
  return const MaterialApp(
    home: ShopMonthlyReportScreen(shopId: 'shop1'),
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
  group('ShopMonthlyReportScreen — Loading state', () {
    testWidgets('1. ローディング中はインジケーターが表示される', (tester) async {
      // _isLoading starts true; pump once to build without settling the Future
      await tester.pumpWidget(_buildScreen(_MockShopService()));
      // initState has fired but the async _load() has not yet resolved
      expect(find.text('読み込み中...'), findsOneWidget);
    });
  });

  // =========================================================================
  group('ShopMonthlyReportScreen — No report state', () {
    testWidgets('2. レポートなし時は空メッセージが表示される', (tester) async {
      await tester.pumpWidget(_buildScreen(_MockShopService()));
      await tester.pump(); // trigger initState load
      await tester.pump(); // settle after Future completes

      expect(find.text('まだレポートがありません'), findsOneWidget);
    });

    testWidgets('3. 再読み込みボタンが表示される', (tester) async {
      await tester.pumpWidget(_buildScreen(_MockShopService()));
      await tester.pump();
      await tester.pump();

      expect(find.text('再読み込み'), findsOneWidget);
    });
  });

  // =========================================================================
  group('ShopMonthlyReportScreen — Error state', () {
    testWidgets('4. エラー時はエラーメッセージが表示される', (tester) async {
      final mock = _MockShopService(error: AppError.server('fail'));
      await tester.pumpWidget(_buildScreen(mock));
      await tester.pump();
      await tester.pump();

      // ServerError.userMessage → 'サーバーエラーが発生しました。しばらく待ってからお試しください'
      expect(find.textContaining('サーバーエラーが発生しました'), findsOneWidget);
    });

    testWidgets('5. エラー時にリトライボタンが表示される', (tester) async {
      final mock = _MockShopService(
        error: AppError.server('エラー'),
      );
      await tester.pumpWidget(_buildScreen(mock));
      await tester.pump();
      await tester.pump();

      expect(find.text('再試行'), findsOneWidget);
    });
  });

  // =========================================================================
  group('ShopMonthlyReportScreen — Report state', () {
    late ShopMonthlyReport report;

    setUp(() {
      report = _makeReport();
    });

    testWidgets('6. 月ヘッダーが表示される', (tester) async {
      await tester.pumpWidget(_buildScreen(_MockShopService(report: report)));
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('2026-05'), findsOneWidget);
    });

    testWidgets('7. 累計問い合わせ件数が表示される', (tester) async {
      await tester.pumpWidget(_buildScreen(_MockShopService(report: report)));
      await tester.pump();
      await tester.pump();

      expect(find.text('42 件'), findsOneWidget);
    });

    testWidgets('8. 新規問い合わせ件数が表示される', (tester) async {
      await tester.pumpWidget(_buildScreen(_MockShopService(report: report)));
      await tester.pump();
      await tester.pump();

      expect(find.text('7 件'), findsOneWidget);
    });

    testWidgets('9. 対応完了件数が表示される', (tester) async {
      await tester.pumpWidget(_buildScreen(_MockShopService(report: report)));
      await tester.pump();
      await tester.pump();

      expect(find.text('5 件'), findsOneWidget);
    });

    testWidgets('10. ページビュー数が表示される', (tester) async {
      await tester.pumpWidget(_buildScreen(_MockShopService(report: report)));
      await tester.pump();
      await tester.pump();

      expect(find.text('120 回'), findsOneWidget);
    });

    testWidgets('11. 検索表示回数が表示される', (tester) async {
      await tester.pumpWidget(_buildScreen(_MockShopService(report: report)));
      await tester.pump();
      await tester.pump();

      expect(find.text('300 回'), findsOneWidget);
    });

    testWidgets('12. 更新日が表示される', (tester) async {
      await tester.pumpWidget(_buildScreen(_MockShopService(report: report)));
      await tester.pump();
      await tester.pump();

      // updatedAt = DateTime(2026, 6, 1) → "2026/06/01"
      expect(find.textContaining('2026/06/01'), findsOneWidget);
    });
  });

  // =========================================================================
  group('ShopMonthlyReportScreen — AppBar', () {
    testWidgets('13. AppBarタイトル「月次レポート」が表示される', (tester) async {
      await tester.pumpWidget(_buildScreen(_MockShopService()));
      await tester.pump();

      expect(find.text('月次レポート'), findsOneWidget);
    });
  });

  // =========================================================================
  group('ShopMonthlyReportScreen — Section headers', () {
    testWidgets('14. 「問い合わせ」セクションヘッダーが表示される', (tester) async {
      final report = _makeReport();
      await tester.pumpWidget(_buildScreen(_MockShopService(report: report)));
      await tester.pump();
      await tester.pump();

      expect(find.text('問い合わせ'), findsOneWidget);
    });

    testWidgets('15. 「露出・閲覧」セクションヘッダーが表示される', (tester) async {
      final report = _makeReport();
      await tester.pumpWidget(_buildScreen(_MockShopService(report: report)));
      await tester.pump();
      await tester.pump();

      expect(find.text('露出・閲覧'), findsOneWidget);
    });

    testWidgets('16. 「累計問い合わせ」ラベルが表示される', (tester) async {
      final report = _makeReport();
      await tester.pumpWidget(_buildScreen(_MockShopService(report: report)));
      await tester.pump();
      await tester.pump();

      expect(find.text('累計問い合わせ'), findsOneWidget);
    });

    testWidgets('17. 「新規（今月）」ラベルが表示される', (tester) async {
      final report = _makeReport();
      await tester.pumpWidget(_buildScreen(_MockShopService(report: report)));
      await tester.pump();
      await tester.pump();

      expect(find.text('新規（今月）'), findsOneWidget);
    });
  });

  // =========================================================================
  group('ShopMonthlyReportScreen — Edge cases', () {
    testWidgets('18. 全ての値が0の場合も正常に表示される', (tester) async {
      final report = _makeReport(
        totalInquiries: 0,
        newInquiries: 0,
        resolvedInquiries: 0,
        pageViews: 0,
        searchAppearances: 0,
      );
      await tester.pumpWidget(_buildScreen(_MockShopService(report: report)));
      await tester.pump();
      await tester.pump();

      expect(find.text('0 件'), findsWidgets);
      expect(find.text('0 回'), findsWidgets);
    });

    testWidgets('19. レポートなし状態の説明文が表示される', (tester) async {
      await tester.pumpWidget(_buildScreen(_MockShopService()));
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('Cloud Functions'), findsOneWidget);
    });

    testWidgets('20. 月ヘッダーに「のパフォーマンス」が含まれる', (tester) async {
      final report = _makeReport(month: '2026-03');
      await tester.pumpWidget(_buildScreen(_MockShopService(report: report)));
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('2026-03 のパフォーマンス'), findsOneWidget);
    });
  });
}
