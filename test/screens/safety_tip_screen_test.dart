// SafetyTipScreen Widget Tests
//
// Coverage:
//   AppBar:
//     1. Shows '安全運転情報' title
//     2. Shows '全て' tab
//     3. Shows category tabs
//   Disclaimer:
//     4. Disclaimer banner always shown
//   Tips loaded:
//     5. Shows tip titles
//     6. Shows tip body text
//     7. Shows source badge text
//     8. Shows '公式サイトへ' link button per tip
//   Empty state:
//     9. Shows empty message when no tips
//   Loading:
//    10. Shows CircularProgressIndicator while loading

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/core/di/injection.dart';
import 'package:trust_car_platform/core/di/service_locator.dart';
import 'package:trust_car_platform/core/error/app_error.dart';
import 'package:trust_car_platform/core/result/result.dart';
import 'package:trust_car_platform/models/safety_tip.dart';
import 'package:trust_car_platform/screens/safety/safety_tip_screen.dart';
import 'package:trust_car_platform/services/safety_tip_service.dart';

// ---------------------------------------------------------------------------
// Mock
// ---------------------------------------------------------------------------

class _MockSafetyTipService implements SafetyTipService {
  final List<SafetyTip> tips;
  final AppError? error;

  _MockSafetyTipService({this.tips = const [], this.error});

  @override
  Future<Result<List<SafetyTip>, AppError>> getTips({
    SafetyTipCategory? category,
    SafetyTipSource? source,
  }) async {
    if (error != null) return Result.failure(error!);
    if (category == null) return Result.success(tips);
    return Result.success(
      tips.where((t) => t.category == category).toList(),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _SlowMockSafetyTipService implements SafetyTipService {
  final _completer = Completer<Result<List<SafetyTip>, AppError>>();

  @override
  Future<Result<List<SafetyTip>, AppError>> getTips({
    SafetyTipCategory? category,
    SafetyTipSource? source,
  }) =>
      _completer.future;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

SafetyTip _makeTip({
  String id = 't1',
  String title = '停車時はエンジン停止を',
  String body = 'アイドリングは周辺への影響があります。',
  SafetyTipCategory category = SafetyTipCategory.drivingBasics,
  SafetyTipSource source = SafetyTipSource.jaf,
}) {
  return SafetyTip(
    id: id,
    title: title,
    body: body,
    category: category,
    source: source,
    sourceUrl: 'https://www.jaf.or.jp/safety',
    publishedAt: DateTime(2026, 1, 1),
  );
}

Widget _buildScreen(_MockSafetyTipService mock) {
  sl.override<SafetyTipService>(mock);
  return const MaterialApp(home: SafetyTipScreen());
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  tearDown(() {
    Injection.reset();
  });

  // =========================================================================
  group('SafetyTipScreen — AppBar', () {
    testWidgets('1. タイトル「安全運転情報」が表示される', (tester) async {
      await tester.pumpWidget(_buildScreen(_MockSafetyTipService()));
      await tester.pump();

      expect(find.text('安全運転情報'), findsOneWidget);
    });

    testWidgets('2. 「全て」タブが最初に表示される', (tester) async {
      await tester.pumpWidget(_buildScreen(_MockSafetyTipService()));
      await tester.pump();

      expect(find.text('全て'), findsOneWidget);
    });

    testWidgets('3. カテゴリタブが表示される', (tester) async {
      await tester.pumpWidget(_buildScreen(_MockSafetyTipService()));
      await tester.pump();

      expect(find.text('基本的な安全運転'), findsOneWidget);
      expect(find.text('季節別の注意事項'), findsOneWidget);
    });
  });

  // =========================================================================
  group('SafetyTipScreen — Disclaimer', () {
    testWidgets('4. 免責条項バナーが常時表示される', (tester) async {
      await tester.pumpWidget(_buildScreen(_MockSafetyTipService()));
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('公式機関の情報に基づいていますが'), findsOneWidget);
    });
  });

  // =========================================================================
  group('SafetyTipScreen — Tips loaded', () {
    final tips = [
      _makeTip(id: 't1', title: '安全確認を怠らない', body: '出発前に車両周辺を確認すること。'),
      _makeTip(
        id: 't2',
        title: '夜間は速度を控えめに',
        body: '視界が制限されます。',
        source: SafetyTipSource.npa,
      ),
    ];

    testWidgets('5. チップのタイトルが表示される', (tester) async {
      await tester.pumpWidget(_buildScreen(_MockSafetyTipService(tips: tips)));
      await tester.pump();
      await tester.pump();

      expect(find.text('安全確認を怠らない'), findsOneWidget);
      expect(find.text('夜間は速度を控えめに'), findsOneWidget);
    });

    testWidgets('6. チップの本文が表示される', (tester) async {
      await tester.pumpWidget(_buildScreen(_MockSafetyTipService(tips: tips)));
      await tester.pump();
      await tester.pump();

      expect(find.text('出発前に車両周辺を確認すること。'), findsOneWidget);
    });

    testWidgets('7. ソースバッジが表示される', (tester) async {
      await tester.pumpWidget(_buildScreen(_MockSafetyTipService(tips: tips)));
      await tester.pump();
      await tester.pump();

      expect(find.text('JAF（日本自動車連盟）'), findsOneWidget);
      expect(find.text('警察庁'), findsOneWidget);
    });

    testWidgets('8. 「公式サイトへ」リンクが各チップに表示される', (tester) async {
      await tester.pumpWidget(_buildScreen(_MockSafetyTipService(tips: tips)));
      await tester.pump();
      await tester.pump();

      expect(find.text('公式サイトへ'), findsNWidgets(2));
    });
  });

  // =========================================================================
  group('SafetyTipScreen — Empty state', () {
    testWidgets('9. チップなし時は空メッセージが表示される', (tester) async {
      await tester.pumpWidget(_buildScreen(_MockSafetyTipService()));
      await tester.pump();
      await tester.pump();

      expect(find.text('この分類の情報はまだありません'), findsOneWidget);
    });
  });

  // =========================================================================
  group('SafetyTipScreen — Error state', () {
    testWidgets('10. エラー時は「再読み込み」ボタンが表示される', (tester) async {
      final mock = _MockSafetyTipService(
        error: AppError.server('fetch failed'),
      );
      await tester.pumpWidget(_buildScreen(mock));
      await tester.pump();
      await tester.pump();

      expect(find.text('再読み込み'), findsOneWidget);
    });
  });

  // =========================================================================
  group('SafetyTipScreen — Loading state', () {
    testWidgets('11. ローディング中はCircularProgressIndicatorが表示される', (tester) async {
      final slow = _SlowMockSafetyTipService();
      sl.override<SafetyTipService>(slow);
      await tester.pumpWidget(const MaterialApp(home: SafetyTipScreen()));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsAtLeast(1));
    });
  });

  // =========================================================================
  group('SafetyTipScreen — Card details', () {
    testWidgets('12. カードにIDベースのキーが設定されている', (tester) async {
      final tips = [_makeTip(id: 'tip-abc', title: 'テストチップ')];
      await tester.pumpWidget(_buildScreen(_MockSafetyTipService(tips: tips)));
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('safety_tip_tip-abc')), findsOneWidget);
    });

    testWidgets('13. 公式リンクにIDベースのキーが設定されている', (tester) async {
      final tips = [_makeTip(id: 'tip-xyz')];
      await tester.pumpWidget(_buildScreen(_MockSafetyTipService(tips: tips)));
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('official_link_tip-xyz')), findsOneWidget);
    });

