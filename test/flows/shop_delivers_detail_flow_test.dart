// 流れ: 店が名簿を入れ、お客さんとつながり、整備明細を届ける。
//
//   店主   顧客台帳 → CSV で名簿を取り込む → 顧客を開く → 専用コードを出す
//   お客さん アプリで「お店のコード」を入れる
//   店主   顧客を開く（アプリ利用中）→ 整備明細を送る
//   お客さん 届いた明細を「記録に追加」→ 工場の記録として入る
//
// 部品ごとのテストはどれも通っていたのに、最後の「記録に追加」で
// 「車両が特定できない」と出る不具合があった（店から開いたスレッドには
// お客さんの車の ID が入らない）。つないだときにだけ出る壊れ方を拾う。

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/models/inquiry.dart';
import 'package:trust_car_platform/screens/marketplace/inquiry_thread_screen.dart';
import 'package:trust_car_platform/screens/settings/shop_invite_screen.dart';
import 'package:trust_car_platform/screens/shop/ledger/customer_ledger_screen.dart';
import 'package:trust_car_platform/screens/shop/ledger/ledger_csv_import_screen.dart';
import 'package:trust_car_platform/screens/shop/ledger/audit_log_screen.dart';
import 'package:trust_car_platform/services/ledger_link_service.dart';
import 'package:trust_car_platform/services/shop_audit_service.dart';
import 'package:trust_car_platform/services/shop_invite_service.dart';
import 'package:trust_car_platform/services/shop_ledger_service.dart';

import 'flow_harness.dart';

const _roster = '顧客番号,顧客名,フリガナ,登録番号,メーカー,車名,車検満了日\n'
    'C001,山田太郎,ヤマダタロウ,品川300あ1234,MINI,クーパー,2027/4/1\n'
    'C002,佐藤花子,サトウハナコ,品川500い55,ホンダ,N-BOX,2026/12/1\n';

void main() {
  // 店のIDの形は2つとも通す（これまでの形・自動ID。
  // docs/SHOP_ID_DECOUPLING_DESIGN.md）
  for (final form in ShopIdForm.values) {
    testWidgets('店が名簿を入れ、お客さんとつながり、整備明細を届ける（${form.label}）', (tester) async {
      await _shopDeliversDetailFlow(tester, form);
    });
  }
}

