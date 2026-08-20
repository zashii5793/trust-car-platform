// プランバッジの視認性テスト。
//
// このバッジはプロフィールの青いグラデーションヘッダーの上に置かれる。
// Chip のテーマ既定（ほぼ白の背景 + テーマ由来の文字色）に任せると
// 白背景に白文字となって読めなくなる不具合が実機で出たため、
// 背景色・前景色を必ず明示していることを色で検証する。

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/core/theme/app_theme.dart';
import 'package:trust_car_platform/widgets/plan_badge.dart';

/// WCAG 2.1 の相対輝度。
double _relativeLuminance(Color c) {
  double channel(int value) {
    final v = value / 255.0;
    return v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4) as double;
  }

  return 0.2126 * channel(c.red) +
      0.7152 * channel(c.green) +
      0.0722 * channel(c.blue);
}

/// WCAG 2.1 のコントラスト比（1.0〜21.0）。
double _contrastRatio(Color a, Color b) {
  final la = _relativeLuminance(a);
  final lb = _relativeLuminance(b);
  final lighter = math.max(la, lb);
  final darker = math.min(la, lb);
  return (lighter + 0.05) / (darker + 0.05);
}

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    home: Scaffold(
      // ヘッダーと同じく濃い青の上に置いた状態で確認する。
      body: ColoredBox(
        color: const Color(0xFF1A4D8F),
        child: Center(child: child),
      ),
    ),
  );
}

void main() {
  group('PlanBadge — 表示', () {
    testWidgets('フリープランではラベルがフリープラン', (tester) async {
      await tester.pumpWidget(_wrap(const PlanBadge(isPremium: false)));
      expect(find.text('フリープラン'), findsOneWidget);
    });

    testWidgets('プレミアムではラベルがプレミアム', (tester) async {
      await tester.pumpWidget(_wrap(const PlanBadge(isPremium: true)));
      expect(find.text('プレミアム'), findsOneWidget);
    });

    testWidgets('プロフィール画面から参照されるキーを保持している', (tester) async {
      await tester.pumpWidget(_wrap(const PlanBadge(isPremium: false)));
      expect(find.byKey(const Key('profile_plan_chip')), findsOneWidget);
    });

    testWidgets('タップするとコールバックが呼ばれる', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(PlanBadge(isPremium: false, onTap: () => tapped = true)),
      );

      await tester.tap(find.byKey(const Key('profile_plan_chip')));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });
  });

  group('PlanBadge — 視認性', () {
    for (final isPremium in [false, true]) {
      final planLabel = isPremium ? 'プレミアム' : 'フリー';

      testWidgets('$planLabel: 背景色をテーマ任せにせず明示している', (tester) async {
        await tester.pumpWidget(_wrap(PlanBadge(isPremium: isPremium)));

        final chip = tester.widget<ActionChip>(find.byType(ActionChip));
        expect(
          chip.backgroundColor,
          isNotNull,
          reason: 'ChipTheme の既定に落ちると青ヘッダー上で背景が読めなくなる',
        );
      });

      testWidgets('$planLabel: ラベルの文字色を明示している', (tester) async {
        await tester.pumpWidget(_wrap(PlanBadge(isPremium: isPremium)));

        final chip = tester.widget<ActionChip>(find.byType(ActionChip));
        final label = chip.label as Text;
        expect(
          label.style?.color,
          isNotNull,
          reason: '文字色が null だと DefaultTextStyle 次第で白文字になりうる',
        );
      });

      testWidgets('$planLabel: 文字と背景のコントラストが 4.5:1 以上', (tester) async {
        await tester.pumpWidget(_wrap(PlanBadge(isPremium: isPremium)));

        final chip = tester.widget<ActionChip>(find.byType(ActionChip));
        final label = chip.label as Text;
        final ratio = _contrastRatio(
          label.style!.color!,
          chip.backgroundColor!,
        );

        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason: 'コントラスト比 ${ratio.toStringAsFixed(2)}:1 では読みにくい',
        );
      });

      testWidgets('$planLabel: アイコンと背景のコントラストが 4.5:1 以上', (tester) async {
        await tester.pumpWidget(_wrap(PlanBadge(isPremium: isPremium)));

        final chip = tester.widget<ActionChip>(find.byType(ActionChip));
        final avatar = chip.avatar! as Icon;
        expect(avatar.color, isNotNull);

        final ratio = _contrastRatio(avatar.color!, chip.backgroundColor!);
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason: 'コントラスト比 ${ratio.toStringAsFixed(2)}:1 では読みにくい',
        );
      });
    }

    testWidgets('フリーとプレミアムで背景色が変わる', (tester) async {
      await tester.pumpWidget(_wrap(const PlanBadge(isPremium: false)));
      final free =
          tester.widget<ActionChip>(find.byType(ActionChip)).backgroundColor;

      await tester.pumpWidget(_wrap(const PlanBadge(isPremium: true)));
      final premium =
          tester.widget<ActionChip>(find.byType(ActionChip)).backgroundColor;

      expect(free, isNot(premium));
    });
  });
}
