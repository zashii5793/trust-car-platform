import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/models/part_listing.dart';

/// 車種で絞り込めているかを確かめる。
///
/// 社長の指摘（2026-08-20）:「パーツ提案って車種からフィルターかける機能いるよね」
///
/// 実装は在る（`VehicleSpec.matchesVehicle`）が、**当たらなかったときの扱い**で
/// 効かなくなっていた。適合車種を宣言しているのに 1 つも当たらない場合、
/// `getCompatibilityFor` は `defaultCompatibility` を返していた。
/// これはたいてい `compatible` なので、**関係ない車のパーツも「対応」で通る。**
///
/// `PartRecommendationService` は `incompatible` の行だけを飛ばすので、
/// **飛ばす対象が 1 件も出ない** → 絞り込みが存在しないのと同じだった。
void main() {
  PartListing part({
    required List<VehicleSpec> specs,
    CompatibilityLevel fallback = CompatibilityLevel.compatible,
  }) =>
      PartListing(
        id: 'p1',
        shopId: 's1',
        name: 'テスト用パーツ',
        description: '',
        category: PartCategory.aero,
        compatibleVehicles: specs,
        defaultCompatibility: fallback,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

  group('適合車種を宣言しているパーツ', () {
    test('宣言した車種に当たれば perfect', () {
      final p = part(specs: [
        const VehicleSpec(makerId: 'toyota', modelId: 'prius'),
      ]);
      expect(
        p.getCompatibilityFor(makerId: 'toyota', modelId: 'prius', year: 2020),
        CompatibilityLevel.perfect,
      );
    });

    test('メーカーだけ合えば conditional', () {
      final p = part(specs: [
        const VehicleSpec(makerId: 'toyota', modelId: 'aqua'),
      ]);
      expect(
        p.getCompatibilityFor(makerId: 'toyota', modelId: 'prius', year: 2020),
        CompatibilityLevel.conditional,
      );
    });

    test('メーカーも車種も違えば incompatible（除外されること）', () {
      // **ここが壊れていた。** スバル専用と宣言したパーツを、トヨタの車で
      // 見たときに `compatible` が返り、提案に混ざっていた。
      final p = part(specs: [
        const VehicleSpec(makerId: 'subaru', modelId: 'impreza'),
      ]);
      expect(
        p.getCompatibilityFor(makerId: 'toyota', modelId: 'prius', year: 2020),
        CompatibilityLevel.incompatible,
        reason: '適合車種を宣言しているのに当たらないなら、その車には付かない',
      );
    });

    test('年式が範囲外なら incompatible', () {
      final p = part(specs: [
        const VehicleSpec(
            makerId: 'toyota', modelId: 'prius', yearFrom: 2016, yearTo: 2022),
      ]);
      // 車種は合うが年式が外れる。メーカーは合うので conditional に落ちる
      expect(
        p.getCompatibilityFor(makerId: 'toyota', modelId: 'prius', year: 2010),
        CompatibilityLevel.conditional,
      );
    });
  });

  group('適合車種を宣言していないパーツ', () {
    test('宣言が無ければ、宣言どおりの既定値を使う', () {
      // 汎用品（オイル・ワイパーなど）は適合表を持たないことがある。
      // **持っていないことと、持っていて外れることは違う。**
      final p = part(specs: const []);
      expect(
        p.getCompatibilityFor(makerId: 'toyota', modelId: 'prius', year: 2020),
        CompatibilityLevel.compatible,
      );
    });

    test('既定値が incompatible ならそのまま', () {
      final p =
          part(specs: const [], fallback: CompatibilityLevel.incompatible);
      expect(
        p.getCompatibilityFor(makerId: 'toyota', modelId: 'prius', year: 2020),
        CompatibilityLevel.incompatible,
      );
    });
  });
}
