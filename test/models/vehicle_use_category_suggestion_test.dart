import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/data/vehicle_master_data.dart';
import 'package:trust_car_platform/models/vehicle.dart';
import 'package:trust_car_platform/models/vehicle_master.dart';

/// 選んだ車種から用途区分を推測する。
///
/// 2026-08-25 の指摘「車検はトラックなども対応しているか」を調べたところ、
/// [VehicleUseCategory] は貨物・事業用まで持っていたのに、
/// **新規登録画面には入力が無く、登録直後は全車が「自家用乗用車」扱い**だった。
/// 車検満了日の計算がそこでずれる。
///
/// 利用者に用途区分を正しく選ばせるのは酷なので、車種から初期値を当てる。
/// **あくまで初期値で、画面で変えられる。**
///
/// 周期（道路運送車両法）:
///   自家用乗用   初回3年 → 以降2年
///   貨物（1・4） 初回2年 → 以降1年
///   軽貨物       初回2年 → 以降2年
///   事業用・大型 初回1年 → 以降1年
void main() {
  group('VehicleUseCategory.suggestFor', () {
    test('乗用車は自家用乗用', () {
      expect(
        VehicleUseCategory.suggestFor(
          modelId: 'toyota_prius',
          bodyType: BodyType.hatchback,
        ),
        VehicleUseCategory.privatePassenger,
      );
    });

    test('軽自動車（乗用）は自家用乗用', () {
      expect(
        VehicleUseCategory.suggestFor(
          modelId: 'honda_nbox',
          bodyType: BodyType.kei,
        ),
        VehicleUseCategory.privatePassenger,
      );
    });

    test('普通トラックは貨物', () {
      expect(
        VehicleUseCategory.suggestFor(
          modelId: 'isuzu_elf',
          bodyType: BodyType.truck,
        ),
        VehicleUseCategory.cargo,
      );
    });

    test('商用バンは貨物', () {
      expect(
        VehicleUseCategory.suggestFor(
          modelId: 'toyota_hiace',
          bodyType: BodyType.van,
        ),
        VehicleUseCategory.cargo,
      );
    });

    test('軽トラックは軽貨物（貨物と周期が違う）', () {
      expect(
        VehicleUseCategory.suggestFor(
          modelId: 'daihatsu_hijet_truck',
          bodyType: BodyType.truck,
        ),
        VehicleUseCategory.keiCargo,
      );
    });

    test('軽バンは軽貨物', () {
      expect(
        VehicleUseCategory.suggestFor(
          modelId: 'suzuki_every_van',
          bodyType: BodyType.van,
        ),
        VehicleUseCategory.keiCargo,
      );
    });

    group('Edge Cases', () {
      test('車種IDが null でも body から判断する', () {
        expect(
          VehicleUseCategory.suggestFor(
              modelId: null, bodyType: BodyType.truck),
          VehicleUseCategory.cargo,
        );
      });

      test('何も分からなければ自家用乗用に倒す', () {
        expect(
          VehicleUseCategory.suggestFor(modelId: null, bodyType: null),
          VehicleUseCategory.privatePassenger,
        );
      });

      test('カタログに無い車種IDでも落ちない', () {
        expect(
          VehicleUseCategory.suggestFor(
            modelId: 'bmw_x5',
            bodyType: BodyType.suv,
          ),
          VehicleUseCategory.privatePassenger,
        );
      });

      test('空文字の車種IDでも落ちない', () {
        expect(
          VehicleUseCategory.suggestFor(modelId: '', bodyType: BodyType.van),
          VehicleUseCategory.cargo,
        );
      });

      test('軽貨物リストの車種は全部マスタに実在する', () {
        final allIds = VehicleMasterData.models.values
            .expand((list) => list)
            .map((m) => m['id'] as String)
            .toSet();

        for (final id in VehicleMasterData.keiCargoModelIds) {
          expect(allIds, contains(id), reason: '$id がマスタに無い');
        }
      });

      test('軽貨物リストの車種は truck か van になっている', () {
        final byId = {
          for (final list in VehicleMasterData.models.values)
            for (final m in list) m['id'] as String: m['bodyType'] as String?,
        };

        for (final id in VehicleMasterData.keiCargoModelIds) {
          expect(
            byId[id],
            anyOf('truck', 'van'),
            reason: '$id の bodyType が貨物になっていない',
          );
        }
      });
    });
  });

  group('VehicleUseCategory — 周期', () {
    test('軽貨物と普通貨物で以降のサイクルが違う', () {
      expect(VehicleUseCategory.cargo.inspectionCycleYears, 1);
      expect(VehicleUseCategory.keiCargo.inspectionCycleYears, 2);
    });
  });
}
