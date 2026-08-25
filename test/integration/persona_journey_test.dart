// ペルソナ・ジャーニーテスト（利用1年後の状態を再現）
//
// persona_scenarios_test.dart が「機能単位のシナリオ」を検証するのに対し、
// 本ファイルはペルソナが1年使い込んだ後のデータ量・データ状態を
// FakeFirebaseFirestore 上に構築し、サービス層を通した一連の流れを検証する。
//
//   Persona B: 法人100台級フリート — 車検期限切れ・30日以内の台数集計と
//              担当者アサインの参照
//   Persona D: 整備記録4年分 — 時系列取得と明細（parts/partsCost/taxAmount）
//              の Firestore 往復
//   共通:      車両登録→装備（VehicleEquipment）保存→読み戻し→退役→復元
//   公開ドライブログ: isPublic の切替と blurRouteEnds による自宅500m除去
//
// Firebase は FakeCloudFirestore で代替（emulator 不要）。

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/core/constants/firestore_collections.dart';
import 'package:trust_car_platform/core/utils/route_privacy.dart';
import 'package:trust_car_platform/models/drive_log.dart';
import 'package:trust_car_platform/models/maintenance_record.dart';
import 'package:trust_car_platform/models/vehicle.dart';
import 'package:trust_car_platform/services/drive_log_service.dart';
import 'package:trust_car_platform/services/fleet_service.dart';
import 'package:trust_car_platform/services/vehicle_retirement_service.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Vehicle _vehicle({
  String id = 'v1',
  String userId = 'journey-user',
  String maker = 'Toyota',
  String model = 'Prius',
  int year = 2022,
  String? licensePlate,
  DateTime? inspectionExpiryDate,
  VehicleUseCategory? useCategory,
  String? companyId,
  String? assigneeName,
  VehicleEquipment? equipment,
  VehicleStatus status = VehicleStatus.active,
}) {
  return Vehicle(
    id: id,
    userId: userId,
    maker: maker,
    model: model,
    year: year,
    grade: 'S',
    mileage: 30000,
    createdAt: DateTime(2025, 8, 1),
    updatedAt: DateTime(2025, 8, 1),
    licensePlate: licensePlate,
    inspectionExpiryDate: inspectionExpiryDate,
    useCategory: useCategory,
    companyId: companyId,
    assigneeName: assigneeName,
    equipment: equipment,
    status: status,
  );
}

MaintenanceRecord _record({
  required String id,
  required MaintenanceType type,
  required DateTime date,
  String vehicleId = 'prius-d1',
  String userId = 'persona-d-user',
  int cost = 4300,
  int? mileage,
  List<Part> parts = const [],
  List<WorkItem> workItems = const [],
  int? partsCost,
  int? laborCost,
  int? miscCost,
  int? taxAmount,
}) =>
    MaintenanceRecord(
      id: id,
      vehicleId: vehicleId,
      userId: userId,
      type: type,
      title: type.displayName,
      cost: cost,
      date: date,
      mileageAtService: mileage,
      createdAt: date,
      parts: parts,
      workItems: workItems,
      partsCost: partsCost,
      laborCost: laborCost,
      miscCost: miscCost,
      taxAmount: taxAmount,
    );

Future<void> _seedVehicle(
    FakeFirebaseFirestore firestore, Vehicle vehicle) async {
  await firestore
      .collection(FirestoreCollections.vehicles)
      .doc(vehicle.id)
      .set(vehicle.toMap());
}

Future<void> _seedRecord(
    FakeFirebaseFirestore firestore, MaintenanceRecord record) async {
  await firestore
      .collection(FirestoreCollections.maintenanceRecords)
      .doc(record.id)
      .set(record.toMap());
}

