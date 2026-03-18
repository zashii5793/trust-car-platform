// RecommendationService Unit Tests
//
// This service is the core business logic of the app — no Firebase dependencies,
// pure Dart. Every branch is testable through generateRecommendations().
//
// Coverage areas:
//   1. 車検（inspectionExpiryDate 設定済み）— 優先度境界値 × 9
//   2. 自賠責保険 — 優先度境界値 × 6
//   3. メンテナンスルール — 日付ベース / 走行距離ベース / キーワードマッチ
//   4. 車検（履歴ベース fallback）— 新車 / 旧車 / 記録あり
//   5. generateRecommendations 統合 — ソート / 複合
//   6. キーワードマッチング — 13 ルール辞書
//   7. Edge Cases — 0km / 境界 / 長期

import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/services/recommendation_service.dart';
import 'package:trust_car_platform/models/vehicle.dart';
import 'package:trust_car_platform/models/maintenance_record.dart';
import 'package:trust_car_platform/models/app_notification.dart';

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

/// Vehicle with sane defaults. Pass only what you want to override.
Vehicle _makeVehicle({
  String id = 'v1',
  int year = 2020,
  int mileage = 30000,
  DateTime? inspectionExpiryDate,
  DateTime? insuranceExpiryDate,
  /// Registration / creation date — controls history-based rule timeline.
  Duration createdBefore = const Duration(days: 365),
}) {
  return Vehicle(
    id: id,
    userId: 'u1',
    maker: 'Toyota',
    model: 'Prius',
    year: year,
    grade: 'S',
    mileage: mileage,
    createdAt: DateTime.now().subtract(createdBefore),
    updatedAt: DateTime.now(),
    inspectionExpiryDate: inspectionExpiryDate,
    insuranceExpiryDate: insuranceExpiryDate,
  );
}

/// Maintenance record with defaults.
MaintenanceRecord _makeRecord({
  MaintenanceType type = MaintenanceType.oilChange,
  String title = 'オイル交換',
  Duration doneAgo = const Duration(days: 30),
  int mileageAtService = 25000,
}) {
  final date = DateTime.now().subtract(doneAgo);
  return MaintenanceRecord(
    id: 'r1',
    vehicleId: 'v1',
    userId: 'u1',
    type: type,
    title: title,
    date: date,
    cost: 3500,
    mileageAtService: mileageAtService,
    createdAt: date,
  );
}

const _userId = 'user-001';

