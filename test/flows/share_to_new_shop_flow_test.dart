// 流れ: 初めて行く店に、車のこれまでを渡す → 店が受け取って台帳に登録する。
//
//   お客さん お店を名前で探す → 渡す内容を選ぶ（連絡先をオン）→ 渡す
//   店主   顧客台帳の受信箱 → 届いた車を開く（未読が消える）→ 台帳に登録
//        → 顧客として台帳に並び、車検満了日の近い順にも出る
//
// 店の検索は本物の ShopService（isActive と名前の前方一致）を通す。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/models/maintenance_record.dart';
import 'package:trust_car_platform/screens/shop/ledger/customer_ledger_screen.dart';
import 'package:trust_car_platform/screens/vehicle/share_to_shop_screen.dart';
import 'package:trust_car_platform/services/shop_ledger_service.dart';
import 'package:trust_car_platform/services/shop_service.dart';
import 'package:trust_car_platform/services/vehicle_share_service.dart';

import 'flow_harness.dart';

void main() {
  testWidgets('初めて行く店に車のこれまでを渡し、店が台帳に登録する', (tester) async {
    final world = FlowWorld();
    final owner = FlowActor('owner1', 'タカヤ店主');
    final yamada = FlowActor('app-yamada', '山田太郎');
    await world.createShop(owner, 'タカヤモーター');
    final car = await world.createVehicle(yamada);
    final records = [
      MaintenanceRecord(
        id: 'r1',
        vehicleId: car.id,
        userId: yamada.uid,
        type: MaintenanceType.carInspection,
        title: '車検',
        cost: 132000,
        date: DateTime(2025, 4, 2),
        mileageAtService: 42000,
        shopName: '前の店',
        createdAt: DateTime(2025, 4, 2),
      ),
    ];
    VehicleShareService shares() =>
        VehicleShareService(firestore: world.fs, now: () => world.today);

    // ---- お客さん: 店を探して渡す ----
    await world.pumpAs(
      tester,
      yamada,
      ShareToShopScreen(
        vehicle: car.copyWith(inspectionExpiryDate: DateTime(2027, 4, 1)),
        records: records,
        ownerId: yamada.uid,
        defaultContactName: '山田太郎',
        service: shares(),
        searchShops: (q) => ShopService(firestore: world.fs).searchShops(q),
      ),
    );
    await tester.enterText(find.byKey(const Key('share_shop_query')), 'タカヤ');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('share_shop_${owner.uid}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('share_include_contact')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const Key('share_summary'))).data,
      'タカヤモーター に、MINI クーパー・整備記録1件（費用なし）・連絡先 を30日間渡します。',
    );
    await tester.tap(find.byKey(const Key('share_submit')));
    await tester.pumpAndSettle();

    // ---- 店主: 受信箱から開いて、台帳に登録 ----
    await world.pumpAs(
      tester,
      owner,
      CustomerLedgerScreen(
        service: ShopLedgerService(firestore: world.fs, now: () => world.today),
        shareService: shares(),
        shopId: owner.uid,
        shopName: 'タカヤモーター',
        today: world.today,
      ),
    );
    expect(find.text('まだ顧客が登録されていません'), findsOneWidget);

    await tester.tap(find.byKey(const Key('ledger_shared_vehicles')));
    await tester.pumpAndSettle();
    expect(find.text('未読'), findsOneWidget);
    await tester.tap(find.byKey(Key('shared_${car.id}')));
    await tester.pumpAndSettle();
    // 費用は渡されていない
    expect(find.textContaining('費用は非公開'), findsOneWidget);
    await tester.tap(find.byKey(const Key('shared_import')));
    await tester.pumpAndSettle();

    // 顧客詳細が開き、車が1台
    expect(find.text('車両（1台）'), findsOneWidget);
    expect(find.text('MINI クーパー'), findsOneWidget);

    // 受信箱に戻ると「登録済み」、台帳に戻ると顧客が並ぶ
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('登録済み'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('山田太郎'), findsOneWidget);

    // 車検が近い順にも出る（顧客をまたいだ車両の一覧）
    await tester.tap(find.text('車検が近い'));
    await tester.pumpAndSettle();
    expect(find.text('MINI クーパー　品川 300 あ 12-34'), findsNothing); // ナンバーは渡していない
    expect(find.text('MINI クーパー'), findsOneWidget);
  });
}
