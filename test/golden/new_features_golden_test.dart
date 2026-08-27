@Tags(['golden'])
library;

// 2026-08-27 に足した画面のデモ画像。
//
// ゴールデン画像は「撮った環境」に強く依存するので CI からは外してある
// （`ci.yml` の --exclude-tags）。ここは**見え方を人に見せるための道具**。
//
//   flutter test --update-goldens test/golden/new_features_golden_test.dart
//   → test/golden/goldens/ に PNG が出る
//
// `font_loader.dart` を必ず呼ぶこと。呼ばないと日本語もアイコンも豆腐（□）で
// 写る。過去に「スクリーンショット」として豆腐の画像を報告した事故がある。

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:trust_car_platform/core/theme/app_theme.dart';
import 'package:trust_car_platform/models/fuel_record.dart';
import 'package:trust_car_platform/models/inspection_pipeline.dart';
import 'package:trust_car_platform/models/maintenance_record.dart';
import 'package:trust_car_platform/models/year_in_review.dart';
import 'package:trust_car_platform/screens/fuel/add_fuel_screen.dart';
import 'package:trust_car_platform/screens/marketplace/shop_invite_manage_screen.dart';
import 'package:trust_car_platform/screens/settings/shop_invite_screen.dart';
import 'package:trust_car_platform/screens/year_in_review_screen.dart';
import 'package:trust_car_platform/services/fuel_service.dart';
import 'package:trust_car_platform/services/shop_invite_service.dart';
import 'package:trust_car_platform/widgets/shop/inspection_pipeline_card.dart';

import 'font_loader.dart';

const _phone = Size(390, 844);

