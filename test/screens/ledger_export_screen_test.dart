// 顧客台帳の書き出し（2026-09-29 プロダクト評価 #8・#2）。
//
// 書き出しは個人情報の持ち出し。ここで確かめたいのは、
// **渡したファイルの中身・操作の記録に残ること・案内した日が付くこと**。

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:trust_car_platform/models/shop_ledger.dart';
import 'package:trust_car_platform/screens/shop/ledger/customer_ledger_screen.dart';
import 'package:trust_car_platform/services/shop_audit_service.dart';
import 'package:trust_car_platform/services/shop_ledger_service.dart';
import 'package:trust_car_platform/services/shop_staff_service.dart';

const _shopId = 'shop_1';
final _today = DateTime(2026, 9, 27);

class _Shared {
  final String csv;
  final String fileName;
  _Shared(this.csv, this.fileName);
}

class _Audit {
  final ShopAuditAction action;
  final String? detail;
  _Audit(this.action, this.detail);
}

void main() {
  late FakeFirebaseFirestore fs;
  late ShopLedgerService service;
  late List<_Shared> shared;
  late List<_Audit> audits;
  late bool handOver;

  setUp(() {
    fs = FakeFirebaseFirestore();
    service = ShopLedgerService(firestore: fs, now: () => _today);
    shared = [];
    audits = [];
    handOver = true;
  });

  Widget build({bool owner = true}) {
    return MaterialApp(
      home: CustomerLedgerScreen(
        service: service,
        staffService: owner ? ShopStaffService(firestore: fs) : null,
        ownerUid: owner ? 'owner_uid' : null,
        shopId: _shopId,
        shopName: 'テスト工場',
        today: _today,
        onAudit: (action, {targetId, targetLabel, detail}) =>
            audits.add(_Audit(action, detail)),
        csvSharer: ({required csv, required fileName, required subject}) async {
          shared.add(_Shared(csv, fileName));
          return handOver;
        },
      ),
    );
  }

  Future<LedgerCustomer> add(String name, {String? address = '東京都1-1'}) async {
    return (await service.createCustomer(
      shopId: _shopId,
      kind: LedgerCustomerKind.individual,
      name: name,
      address: address,
    ))
        .valueOrNull!;
  }

  Future<LedgerVehicle> car(
      LedgerCustomer c, String model, DateTime? exp) async {
    return (await service.saveVehicle(
      shopId: _shopId,
      customerId: c.id,
      maker: 'トヨタ',
      model: model,
      inspectionExpiry: exp,
    ))
        .valueOrNull!;
  }

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('ledger_more')));
    await tester.pumpAndSettle();
  }

  Future<LedgerVehicle> reload(LedgerVehicle v) async => LedgerVehicle.fromMap(
      v.id,
      (await fs.doc('shops/$_shopId/customer_vehicles/${v.id}').get()).data()!);

  group('台帳の全件書き出し', () {
    testWidgets('店主のメニューには、全件の書き出しと車検案内の両方が出る', (tester) async {
      await tester.pumpWidget(build(owner: true));
      await tester.pumpAndSettle();
      await openMenu(tester);
      expect(find.text('台帳を書き出す（CSV）'), findsOneWidget);
      expect(find.text('車検案内の宛名を書き出す'), findsOneWidget);
    });

    testWidgets('スタッフのメニューには、車検案内だけが出る（全件は店主だけ）', (tester) async {
      await tester.pumpWidget(build(owner: false));
      await tester.pumpAndSettle();
      await openMenu(tester);
      expect(find.text('台帳を書き出す（CSV）'), findsNothing);
      expect(find.text('車検案内の宛名を書き出す'), findsOneWidget);
    });

    testWidgets('確かめてから書き出し、BOM 付き CSV を渡して操作の記録に残す', (tester) async {
      final a = await add('山田太郎');
      await car(a, 'プリウス', DateTime(2027, 1, 1));
      await add('青木花子');

      await tester.pumpWidget(build());
      await tester.pumpAndSettle();
      await openMenu(tester);
      await tester.tap(find.text('台帳を書き出す（CSV）'));
      await tester.pumpAndSettle();

      // 何人分が出ていくかを先に見せる
      expect(find.textContaining('2人'), findsWidgets);
      expect(shared, isEmpty);

      await tester.tap(find.byKey(const Key('ledger_export_all_confirm')));
      await tester.pumpAndSettle();

      expect(shared, hasLength(1));
      expect(shared.single.csv.startsWith('\u{FEFF}'), isTrue);
      expect(shared.single.csv, contains('山田太郎'));
      expect(shared.single.csv, contains('青木花子'));
      expect(shared.single.fileName, endsWith('.csv'));

      expect(audits.map((e) => e.action), [ShopAuditAction.exportLedger]);
      expect(audits.single.detail, contains('顧客2人'));
      expect(audits.single.detail, contains('車両1台'));
    });

    group('Edge Cases', () {
      testWidgets('確かめる画面でやめたら、何も渡さず記録もしない', (tester) async {
        await add('山田太郎');
        await tester.pumpWidget(build());
        await tester.pumpAndSettle();
        await openMenu(tester);
        await tester.tap(find.text('台帳を書き出す（CSV）'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('やめる'));
        await tester.pumpAndSettle();

        expect(shared, isEmpty);
        expect(audits, isEmpty);
      });
    });
  });

  group('車検案内の宛名の書き出し', () {
    testWidgets('期間内の車だけを書き出し、案内した日を付け、記録に残す', (tester) async {
      final a = await add('山田太郎');
      final near = await car(a, '近い', DateTime(2026, 10, 20));
      final far = await car(a, '遠い', DateTime(2027, 3, 1));

      await tester.pumpWidget(build(owner: false));
      await tester.pumpAndSettle();
      await openMenu(tester);
      await tester.tap(find.text('車検案内の宛名を書き出す'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ledger_notice_export')));
      await tester.pumpAndSettle();

      expect(shared, hasLength(1));
      final csv = shared.single.csv;
      expect(csv.startsWith('\u{FEFF}'), isTrue);
      expect(csv, contains('トヨタ 近い'));
      expect(csv, isNot(contains('トヨタ 遠い')));

      expect((await reload(near)).inspectionNoticeAt, _today);
      expect((await reload(far)).inspectionNoticeAt, isNull);

      expect(audits.map((e) => e.action),
          [ShopAuditAction.exportInspectionNotice]);
      expect(audits.single.detail, contains('1台'));
      expect(find.textContaining('1台'), findsWidgets);
    });

    testWidgets('期間を3か月にすると、その先の車も入る', (tester) async {
      final a = await add('山田太郎');
      await car(a, '近い', DateTime(2026, 10, 20));
      await car(a, '12月', DateTime(2026, 12, 20));

      await tester.pumpWidget(build());
      await tester.pumpAndSettle();
      await openMenu(tester);
      await tester.tap(find.text('車検案内の宛名を書き出す'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ledger_notice_months_3')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ledger_notice_export')));
      await tester.pumpAndSettle();

      expect(shared.single.csv, contains('トヨタ 12月'));
    });

    group('Edge Cases', () {
      testWidgets('対象の車が無ければ、何も渡さず記録もしない', (tester) async {
        final a = await add('山田太郎');
        await car(a, '遠い', DateTime(2027, 3, 1));

        await tester.pumpWidget(build());
        await tester.pumpAndSettle();
        await openMenu(tester);
        await tester.tap(find.text('車検案内の宛名を書き出す'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('ledger_notice_export')));
        await tester.pumpAndSettle();

        expect(shared, isEmpty);
        expect(audits, isEmpty);
        expect(find.textContaining('対象の車はありません'), findsOneWidget);
      });

      testWidgets('共有を取り消したら案内した日は付けない（記録は残す）', (tester) async {
        handOver = false;
        final a = await add('山田太郎');
        final near = await car(a, '近い', DateTime(2026, 10, 20));

        await tester.pumpWidget(build());
        await tester.pumpAndSettle();
        await openMenu(tester);
        await tester.tap(find.text('車検案内の宛名を書き出す'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('ledger_notice_export')));
        await tester.pumpAndSettle();

        expect(shared, hasLength(1));
        expect((await reload(near)).inspectionNoticeAt, isNull);
        expect(audits.map((e) => e.action),
            [ShopAuditAction.exportInspectionNotice]);
      });

      testWidgets('住所の無い客は除いたと知らせる', (tester) async {
        final a = await add('山田太郎');
        await car(a, '近い', DateTime(2026, 10, 20));
        final b = await add('住所なし', address: null);
        await car(b, '近い2', DateTime(2026, 10, 21));

        await tester.pumpWidget(build());
        await tester.pumpAndSettle();
        await openMenu(tester);
        await tester.tap(find.text('車検案内の宛名を書き出す'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('ledger_notice_export')));
        await tester.pumpAndSettle();

        expect(shared.single.csv, isNot(contains('住所なし')));
        expect(find.textContaining('住所の無い1台'), findsOneWidget);
      });
    });
  });
}