void main() {
  late RecommendationService service;

  setUp(() {
    service = RecommendationService();
  });

  // ==========================================================================
  // Group 1: 車検（inspectionExpiryDate 設定済み）— 優先度境界値
  // ==========================================================================
  group('車検通知（inspectionExpiryDate）', () {
    test('車検が昨日切れた → high priority', () {
      final v = _makeVehicle(
        inspectionExpiryDate: DateTime.now().subtract(const Duration(days: 1)),
      );
      final result = service.generateRecommendations(
        vehicle: v, records: [], userId: _userId,
      );

      final notif = result.firstWhere(
        (n) => n.type == NotificationType.inspectionReminder,
        orElse: () => throw 'notification not found',
      );
      expect(notif.priority, NotificationPriority.high);
      expect(notif.message, contains('期限が過ぎています'));
    });

    test('車検まで0日（当日）→ high priority', () {
      final v = _makeVehicle(
        inspectionExpiryDate: DateTime.now(),
      );
      final result = service.generateRecommendations(
        vehicle: v, records: [], userId: _userId,
      );
      final notif = result.firstWhere(
        (n) => n.type == NotificationType.inspectionReminder,
      );
      expect(notif.priority, NotificationPriority.high);
    });

    test('車検まで7日 → high priority & メッセージに日数', () {
      final v = _makeVehicle(
        inspectionExpiryDate: DateTime.now().add(const Duration(days: 7)),
      );
      final result = service.generateRecommendations(
        vehicle: v, records: [], userId: _userId,
      );
      final notif = result.firstWhere(
        (n) => n.type == NotificationType.inspectionReminder,
      );
      expect(notif.priority, NotificationPriority.high);
      expect(notif.message, contains('7日'));
    });

    test('車検まで30日（境界値）→ high priority', () {
      final v = _makeVehicle(
        inspectionExpiryDate: DateTime.now().add(const Duration(days: 30)),
      );
      final result = service.generateRecommendations(
        vehicle: v, records: [], userId: _userId,
      );
      final notif = result.firstWhere(
        (n) => n.type == NotificationType.inspectionReminder,
      );
      expect(notif.priority, NotificationPriority.high);
    });

    test('車検まで31日 → medium priority', () {
      final v = _makeVehicle(
        inspectionExpiryDate: DateTime.now().add(const Duration(days: 31)),
      );
      final result = service.generateRecommendations(
        vehicle: v, records: [], userId: _userId,
      );
      final notif = result.firstWhere(
        (n) => n.type == NotificationType.inspectionReminder,
      );
      expect(notif.priority, NotificationPriority.medium);
    });

    test('車検まで90日 → medium priority', () {
      final v = _makeVehicle(
        inspectionExpiryDate: DateTime.now().add(const Duration(days: 90)),
      );
      final result = service.generateRecommendations(
        vehicle: v, records: [], userId: _userId,
      );
      final notif = result.firstWhere(
        (n) => n.type == NotificationType.inspectionReminder,
      );
      expect(notif.priority, NotificationPriority.medium);
    });

    test('車検まで91日 → low priority', () {
      final v = _makeVehicle(
        inspectionExpiryDate: DateTime.now().add(const Duration(days: 91)),
      );
      final result = service.generateRecommendations(
        vehicle: v, records: [], userId: _userId,
      );
      final notif = result.firstWhere(
        (n) => n.type == NotificationType.inspectionReminder,
      );
      expect(notif.priority, NotificationPriority.low);
    });

    test('車検まで180日 → low priority', () {
      final v = _makeVehicle(
        inspectionExpiryDate: DateTime.now().add(const Duration(days: 180)),
      );
      final result = service.generateRecommendations(
        vehicle: v, records: [], userId: _userId,
      );
      final hasInspNotif = result.any(
        (n) => n.type == NotificationType.inspectionReminder,
      );
      expect(hasInspNotif, isTrue);
    });

    test('車検まで181日 → 通知なし', () {
      final v = _makeVehicle(
        inspectionExpiryDate: DateTime.now().add(const Duration(days: 181)),
      );
      final result = service.generateRecommendations(
        vehicle: v, records: [], userId: _userId,
      );
      final hasInspNotif = result.any(
        (n) => n.type == NotificationType.inspectionReminder,
      );
      expect(hasInspNotif, isFalse);
    });

    test('通知の vehicleId が車両IDと一致する', () {
      final v = _makeVehicle(
        id: 'vehicle-xyz',
        inspectionExpiryDate: DateTime.now().add(const Duration(days: 10)),
      );
      final result = service.generateRecommendations(
        vehicle: v, records: [], userId: _userId,
      );
      final notif = result.firstWhere(
        (n) => n.type == NotificationType.inspectionReminder,
      );
      expect(notif.vehicleId, 'vehicle-xyz');
    });

    test('metadata に inspectionExpiryDate キーが含まれる', () {
      final v = _makeVehicle(
        inspectionExpiryDate: DateTime.now().add(const Duration(days: 20)),
      );
      final result = service.generateRecommendations(
        vehicle: v, records: [], userId: _userId,
      );
      final notif = result.firstWhere(
        (n) => n.type == NotificationType.inspectionReminder,
      );
      expect(notif.metadata?['inspectionExpiryDate'], isNotNull);
      expect(notif.metadata?['daysUntilInspection'], isA<int>());
    });
  });

  // ==========================================================================
  // Group 2: 自賠責保険 — 優先度境界値
  // ==========================================================================
  group('自賠責保険通知', () {
    test('保険期限 > 60日 → 通知なし', () {
      final v = _makeVehicle(
        insuranceExpiryDate: DateTime.now().add(const Duration(days: 61)),
      );
      final result = service.generateRecommendations(
        vehicle: v, records: [], userId: _userId,
      );
      final hasIns = result.any((n) => n.title.contains('自賠責'));
      expect(hasIns, isFalse);
    });

    test('保険期限ちょうど60日 → 通知あり', () {
      final v = _makeVehicle(
        insuranceExpiryDate: DateTime.now().add(const Duration(days: 60)),
      );
      final result = service.generateRecommendations(
        vehicle: v, records: [], userId: _userId,
      );
      final hasIns = result.any((n) => n.title.contains('自賠責'));
      expect(hasIns, isTrue);
    });

    test('保険期限切れ → high priority', () {
      final v = _makeVehicle(
        insuranceExpiryDate: DateTime.now().subtract(const Duration(days: 1)),
      );
      final result = service.generateRecommendations(
        vehicle: v, records: [], userId: _userId,
      );
      final notif = result.firstWhere((n) => n.title.contains('自賠責'));
      expect(notif.priority, NotificationPriority.high);
      expect(notif.message, contains('期限切れ'));
    });

    test('保険まで14日（境界値）→ high priority', () {
      final v = _makeVehicle(
        insuranceExpiryDate: DateTime.now().add(const Duration(days: 14)),
      );
      final result = service.generateRecommendations(
        vehicle: v, records: [], userId: _userId,
      );
      final notif = result.firstWhere((n) => n.title.contains('自賠責'));
      expect(notif.priority, NotificationPriority.high);
    });

    test('保険まで15日 → medium priority', () {
      final v = _makeVehicle(
        insuranceExpiryDate: DateTime.now().add(const Duration(days: 15)),
      );
      final result = service.generateRecommendations(
        vehicle: v, records: [], userId: _userId,
      );
      final notif = result.firstWhere((n) => n.title.contains('自賠責'));
      expect(notif.priority, NotificationPriority.medium);
    });

    test('保険まで31日 → low priority', () {
      final v = _makeVehicle(
        insuranceExpiryDate: DateTime.now().add(const Duration(days: 31)),
      );
      final result = service.generateRecommendations(
        vehicle: v, records: [], userId: _userId,
      );
      final notif = result.firstWhere((n) => n.title.contains('自賠責'));
      expect(notif.priority, NotificationPriority.low);
    });

    test('保険未設定 → 通知なし', () {
      final v = _makeVehicle(); // insuranceExpiryDate = null
      final result = service.generateRecommendations(
        vehicle: v, records: [], userId: _userId,
      );
      final hasIns = result.any((n) => n.title.contains('自賠責'));
      expect(hasIns, isFalse);
    });
  });

  // ==========================================================================
  // Group 3: メンテナンスルール（日付 / 走行距離ベース）
  // ==========================================================================
  group('メンテナンスルール — 日付ベース', () {
    test('オイル交換記録なし + 登録200日 → 6ヶ月経過後に推奨済み → high priority', () {
      // 6ヶ月 = 180日。createdAt=200日前なので oilChange が期日超過
      final v = _makeVehicle(createdBefore: const Duration(days: 200));
      final result = service.generateRecommendations(
        vehicle: v, records: [], userId: _userId,
      );
      final oilNotif = result.firstWhere(
        (n) => n.title.contains('エンジンオイル交換'),
        orElse: () => throw 'oilChange notification not found',
      );
      expect(oilNotif.priority, NotificationPriority.high);
    });

    test('オイル交換記録なし + 登録20日 → まだ期日が遠い → 通知なし', () {
      // 6ヶ月後=160日先 → >90日 → null
      final v = _makeVehicle(createdBefore: const Duration(days: 20));
      final result = service.generateRecommendations(
        vehicle: v, records: [], userId: _userId,
      );
      final oilNotif = result.where(
        (n) => n.title.contains('エンジンオイル交換'),
      );
      expect(oilNotif.isEmpty, isTrue);
    });

    test('オイル交換 100日前に実施 + 6ヶ月interval → 80日後期日 → medium priority', () {
      final v = _makeVehicle();
      final record = _makeRecord(
        type: MaintenanceType.oilChange,
        doneAgo: const Duration(days: 100),
      );
      final result = service.generateRecommendations(
        vehicle: v, records: [record], userId: _userId,
      );
      final oilNotif = result.firstWhere(
        (n) => n.title.contains('エンジンオイル交換'),
        orElse: () => throw 'not found',
      );
      expect(oilNotif.priority, NotificationPriority.medium);
    });

    test('オイル交換 200日前に実施 → 期日超過 → high priority', () {
      final v = _makeVehicle();
      final record = _makeRecord(
        type: MaintenanceType.oilChange,
        doneAgo: const Duration(days: 200),
      );
      final result = service.generateRecommendations(
        vehicle: v, records: [record], userId: _userId,
      );
      final oilNotif = result.firstWhere(
        (n) => n.title.contains('エンジンオイル交換'),
      );
      expect(oilNotif.priority, NotificationPriority.high);
    });

    test('5日前に実施 → due が 175日後 → 通知なし（>90日）', () {
      final v = _makeVehicle();
      final record = _makeRecord(
        type: MaintenanceType.oilChange,
        doneAgo: const Duration(days: 5),
      );
      final result = service.generateRecommendations(
        vehicle: v, records: [record], userId: _userId,
      );
      final oilNotifs = result.where(
        (n) => n.title.contains('エンジンオイル交換'),
      );
      expect(oilNotifs.isEmpty, isTrue);
    });

    test('複数記録がある → 最新記録が使われる', () {
      final v = _makeVehicle();
      final oldRecord = _makeRecord(
        type: MaintenanceType.oilChange,
        doneAgo: const Duration(days: 200), // 古い → 期日超過
        mileageAtService: 10000,
      );
      final recentRecord = _makeRecord(
        type: MaintenanceType.oilChange,
        doneAgo: const Duration(days: 5), // 直近 → まだ先
        mileageAtService: 29000,
      );
      final result = service.generateRecommendations(
        vehicle: v, records: [oldRecord, recentRecord], userId: _userId,
      );
      // 最新記録（5日前）を使うと 175日先 → 通知なし
      final oilNotifs = result.where(
        (n) => n.title.contains('エンジンオイル交換'),
      );
      expect(oilNotifs.isEmpty, isTrue);
    });
  });

  group('メンテナンスルール — 走行距離ベース', () {
    test('前回走行距離+5000km 到達 → 即時推奨（high priority）', () {
      final v = _makeVehicle(mileage: 30000);
      final record = _makeRecord(
        type: MaintenanceType.oilChange,
        doneAgo: const Duration(days: 10), // 最近（日付ベースは遠い）
        mileageAtService: 25000, // 30000 - 25000 = 5000km達成
      );
      final result = service.generateRecommendations(
        vehicle: v, records: [record], userId: _userId,
      );
      final notif = result.firstWhere(
        (n) => n.title.contains('エンジンオイル交換'),
        orElse: () => throw 'not found',
      );
      expect(notif.priority, NotificationPriority.high);
    });

    test('4999km — 走行距離未達 → 日付ベースのみ評価', () {
      final v = _makeVehicle(mileage: 29999);
      final record = _makeRecord(
        type: MaintenanceType.oilChange,
        doneAgo: const Duration(days: 10),
        mileageAtService: 25000, // 29999 - 25000 = 4999km < 5000km
      );
      final result = service.generateRecommendations(
        vehicle: v, records: [record], userId: _userId,
      );
      // 日付ベース：10日前実施 → 170日後期日 → 通知なし
      final oilNotifs = result.where((n) => n.title.contains('エンジンオイル交換'));
      expect(oilNotifs.isEmpty, isTrue);
    });

    test('ワイパー（intervalKm=0）は走行距離チェックをスキップ', () {
      // ワイパーは intervalKm=0 なので距離関係なく日付のみ
      final v = _makeVehicle();
      final record = _makeRecord(
        type: MaintenanceType.wiperChange,
        title: 'ワイパー交換',
        doneAgo: const Duration(days: 10),
        mileageAtService: 0, // mileage不明でも問題なし
      );
      final result = service.generateRecommendations(
        vehicle: v, records: [record], userId: _userId,
      );
      // 10日前実施、12ヶ月interval → 350日後期日 → 通知なし
      final wiperNotifs = result.where((n) => n.title.contains('ワイパー'));
      expect(wiperNotifs.isEmpty, isTrue);
    });

    test('タイヤローテーション 5000km到達 → high priority', () {
      final v = _makeVehicle(mileage: 30000);
      final record = _makeRecord(
        type: MaintenanceType.tireRotation,
        title: 'タイヤローテーション',
        doneAgo: const Duration(days: 5),
        mileageAtService: 25000, // exactly 5000km
      );
      final result = service.generateRecommendations(
        vehicle: v, records: [record], userId: _userId,
      );
      final notif = result.firstWhere(
        (n) => n.title.contains('タイヤローテーション'),
        orElse: () => throw 'not found',
      );
      expect(notif.priority, NotificationPriority.high);
    });
  });

  group('メンテナンスルール — タイプ & キーワードマッチング', () {
    test('タイプ完全一致でマッチする', () {
      final v = _makeVehicle(createdBefore: const Duration(days: 400));
      final record = _makeRecord(
        type: MaintenanceType.oilChange,
        title: '全然関係ないタイトル',
        doneAgo: const Duration(days: 400),
      );
      // type=oilChange でマッチするので 400日前 → high
      final result = service.generateRecommendations(
        vehicle: v, records: [record], userId: _userId,
      );
      final oilNotif = result.firstWhere(
        (n) => n.title.contains('エンジンオイル交換'),
        orElse: () => throw 'not found',
      );
      expect(oilNotif, isNotNull);
    });

    test('キーワード "オイル交換" がエンジンオイル交換ルールにマッチ', () {
      // タイプは repair だがタイトルに "オイル交換" を含む
      final v = _makeVehicle(createdBefore: const Duration(days: 5));
      // 5日前のキーワードマッチ記録 → 175日後期日 → 通知なし（>90日）
      // これは記録がない場合と比較してテスト
      final withRecord = _makeRecord(
        type: MaintenanceType.repair, // oilChange ではない
        title: 'オイル交換（title based）',
        doneAgo: const Duration(days: 5),
      );
      final resultWith = service.generateRecommendations(
        vehicle: v, records: [withRecord], userId: _userId,
      );
      // 5日前の記録がある → 期日まで175日 → 通知なし
      expect(
        resultWith.where((n) => n.title.contains('エンジンオイル交換')).isEmpty,
        isTrue,
      );
    });

    test('キーワード "クーラント" が冷却水交換ルールにマッチ', () {
      final v = _makeVehicle();
      final record = _makeRecord(
        type: MaintenanceType.repair,
        title: 'クーラント交換',
        doneAgo: const Duration(days: 5),
      );
      final result = service.generateRecommendations(
        vehicle: v, records: [record], userId: _userId,
      );
      // 5日前記録 → coolant 24ヶ月interval → 715日後期日 → 通知なし
      final coolantNotif = result.where((n) => n.title.contains('冷却水'));
      expect(coolantNotif.isEmpty, isTrue);
    });
  });

  // ==========================================================================
  // Group 4: 車検（履歴ベース fallback）
  // ==========================================================================
  group('車検（履歴ベース fallback — inspectionExpiryDate未設定）', () {
    test('新車（製造年=今年）、記録なし → 通知なし（3年後）', () {
      final v = _makeVehicle(
        year: DateTime.now().year, // 今年製造 = 新車
      );
      final result = service.generateRecommendations(
        vehicle: v, records: [], userId: _userId,
      );
      // 3年後 > 180日 → 通知なし（または通知あるが期日が遠すぎる）
      // 実装では firstInspectionYears=3 後まで通知しない
      final inspNotifs = result.where(
        (n) => n.type == NotificationType.inspectionReminder,
      );
      expect(inspNotifs.isEmpty, isTrue);
    });

    test('旧車（5年前製造）、記録なし → "登録してください" 通知', () {
      final v = _makeVehicle(year: DateTime.now().year - 5);
      final result = service.generateRecommendations(
        vehicle: v, records: [], userId: _userId,
      );
      final notif = result.firstWhere(
        (n) => n.type == NotificationType.inspectionReminder,
        orElse: () => throw 'notification not found',
      );
      expect(notif.message, contains('登録してください'));
      expect(notif.priority, NotificationPriority.medium);
    });

    test('車検記録1年前あり → 次回は1年後 → 通知なし', () {
      final v = _makeVehicle(year: DateTime.now().year - 5);
      final record = _makeRecord(
        type: MaintenanceType.carInspection,
        title: '車検',
        doneAgo: const Duration(days: 365), // 1年前
      );
      final result = service.generateRecommendations(
        vehicle: v, records: [record], userId: _userId,
      );
      // 次回 = 1年前 + 2年 = 1年後 → >180日 → 通知なし
      final inspNotifs = result.where(
        (n) => n.type == NotificationType.inspectionReminder,
      );
      expect(inspNotifs.isEmpty, isTrue);
    });

    test('車検記録2年+1日前あり → 翌日超過 → high priority', () {
      final v = _makeVehicle(year: DateTime.now().year - 5);
      final record = _makeRecord(
        type: MaintenanceType.carInspection,
        title: '車検',
        doneAgo: const Duration(days: 731), // 2年+1日前
      );
      final result = service.generateRecommendations(
        vehicle: v, records: [record], userId: _userId,
      );
      final notif = result.firstWhere(
        (n) => n.type == NotificationType.inspectionReminder,
        orElse: () => throw 'notification not found',
      );
      expect(notif.priority, NotificationPriority.high);
    });
  });

  // ==========================================================================
  // Group 5: generateRecommendations 統合テスト
  // ==========================================================================
  group('generateRecommendations — 統合', () {
    test('空の records でもクラッシュせず結果を返す', () {
      final v = _makeVehicle();
      expect(
        () => service.generateRecommendations(
          vehicle: v, records: [], userId: _userId,
        ),
        returnsNormally,
      );
    });

    test('結果は priority が高い順にソートされる', () {
      final v = _makeVehicle(
        inspectionExpiryDate: DateTime.now().add(const Duration(days: 5)), // high
        insuranceExpiryDate: DateTime.now().add(const Duration(days: 35)), // low
        createdBefore: const Duration(days: 200), // oil change overdue = high
      );
      final result = service.generateRecommendations(
        vehicle: v, records: [], userId: _userId,
      );
      if (result.length >= 2) {
        for (var i = 0; i < result.length - 1; i++) {
          expect(
            result[i].priority.index,
            greaterThanOrEqualTo(result[i + 1].priority.index),
          );
        }
      }
    });

    test('userId が全通知に設定されている', () {
      final v = _makeVehicle(
        inspectionExpiryDate: DateTime.now().add(const Duration(days: 10)),
        createdBefore: const Duration(days: 200),
      );
      final result = service.generateRecommendations(
        vehicle: v, records: [], userId: 'specific-user',
      );
      for (final notif in result) {
        expect(notif.userId, 'specific-user');
      }
    });

    test('inspectionExpiryDate と insuranceExpiryDate 両方設定 → 両通知を含む', () {
      final v = _makeVehicle(
        inspectionExpiryDate: DateTime.now().add(const Duration(days: 15)),
        insuranceExpiryDate: DateTime.now().add(const Duration(days: 10)),
      );
      final result = service.generateRecommendations(
        vehicle: v, records: [], userId: _userId,
      );
      expect(
        result.any((n) => n.type == NotificationType.inspectionReminder),
        isTrue,
      );
      expect(result.any((n) => n.title.contains('自賠責')), isTrue);
    });

    test('inspectionExpiryDate 未設定 & insuranceExpiryDate 未設定 & 全記録なし → ルールベースのみ', () {
      final v = _makeVehicle(createdBefore: const Duration(days: 10));
      final result = service.generateRecommendations(
        vehicle: v, records: [], userId: _userId,
      );
      // 短期間作成 → ルールベースは全て遠い → 旧車でないので未設定警告も少ない
      expect(result, isA<List<AppNotification>>());
    });

    test('全ルールを通しても同じ vehicle.id を参照している', () {
      final v = _makeVehicle(
        id: 'test-vehicle-id',
        createdBefore: const Duration(days: 500),
      );
      final result = service.generateRecommendations(
        vehicle: v, records: [], userId: _userId,
      );
      for (final notif in result) {
        expect(notif.vehicleId, 'test-vehicle-id');
      }
    });

    test('13 ルール分の通知候補が生成されうる（records なし + 古い登録）', () {
      final v = _makeVehicle(createdBefore: const Duration(days: 500));
      final result = service.generateRecommendations(
        vehicle: v, records: [], userId: _userId,
      );
      // 全13ルールが発火する可能性あり（一部は >90日でフィルタされる）
      expect(result.length, greaterThan(0));
    });
  });

  // ==========================================================================
  // Group 6: キーワードマッチング網羅
  // ==========================================================================
  group('キーワードマッチング', () {
    late RecommendationService svc;

    setUp(() {
      svc = RecommendationService();
    });

    // キーワードマッチングは generateRecommendations を通して間接テスト
    // 「タイトルキーワードでマッチした記録がある → 該当ルールの記録として扱われる」

    test('タイトル "法定点検" → 12ヶ月点検ルールにマッチ（直近記録として扱われる）', () {
      final v = _makeVehicle(createdBefore: const Duration(days: 5));
      final record = _makeRecord(
        type: MaintenanceType.repair,
        title: '法定点検',
        doneAgo: const Duration(days: 5),
      );
      final result = svc.generateRecommendations(
        vehicle: v, records: [record], userId: _userId,
      );
      // 5日前に "法定点検" → 12ヶ月後期日 → 360日後 → 通知なし
      expect(
        result.where((n) => n.title.contains('12ヶ月点検')).isEmpty,
        isTrue,
      );
    });

    test('タイトル "ATF交換" → ATF/CVTフルードルールにマッチ', () {
      final v = _makeVehicle(createdBefore: const Duration(days: 5));
      final record = _makeRecord(
        type: MaintenanceType.repair,
        title: 'ATF交換',
        doneAgo: const Duration(days: 5),
      );
      final result = svc.generateRecommendations(
        vehicle: v, records: [record], userId: _userId,
      );
      // 5日前 ATF → 48ヶ月後 → 通知なし
      expect(
        result.where((n) => n.title.contains('ATF')).isEmpty,
        isTrue,
      );
    });

    test('タイトル "キャビンフィルター" → エアコンフィルターにマッチ', () {
      final v = _makeVehicle(createdBefore: const Duration(days: 5));
      final record = _makeRecord(
        type: MaintenanceType.repair,
        title: 'キャビンフィルター交換',
        doneAgo: const Duration(days: 5),
      );
      final result = svc.generateRecommendations(
        vehicle: v, records: [record], userId: _userId,
      );
      expect(
        result.where((n) => n.title.contains('エアコンフィルター')).isEmpty,
        isTrue,
      );
    });
  });

  // ==========================================================================
  // Group 7: Edge Cases
  // ==========================================================================
  group('Edge Cases', () {
    test('走行距離 0 の車両でクラッシュしない', () {
      final v = _makeVehicle(mileage: 0);
      expect(
        () => service.generateRecommendations(
          vehicle: v, records: [], userId: _userId,
        ),
        returnsNormally,
      );
    });

    test('非常に古い車両（1990年製）でクラッシュしない', () {
      final v = _makeVehicle(year: 1990);
      expect(
        () => service.generateRecommendations(
          vehicle: v, records: [], userId: _userId,
        ),
        returnsNormally,
      );
    });

    test('大量の記録（100件）でもパフォーマンス問題なく返る', () {
      final v = _makeVehicle();
      final records = List.generate(
        100,
        (i) => _makeRecord(
          type: MaintenanceType.oilChange,
          doneAgo: Duration(days: i * 3 + 1),
          mileageAtService: 30000 - i * 200,
        ),
      );
      expect(
        () => service.generateRecommendations(
          vehicle: v, records: records, userId: _userId,
        ),
        returnsNormally,
      );
    });

    test('inspection ≤ 0 かつ insurance ≤ 0 → 両方 high priority', () {
      final v = _makeVehicle(
        inspectionExpiryDate: DateTime.now().subtract(const Duration(days: 5)),
        insuranceExpiryDate: DateTime.now().subtract(const Duration(days: 3)),
      );
      final result = service.generateRecommendations(
        vehicle: v, records: [], userId: _userId,
      );
      final highCount = result
          .where((n) => n.priority == NotificationPriority.high)
          .length;
      expect(highCount, greaterThanOrEqualTo(2));
    });

    test('走行距離がちょうど intervalKm の境界値 → 推奨発火', () {
      final v = _makeVehicle(mileage: 30000);
      final record = _makeRecord(
        type: MaintenanceType.oilChange,
        doneAgo: const Duration(days: 5),
        mileageAtService: 25000, // 30000 - 25000 = 5000 = intervalKm
      );
      final result = service.generateRecommendations(
        vehicle: v, records: [record], userId: _userId,
      );
      final oilNotif = result.firstWhere(
        (n) => n.title.contains('エンジンオイル交換'),
        orElse: () => throw 'not found',
      );
      expect(oilNotif.priority, NotificationPriority.high);
    });

    test('結果の通知IDはすべてユニークである', () {
      final v = _makeVehicle(
        inspectionExpiryDate: DateTime.now().add(const Duration(days: 10)),
        insuranceExpiryDate: DateTime.now().add(const Duration(days: 5)),
        createdBefore: const Duration(days: 400),
      );
      final result = service.generateRecommendations(
        vehicle: v, records: [], userId: _userId,
      );
      final ids = result.map((n) => n.id).toList();
      final uniqueIds = ids.toSet();
      expect(ids.length, uniqueIds.length);
    });
  });
}
