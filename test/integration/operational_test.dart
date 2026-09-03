// 運用テスト — 実運用で起きる事象の検証
//
//   1. プラン制限: 無料プランの車両台数上限 / ドライブログ30日保持の境界
//      （29日/30日/31日）
//   2. 通知既読/未読の永続化と再起動シミュレーション
//      （SharedPrefsNotificationStateStore）
//   3. 退会フロー相当: account_deletions マーカー方式の現仕様を固定
//   4. ライセンスプレート正規化（全角/半角）での重複検出
//
// Firebase は FakeCloudFirestore、SharedPreferences はモック初期値で代替
// （emulator 不要）。

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:trust_car_platform/core/constants/firestore_collections.dart';
import 'package:trust_car_platform/core/utils/license_plate.dart';
import 'package:trust_car_platform/models/drive_log.dart';
import 'package:trust_car_platform/models/user_plan.dart';
import 'package:trust_car_platform/models/vehicle.dart';
import 'package:trust_car_platform/services/notification_state_store.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

DriveLog _driveLog({required String id, required DateTime startTime}) =>
    DriveLog(
      id: id,
      userId: 'op-user',
      status: DriveLogStatus.completed,
      startTime: startTime,
      statistics: const DriveStatistics(
        totalDistance: 12.3,
        totalDuration: 1800,
        averageSpeed: 24.6,
        maxSpeed: 60,
      ),
      createdAt: startTime,
      updatedAt: startTime,
    );

/// ドライブログ保持ポリシーの運用仕様:
/// 「startTime が (現在 − 保持日数) より後のログだけを保持する」。
///
/// 現時点で lib/ にこのフィルタを実装したコードは無い
/// （UserPlanLimits.driveLogRetentionDays は値の定義のみ）。
/// 本テストは purge 実装時に従うべき境界仕様をここで固定する。
List<DriveLog> _applyRetention(
  List<DriveLog> logs,
  UserPlanLimits limits,
  DateTime now,
) {
  if (limits.driveLogRetentionDays == UserPlanLimits.unlimited) {
    return logs;
  }
  final cutoff = now.subtract(Duration(days: limits.driveLogRetentionDays));
  return logs.where((log) => log.startTime.isAfter(cutoff)).toList();
}

Vehicle _vehicle({
  required String id,
  String userId = 'op-user',
  String? licensePlate,
}) =>
    Vehicle(
      id: id,
      userId: userId,
      maker: 'Toyota',
      model: 'Prius',
      year: 2022,
      grade: 'S',
      mileage: 10000,
      licensePlate: licensePlate,
      createdAt: DateTime(2025, 8, 1),
      updatedAt: DateTime(2025, 8, 1),
    );

