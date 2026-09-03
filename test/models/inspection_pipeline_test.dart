import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/models/inspection_pipeline.dart';
import 'package:trust_car_platform/models/maintenance_record.dart';
import 'package:trust_car_platform/models/vehicle.dart';

/// 車検の取りこぼしを数える。
///
/// `docs/BUSINESS_MODEL_RETHINK_2026-08-27.md` §2-4。
///
/// オーナーへの聞き取りで、**年間の取りこぼし台数は「把握できていない」**
/// という回答だった。分母が無いので、
///
/// - 何台逃しているのか分からない
/// - 手を打っても、効いたかどうか分からない
///
/// **アプリの最大の価値は、実は「取りこぼしが数えられるようになること」
/// かもしれない。** 収益より前の、経営の可視化に近い。
///
/// ```
///  満了を迎える顧客     ← 車検満了日から出る
///  そのうち入庫した台数  ← 整備記録から出る
///  ─────────────────
///  差分 = 取りこぼし
/// ```
///
/// **数えられないものを0と書かない。** 「取りこぼし0台」と「まだ分からない」
/// はまったく違う。ここを混ぜると、経営判断を誤らせる。
void main() {
  final today = DateTime(2026, 8, 28);

  Vehicle vehicle({
    required String id,
    required DateTime? expiry,
    String userId = 'u1',
  }) {
    return Vehicle(
      id: id,
      userId: userId,
      maker: 'トヨタ',
      model: 'アルファード',
      year: 2021,
      grade: 'Z',
      mileage: 30000,
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2025, 1, 1),
      inspectionExpiryDate: expiry,
    );
  }

  MaintenanceRecord inspection({
    required String vehicleId,
    required DateTime date,
    MaintenanceType type = MaintenanceType.legalInspection24,
  }) {
    return MaintenanceRecord(
      id: 'r-$vehicleId-${date.millisecondsSinceEpoch}',
      vehicleId: vehicleId,
      userId: 'u1',
      type: type,
      title: type.displayName,
      cost: 74000,
      date: date,
      createdAt: date,
    );
  }

  group('InspectionPipeline — 満了予定の抽出', () {
    test('期間内に満了する車を拾う', () {
      final pipeline = InspectionPipeline.build(
        vehicles: [
          vehicle(id: 'v1', expiry: DateTime(2026, 9, 15)),
          vehicle(id: 'v2', expiry: DateTime(2026, 10, 20)),
          vehicle(id: 'v3', expiry: DateTime(2027, 5, 1)), // 期間外
        ],
        records: const [],
        from: DateTime(2026, 9, 1),
        to: DateTime(2026, 10, 31),
        today: today,
      );

      expect(pipeline.dueCount, 2);
    });

    test('入庫済みと未入庫を分ける', () {
      final pipeline = InspectionPipeline.build(
        vehicles: [
          vehicle(id: 'v1', expiry: DateTime(2026, 9, 15)),
          vehicle(id: 'v2', expiry: DateTime(2026, 9, 20)),
        ],
        records: [
          // v1 は満了前に車検を受けた
          inspection(vehicleId: 'v1', date: DateTime(2026, 9, 3)),
        ],
        from: DateTime(2026, 9, 1),
        to: DateTime(2026, 9, 30),
        today: today,
      );

      expect(pipeline.completedCount, 1);
      expect(pipeline.pendingCount, 1);
    });

    test('満了日より前でも後でも、近い時期の車検なら入庫済みとみなす', () {
      // 実務では満了日の少し後に受けることもある（継続検査の猶予）。
      final pipeline = InspectionPipeline.build(
        vehicles: [vehicle(id: 'v1', expiry: DateTime(2026, 9, 15))],
        records: [inspection(vehicleId: 'v1', date: DateTime(2026, 9, 20))],
        from: DateTime(2026, 9, 1),
        to: DateTime(2026, 9, 30),
        today: today,
      );

      expect(pipeline.completedCount, 1);
    });

    test('12ヶ月点検も車検の入庫として数える', () {
      final pipeline = InspectionPipeline.build(
        vehicles: [vehicle(id: 'v1', expiry: DateTime(2026, 9, 15))],
        records: [
          inspection(
            vehicleId: 'v1',
            date: DateTime(2026, 9, 10),
            type: MaintenanceType.legalInspection12,
          ),
        ],
        from: DateTime(2026, 9, 1),
        to: DateTime(2026, 9, 30),
        today: today,
      );

      expect(pipeline.completedCount, 1);
    });
  });

  group('InspectionPipeline — 取りこぼし', () {
    test('満了日を過ぎて入庫が無ければ、取りこぼしに数える', () {
      final pipeline = InspectionPipeline.build(
        vehicles: [vehicle(id: 'v1', expiry: DateTime(2026, 7, 15))],
        records: const [],
        from: DateTime(2026, 7, 1),
        to: DateTime(2026, 7, 31),
        today: today, // 8/28 なので、7/15 はとっくに過ぎている
      );

      expect(pipeline.missedCount, 1);
    });

    test('まだ満了日が来ていない車は、取りこぼしに数えない', () {
      // ここを数えると「まだ来ていないだけ」を失注として報告してしまう。
      final pipeline = InspectionPipeline.build(
        vehicles: [vehicle(id: 'v1', expiry: DateTime(2026, 9, 15))],
        records: const [],
        from: DateTime(2026, 9, 1),
        to: DateTime(2026, 9, 30),
        today: today,
      );

      expect(pipeline.missedCount, 0);
      expect(pipeline.pendingCount, 1);
    });

    test('満了直後は猶予を見る（すぐには取りこぼしにしない）', () {
      // 満了の翌日に「逃した」と出すのは早すぎる。
      final pipeline = InspectionPipeline.build(
        vehicles: [
          vehicle(id: 'v1', expiry: today.subtract(const Duration(days: 3))),
        ],
        records: const [],
        from: DateTime(2026, 8, 1),
        to: DateTime(2026, 8, 31),
        today: today,
      );

      expect(pipeline.missedCount, 0);
    });

    test('猶予を過ぎたら取りこぼしになる', () {
      final pipeline = InspectionPipeline.build(
        vehicles: [
          vehicle(
            id: 'v1',
            expiry: today.subtract(
              Duration(days: InspectionPipeline.graceDays + 1),
            ),
          ),
        ],
        records: const [],
        from: DateTime(2026, 1, 1),
        to: DateTime(2026, 12, 31),
        today: today,
      );

      expect(pipeline.missedCount, 1);
    });
  });

  group('InspectionPipeline — 数えられるか', () {
    test('満了日を持つ車が1台も無ければ「まだ分からない」', () {
      // **これが「取りこぼし0台」と混ざるのが一番まずい。**
      final pipeline = InspectionPipeline.build(
        vehicles: [
          vehicle(id: 'v1', expiry: null),
          vehicle(id: 'v2', expiry: null),
        ],
        records: const [],
        from: DateTime(2026, 1, 1),
        to: DateTime(2026, 12, 31),
        today: today,
      );

      expect(pipeline.canCount, isFalse);
    });

    test('満了日を持つ車があれば数えられる', () {
      final pipeline = InspectionPipeline.build(
        vehicles: [vehicle(id: 'v1', expiry: DateTime(2026, 9, 15))],
        records: const [],
        from: DateTime(2026, 9, 1),
        to: DateTime(2026, 9, 30),
        today: today,
      );

      expect(pipeline.canCount, isTrue);
    });

    test('満了日が未入力の台数を出す（潰すべき穴の大きさ）', () {
      final pipeline = InspectionPipeline.build(
        vehicles: [
          vehicle(id: 'v1', expiry: DateTime(2026, 9, 15)),
          vehicle(id: 'v2', expiry: null),
          vehicle(id: 'v3', expiry: null),
        ],
        records: const [],
        from: DateTime(2026, 9, 1),
        to: DateTime(2026, 9, 30),
        today: today,
      );

      expect(pipeline.unknownExpiryCount, 2);
    });
  });

  group('Edge Cases', () {
    test('車が0台でも落ちない', () {
      final pipeline = InspectionPipeline.build(
        vehicles: const [],
        records: const [],
        from: DateTime(2026, 9, 1),
        to: DateTime(2026, 9, 30),
        today: today,
      );

      expect(pipeline.dueCount, 0);
      expect(pipeline.canCount, isFalse);
    });

    test('期間の端ちょうどの満了日は含める', () {
      final pipeline = InspectionPipeline.build(
        vehicles: [
          vehicle(id: 'v1', expiry: DateTime(2026, 9, 1)),
          vehicle(id: 'v2', expiry: DateTime(2026, 9, 30)),
        ],
        records: const [],
        from: DateTime(2026, 9, 1),
        to: DateTime(2026, 9, 30),
        today: today,
      );

      expect(pipeline.dueCount, 2);
    });

    test('別の車の整備記録は入庫として数えない', () {
      final pipeline = InspectionPipeline.build(
        vehicles: [vehicle(id: 'v1', expiry: DateTime(2026, 9, 15))],
        records: [inspection(vehicleId: 'v2', date: DateTime(2026, 9, 10))],
        from: DateTime(2026, 9, 1),
        to: DateTime(2026, 9, 30),
        today: today,
      );

      expect(pipeline.completedCount, 0);
    });

    test('車検と無関係な整備は入庫として数えない', () {
      // オイル交換で来ただけでは、車検を取れたことにならない。
      final pipeline = InspectionPipeline.build(
        vehicles: [vehicle(id: 'v1', expiry: DateTime(2026, 9, 15))],
        records: [
          inspection(
            vehicleId: 'v1',
            date: DateTime(2026, 9, 10),
            type: MaintenanceType.oilChange,
          ),
        ],
        from: DateTime(2026, 9, 1),
        to: DateTime(2026, 9, 30),
        today: today,
      );

      expect(pipeline.completedCount, 0);
    });

    test('ずっと前の車検は、今回の入庫として数えない', () {
      // 2年前の車検が「今回受けた」ことになると、取りこぼしが消える。
      final pipeline = InspectionPipeline.build(
        vehicles: [vehicle(id: 'v1', expiry: DateTime(2026, 9, 15))],
        records: [inspection(vehicleId: 'v1', date: DateTime(2024, 9, 10))],
        from: DateTime(2026, 9, 1),
        to: DateTime(2026, 9, 30),
        today: today,
      );

      expect(pipeline.completedCount, 0);
    });

    test('from と to が逆でも落ちない', () {
      final pipeline = InspectionPipeline.build(
        vehicles: [vehicle(id: 'v1', expiry: DateTime(2026, 9, 15))],
        records: const [],
        from: DateTime(2026, 9, 30),
        to: DateTime(2026, 9, 1),
        today: today,
      );

      expect(pipeline.dueCount, 1);
    });

    test('合計が合う（入庫済み + 未入庫 = 満了予定）', () {
      final pipeline = InspectionPipeline.build(
        vehicles: [
          vehicle(id: 'v1', expiry: DateTime(2026, 9, 5)),
          vehicle(id: 'v2', expiry: DateTime(2026, 9, 15)),
          vehicle(id: 'v3', expiry: DateTime(2026, 9, 25)),
        ],
        records: [inspection(vehicleId: 'v1', date: DateTime(2026, 9, 2))],
        from: DateTime(2026, 9, 1),
        to: DateTime(2026, 9, 30),
        today: today,
      );

      expect(
        pipeline.completedCount + pipeline.pendingCount,
        pipeline.dueCount,
      );
    });
  });

  /// 店側の集計（案A）。
  ///
  /// `docs/BUSINESS_MODEL_RETHINK_2026-08-27.md` §6-2。
  ///
  /// 店は顧客の `vehicles` を読めない。**読めるようにするほうが問題**なので、
  /// 顧客が自分で「車検の満了日だけ」を置き、店はそれを読む。
  /// 入庫したかどうかは渡らないので、**「取りこぼし」と言い切ってはいけない。**
  group('fromSharedExpiries（店側・満了日だけを受け取る）', () {
    CustomerExpirySummary customer({
      List<DateTime> expiries = const [],
      int? vehicleCount,
      bool isSharing = true,
    }) {
      return CustomerExpirySummary(
        expiries: expiries,
        vehicleCount: vehicleCount ?? expiries.length,
        isSharing: isSharing,
      );
    }

    InspectionPipeline pipelineOf(List<CustomerExpirySummary> customers) {
      return InspectionPipeline.fromSharedExpiries(
        customers: customers,
        from: DateTime(2026, 8, 1),
        to: DateTime(2026, 10, 31),
        today: today,
      );
    }

    test('期間内の満了日を数える', () {
      final pipeline = pipelineOf([
        customer(expiries: [DateTime(2026, 9, 10)]),
        customer(expiries: [DateTime(2026, 10, 2)]),
      ]);

      expect(pipeline.dueCount, 2);
    });

    test('期間外の満了日は数えない', () {
      final pipeline = pipelineOf([
        customer(expiries: [DateTime(2026, 7, 31), DateTime(2026, 11, 1)]),
      ]);

      expect(pipeline.dueCount, 0);
    });

    test('入庫が分からないので、取りこぼしは名乗らない', () {
      // ここが 0 でないと、「入庫済みかもしれない車」を逃したことにしてしまう。
      final pipeline = pipelineOf([
        customer(expiries: [DateTime(2026, 8, 1)]),
      ]);

      expect(pipeline.isCompletionKnown, isFalse);
      expect(pipeline.missedCount, 0);
      expect(pipeline.completedCount, 0);
    });

    test('猶予を過ぎたものは「要確認」に入る', () {
      // 8/28 時点。8/1 満了は猶予14日を過ぎている。
      final pipeline = pipelineOf([
        customer(expiries: [DateTime(2026, 8, 1)]),
      ]);

      expect(pipeline.overdueCount, 1);
    });

    test('猶予の中はまだ要確認にしない', () {
      // 8/20 満了は、8/28 時点で猶予14日の中。
      final pipeline = pipelineOf([
        customer(expiries: [DateTime(2026, 8, 20)]),
      ]);

      expect(pipeline.overdueCount, 0);
      expect(pipeline.dueCount, 1);
    });

    test('満了日が未入力の台数は「分からない」に積む', () {
      final pipeline = pipelineOf([
        customer(expiries: [DateTime(2026, 9, 10)], vehicleCount: 3),
      ]);

      expect(pipeline.unknownExpiryCount, 2);
    });

    test('共有を切っている人は、台数まるごと分からない扱い', () {
      // 0台として数えると、分母が小さく見えて取りこぼしを見落とす。
      final pipeline = pipelineOf([
        customer(expiries: const [], vehicleCount: 2, isSharing: false),
      ]);

      expect(pipeline.unknownExpiryCount, 2);
      expect(pipeline.dueCount, 0);
    });

    test('共有を切っている人の満了日は、残っていても数えない', () {
      final pipeline = pipelineOf([
        customer(
          expiries: [DateTime(2026, 9, 10)],
          vehicleCount: 1,
          isSharing: false,
        ),
      ]);

      expect(pipeline.dueCount, 0);
    });

    test('誰もいなければ「数えられない」', () {
      // 顧客0名で「取りこぼし0台」と出すと、うまく行っていると誤解される。
      expect(pipelineOf(const []).canCount, isFalse);
    });

    test('満了予定 = 猶予内 + 要確認', () {
      final pipeline = pipelineOf([
        customer(expiries: [DateTime(2026, 8, 1), DateTime(2026, 9, 20)]),
        customer(expiries: [DateTime(2026, 10, 5)]),
      ]);

      expect(pipeline.pendingCount, pipeline.dueCount);
      expect(pipeline.overdueCount, 1);
    });

    test('from と to が逆でも落ちない', () {
      final pipeline = InspectionPipeline.fromSharedExpiries(
        customers: [
          customer(expiries: [DateTime(2026, 9, 15)])
        ],
        from: DateTime(2026, 10, 31),
        to: DateTime(2026, 8, 1),
        today: today,
      );

      expect(pipeline.dueCount, 1);
    });
  });
}
