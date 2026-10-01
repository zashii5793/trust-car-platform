// 流れ: 店が整備履歴を取り込み、アプリ利用客への明細をまとめて送る
// （2026-09-29 プロダクト評価 #4「明細送付を入庫の流れに組み込む」）。
//
//   店主   名簿を取り込む → 山田さん専用のコードを出す
//   山田さん アプリでコードを入れる
//   店主   山田さんを開く（「アプリ利用中」になる）
//   店主   整備履歴（伝票）を取り込む → 「送っていない明細」を開く
//          → 明細送付率 0% → すべて選ぶ → まとめて送る → 100%
//   山田さん 届いた明細を「記録に追加」→ 工場の記録として入る
//
// アプリを使っていない佐藤さんの伝票は、一覧にも率の分母にも入らない。

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/models/inquiry.dart';
import 'package:trust_car_platform/screens/marketplace/inquiry_thread_screen.dart';
import 'package:trust_car_platform/screens/settings/shop_invite_screen.dart';
import 'package:trust_car_platform/screens/shop/ledger/audit_log_screen.dart';
import 'package:trust_car_platform/screens/shop/ledger/customer_ledger_screen.dart';
import 'package:trust_car_platform/screens/shop/ledger/ledger_csv_import_screen.dart';
import 'package:trust_car_platform/services/detail_delivery_service.dart';
import 'package:trust_car_platform/services/ledger_link_service.dart';
import 'package:trust_car_platform/services/shop_audit_service.dart';
import 'package:trust_car_platform/services/shop_invite_service.dart';
import 'package:trust_car_platform/services/shop_ledger_service.dart';

import 'flow_harness.dart';

const _roster = '顧客番号,顧客名,フリガナ,登録番号,メーカー,車名,車検満了日\n'
    'C001,山田太郎,ヤマダタロウ,品川300あ1234,MINI,クーパー,2027/4/1\n'
    'C002,佐藤花子,サトウハナコ,品川500い55,ホンダ,N-BOX,2026/12/1\n';

const _history = '作業日,伝票番号,顧客番号,作業内容,金額,走行距離\n'
    '2026/9/20,S-100,C001,24か月点検・車検,128000,48200\n'
    '2026/9/22,S-101,C002,オイル交換,8800,30100\n';

void main() {
  testWidgets('整備履歴を取り込み、アプリ利用客への明細をまとめて送る', (tester) async {
    final world = FlowWorld();
    final owner = FlowActor('owner1', 'タカヤ店主');
    final yamada = FlowActor('app-yamada', '山田太郎');
    await world.createShop(owner, 'タカヤモーター');
    final car = await world.createVehicle(yamada);

    final audit = ShopAuditService(firestore: world.fs, now: () => world.today);
    final link = LedgerLinkService(firestore: world.fs, now: () => world.today);
    var csv = _roster;
    Widget ledger() => CustomerLedgerScreen(
          onAudit: audit.recorderFor(
              shopId: owner.uid, actorUid: owner.uid, actorName: owner.name),
          auditService: audit,
          service:
              ShopLedgerService(firestore: world.fs, now: () => world.today),
          linkService: link,
          inviteService:
              ShopInviteService(firestore: world.fs, now: () => world.today),
          deliveryService: DetailDeliveryService(
            firestore: world.fs,
            linkService: link,
            inquiryService: world.inquiryFor(owner),
            now: () => world.today,
          ),
          currentUid: owner.uid,
          ownerUid: owner.uid,
          shopId: owner.uid,
          shopName: 'タカヤモーター',
          today: world.today,
          csvPicker: () async => PickedCsvFile('取込.csv', utf8.encode(csv)),
        );

    // ---- 店主: 名簿を取り込み、山田さん専用のコードを出す ----
    await world.pumpAs(tester, owner, ledger());
    await tester.tap(find.byKey(const Key('ledger_import_csv')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('csv_pick')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('csv_import_run')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('csv_import_done')));
    await tester.pumpAndSettle();
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

    // ---- 店主: 山田さんを開く（台帳に「アプリ利用中」が付く）----
    await world.pumpAs(tester, owner, ledger());
    await tester.tap(find.text('山田太郎'));
    await tester.pumpAndSettle();
    expect(find.text('利用中'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // ---- 店主: 整備履歴を取り込む ----
    csv = _history;
    await tester.tap(find.byKey(const Key('ledger_import_csv')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('整備履歴'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('csv_pick')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('csv_history_run')));
    await tester.pumpAndSettle();
    expect(find.text('伝票 2件'), findsOneWidget);
    expect(find.byKey(const Key('csv_history_send_hint')), findsOneWidget);
    await tester.tap(find.byKey(const Key('csv_import_done')));
    await tester.pumpAndSettle();

    // ---- 店主: 送っていない明細を開く。並ぶのは山田さんの1件だけ ----
    await tester.tap(find.byKey(const Key('ledger_unsent_details')));
    await tester.pumpAndSettle();
    expect(find.text('0%'), findsOneWidget);
    expect(find.textContaining('アプリ利用客の入庫 1件のうち 0件'), findsOneWidget);
    expect(find.textContaining('山田太郎'), findsOneWidget);
    expect(find.textContaining('佐藤花子'), findsNothing);

    await tester.tap(find.byKey(const Key('detail_select_all')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('detail_send_selected')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('detail_send_confirm')));
    await tester.pumpAndSettle();
    expect(find.textContaining('1件の整備明細を送りました'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('送っていない明細はありません'), findsOneWidget);

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

    final records = await world
        .firebaseFor(yamada)
        .getVehicleMaintenanceRecords(car.id)
        .first;
    expect(records, hasLength(1));
    expect(records.single.cost, 128000);
    expect(records.single.mileageAtService, 48200);
    expect(records.single.date, DateTime(2026, 9, 20));
    expect(records.single.isVerified, isTrue);
    expect(records.single.inquiryId, inquiry.id);

    // ---- 店主: もう一度開いても、二重には並ばない。記録も残っている ----
    await world.pumpAs(tester, owner, ledger());
    await tester.tap(find.byKey(const Key('ledger_unsent_details')));
    await tester.pumpAndSettle();
    expect(find.text('送っていない明細はありません'), findsOneWidget);

    await world.pumpAs(
        tester, owner, AuditLogScreen(service: audit, shopId: owner.uid));
    expect(find.textContaining('整備履歴を取り込んだ'), findsWidgets);
    expect(find.textContaining('まとめて送った'), findsWidgets);
  });
}
