@Tags(['golden'])
library;

// 2026-09-27 に足した画面（docs/SHOP_CRM_DESIGN_2026-09-27.md）。
//
// 店の顧客台帳・CSV 取込・新しい店への共有・車種別の維持費レポート。
// 見え方は撮った本人が目視する（CLAUDE.md「ゴールデンテストは CI から外してある」）。

import 'dart:convert';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:trust_car_platform/core/result/result.dart';
import 'package:trust_car_platform/core/theme/app_theme.dart';
import 'package:trust_car_platform/models/maintenance_record.dart';
import 'package:trust_car_platform/models/model_cost_report.dart';
import 'package:trust_car_platform/models/vehicle.dart';
import 'package:trust_car_platform/screens/shop/ledger/customer_detail_screen.dart';
import 'package:trust_car_platform/screens/shop/ledger/customer_ledger_screen.dart';
import 'package:trust_car_platform/screens/shop/ledger/ledger_csv_import_screen.dart';
import 'package:trust_car_platform/screens/shop/ledger/shared_vehicles_screen.dart';
import 'package:trust_car_platform/screens/vehicle/model_cost_report_screen.dart';
import 'package:trust_car_platform/screens/vehicle/share_to_shop_screen.dart';
import 'package:trust_car_platform/services/ledger_csv_import.dart';
import 'package:trust_car_platform/services/shop_ledger_service.dart';
import 'package:trust_car_platform/services/vehicle_share_service.dart';

import 'font_loader.dart';

const _phone = Size(390, 844);
final _today = DateTime(2026, 9, 27);
const _shopId = 'shop_takaya';

const _rosterCsv = '顧客番号,顧客名,フリガナ,登録番号,メーカー,車名,車検満了日,最終入庫日\n'
    'C001,株式会社サンプル運輸,サンプルウンユ,品川400さ1,トヨタ,ハイエース,2026/10/10,2026/4/1\n'
    'C001,株式会社サンプル運輸,サンプルウンユ,品川400さ2,トヨタ,ハイエース,2027/1/20,2026/6/1\n'
    'C002,山田太郎,ヤマダタロウ,品川300あ1234,MINI,クーパー,2026/11/5,2025/7/1\n'
    'C003,青木花子,アオキハナコ,品川500い55,ホンダ,N-BOX,2027/3/1,2024/8/1\n'
    'C004,佐藤次郎,サトウジロウ,品川300う777,日産,ノート,R8.12.24,2026/9/1\n';

Vehicle _vehicle() => Vehicle(
      id: 'v1',
      userId: 'u1',
      maker: 'MINI',
      model: 'クーパー',
      year: 2019,
      grade: 'S',
      mileage: 48210,
      licensePlate: '品川 300 あ 12-34',
      inspectionExpiryDate: DateTime(2027, 4, 1),
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
    );

List<MaintenanceRecord> _records() => [
      for (final (i, d, t, c) in [
        (1, DateTime(2026, 5, 1), 'オイル交換', 8800),
        (2, DateTime(2025, 11, 12), 'タイヤ交換（4本）', 92000),
        (3, DateTime(2025, 4, 2), '車検', 132000),
      ])
        MaintenanceRecord(
          id: 'r$i',
          vehicleId: 'v1',
          userId: 'u1',
          type: MaintenanceType.oilChange,
          title: t,
          cost: c,
          date: d,
          mileageAtService: 40000 + i * 2500,
          shopName: '前の店',
          createdAt: d,
        ),
    ];

