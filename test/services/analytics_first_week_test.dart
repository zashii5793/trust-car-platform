import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/services/analytics_service.dart';

/// 利用者の最初の7日（プロダクト評価 2026-09-29 改善 #6）。
///
/// 登録 → 車の登録 → 過去の記録を移す → 同じ車種の維持費を見る → 店とつながる、
/// の各段階に着いたかを、登録から何日目かと一緒に送る。Firebase Analytics の
/// ファネルで「7日以内に移管した割合」などを出すため。
void main() {
  late List<(String, Map<String, Object>?)> sent;
  late DateTime now;
  DateTime? createdAt;
  late AnalyticsService sut;

  setUp(() {
    sent = [];
    now = DateTime(2026, 10, 1, 12);
    createdAt = DateTime(2026, 9, 28, 9);
    sut = AnalyticsService.forTesting(
      onLog: (name, params) => sent.add((name, params)),
      clock: () => now,
      accountCreatedAt: () => createdAt,
    );
  });

  group('trackFirstWeekStep', () {
    test('段階・登録からの日数・7日以内かを送る', () async {
      await sut.trackFirstWeekStep(FirstWeekStep.pastRecordsImported);

      expect(sent, hasLength(1));
      final (name, params) = sent.single;
      expect(name, 'first_week_step');
      expect(params!['step'], 'past_records_imported');
      expect(params['days_since_signup'], 3);
      expect(params['within_7_days'], 1);
    });

    test('全段階に、重ならない名前がある', () {
      final names = FirstWeekStep.values.map((s) => s.eventValue).toList();
      expect(names.toSet(), hasLength(FirstWeekStep.values.length));
      expect(
          names,
          containsAll(<String>[
            'vehicle_added',
            'past_records_imported',
            'model_cost_viewed',
            'shop_linked',
          ]));
    });

    test('8日目は7日以内に数えない', () async {
      now = DateTime(2026, 10, 6, 10); // 登録から8日目
      await sut.trackFirstWeekStep(FirstWeekStep.shopLinked);

      final params = sent.single.$2!;
      expect(params['days_since_signup'], 8);
      expect(params['within_7_days'], 0);
    });

    test('7日目ちょうどは7日以内', () async {
      now = DateTime(2026, 10, 6, 8); // 7日と23時間
      await sut.trackFirstWeekStep(FirstWeekStep.modelCostViewed);

      expect(sent.single.$2!['days_since_signup'], 7);
      expect(sent.single.$2!['within_7_days'], 1);
    });

    group('Edge Cases', () {
      test('登録日が分からないときは -1 で送り、7日以内に数えない', () async {
        createdAt = null;
        await sut.trackFirstWeekStep(FirstWeekStep.vehicleAdded);

        expect(sent.single.$2!['days_since_signup'], -1);
        expect(sent.single.$2!['within_7_days'], 0);
      });

      test('端末の時計が登録日より前でも負の日数を送らない', () async {
        now = DateTime(2026, 9, 27);
        await sut.trackFirstWeekStep(FirstWeekStep.vehicleAdded);

        expect(sent.single.$2!['days_since_signup'], 0);
        expect(sent.single.$2!['within_7_days'], 1);
      });

      test('送り先が無い（テスト・デバッグ）ときも落ちない', () async {
        await expectLater(
          AnalyticsService.forTesting()
              .trackFirstWeekStep(FirstWeekStep.shopLinked),
          completes,
        );
      });
    });
  });
}
