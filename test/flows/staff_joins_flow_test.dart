// 流れ: スタッフが招待コードで参加し、顧客台帳を開いて明細を送る。
//
//   店主    顧客台帳 → メニュー「スタッフ」→ コードを発行
//   スタッフ 掲載管理（自分の店は無い）→「店のスタッフの方」→ コードを入れる
//          → その店の顧客台帳が開く → つながったお客さんに整備明細を送る
//   店主    スタッフの一覧に名前が出る
//
// スタッフは自分の店を持たない。本物の「掲載管理」画面の入口から入れるかを
// 確かめる。店のIDの形は2つとも通す（docs/SHOP_ID_DECOUPLING_DESIGN.md）:
// これまでの形（店のID ＝ 店主の uid）と、新しい形（自動ID）。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/core/di/service_locator.dart';
import 'package:trust_car_platform/models/shop_ledger.dart';
import 'package:trust_car_platform/screens/marketplace/shop_owner_screen.dart';
import 'package:trust_car_platform/screens/shop/ledger/customer_ledger_screen.dart';
import 'package:trust_car_platform/services/ledger_link_service.dart';
import 'package:trust_car_platform/services/shop_invite_service.dart';
import 'package:trust_car_platform/services/shop_ledger_service.dart';
import 'package:trust_car_platform/services/shop_service.dart';
import 'package:trust_car_platform/services/shop_staff_service.dart';
import 'package:trust_car_platform/services/vehicle_share_service.dart';

import 'flow_harness.dart';

void main() {
  for (final form in ShopIdForm.values) {
    testWidgets('スタッフが参加して、顧客台帳から明細を送る（${form.label}）', (tester) async {
      await _staffJoinsFlow(tester, form);
    });
  }
}

Future<void> _staffJoinsFlow(WidgetTester tester, ShopIdForm form) async {
  final world = FlowWorld();
  final owner = FlowActor('owner1', 'タカヤ店主');
  final staff = FlowActor('staff-sato', '佐藤');
  final yamada = FlowActor('app-yamada', '山田太郎');
  final shopId = await world.createShop(owner, 'タカヤモーター', form: form);

  final ledger = ShopLedgerService(firestore: world.fs, now: () => world.today);
  final invites =
      ShopInviteService(firestore: world.fs, now: () => world.today);
  final links = LedgerLinkService(firestore: world.fs, now: () => world.today);
  final staffService =
      ShopStaffService(firestore: world.fs, now: () => world.today);
  sl.override<ShopLedgerService>(ledger);
  sl.override<ShopInviteService>(invites);
  sl.override<LedgerLinkService>(links);
  sl.override<ShopStaffService>(staffService);
  // 本物のアプリと同じく、スタッフの入口が店の ownerId（いまの店主）を引ける
  sl.override<ShopService>(ShopService(firestore: world.fs));
  sl.override<VehicleShareService>(
      VehicleShareService(firestore: world.fs, now: () => world.today));

  // 山田さんは、すでに台帳に載っていてアプリともつながっている
  final c = (await ledger.createCustomer(
    shopId: shopId,
    kind: LedgerCustomerKind.individual,
    name: '山田太郎',
    nameKana: 'ヤマダタロウ',
  ))
      .valueOrNull!;
  final code = (await invites.createInvite(
    shopId: shopId,
    shopName: 'タカヤモーター',
    shopOwnerId: owner.uid,
    customerId: c.id,
  ))
      .valueOrNull!
      .code;
  await invites.redeem(code: code, userId: yamada.uid);

  // ---- 店主: スタッフ用のコードを発行 ----
  await world.pumpAs(
    tester,
    owner,
    CustomerLedgerScreen(
      service: ledger,
      staffService: staffService,
      ownerUid: owner.uid,
      linkService: links,
      inviteService: invites,
      shopId: shopId,
      shopName: 'タカヤモーター',
      today: world.today,
    ),
  );
  await tester.tap(find.byKey(const Key('ledger_more')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('スタッフ'));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('staff_issue')));
  await tester.pumpAndSettle();
  final staffCode = tester
      .widget<SelectableText>(find.byKey(const Key('staff_invite_code')))
      .data!;

  // ---- スタッフ: 掲載管理（自分の店は無い）から参加 ----
  await world.pumpAs(tester, staff, const ShopOwnerScreen());
  await tester.scrollUntilVisible(
    find.byKey(const Key('staff_entry')),
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(find.byKey(const Key('staff_entry')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('staff_join_code')), staffCode);
  await tester.tap(find.byKey(const Key('staff_join_submit')));
  await tester.pumpAndSettle();

  // その店の顧客台帳が開く
  expect(find.text('顧客台帳'), findsOneWidget);
  expect(find.text('山田太郎'), findsOneWidget);

  // ---- スタッフ: 山田さんに整備明細を送る ----
  await tester.tap(find.text('山田太郎'));
  await tester.pumpAndSettle();
  expect(find.text('利用中'), findsOneWidget);
  await tester.tap(find.byKey(const Key('customer_send_detail')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('send_maintenance_detail_btn')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('detail_title_field')), 'オイル交換');
  await tester.enterText(find.byKey(const Key('detail_cost_field')), '8800');
  await tester.tap(find.text('送信'));
  await tester.pumpAndSettle();
  expect(find.text('整備明細を送信しました'), findsOneWidget);

  // 送ったのはスタッフ本人（誰が送ったかが残る）
  final inquiry = (await world.fs
          .collection('inquiries')
          .where('userId', isEqualTo: yamada.uid)
          .get())
      .docs
      .single;
  final messages = await inquiry.reference.collection('messages').get();
  final detail = messages.docs
      .map((d) => d.data())
      .firstWhere((m) => m['maintenancePayload'] != null);
  expect(detail['senderId'], staff.uid);

  // ---- 店主: スタッフの一覧に名前が出る ----
  final members = (await staffService.members(shopId)).valueOrNull!;
  switch (form) {
    case ShopIdForm.ownerUid:
      // これまでの形の店は、名簿に店主の行が無い（本番のタカヤモーター）
      expect(members.map((m) => m.displayName), ['佐藤']);
    case ShopIdForm.autoId:
      // 新しい形の店は、作ったときに店主が owner として名簿に載る
      expect(
        members.map((m) => '${m.displayName}:${m.role}'),
        unorderedEquals(['タカヤ店主:owner', '佐藤:staff']),
      );
  }
}
