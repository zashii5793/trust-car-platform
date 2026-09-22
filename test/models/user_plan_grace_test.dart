// 使い始めの半年は、全部開ける。
//
// なぜ:
//   このアプリの価値は**記録が溜まって初めて出る**。燃費も整備間隔も
//   次回予測も、データが無いうちは何も言えない。
//
//   ところが無料プランは `driveLogRetentionDays: 30` で、**溜まる前に
//   消える**。溜まることが価値なのに溜めさせない、という食い違いがあった。
//
//   「半年使ってもらって、価値が出てから課金を相談する」に変える。
//   登録から180日は、プランに関係なくプレミアムと同じ上限で動かす。
//
// 見るのは `AppUser.createdAt` だけ。**Cloud Functions は要らない**
// （`planType` / `planExpiresAt` はルール上 Functions 経由でしか書けず、
// その Functions がまだ本番に無い）。

import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/models/user_plan.dart';

void main() {
  final signedUp = DateTime(2026, 1, 10);

  group('UserPlanLimits.effective — 使い始めの半年', () {
    test('登録直後は、無料でもプレミアムと同じ上限', () {
      final limits = UserPlanLimits.effective(
        UserPlanType.free,
        accountCreatedAt: signedUp,
        now: signedUp,
      );

      expect(limits.driveLogRetentionDays, UserPlanLimits.unlimited);
      expect(limits.canExportPdf, isTrue);
      expect(limits.maxVehicles, UserPlanLimits.unlimited);
    });

    test('180日目までは開いている', () {
      final limits = UserPlanLimits.effective(
        UserPlanType.free,
        accountCreatedAt: signedUp,
        now: signedUp.add(const Duration(days: 180)),
      );

      expect(limits.canExportPdf, isTrue);
    });

    test('181日目から無料プランの上限に戻る', () {
      final limits = UserPlanLimits.effective(
        UserPlanType.free,
        accountCreatedAt: signedUp,
        now: signedUp.add(const Duration(days: 181)),
      );

      expect(limits.driveLogRetentionDays, 30);
      expect(limits.canExportPdf, isFalse);
      expect(limits.maxVehicles, 3);
    });

    test('プレミアムは半年を過ぎても開いたまま', () {
      final limits = UserPlanLimits.effective(
        UserPlanType.premium,
        accountCreatedAt: signedUp,
        now: signedUp.add(const Duration(days: 400)),
      );

      expect(limits.canExportPdf, isTrue);
    });

    group('Edge Cases', () {
      test('登録日が分からなければ、素のプランで扱う', () {
        // 古いアカウントで createdAt が欠けている場合。開けっ放しに
        // しないほうが安全側。
        final limits = UserPlanLimits.effective(
          UserPlanType.free,
          accountCreatedAt: null,
          now: signedUp,
        );

        expect(limits.canExportPdf, isFalse);
      });

      test('登録日が未来でも開いた扱いにする（時計のずれ）', () {
        final limits = UserPlanLimits.effective(
          UserPlanType.free,
          accountCreatedAt: signedUp.add(const Duration(days: 3)),
          now: signedUp,
        );

        expect(limits.canExportPdf, isTrue);
      });
    });
  });

  group('UserPlanLimits.graceRemaining — 残りを伝える', () {
    test('残り日数が出る', () {
      final left = UserPlanLimits.graceRemaining(
        accountCreatedAt: signedUp,
        now: signedUp.add(const Duration(days: 150)),
      );

      expect(left, 30);
    });

    test('終わっていれば0', () {
      final left = UserPlanLimits.graceRemaining(
        accountCreatedAt: signedUp,
        now: signedUp.add(const Duration(days: 200)),
      );

      expect(left, 0);
    });

    test('登録日が分からなければ0', () {
      expect(
        UserPlanLimits.graceRemaining(accountCreatedAt: null, now: signedUp),
        0,
      );
    });
  });
}