void main() {
  // ===========================================================================
  // Persona B ジャーニー: 法人100台級フリートの1年運用
  //   「導入から1年。車両は100台に増えた。月初に車検の危ない車両を
  //    把握し、担当ドライバーを確認して手配する。」
  // ===========================================================================
  group('Persona B ジャーニー — 法人100台フリートの月初点検', () {
    late FakeFirebaseFirestore firestore;
    late FleetService fleetService;
    const companyId = 'fleet-president-100';

    // 100台の内訳:
    //   0..5   (6台): 車検期限切れ（10日前に失効）→ critical
    //   6..9   (4台): 5日後に期限 → critical
    //   10..24 (15台): 20日後に期限 → warning
    //   25..99 (75台): 300日後に期限 → normal
    setUp(() async {
      firestore = FakeFirebaseFirestore();
      fleetService = FleetService(firestore: firestore);

      for (var i = 0; i < 100; i++) {
        final DateTime expiry;
        if (i < 6) {
          expiry = DateTime.now().subtract(const Duration(days: 10));
        } else if (i < 10) {
          expiry = DateTime.now().add(const Duration(days: 5));
        } else if (i < 25) {
          expiry = DateTime.now().add(const Duration(days: 20));
        } else {
          expiry = DateTime.now().add(const Duration(days: 300));
        }
        await _seedVehicle(
          firestore,
          _vehicle(
            id: 'fleet-v$i',
            userId: 'driver-$i',
            companyId: companyId,
            licensePlate: '足立 100 あ ${(i ~/ 10)}${(i % 10)}-01',
            inspectionExpiryDate: expiry,
            useCategory: i.isEven ? VehicleUseCategory.cargo : null, // 半数は貨物
            assigneeName: i < 50 ? 'ドライバー$i' : null, // 半数はアサイン済み
          ),
        );
      }
    });

    test('100台が critical=10 / warning=15 / normal=75 に集計される', () async {
      final stats = (await fleetService.getFleetStats(companyId)).getOrThrow();

      expect(stats.total, 100);
      expect(stats.critical, 10); // 期限切れ6 + 7日以内4
      expect(stats.warning, 15); // 8〜30日
      expect(stats.normal, 75);
      expect(stats.urgencyRatio, closeTo(0.10, 0.001));
    });

    test('車検期限切れの台数が正しく抽出される（6台）', () async {
      final snap = await firestore
          .collection(FirestoreCollections.vehicles)
          .where('companyId', isEqualTo: companyId)
          .get();
      final vehicles = snap.docs.map(Vehicle.fromFirestore).toList();

      final expired = vehicles.where((v) => v.isInspectionExpired).toList();
      expect(expired, hasLength(6));
      // 期限切れ車両はすべて daysUntilInspection が負
      for (final v in expired) {
        expect(v.daysUntilInspection!, lessThan(0));
      }
    });

    test('30日以内（期限切れ含む）は25台、期限内の30日以内は19台', () async {
      final snap = await firestore
          .collection(FirestoreCollections.vehicles)
          .where('companyId', isEqualTo: companyId)
          .get();
      final vehicles = snap.docs.map(Vehicle.fromFirestore).toList();

      final within30 = vehicles
          .where((v) =>
              v.daysUntilInspection != null && v.daysUntilInspection! <= 30)
          .toList();
      expect(within30, hasLength(25));

      final dueSoon = vehicles.where((v) => v.isInspectionDueSoon).toList();
      expect(dueSoon, hasLength(19)); // 期限切れの6台は含まない
    });

    test('担当者アサイン: オーナーが設定した担当者を読み戻せる', () async {
      final result = await fleetService.assignVehicle(
        'fleet-v99',
        'staff-new',
        '中途 入社太郎',
        companyId,
      );
      expect(result.isSuccess, isTrue);

      final doc = await firestore
          .collection(FirestoreCollections.vehicles)
          .doc('fleet-v99')
          .get();
      final vehicle = Vehicle.fromFirestore(doc);
      expect(vehicle.assigneeId, 'staff-new');
      expect(vehicle.assigneeName, '中途 入社太郎');
    });

    test('アサイン済み台数を担当者名で集計できる（50台）', () async {
      final snap = await firestore
          .collection(FirestoreCollections.vehicles)
          .where('companyId', isEqualTo: companyId)
          .get();
      final vehicles = snap.docs.map(Vehicle.fromFirestore).toList();

      final assigned = vehicles.where((v) => v.assigneeName != null).toList();
      expect(assigned, hasLength(50));
    });

    group('Edge Cases', () {
      test('0台の法人: 統計はすべて0で urgencyRatio も0', () async {
        final stats =
            (await fleetService.getFleetStats('empty-company')).getOrThrow();
        expect(stats.total, 0);
        expect(stats.critical, 0);
        expect(stats.warning, 0);
        expect(stats.normal, 0);
        expect(stats.urgencyRatio, 0.0);
      });

      test('存在しない車両IDへの担当者アサインは失敗する', () async {
        final result = await fleetService.assignVehicle(
          'does-not-exist',
          'staff-1',
          '誰か',
          companyId,
        );
        expect(result.isFailure, isTrue);
      });
    });
  });

  // ===========================================================================
  // Persona D ジャーニー: 整備記録4年分の時系列と明細
  //   「4年分・10件の記録が貯まった。時系列で振り返り、車検の明細
  //    （部品・工賃・税）が正しく残っていることを確認したい。」
  // ===========================================================================
  group('Persona D ジャーニー — 整備記録4年分の時系列と明細', () {
    late FakeFirebaseFirestore firestore;

    setUp(() async {
      firestore = FakeFirebaseFirestore();

      // 4年分のオイル交換（半年ごと・8件）
      final base = DateTime(2022, 6, 1);
      for (var i = 0; i < 8; i++) {
        await _seedRecord(
          firestore,
          _record(
            id: 'oil-$i',
            type: MaintenanceType.oilChange,
            date: base.add(Duration(days: 180 * i)),
            mileage: 10000 + 5000 * i,
          ),
        );
      }

      // 明細なしの旧形式車検（アプリ導入前の手入力・後方互換確認用）
      await _seedRecord(
        firestore,
        _record(
          id: 'shaken-legacy',
          type: MaintenanceType.carInspection,
          date: DateTime(2022, 5, 20),
          cost: 75000,
        ),
      );

      // 明細付きの車検（部品・工賃・法定費用・税）
      await _seedRecord(
        firestore,
        _record(
          id: 'shaken-2024',
          type: MaintenanceType.carInspection,
          date: DateTime(2024, 5, 20),
          cost: 82500,
          mileage: 41000,
          parts: const [
            Part(
              partNumber: '90915-YZZD4',
              name: 'オイルフィルター',
              manufacturer: 'TOYOTA',
              unitPrice: 1200,
              quantity: 1,
            ),
            Part(
              partNumber: 'V9115-3504',
              name: 'エンジンオイル',
              unitPrice: 1500,
              quantity: 4,
            ),
          ],
          workItems: const [
            WorkItem(name: '24ヶ月点検整備', laborCost: 25000),
          ],
          partsCost: 7200,
          laborCost: 25000,
          miscCost: 42800, // 法定費用（自賠責・重量税・印紙代）
          taxAmount: 7500,
        ),
      );
    });

    Future<List<MaintenanceRecord>> fetchHistory(String vehicleId) async {
      final snap = await firestore
          .collection(FirestoreCollections.maintenanceRecords)
          .where('vehicleId', isEqualTo: vehicleId)
          .orderBy('date', descending: true)
          .get();
      return snap.docs.map(MaintenanceRecord.fromFirestore).toList();
    }

    test('時系列取得: 全10件が日付降順で返る', () async {
      final records = await fetchHistory('prius-d1');

      expect(records, hasLength(10));
      for (var i = 0; i < records.length - 1; i++) {
        expect(
          records[i].date.isBefore(records[i + 1].date),
          isFalse,
          reason: '日付降順であること（${records[i].id} → ${records[i + 1].id}）',
        );
      }
      // 最古は導入前の旧形式車検
      expect(records.last.id, 'shaken-legacy');
    });

    test('明細往復: parts / partsCost / taxAmount が保持される', () async {
      final records = await fetchHistory('prius-d1');
      final shaken = records.firstWhere((r) => r.id == 'shaken-2024');

      expect(shaken.parts, hasLength(2));
      expect(shaken.parts.first.partNumber, '90915-YZZD4');
      expect(shaken.parts.first.manufacturer, 'TOYOTA');
      expect(shaken.parts[1].quantity, 4);
      expect(shaken.partsCost, 7200);
      expect(shaken.laborCost, 25000);
      expect(shaken.miscCost, 42800);
      expect(shaken.taxAmount, 7500);
      expect(shaken.workItems.single.name, '24ヶ月点検整備');
    });

    test('明細の合計: calculatedTotal / calculatedPartsCost が一致する', () async {
      final records = await fetchHistory('prius-d1');
      final shaken = records.firstWhere((r) => r.id == 'shaken-2024');

      // 7200 + 25000 + 42800 + 7500 - 0 = 82500（= cost と一致）
      expect(shaken.calculatedTotal, 82500);
      expect(shaken.calculatedTotal, shaken.cost);
      // 部品リストからの再計算: 1200×1 + 1500×4 = 7200
      expect(shaken.calculatedPartsCost, 7200);
      expect(shaken.calculatedPartsCost, shaken.partsCost);
    });

    group('Edge Cases', () {
      test('記録なし車両: クエリ結果は空リスト', () async {
        final records = await fetchHistory('no-records-vehicle');
        expect(records, isEmpty);
      });

      test('明細なしの旧記録も安全に読める（後方互換）', () async {
        final records = await fetchHistory('prius-d1');
        final legacy = records.firstWhere((r) => r.id == 'shaken-legacy');

        expect(legacy.parts, isEmpty);
        expect(legacy.workItems, isEmpty);
        expect(legacy.partsCost, isNull);
        expect(legacy.taxAmount, isNull);
        expect(legacy.calculatedTotal, 0); // 内訳なし → 0（cost とは別管理）
        expect(legacy.cost, 75000);
      });
    });
  });

  // ===========================================================================
  // ペルソナ共通ジャーニー: 車両登録→装備保存→読み戻し→退役→復元
  //   「登録時に装備（ナビ・ドラレコ・ETC・フラグ装備）を入力。
  //    1年後に売却して退役、直後に誤操作と気づいて復元する。」
  // ===========================================================================
  group('共通ジャーニー — 車両登録→装備→退役→復元', () {
    late FakeFirebaseFirestore firestore;
    late VehicleRetirementService retirementService;
    const ownerId = 'journey-user';

    const equipment = VehicleEquipment(
      navigation: EquipmentItem(
        installed: true,
        maker: 'Panasonic',
        modelNumber: 'CN-F1X10BLD',
      ),
      driveRecorder: EquipmentItem(
        installed: true,
        maker: 'COMTEC',
        modelNumber: 'ZDR035',
      ),
      etc: EquipmentItem(installed: true),
      features: {
        VehicleFeature.backCamera,
        VehicleFeature.keylessEntry,
        VehicleFeature.collisionMitigationBrake,
      },
      others: ['寒冷地仕様'],
    );

    setUp(() {
      firestore = FakeFirebaseFirestore();
      retirementService = VehicleRetirementService(firestore: firestore);
    });

    Future<Vehicle> readVehicle(String id) async {
      final doc = await firestore
          .collection(FirestoreCollections.vehicles)
          .doc(id)
          .get();
      return Vehicle.fromFirestore(doc);
    }

    test('装備付きで登録した車両を読み戻すと装備が一致する', () async {
      await _seedVehicle(
        firestore,
        _vehicle(id: 'eq-car', equipment: equipment),
      );

      final readBack = await readVehicle('eq-car');

      expect(readBack.equipment, isNotNull);
      expect(readBack.equipment, equals(equipment));
      // 一覧表示用ラベルにも反映される
      expect(
        readBack.equipment!.summaryLabels,
        containsAll(<String>['バックカメラ', '寒冷地仕様']),
      );
      expect(
        readBack.equipment!.navigation.displayLabel,
        'Panasonic CN-F1X10BLD',
      );
    });

    test('売却退役してもステータス以外（装備・保持フラグ）は残る', () async {
      await _seedVehicle(
        firestore,
        _vehicle(id: 'eq-car', equipment: equipment),
      );

      final result = await retirementService.retireVehicle(
        vehicleId: 'eq-car',
        ownerId: ownerId,
        reason: VehicleStatus.sold,
        retainData: true,
        note: '下取り 55万円',
      );
      expect(result.isSuccess, isTrue);

      final retired = await readVehicle('eq-car');
      expect(retired.status, VehicleStatus.sold);
      expect(retired.isDataRetained, isTrue);
      expect(retired.equipment, equals(equipment)); // 装備は失われない
    });

    test('復元すると使用中に戻り装備もそのまま', () async {
      await _seedVehicle(
        firestore,
        _vehicle(id: 'eq-car', equipment: equipment),
      );
      await retirementService.retireVehicle(
        vehicleId: 'eq-car',
        ownerId: ownerId,
        reason: VehicleStatus.sold,
        retainData: true,
      );

      final restore = await retirementService.restoreVehicle(
        vehicleId: 'eq-car',
        ownerId: ownerId,
      );
      expect(restore.isSuccess, isTrue);

      final restored = await readVehicle('eq-car');
      expect(restored.status, VehicleStatus.active);
      expect(restored.equipment, equals(equipment));
    });

    group('Edge Cases', () {
      test('装備未登録（equipment=null）の車両も安全に読み戻せる', () async {
        await _seedVehicle(firestore, _vehicle(id: 'plain-car'));

        final readBack = await readVehicle('plain-car');
        expect(readBack.equipment, isNull);
      });

      test('全項目が空の装備は保存されず null として読み戻る', () async {
        await _seedVehicle(
          firestore,
          _vehicle(id: 'empty-eq-car', equipment: const VehicleEquipment()),
        );

        final readBack = await readVehicle('empty-eq-car');
        // toMap は hasAnyValue=false の装備を書き込まない仕様
        expect(readBack.equipment, isNull);
      });

      test('存在しない車両IDの退役は失敗する', () async {
        final result = await retirementService.retireVehicle(
          vehicleId: 'ghost-car',
          ownerId: ownerId,
          reason: VehicleStatus.sold,
          retainData: true,
        );
        expect(result.isFailure, isTrue);
      });
    });
  });

  // ===========================================================================
  // 公開ドライブログ ジャーニー: isPublic 切替と自宅500m除去
  //   「自宅発着のドライブを記録した。後から公開に切り替えるが、
  //    公開経路からは自宅が特定できないこと。」
  // ===========================================================================
  group('公開ドライブログ ジャーニー — isPublic切替と経路ぼかし', () {
    late FakeFirebaseFirestore firestore;
    late DriveLogService driveService;
    const userId = 'drive-user';
    const homeAddress = '東京都世田谷区北沢2-1-3';
    const home = GeoPoint2D(latitude: 35.6, longitude: 139.6);

    // 自宅発着の往復経路。緯度0.001度 ≒ 111m。
    //   自宅(0m) → 111m → 666m → 1.1km → 2.2km → 666m → 55m → 自宅(0m)
    // 500m圏内は両端4点（0m, 111m, 55m, 0m）。
    List<GeoPoint2D> homeRoundTrip() => const [
          home,
          GeoPoint2D(latitude: 35.601, longitude: 139.6),
          GeoPoint2D(latitude: 35.606, longitude: 139.6),
          GeoPoint2D(latitude: 35.610, longitude: 139.6),
          GeoPoint2D(latitude: 35.620, longitude: 139.6),
          GeoPoint2D(latitude: 35.606, longitude: 139.6),
          GeoPoint2D(latitude: 35.6005, longitude: 139.6),
          home,
        ];

    setUp(() {
      firestore = FakeFirebaseFirestore();
      driveService = DriveLogService(firestore: firestore);
    });

    Future<DriveLog> recordCompletedDrive({bool isPublic = false}) async {
      final started = (await driveService.startDrive(
        userId: userId,
        vehicleId: 'roadster-1',
        startLocation: home,
        startAddress: homeAddress,
      ))
          .getOrThrow();

      return (await driveService.endDrive(
        driveLogId: started.id,
        userId: userId,
        endLocation: home,
        endAddress: homeAddress,
        statistics: const DriveStatistics(
          totalDistance: 42.5,
          totalDuration: 5400,
          averageSpeed: 28.3,
          maxSpeed: 78,
        ),
        title: '週末の箱根ドライブ',
        isPublic: isPublic,
      ))
          .getOrThrow();
    }

    test('非公開のまま終了したドライブは公開フィードに出ない', () async {
      final log = await recordCompletedDrive(isPublic: false);
      expect(log.isPublic, isFalse);

      final feed = (await driveService.getPublicDriveLogs()).getOrThrow();
      expect(feed.map((l) => l.id), isNot(contains(log.id)));
    });

    test('isPublic を true に切り替えると公開フィードに出る', () async {
      final log = await recordCompletedDrive(isPublic: false);

      final updated = (await driveService.updateDriveLog(
        driveLogId: log.id,
        userId: userId,
        isPublic: true,
      ))
          .getOrThrow();
      expect(updated.isPublic, isTrue);

      final feed = (await driveService.getPublicDriveLogs()).getOrThrow();
      expect(feed.map((l) => l.id), contains(log.id));
    });

    test('公開経路は自宅500m圏内の点がすべて除去される', () {
      final blurred = buildBlurredRoute(
        waypoints: homeRoundTrip(),
        startAddress: homeAddress,
        endAddress: homeAddress,
        isPublic: true,
      );

      expect(blurred.hasRoute, isTrue);
      expect(blurred.waypoints, hasLength(4)); // 666m/1.1km/2.2km/666m
      for (final p in blurred.waypoints) {
        expect(
          p.distanceTo(home),
          greaterThan(kDefaultPrivacyRadiusMeters),
          reason: '公開経路に自宅500m圏内の点が残ってはいけない',
        );
      }
    });

    test('公開時は住所が市区町村までに丸められる', () {
      final blurred = buildBlurredRoute(
        waypoints: homeRoundTrip(),
        startAddress: homeAddress,
        endAddress: homeAddress,
        isPublic: true,
      );

      expect(blurred.startAddress, '東京都世田谷区');
      expect(blurred.endAddress, '東京都世田谷区');
      expect(blurred.startAddress, isNot(contains('北沢')));
    });

    test('非公開（本人閲覧）は経路も住所もぼかされない', () {
      final blurred = buildBlurredRoute(
        waypoints: homeRoundTrip(),
        startAddress: homeAddress,
        endAddress: homeAddress,
        isPublic: false,
      );

      expect(blurred.waypoints, hasLength(homeRoundTrip().length));
      expect(blurred.startAddress, homeAddress);
      expect(blurred.endAddress, homeAddress);
    });

    group('Edge Cases', () {
      test('自宅周辺のみの短い経路は公開時に空になる（1点も漏らさない）', () {
        final blurred = buildBlurredRoute(
          waypoints: const [
            home,
            GeoPoint2D(latitude: 35.601, longitude: 139.6), // 111m
            home,
          ],
          startAddress: homeAddress,
          endAddress: homeAddress,
          isPublic: true,
        );

        expect(blurred.waypoints, isEmpty);
        expect(blurred.hasRoute, isFalse);
      });

      test('存在しないドライブログIDの取得は notFound で失敗する', () async {
        final result = await driveService.getDriveLog('ghost-log');
        expect(result.isFailure, isTrue);
      });

      test('他人のドライブログの isPublic は切り替えられない', () async {
        final log = await recordCompletedDrive(isPublic: false);

        final result = await driveService.updateDriveLog(
          driveLogId: log.id,
          userId: 'someone-else',
          isPublic: true,
        );
        expect(result.isFailure, isTrue);
      });
    });
  });
}