    testWidgets('14. カテゴリバッジが表示される', (tester) async {
      final tips = [
        _makeTip(
          id: 't1',
          category: SafetyTipCategory.vehicleCheck,
        ),
      ];
      await tester.pumpWidget(_buildScreen(_MockSafetyTipService(tips: tips)));
      await tester.pump();
      await tester.pump();

      expect(
          find.text(SafetyTipCategory.vehicleCheck.displayName), findsWidgets);
    });

    testWidgets('15. MLIT（国土交通省）ソースバッジが表示される', (tester) async {
      final tips = [
        _makeTip(
          id: 't1',
          source: SafetyTipSource.mlit,
        ),
      ];
      await tester.pumpWidget(_buildScreen(_MockSafetyTipService(tips: tips)));
      await tester.pump();
      await tester.pump();

      expect(find.text(SafetyTipSource.mlit.displayName), findsOneWidget);
    });
  });

  // =========================================================================
  group('SafetyTipScreen — Tab titles', () {
    testWidgets('16. 「乗車前点検」タブが表示される', (tester) async {
      await tester.pumpWidget(_buildScreen(_MockSafetyTipService()));
      await tester.pump();

      expect(find.text('乗車前点検'), findsOneWidget);
    });

    testWidgets('17. 「緊急時の対応」タブが表示される', (tester) async {
      await tester.pumpWidget(_buildScreen(_MockSafetyTipService()));
      await tester.pump();

      expect(find.text('緊急時の対応'), findsOneWidget);
    });
  });
}