Future<ShopLedgerService> _seededLedger(FakeFirebaseFirestore fs) async {
  final service = ShopLedgerService(firestore: fs, now: () => _today);
  final table = parseCsv(_rosterCsv);
  await service.importPlan(
    shopId: _shopId,
    plan: buildImportPlan(table.sublist(1), guessColumns(table.first)),
  );
  return service;
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
    Future<void> Function()? before,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(theme: goldenTheme(AppTheme.lightTheme), home: screen),
    );
    await tester.pumpAndSettle();
    if (before != null) {
      await before();
      await tester.pumpAndSettle();
    }

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/$name.png'),
    );
  }

  group('店の顧客台帳', () {
    testWidgets('一覧（件数・50音順）', (tester) async {
      final fs = FakeFirebaseFirestore();
      final service = await _seededLedger(fs);
      await shoot(
        tester,
        CustomerLedgerScreen(
          service: service,
          shareService: VehicleShareService(firestore: fs, now: () => _today),
          shopId: _shopId,
          shopName: 'タカヤモーター',
          today: _today,
        ),
        'ledger_customers',
      );
    });

    testWidgets('車検が近い', (tester) async {
      final fs = FakeFirebaseFirestore();
      final service = await _seededLedger(fs);
      await shoot(
        tester,
        CustomerLedgerScreen(
          service: service,
          shopId: _shopId,
          shopName: 'タカヤモーター',
          today: _today,
        ),
        'ledger_inspection',
        before: () => tester.tap(find.text('車検が近い')),
      );
    });

    testWidgets('顧客詳細（法人・2台）', (tester) async {
      final fs = FakeFirebaseFirestore();
      final service = await _seededLedger(fs);
      await shoot(
        tester,
        CustomerDetailScreen(
          service: service,
          shopId: _shopId,
          customerId: ShopLedgerService.idForExternal('c', 'C001'),
          today: _today,
        ),
        'ledger_customer_detail',
      );
    });

    testWidgets('CSV 取込（ファイルを選んだあと）', (tester) async {
      final fs = FakeFirebaseFirestore();
      await shoot(
        tester,
        LedgerCsvImportScreen(
          service: ShopLedgerService(firestore: fs, now: () => _today),
          shopId: _shopId,
          pickFile: () async =>
              PickedCsvFile('顧客名簿.csv', utf8.encode(_rosterCsv)),
        ),
        'ledger_csv_import',
        size: const Size(390, 1800),
        before: () => tester.tap(find.byKey(const Key('csv_pick'))),
      );
    });

    testWidgets('共有された車（中身）', (tester) async {
      final fs = FakeFirebaseFirestore();
      final shares = VehicleShareService(firestore: fs, now: () => _today);
      await shares.share(
        ownerId: 'u1',
        vehicle: _vehicle(),
        shopId: _shopId,
        shopName: 'タカヤモーター',
        records: _records(),
        days: 30,
        includePlate: true,
        contactName: '山田太郎',
        message: '車検の見積もりをお願いします',
      );
      await shoot(
        tester,
        SharedVehiclesScreen(
          service: shares,
          ledger: ShopLedgerService(firestore: fs, now: () => _today),
          shopId: _shopId,
          today: _today,
        ),
        'shared_vehicle_detail',
        size: const Size(390, 1100),
        before: () => tester.tap(find.byKey(const Key('shared_v1'))),
      );
    });
  });

  group('利用者の画面', () {
    testWidgets('お店に共有する（店を選んだあと）', (tester) async {
      final fs = FakeFirebaseFirestore();
      await shoot(
        tester,
        ShareToShopScreen(
          vehicle: _vehicle(),
          records: _records(),
          ownerId: 'u1',
          service: VehicleShareService(firestore: fs, now: () => _today),
          searchShops: (q) async => const Result.success([]),
        ),
        'share_to_shop',
        size: const Size(390, 1500),
      );
    });

    testWidgets('車種別の維持費レポート', (tester) async {
      final report = ModelCostReport.fromMap('mini__くーぱー', {
        'level': 'model',
        'maker': 'MINI',
        'model': 'クーパー',
        'ownerCount': 12,
        'vehicleCount': 14,
        'maintenanceAnnual': {
          'median': 61000,
          'p25': 42000,
          'p75': 88000,
          'n': 12,
        },
        'inspectionPerEvent': {
          'median': 128000,
          'p25': 105000,
          'p75': 150000,
          'n': 9,
        },
        'fuelAnnual': {'median': 62000, 'p25': 50000, 'p75': 80000, 'n': 6},
        'annualEstimate': 187000,
        'byAge': [
          {'label': '〜3年目', 'median': 38000, 'n': 5},
          {'label': '4〜6年目', 'median': 91000, 'n': 7},
          {'label': '7〜9年目', 'median': 142000, 'n': 5},
        ],
        'topItems': [
          {'type': 'オイル交換', 'owners': 11, 'medianCost': 8800},
          {'type': 'タイヤ交換', 'owners': 7, 'medianCost': 88000},
          {'type': 'バッテリー交換', 'owners': 6, 'medianCost': 32000},
        ],
        'sources': {'app': 7, 'shop': 5},
      });
      await shoot(
        tester,
        ModelCostReportScreen(report: report, onBrowseOthers: () {}),
        'model_cost_report',
        size: const Size(390, 1500),
      );
    });
  });
}
