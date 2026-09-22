// 店側の「お客様に配るコード」画面。
//
// この画面にはウィジェットテストが1本も無かった（2026-09-22 時点。
// ゴールデンは test/golden/new_features_golden_test.dart にあるが、
// あれは CI の対象外で、値の正しさも見ていない）。
//
// ここで見るのは「この先の車検（6か月）」カード。店が段取りを組むための
// 数字なので、**出ていることより、数が合っていること**が大事。

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:trust_car_platform/screens/marketplace/shop_invite_manage_screen.dart';
import 'package:trust_car_platform/services/shop_invite_service.dart';

const _shopId = 'shop_1';
const _ownerId = 'owner_1';
final _today = DateTime(2026, 9, 22);

/// 顧客の紐づけを直接置く。画面は `customersOf(shopId)` で読む。
Future<void> _link(
  FakeFirebaseFirestore fs, {
  required String userId,
  required List<DateTime> expiries,
  int vehicleCount = 1,
  bool sharing = true,
}) async {
  await fs.collection('shop_customers').doc(userId).set(
        ShopCustomerLink(
          shopId: _shopId,
          shopName: 'テスト工場',
          userId: userId,
          linkedAt: DateTime(2026, 1, 1),
          inspectionExpiries: expiries,
          vehicleCount: vehicleCount,
          sharesInspectionExpiry: sharing,
        ).toMap(),
      );
}

Widget _build(FakeFirebaseFirestore fs) {
  return MaterialApp(
    home: ShopInviteManageScreen(
      service: ShopInviteService(firestore: fs, now: () => _today),
      shopId: _shopId,
      shopName: 'テスト工場',
      shopOwnerId: _ownerId,
      today: _today,
    ),
  );
}

void main() {
  group('この先の車検（6か月）', () {
    testWidgets('顧客がいなければ、共有を促す案内が出る', (tester) async {
      final fs = FakeFirebaseFirestore();

      await tester.pumpWidget(_build(fs));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('inspection_forecast_card')), findsOneWidget);
      expect(find.textContaining('満了日を共有すると'), findsOneWidget);
    });

    testWidgets('月ごとの件数が出る', (tester) async {
      final fs = FakeFirebaseFirestore();
      await _link(fs, userId: 'u1', expiries: [DateTime(2026, 10, 5)]);
      await _link(fs, userId: 'u2', expiries: [DateTime(2026, 11, 2)]);
      await _link(fs, userId: 'u3', expiries: [DateTime(2026, 11, 18)]);

      await tester.pumpWidget(_build(fs));
      await tester.pumpAndSettle();

      expect(find.text('2026/10'), findsOneWidget);
      expect(find.text('2026/11'), findsOneWidget);
      // 合計は本文にも出す。
      expect(find.textContaining('合計 3 件'), findsOneWidget);
    });

    testWidgets('共有していない顧客は数に入らない', (tester) async {
      final fs = FakeFirebaseFirestore();
      await _link(fs, userId: 'u1', expiries: [DateTime(2026, 10, 5)]);
      await _link(
        fs,
        userId: 'u2',
        expiries: [DateTime(2026, 10, 9)],
        sharing: false,
      );

      await tester.pumpWidget(_build(fs));
      await tester.pumpAndSettle();

      expect(find.textContaining('合計 1 件'), findsOneWidget);
    });

    testWidgets('個人は出さない（誰のものかは店に渡っていない）', (tester) async {
      final fs = FakeFirebaseFirestore();
      await _link(fs,
          userId: 'customer_taro', expiries: [DateTime(2026, 10, 5)]);

      await tester.pumpWidget(_build(fs));
      await tester.pumpAndSettle();

      // userId が画面に漏れていないこと。出したところで店には意味が無く、
      // 設計上も渡していない情報。
      expect(find.textContaining('customer_taro'), findsNothing);
    });

    group('Edge Cases', () {
      testWidgets('満了日を1件も共有していなくても落ちない', (tester) async {
        final fs = FakeFirebaseFirestore();
        await _link(fs, userId: 'u1', expiries: const [], vehicleCount: 2);

        await tester.pumpWidget(_build(fs));
        await tester.pumpAndSettle();

        expect(
            find.byKey(const Key('inspection_forecast_card')), findsOneWidget);
        expect(find.textContaining('満了日を共有すると'), findsOneWidget);
      });

      testWidgets('6か月より先の満了日は数えない', (tester) async {
        final fs = FakeFirebaseFirestore();
        await _link(fs, userId: 'u1', expiries: [DateTime(2027, 8, 1)]);

        await tester.pumpWidget(_build(fs));
        await tester.pumpAndSettle();

        expect(find.textContaining('満了日を共有すると'), findsOneWidget);
      });
    });
  });
}
