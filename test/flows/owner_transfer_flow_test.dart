// 流れ: 店主をスタッフに引き継ぐ（2026-09-29 プロダクト評価 #5 の前半）。
//
//   店主（前）  台帳 → スタッフ → 佐藤さんの「店主を引き継ぐ」
//   佐藤（新）  掲載管理を開くと、自分の店として開く（店のIDは前の店主の uid のまま）
//   店主（前）  掲載管理を開くと、自分の店は無く「スタッフの方」の入口から台帳へ
//
// 店のIDの形は2つとも通す（docs/SHOP_ID_DECOUPLING_DESIGN.md）:
// - これまでの形（店のID ＝ 最初の店主の uid。本番のタカヤモーター）
// - 新しい形（自動ID。アプリで新しく登録した店）

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/core/di/service_locator.dart';
import 'package:trust_car_platform/models/shop_ledger.dart';
import 'package:trust_car_platform/screens/marketplace/shop_owner_screen.dart';
import 'package:trust_car_platform/screens/shop/ledger/customer_ledger_screen.dart';
import 'package:trust_car_platform/services/ledger_link_service.dart';
import 'package:trust_car_platform/services/shop_audit_service.dart';
import 'package:trust_car_platform/services/shop_demand_service.dart';
import 'package:trust_car_platform/services/shop_invite_service.dart';
import 'package:trust_car_platform/services/shop_ledger_service.dart';
import 'package:trust_car_platform/services/shop_service.dart';
import 'package:trust_car_platform/services/shop_staff_service.dart';
import 'package:trust_car_platform/services/vehicle_share_service.dart';

import 'flow_harness.dart';

void main() {
  for (final form in ShopIdForm.values) {
    testWidgets('店主をスタッフに引き継ぐ（${form.label}）', (tester) async {
      await _ownerTransferFlow(tester, form);
    });
  }
}

Future<void> _ownerTransferFlow(WidgetTester tester, ShopIdForm form) async {
  final world = FlowWorld();
  final oldOwner = FlowActor('owner-old', '初代店主');
  final sato = FlowActor('staff-sato', '佐藤');
  final shopId = await world.createShop(oldOwner, 'タカヤモーター', form: form);

  final ledger = ShopLedgerService(firestore: world.fs, now: () => world.today);
  final staff = ShopStaffService(firestore: world.fs, now: () => world.today);
  sl.override<ShopLedgerService>(ledger);
  sl.override<ShopStaffService>(staff);
  sl.override<ShopService>(ShopService(firestore: world.fs));
  sl.override<ShopInviteService>(
      ShopInviteService(firestore: world.fs, now: () => world.today));
  sl.override<LedgerLinkService>(
      LedgerLinkService(firestore: world.fs, now: () => world.today));
  sl.override<VehicleShareService>(
      VehicleShareService(firestore: world.fs, now: () => world.today));
  sl.override<ShopDemandService>(ShopDemandService(firestore: world.fs));
  sl.override<ShopAuditService>(
      ShopAuditService(firestore: world.fs, now: () => world.today));

  await ledger.createCustomer(
    shopId: shopId,
    kind: LedgerCustomerKind.individual,
    name: '山田太郎',
  );
  // 佐藤さんはスタッフとして参加済み
  final code = (await staff.issue(
    shopId: shopId,
    shopName: 'タカヤモーター',
    issuedBy: oldOwner.uid,
  ))
      .valueOrNull!
      .code;
  await staff.redeem(code: code, uid: sato.uid, displayName: '佐藤');

  // ---- 前の店主: スタッフの一覧から引き継ぐ ----
  await world.pumpAs(
    tester,
    oldOwner,
    Builder(
      builder: (context) => TextButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => CustomerLedgerScreen(
              service: ledger,
              staffService: staff,
              ownerUid: oldOwner.uid,
              ownerName: oldOwner.name,
              shopId: shopId,
              shopName: 'タカヤモーター',
              today: world.today,
            ),
          ),
        ),
        child: const Text('台帳'),
      ),
    ),
  );
  await tester.tap(find.text('台帳'));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('ledger_more')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('スタッフ'));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key('staff_menu_${sato.uid}')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('店主を引き継ぐ'));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('staff_transfer_confirm')));
  await tester.pumpAndSettle();
  expect(find.text('台帳'), findsOneWidget); // 最初の画面まで戻った

  final shop = (await world.fs.doc('shops/$shopId').get()).data()!;
  expect(shop['ownerId'], sato.uid);

  // ---- 佐藤さん: 掲載管理を開くと、自分の店として開く ----
  await world.pumpAs(tester, sato, const ShopOwnerScreen());
  expect(find.text('タカヤモーター'), findsWidgets);
  expect(find.byKey(const Key('customer_ledger_btn')), findsOneWidget);
  expect(find.byKey(const Key('staff_entry')), findsNothing);

  // ---- 前の店主: 自分の店は無く、スタッフの入口から台帳を開ける ----
  await world.pumpAs(tester, oldOwner, const ShopOwnerScreen());
  expect(find.byKey(const Key('customer_ledger_btn')), findsNothing);
  await tester.scrollUntilVisible(
    find.byKey(const Key('staff_entry')),
    300,
    scrollable: find.byType(Scrollable).first,
  );
  expect(find.text('タカヤモーター のスタッフ'), findsOneWidget);
  await tester.tap(find.byKey(const Key('staff_entry')));
  await tester.pumpAndSettle();
  expect(find.text('山田太郎'), findsOneWidget);
  // スタッフになったので、スタッフの管理は出ない
  await tester.tap(find.byKey(const Key('ledger_more')));
  await tester.pumpAndSettle();
  expect(find.text('スタッフ'), findsNothing);
}