void main() {
  setUpAll(() async {
    await loadMaterialIcons();
    await loadJapaneseFont();
  });

  Future<void> shoot(
    WidgetTester tester,
    Widget screen,
    String name, {
    Size size = _phone,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(theme: goldenTheme(AppTheme.lightTheme), home: screen),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/$name.png'),
    );
  }

  group('2026-08-27 に足した画面', () {
    testWidgets('お店のコードを入れる（未登録）', (tester) async {
      final service = ShopInviteService(firestore: FakeFirebaseFirestore());

      await shoot(
        tester,
        ShopInviteScreen(service: service, userId: 'user-a'),
        'shop_invite_empty',
      );
    });

    testWidgets('お店のコードを入れる（登録済み）', (tester) async {
      final firestore = FakeFirebaseFirestore();
      final service = ShopInviteService(firestore: firestore);
      await service.createInvite(
        shopId: 'shop_takaya_motor_okayama',
        shopName: 'タカヤモーター株式会社',
        shopOwnerId: 'shop-owner-takaya',
      );
      await firestore.collection('shop_customers').doc('user-a').set({
        'shopId': 'shop_takaya_motor_okayama',
        'shopName': 'タカヤモーター株式会社',
        'userId': 'user-a',
        'linkedAt': DateTime(2026, 8, 27),
      });

      await shoot(
        tester,
        ShopInviteScreen(service: service, userId: 'user-a'),
        'shop_invite_linked',
      );
    });

    testWidgets('給油を記録', (tester) async {
      final service = FuelService(firestore: FakeFirebaseFirestore());

      await shoot(
        tester,
        AddFuelScreen(
          service: service,
          vehicleId: 'veh-a-family',
          userId: 'user-a',
          lastOdometer: 30450,
        ),
        'add_fuel',
      );
    });

    testWidgets('この1年のふりかえり', (tester) async {
      MaintenanceRecord rec({
        required DateTime date,
        required int cost,
        MaintenanceType type = MaintenanceType.oilChange,
        int? mileage,
        String? shop,
      }) {
        return MaintenanceRecord(
          id: 'r-${date.millisecondsSinceEpoch}',
          vehicleId: 'veh-a-family',
          userId: 'user-a',
          type: type,
          title: type.displayName,
          cost: cost,
          date: date,
          mileageAtService: mileage,
          shopName: shop,
          createdAt: date,
        );
      }

      final review = YearInReview.from(
        records: [
          rec(
            date: DateTime(2025, 9, 12),
            cost: 5800,
            mileage: 30000,
            shop: 'タカヤモーター',
          ),
          rec(
            date: DateTime(2025, 12, 3),
            cost: 42000,
            type: MaintenanceType.tireRotation,
            mileage: 33200,
            shop: 'タカヤモーター',
          ),
          rec(
            date: DateTime(2026, 3, 18),
            cost: 74000,
            type: MaintenanceType.legalInspection24,
            mileage: 37800,
            shop: 'タカヤモーター',
          ),
          rec(
            date: DateTime(2026, 7, 2),
            cost: 6200,
            mileage: 42400,
            shop: 'タカヤモーター',
          ),
        ],
        from: DateTime(2025, 8, 27),
        to: DateTime(2026, 8, 27),
        peerAverageCost: 152000,
      );

      await shoot(
        tester,
        YearInReviewScreen(review: review, vehicleName: 'トヨタ アルファード'),
        'year_in_review',
      );
    });

    testWidgets('この1年のふりかえり（記録が足りないとき）', (tester) async {
      final review = YearInReview.from(
        records: const [],
        from: DateTime(2025, 8, 27),
        to: DateTime(2026, 8, 27),
      );

      await shoot(
        tester,
        YearInReviewScreen(review: review, vehicleName: 'トヨタ アルファード'),
        'year_in_review_empty',
      );
    });
  });

  group('燃費の見え方（値の確認）', () {
    // 画像だけでなく、数字が合っていることも一緒に固定しておく。
    // 「見た目は出ているが値が嘘」がいちばん怖い。
    test('デモに使う値の燃費が期待どおり', () {
      FuelRecord fuel(DateTime date, double liters, int odo) => FuelRecord(
            id: '',
            vehicleId: 'veh-a-family',
            userId: 'user-a',
            date: date,
            liters: liters,
            cost: (liters * 170).round(),
            odometer: odo,
            isFullTank: true,
            createdAt: date,
          );

      final efficiency = FuelEfficiency.latestFor([
        fuel(DateTime(2026, 7, 1), 38, 30000),
        fuel(DateTime(2026, 8, 1), 40, 30500),
      ]);

      expect(efficiency, closeTo(12.5, 0.01));
    });
  });

  group('店側の画面', () {
    testWidgets('お客様に配るコード（発行前）', (tester) async {
      final service = ShopInviteService(firestore: FakeFirebaseFirestore());

      await shoot(
        tester,
        ShopInviteManageScreen(
          service: service,
          shopId: 'shop_takaya_motor_okayama',
          shopName: 'タカヤモーター株式会社',
          shopOwnerId: 'shop-owner-takaya',
        ),
        'shop_invite_manage_before',
      );
    });

    testWidgets('お客様に配るコード（発行後・顧客3名）', (tester) async {
      final firestore = FakeFirebaseFirestore();
      final service = ShopInviteService(firestore: firestore);
      for (final uid in ['user-a', 'user-c', 'persona-j-user']) {
        await firestore.collection('shop_customers').doc(uid).set({
          'shopId': 'shop_takaya_motor_okayama',
          'shopName': 'タカヤモーター株式会社',
          'userId': uid,
          'linkedAt': DateTime(2026, 8, 27),
        });
      }

      await tester.binding.setSurfaceSize(_phone);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: goldenTheme(AppTheme.lightTheme),
          home: ShopInviteManageScreen(
            service: service,
            shopId: 'shop_takaya_motor_okayama',
            shopName: 'タカヤモーター株式会社',
            shopOwnerId: 'shop-owner-takaya',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('issue_invite_button')));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/shop_invite_manage_issued.png'),
      );
    });
  });

  group('取りこぼしの可視化', () {
    Widget card(InspectionPipeline pipeline) => Scaffold(
          backgroundColor: const Color(0xFFF3F4F6),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: InspectionPipelineCard(
              pipeline: pipeline,
              periodLabel: '2026年9月',
            ),
          ),
        );

    testWidgets('数えられるとき', (tester) async {
      await shoot(
        tester,
        card(const InspectionPipeline(
          dueCount: 48,
          completedCount: 41,
          pendingCount: 7,
          missedCount: 5,
          unknownExpiryCount: 12,
        )),
        'inspection_pipeline',
        size: const Size(390, 420),
      );
    });

    testWidgets('まだ数えられないとき', (tester) async {
      // **「取りこぼし0台」とは書かない。** 分母が無いのに0と出すと
      // 経営判断を誤らせる。
      await shoot(
        tester,
        card(const InspectionPipeline(
          dueCount: 0,
          completedCount: 0,
          pendingCount: 0,
          missedCount: 0,
          unknownExpiryCount: 23,
        )),
        'inspection_pipeline_unknown',
        size: const Size(390, 420),
      );
    });
  });
}