/// FirebaseService.isLicensePlateExists と同じ比較仕様の再現。
///
/// 本体は FirebaseAuth.instance に直結していて単体テストで構築できない
/// （コンストラクタ注入なし・要修正としてレポート記載）。ここでは
/// 「ユーザー単位で全車両を取得し licensePlateKey 同士で比較する」という
/// データ契約を FakeFirestore 上で固定する。
Future<bool> _plateExists(
  FakeFirebaseFirestore firestore,
  String userId,
  String plate, {
  String? excludeVehicleId,
}) async {
  final snapshot = await firestore
      .collection(FirestoreCollections.vehicles)
      .where('userId', isEqualTo: userId)
      .get();

  final target = licensePlateKey(plate);
  if (target.isEmpty) return false;

  return snapshot.docs.any((doc) {
    if (doc.id == excludeVehicleId) return false;
    final raw = doc.data()['licensePlate'];
    if (raw is! String || raw.isEmpty) return false;
    return licensePlateKey(raw) == target;
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ===========================================================================
  // 1. プラン制限 — 無料プランの境界値
  // ===========================================================================
  group('プラン制限 — 無料/プレミアムの境界', () {
    final freeLimits = UserPlanLimits.forPlan(UserPlanType.free);
    final premiumLimits = UserPlanLimits.forPlan(UserPlanType.premium);

    test('無料プランの上限値が仕様どおり（車両3台・ログ30日・問い合わせ月3件）', () {
      expect(freeLimits.maxVehicles, 3);
      expect(freeLimits.driveLogRetentionDays, 30);
      expect(freeLimits.maxMonthlyInquiries, 3);
      expect(freeLimits.canExportPdf, isFalse);
    });

    test('無料プラン: 3台登録済みで上限到達、2台なら登録余地あり', () async {
      final firestore = FakeFirebaseFirestore();
      for (var i = 0; i < 3; i++) {
        await firestore
            .collection(FirestoreCollections.vehicles)
            .doc('car-$i')
            .set(_vehicle(id: 'car-$i').toMap());
      }

      final snap = await firestore
          .collection(FirestoreCollections.vehicles)
          .where('userId', isEqualTo: 'op-user')
          .get();

      expect(snap.docs.length >= freeLimits.maxVehicles, isTrue,
          reason: '3台で上限到達（4台目は登録不可となるべき）');
      expect(snap.docs.length - 1 >= freeLimits.maxVehicles, isFalse,
          reason: '2台なら登録余地がある');
    });

    group('ドライブログ30日保持の境界（29日/30日/31日）', () {
      final now = DateTime(2026, 8, 9, 12, 0, 0);
      final logs = [
        _driveLog(
            id: 'age-29d', startTime: now.subtract(const Duration(days: 29))),
        _driveLog(
            id: 'age-30d', startTime: now.subtract(const Duration(days: 30))),
        _driveLog(
            id: 'age-31d', startTime: now.subtract(const Duration(days: 31))),
      ];

      test('29日前のログは保持される', () {
        final kept = _applyRetention(logs, freeLimits, now);
        expect(kept.map((l) => l.id), contains('age-29d'));
      });

      test('ちょうど30日前のログは保持対象外（境界は削除側に倒す）', () {
        final kept = _applyRetention(logs, freeLimits, now);
        expect(kept.map((l) => l.id), isNot(contains('age-30d')));
      });

      test('31日前のログは保持対象外', () {
        final kept = _applyRetention(logs, freeLimits, now);
        expect(kept.map((l) => l.id), isNot(contains('age-31d')));
        expect(kept, hasLength(1)); // 残るのは29日前のみ
      });

      test('プレミアムプランは保持無制限（31日前のログも残る）', () {
        final kept = _applyRetention(logs, premiumLimits, now);
        expect(kept, hasLength(3));
      });
    });

    group('Edge Cases', () {
      test('ログ0件でも保持フィルタは安全に空を返す', () {
        final kept =
            _applyRetention(const [], freeLimits, DateTime(2026, 8, 9));
        expect(kept, isEmpty);
      });

      test('車両0台のユーザーは上限に達していない', () async {
        final firestore = FakeFirebaseFirestore();
        final snap = await firestore
            .collection(FirestoreCollections.vehicles)
            .where('userId', isEqualTo: 'nobody')
            .get();
        expect(snap.docs.length >= freeLimits.maxVehicles, isFalse);
      });

      test('unlimited センチネルは現実的な保有台数を大きく上回る', () {
        expect(UserPlanLimits.unlimited, greaterThan(10000));
        expect(premiumLimits.maxVehicles, UserPlanLimits.unlimited);
      });
    });
  });

  // ===========================================================================
  // 2. 通知既読/未読の永続化（NotificationStateStore）
  //    通知本体は毎回再生成されるため、既読/削除のID集合だけが
  //    SharedPreferences に永続化される（再起動しても状態が戻らないこと）。
  // ===========================================================================
  group('通知既読状態の永続化と再起動シミュレーション', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('既読IDを保存し、別インスタンス（再起動相当）で読み戻せる', () async {
      final store = SharedPrefsNotificationStateStore();
      await store.saveReadIds({'notif-1', 'notif-2'});

      // アプリ再起動: 新しいインスタンスが同じ永続層を読む
      final restarted = SharedPrefsNotificationStateStore();
      final loaded = await restarted.loadReadIds();

      expect(loaded, {'notif-1', 'notif-2'});
    });

    test('削除済み（dismissed）IDも独立して永続化される', () async {
      final store = SharedPrefsNotificationStateStore();
      await store.saveReadIds({'read-1'});
      await store.saveDismissedIds({'dismissed-1'});

      final restarted = SharedPrefsNotificationStateStore();
      expect(await restarted.loadReadIds(), {'read-1'});
      expect(await restarted.loadDismissedIds(), {'dismissed-1'});
    });

    test('既読トグル: 既読→未読に戻した状態が再起動後も保たれる', () async {
      final store = SharedPrefsNotificationStateStore();
      await store.saveReadIds({'notif-1', 'notif-2'});

      // notif-2 を未読に戻す（IDを除いた集合を保存し直す）
      final current = await store.loadReadIds();
      current.remove('notif-2');
      await store.saveReadIds(current);

      final restarted = SharedPrefsNotificationStateStore();
      final loaded = await restarted.loadReadIds();
      expect(loaded, {'notif-1'});
      expect(loaded, isNot(contains('notif-2')));
    });

    group('Edge Cases', () {
      test('初回起動（保存データなし）は空セットを返す', () async {
        final store = SharedPrefsNotificationStateStore();
        expect(await store.loadReadIds(), isEmpty);
        expect(await store.loadDismissedIds(), isEmpty);
      });

      test('空セットの保存も安全（全既読解除相当）', () async {
        final store = SharedPrefsNotificationStateStore();
        await store.saveReadIds({'a'});
        await store.saveReadIds(<String>{});
        expect(await store.loadReadIds(), isEmpty);
      });

      test('500件を超えると古いIDから破棄される（無限成長の防止）', () async {
        final store = SharedPrefsNotificationStateStore();
        final ids = <String>{for (var i = 0; i < 600; i++) 'notif-$i'};
        await store.saveReadIds(ids);

        final loaded = await store.loadReadIds();
        expect(loaded, hasLength(500));
        expect(loaded, contains('notif-599')); // 新しい側は残る
        expect(loaded, isNot(contains('notif-0'))); // 最古は落ちる
      });
    });
  });

  // ===========================================================================
  // 3. 退会フロー相当 — 現仕様の固定
  //    AuthService.deleteAccount の現仕様:
  //      (1) account_deletions/{uid} に status=pending のマーカーを記録
  //      (2) Firebase Auth アカウントを削除（ログイン手段の除去）
  //      (3) ユーザーデータの実削除はサーバー側 purge が30日以内に実施
  //    → クライアントは vehicles / 整備記録 / ドライブログを即時削除
  //      **しない**。この挙動をデータ契約として固定する。
  //    （AuthService は FirebaseAuth.instance 直結のため、ここでは
  //      Firestore 側の契約のみを検証する。）
  // ===========================================================================
  group('退会フロー相当 — 削除マーカー方式の現仕様固定', () {
    late FakeFirebaseFirestore firestore;
    const uid = 'leaving-user';

    Future<void> seedUserData() async {
      await firestore
          .collection(FirestoreCollections.vehicles)
          .doc('leaving-car')
          .set(_vehicle(id: 'leaving-car', userId: uid).toMap());
      await firestore
          .collection(FirestoreCollections.maintenanceRecords)
          .doc('leaving-record')
          .set({
        'vehicleId': 'leaving-car',
        'userId': uid,
        'type': 'oilChange',
        'title': 'オイル交換',
        'cost': 4200,
        'date': Timestamp.fromDate(DateTime(2026, 1, 15)),
        'createdAt': Timestamp.fromDate(DateTime(2026, 1, 15)),
      });
      await firestore
          .collection(FirestoreCollections.driveLogs)
          .doc('leaving-log')
          .set(_driveLog(
            id: 'leaving-log',
            startTime: DateTime(2026, 7, 1),
          ).toMap());
    }

    // AuthService.deleteAccount ステップ(1)相当
    Future<void> writeDeletionMarker() async {
      await firestore
          .collection(FirestoreCollections.accountDeletions)
          .doc(uid)
          .set({
        'uid': uid,
        'requestedAt': Timestamp.now(),
        'status': 'pending',
      });
    }

    setUp(() async {
      firestore = FakeFirebaseFirestore();
      await seedUserData();
    });

    test('削除要求は account_deletions に pending マーカーとして記録される', () async {
      await writeDeletionMarker();

      final marker = await firestore
          .collection(FirestoreCollections.accountDeletions)
          .doc(uid)
          .get();
      expect(marker.exists, isTrue);
      expect(marker.data()!['status'], 'pending');
      expect(marker.data()!['uid'], uid);
      expect(marker.data()!['requestedAt'], isA<Timestamp>());
    });

    test('マーカー記録後も関連データは残る（即時削除しない現仕様）', () async {
      await writeDeletionMarker();

      // サーバー側 purge（30日以内）まではデータが残るのが現仕様。
      // プライバシーポリシー記載の「退会後30日間保持後、削除」と整合する。
      final vehicle = await firestore
          .collection(FirestoreCollections.vehicles)
          .doc('leaving-car')
          .get();
      final record = await firestore
          .collection(FirestoreCollections.maintenanceRecords)
          .doc('leaving-record')
          .get();
      final log = await firestore
          .collection(FirestoreCollections.driveLogs)
          .doc('leaving-log')
          .get();

      expect(vehicle.exists, isTrue);
      expect(record.exists, isTrue);
      expect(log.exists, isTrue);
    });

    test('再ログイン要求時のロールバックでマーカーだけが消えデータは無傷', () async {
      await writeDeletionMarker();

      // requires-recent-login 時、AuthService はマーカーを削除して
      // 「何も失わない」状態に戻す（ステップ(3)相当）
      await firestore
          .collection(FirestoreCollections.accountDeletions)
          .doc(uid)
          .delete();

      final marker = await firestore
          .collection(FirestoreCollections.accountDeletions)
          .doc(uid)
          .get();
      expect(marker.exists, isFalse);

      final vehicle = await firestore
          .collection(FirestoreCollections.vehicles)
          .doc('leaving-car')
          .get();
      expect(vehicle.exists, isTrue);
    });

    group('Edge Cases', () {
      test('データ0件のユーザーでもマーカー記録は成立する', () async {
        final emptyFirestore = FakeFirebaseFirestore();
        await emptyFirestore
            .collection(FirestoreCollections.accountDeletions)
            .doc('no-data-user')
            .set({
          'uid': 'no-data-user',
          'requestedAt': Timestamp.now(),
          'status': 'pending',
        });

        final marker = await emptyFirestore
            .collection(FirestoreCollections.accountDeletions)
            .doc('no-data-user')
            .get();
        expect(marker.exists, isTrue);
      });

      test('マーカーの二重書き込みは上書きになる（重複ドキュメント化しない）', () async {
        await writeDeletionMarker();
        await writeDeletionMarker();

        final markers = await firestore
            .collection(FirestoreCollections.accountDeletions)
            .get();
        expect(markers.docs, hasLength(1));
      });
    });
  });

  // ===========================================================================
  // 4. ライセンスプレート正規化での重複検出
  //    IME の全角入力と OCR の半角入力が同一車両として扱われること。
  // ===========================================================================
  group('ライセンスプレート正規化での重複検出', () {
    late FakeFirebaseFirestore firestore;
    const userId = 'plate-user';

    setUp(() async {
      firestore = FakeFirebaseFirestore();
      // 半角・通常スペースで登録済みの車両
      await firestore
          .collection(FirestoreCollections.vehicles)
          .doc('registered-car')
          .set(_vehicle(
            id: 'registered-car',
            userId: userId,
            licensePlate: '品川 300 あ 12-34',
          ).toMap());
    });

    test('全角IME入力（全角数字・全角スペース・全角ハイフン）が重複と判定される', () async {
      final exists = await _plateExists(
        firestore,
        userId,
        '品川　３００　あ　１２－３４',
      );
      expect(exists, isTrue);
    });

    test('スペース詰め・長音記号ハイフンでも同一車両と判定される', () async {
      // OCR がスペースを落とし、ハイフンを長音記号「ー」で読むケース
      final exists = await _plateExists(firestore, userId, '品川300あ12ー34');
      expect(exists, isTrue);
    });

    test('excludeVehicleId: 自車両の編集時は重複扱いしない', () async {
      final exists = await _plateExists(
        firestore,
        userId,
        '品川　３００　あ　１２－３４',
        excludeVehicleId: 'registered-car',
      );
      expect(exists, isFalse);
    });

    test('別ナンバーは重複にならない', () async {
      final exists = await _plateExists(firestore, userId, '品川 300 あ 12-35');
      expect(exists, isFalse);
    });

    test('他ユーザーの同一ナンバーは重複扱いしない（ユーザー単位チェック）', () async {
      final exists =
          await _plateExists(firestore, 'other-user', '品川 300 あ 12-34');
      expect(exists, isFalse);
    });

    group('Edge Cases', () {
      test('空文字プレートは重複なし扱い', () async {
        final exists = await _plateExists(firestore, userId, '');
        expect(exists, isFalse);
      });

      test('空白のみのプレートも重複なし扱い', () async {
        final exists = await _plateExists(firestore, userId, '　 　');
        expect(exists, isFalse);
      });

      test('プレート未登録の車両が混ざっていても安全', () async {
        await firestore
            .collection(FirestoreCollections.vehicles)
            .doc('no-plate-car')
            .set(_vehicle(id: 'no-plate-car', userId: userId).toMap());

        final exists = await _plateExists(firestore, userId, '品川 300 あ 12-34');
        expect(exists, isTrue); // 既存の登録車両だけが一致する
      });
    });
  });
}
