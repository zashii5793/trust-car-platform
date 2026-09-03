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
import 'package:trust_car_platform/models/vehicle.dart';
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

/// 画像を撮る日。**画面の「今日」を全部これに寄せる。**
///
/// 寄せないと、日付が写る画面（給油日の初期値・「◯月◯日に更新」・
/// 車検の集計期間）が**日付が変わっただけで落ちる**。2026-09-01 に撮った
/// 画像が 09-03 に3件落ちたのが実例。
final _goldenToday = DateTime(2026, 9, 1);

/// 画面に渡すだけのダミー車両。**中身は店に渡らない**ことを示すために置く。
Vehicle demoVehicle({required String id, DateTime? expiry}) {
  return Vehicle(
    id: id,
    userId: 'user-a',
    maker: 'トヨタ',
    model: 'アルファード',
    year: 2021,
    grade: 'Z',
    mileage: 30450,
    createdAt: DateTime(2025, 1, 1),
    updatedAt: DateTime(2026, 8, 27),
    inspectionExpiryDate: expiry,
  );
}

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
      final service = ShopInviteService(
        firestore: FakeFirebaseFirestore(),
        now: () => _goldenToday,
      );

      await shoot(
        tester,
        ShopInviteScreen(service: service, userId: 'user-a'),
        'shop_invite_empty',
      );
    });

    testWidgets('お店のコードを入れる（登録済み）', (tester) async {
      final firestore = FakeFirebaseFirestore();
      final service = ShopInviteService(
        firestore: firestore,
        now: () => _goldenToday,
      );
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
        ShopInviteScreen(
          service: service,
          userId: 'user-a',
          // 満了日が店に渡っている状態を写す。渡るのは日付と台数だけで、
          // 車種も走行距離もこの画面から出て行かない。
          vehicles: [
            demoVehicle(id: 'veh-a-family', expiry: DateTime(2026, 11, 20)),
            demoVehicle(id: 'veh-a-second', expiry: null),
          ],
        ),
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
          today: _goldenToday,
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
      final service = ShopInviteService(
        firestore: FakeFirebaseFirestore(),
        now: () => _goldenToday,
      );

      await shoot(
        tester,
        ShopInviteManageScreen(
          service: service,
          shopId: 'shop_takaya_motor_okayama',
          shopName: 'タカヤモーター株式会社',
          shopOwnerId: 'shop-owner-takaya',
          today: _goldenToday,
        ),
        'shop_invite_manage_before',
      );
    });

    testWidgets('お客様に配るコード（発行後・顧客3名）', (tester) async {
      final firestore = FakeFirebaseFirestore();
      final service = ShopInviteService(
        firestore: firestore,
        now: () => _goldenToday,
      );
      // 満了日は画面の「今日」を基準に置く。相対で置いておけば、撮る日を
      // 動かしてもカードの中身（迫っている／猶予がある）が変わらない。
      final now = _goldenToday;
      final expiriesByUser = {
        'user-a': [now.add(const Duration(days: 40))],
        'user-c': [now.add(const Duration(days: 12))],
        'persona-j-user': [now.subtract(const Duration(days: 30))],
      };
      for (final uid in ['user-a', 'user-c', 'persona-j-user']) {
        await firestore.collection('shop_customers').doc(uid).set({
          'shopId': 'shop_takaya_motor_okayama',
          'shopName': 'タカヤモーター株式会社',
          'userId': uid,
          'linkedAt': DateTime(2026, 8, 27),
          'inspectionExpiries': expiriesByUser[uid],
          'vehicleCount': uid == 'user-a' ? 2 : 1,
          'sharesInspectionExpiry': true,
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
            today: _goldenToday,
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

    testWidgets('店が受け取った満了日だけで数えるとき', (tester) async {
      // 店は顧客の整備記録を読めない（読めるようにするほうが問題）。
      // **入庫の有無が分からないので「取りこぼし」とは書かない。**
      final today = DateTime(2026, 9, 20);
      await shoot(
        tester,
        card(InspectionPipeline.fromSharedExpiries(
          customers: [
            CustomerExpirySummary(
              expiries: [DateTime(2026, 9, 25)],
              vehicleCount: 2,
              isSharing: true,
            ),
            CustomerExpirySummary(
              expiries: [DateTime(2026, 9, 1), DateTime(2026, 9, 20)],
              vehicleCount: 2,
              isSharing: true,
            ),
            CustomerExpirySummary(
              expiries: const [],
              vehicleCount: 3,
              isSharing: false,
            ),
          ],
          from: DateTime(2026, 9, 1),
          to: DateTime(2026, 9, 30),
          today: today,
        )),
        'inspection_pipeline_shared',
        size: const Size(390, 480),
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