Future<void> _shopDeliversDetailFlow(
    WidgetTester tester, ShopIdForm form) async {
  final world = FlowWorld();
  final owner = FlowActor('owner1', 'タカヤ店主');
  final yamada = FlowActor('app-yamada', '山田太郎');
  final shopId = await world.createShop(owner, 'タカヤモーター', form: form);
  final car = await world.createVehicle(yamada);

  final audit = ShopAuditService(firestore: world.fs, now: () => world.today);
  Widget ledger() => CustomerLedgerScreen(
        onAudit: audit.recorderFor(
            shopId: shopId, actorUid: owner.uid, actorName: owner.name),
        auditService: audit,
        service: ShopLedgerService(firestore: world.fs, now: () => world.today),
        linkService:
            LedgerLinkService(firestore: world.fs, now: () => world.today),
        inviteService:
            ShopInviteService(firestore: world.fs, now: () => world.today),
        ownerUid: owner.uid,
        shopId: shopId,
        shopName: 'タカヤモーター',
        today: world.today,
        csvPicker: () async => PickedCsvFile('名簿.csv', utf8.encode(_roster)),
      );

  // ---- 店主: 名簿を取り込む ----
  await world.pumpAs(tester, owner, ledger());
  await tester.tap(find.byKey(const Key('ledger_import_csv')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('csv_pick')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('csv_import_run')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('csv_import_done')));
  await tester.pumpAndSettle();
  expect(find.text('山田太郎'), findsOneWidget);

  // ---- 店主: 山田さん専用のコードを出す ----
  await tester.tap(find.text('山田太郎'));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('customer_issue_invite')));
  await tester.pumpAndSettle();
  final code = tester
      .widget<SelectableText>(find.byKey(const Key('customer_invite_code')))
      .data!;

  // ---- 山田さん: アプリでコードを入れる ----
  await world.pumpAs(
    tester,
    yamada,
    ShopInviteScreen(
      service: ShopInviteService(firestore: world.fs, now: () => world.today),
      userId: yamada.uid,
      vehicles: [car],
    ),
  );
  await tester.enterText(find.byKey(const Key('invite_code_field')), code);
  await tester.tap(find.byKey(const Key('invite_submit_button')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('linked_shop_card')), findsOneWidget);

  // ---- 店主: 山田さんを開くと「アプリ利用中」。明細を送る ----
  await world.pumpAs(tester, owner, ledger());
  await tester.tap(find.text('山田太郎'));
  await tester.pumpAndSettle();
  expect(find.text('利用中'), findsOneWidget);

  await tester.tap(find.byKey(const Key('customer_send_detail')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('send_maintenance_detail_btn')));
  await tester.pumpAndSettle();
  await tester.enterText(
      find.byKey(const Key('detail_title_field')), '24か月点検・車検');
  await tester.enterText(find.byKey(const Key('detail_cost_field')), '128000');
  await tester.tap(find.text('送信'));
  await tester.pumpAndSettle();
  expect(find.text('整備明細を送信しました'), findsOneWidget);

  // ---- 山田さん: 届いた明細を「記録に追加」----
  final inquiries = await world.fs
      .collection('inquiries')
      .where('userId', isEqualTo: yamada.uid)
      .get();
  expect(inquiries.docs, hasLength(1));
  final inquiry = Inquiry.fromFirestore(inquiries.docs.single);

  await world.pumpAs(tester, yamada, InquiryThreadScreen(inquiry: inquiry));
  await tester.tap(find.byKey(const Key('import_maintenance_btn')));
  await tester.pumpAndSettle();
  expect(find.text('整備記録に追加しました'), findsOneWidget);

  // 山田さんの車に、工場の記録として入っている（車両画面と同じ読み出し経路）
  final records = await world
      .firebaseFor(yamada)
      .getVehicleMaintenanceRecords(car.id)
      .first;
  expect(records, hasLength(1));
  expect(records.single.cost, 128000);
  expect(records.single.isVerified, isTrue);
  expect(records.single.inquiryId, inquiry.id);

  // ---- 山田さん: スレッドを開き直しても「追加済み」。二重に取り込めない ----
  // （2026-10-09 使用感テスト: 画面の中でしか覚えていなかった）
  await world.pumpAs(tester, yamada, InquiryThreadScreen(inquiry: inquiry));
  expect(find.byKey(const Key('import_maintenance_done')), findsOneWidget);
  expect(find.byKey(const Key('import_maintenance_btn')), findsNothing);
  final again = await world
      .firebaseFor(yamada)
      .getVehicleMaintenanceRecords(car.id)
      .first;
  expect(again, hasLength(1));

  // 明細には店が選んだ車（台帳の1台）が入っている
  final detailMessages = await world.fs
      .collection('inquiries')
      .doc(inquiry.id)
      .collection('messages')
      .get();
  final payload = detailMessages.docs
      .map((d) => d.data()['maintenancePayload'])
      .firstWhere((p) => p != null) as Map;
  expect(payload['licensePlate'], '品川300あ1234');
  expect(payload['vehicleLabel'], 'MINI クーパー');

  // ---- 店主: 顧客を開くと、送った明細が「記録に追加済み」----
  await world.pumpAs(tester, owner, ledger());
  await tester.tap(find.text('山田太郎'));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('sent_details_section')), findsOneWidget);
  expect(find.textContaining('記録に追加済み'), findsOneWidget);

  // ---- 店主: 操作の記録に、取込・閲覧・コード発行・明細送付が残っている ----
  await world.pumpAs(
      tester, owner, AuditLogScreen(service: audit, shopId: shopId));
  for (final label in ['名簿を取り込んだ', '顧客を見た', '顧客専用のコードを出した', '整備明細を送った']) {
    expect(find.textContaining(label), findsWidgets, reason: label);
  }
}
