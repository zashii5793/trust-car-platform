// プラン画面のテスト。
//
// 比較表は UserPlanLimits.forPlan() から組み立てている。
// プラン定義を変えたのに画面の表示だけ古いまま、という食い違いが
// 起きないことを確認する。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:trust_car_platform/models/user_plan.dart';
import 'package:trust_car_platform/providers/user_subscription_provider.dart';
import 'package:trust_car_platform/screens/settings/plan_screen.dart';

Widget _wrap(UserSubscriptionProvider provider) {
  return MaterialApp(
    home: ChangeNotifierProvider<UserSubscriptionProvider>.value(
      value: provider,
      child: const PlanScreen(),
    ),
  );
}

void main() {
  group('PlanScreen', () {
    testWidgets('フリープランでは現在のプランがフリーと表示される', (tester) async {
      final provider = UserSubscriptionProvider();
      provider.loadFromUser(UserPlanType.free, null);

      await tester.pumpWidget(_wrap(provider));
      await tester.pump();

      expect(find.byKey(const Key('plan_current_label')), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('plan_current_label'))).data,
        'フリープラン',
      );
    });

    testWidgets('フリープランではアップグレードボタンが出る', (tester) async {
      final provider = UserSubscriptionProvider();
      provider.loadFromUser(UserPlanType.free, null);

      await tester.pumpWidget(_wrap(provider));
      await tester.pump();

      // 比較表が長くボタンは初期表示の外にあるため、スクロールして構築させる
      await tester.scrollUntilVisible(
        find.byKey(const Key('plan_upgrade_button')),
        300,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.byKey(const Key('plan_upgrade_button')), findsOneWidget);
    });

    testWidgets('プレミアムではアップグレードボタンを出さない', (tester) async {
      final provider = UserSubscriptionProvider();
      provider.loadFromUser(
        UserPlanType.premium,
        DateTime.now().add(const Duration(days: 30)),
      );

      await tester.pumpWidget(_wrap(provider));
      await tester.pump();

      expect(find.byKey(const Key('plan_upgrade_button')), findsNothing);
      expect(
        tester.widget<Text>(find.byKey(const Key('plan_current_label'))).data,
        'プレミアムプラン',
      );
    });

    testWidgets('制限値が UserPlanLimits の定義どおりに表示される', (tester) async {
      final provider = UserSubscriptionProvider();
      provider.loadFromUser(UserPlanType.free, null);

      await tester.pumpWidget(_wrap(provider));
      await tester.pump();

      final free = UserPlanLimits.forPlan(UserPlanType.free);

      // 車両台数・問い合わせ件数・保持日数が、定義値そのままで出ていること
      expect(find.text('${free.maxVehicles}台まで'), findsOneWidget);
      expect(find.text('${free.maxMonthlyInquiries}件 / 月'), findsOneWidget);
      expect(find.text('${free.driveLogRetentionDays}日間'), findsOneWidget);
    });

    testWidgets('無制限の項目は「無制限」と表示される', (tester) async {
      final provider = UserSubscriptionProvider();
      provider.loadFromUser(UserPlanType.free, null);

      await tester.pumpWidget(_wrap(provider));
      await tester.pump();

      // プレミアム側は台数・問い合わせ・保存日数・履歴共有が無制限
      expect(find.text('無制限'), findsWidgets);
    });

    testWidgets('比較表に主要な機能名が並ぶ', (tester) async {
      final provider = UserSubscriptionProvider();
      provider.loadFromUser(UserPlanType.free, null);

      await tester.pumpWidget(_wrap(provider));
      await tester.pump();

      expect(find.text('車両の登録'), findsOneWidget);
      expect(find.text('工場への問い合わせ'), findsOneWidget);
      expect(find.text('愛車カルテのPDF出力'), findsOneWidget);
      expect(find.text('フリー'), findsOneWidget);
      expect(find.text('プレミアム'), findsOneWidget);
    });
  });

  group('Edge Cases', () {
    testWidgets('期限切れのプレミアムはフリー扱いで表示される', (tester) async {
      final provider = UserSubscriptionProvider();
      provider.loadFromUser(
        UserPlanType.premium,
        DateTime.now().subtract(const Duration(days: 1)),
      );

      await tester.pumpWidget(_wrap(provider));
      await tester.pump();

      expect(
        tester.widget<Text>(find.byKey(const Key('plan_current_label'))).data,
        'フリープラン',
        reason: '期限を過ぎたら課金機能は使えないので、表示もフリーに戻すべき',
      );

      await tester.scrollUntilVisible(
        find.byKey(const Key('plan_upgrade_button')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byKey(const Key('plan_upgrade_button')), findsOneWidget);
    });
  });
}
