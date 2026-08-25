import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/data/vehicle_master_data.dart';
import 'package:trust_car_platform/models/vehicle_master.dart';

/// 車種マスタの網羅性。
///
/// 2026-08-25 の指摘: **登録画面で選べるメーカーと車種が少なすぎる。**
/// 実測すると 9メーカー / 88車種しかなく、しかも
///
/// - 商用専業メーカー（いすゞ・日野・UD・三菱ふそう）が1社も無い
/// - `BodyType.truck` / `BodyType.van` の車種が**1件も無い**（定義はあるのに）
/// - 光岡が無い
///
/// という状態だった。自分の車が一覧に無い人は、そこで登録をやめる。
/// テストデータの質以前に、**アプリが使えない人が出る**。
///
/// ここは「何件あるか」を数える検査。中身の正しさ（年式など）までは見ない。
void main() {
  List<VehicleModel> allModels() {
    return VehicleMasterData.models.keys
        .expand(VehicleMasterData.getModelsForMaker)
        .toList();
  }

  group('VehicleMasterData — メーカー', () {
    test('商用車の専業メーカーが入っている', () {
      final names = VehicleMasterData.makers.map((m) => m['id']).toSet();

      expect(names, contains('isuzu'));
      expect(names, contains('hino'));
      expect(names, contains('ud'));
      expect(names, contains('fuso'));
    });

    test('光岡が入っている', () {
      final ids = VehicleMasterData.makers.map((m) => m['id']).toSet();
      expect(ids, contains('mitsuoka'));
    });

    test('既存のメーカーが消えていない', () {
      final ids = VehicleMasterData.makers.map((m) => m['id']).toSet();

      for (final id in [
        'toyota',
        'honda',
        'nissan',
        'mazda',
        'subaru',
        'suzuki',
        'daihatsu',
        'mitsubishi',
        'lexus',
      ]) {
        expect(ids, contains(id), reason: '$id が消えている');
      }
    });

    test('メーカーIDが重複しない', () {
      final ids = VehicleMasterData.makers.map((m) => m['id']).toList();
      expect(ids.length, ids.toSet().length);
    });

    test('表示順が重複しない', () {
      final orders =
          VehicleMasterData.makers.map((m) => m['displayOrder']).toList();
      expect(orders.length, orders.toSet().length);
    });
  });

  group('VehicleMasterData — 車種', () {
    test('全体で400車種以上ある', () {
      expect(allModels().length, greaterThanOrEqualTo(400));
    });

    test('主要メーカーは1社あたり30車種以上ある', () {
      for (final makerId in ['toyota', 'honda', 'nissan']) {
        expect(
          VehicleMasterData.getModelsForMaker(makerId).length,
          greaterThanOrEqualTo(30),
          reason: '$makerId の車種が少ない',
        );
      }
    });

    test('トラックが登録されている', () {
      final trucks =
          allModels().where((m) => m.bodyType == BodyType.truck).toList();
      expect(trucks.length, greaterThanOrEqualTo(15));
    });

    test('バン（貨物）が登録されている', () {
      final vans =
          allModels().where((m) => m.bodyType == BodyType.van).toList();
      expect(vans.length, greaterThanOrEqualTo(15));
    });

    test('既存の車種が消えていない', () {
      final names = allModels().map((m) => m.name).toSet();

      // シードデータやテストが名前で参照しているもの。
      for (final name in [
        'プリウス',
        'RAV4',
        'カローラ',
        'アルファード',
        'N-BOX',
        'フィット',
        'セレナ',
        'リーフ',
        'ヴォクシー',
      ]) {
        expect(names, contains(name), reason: '$name が消えている');
      }
    });

    group('Edge Cases', () {
      test('車種IDが全体で重複しない', () {
        final ids = allModels().map((m) => m.id).toList();
        final dupes = <String>{};
        final seen = <String>{};
        for (final id in ids) {
          if (!seen.add(id)) dupes.add(id);
        }
        expect(dupes, isEmpty, reason: '重複: $dupes');
      });

      test('bodyType が未設定の車種が無い', () {
        final missing =
            allModels().where((m) => m.bodyType == null).map((m) => m.name);
        expect(missing, isEmpty, reason: 'bodyType 未設定: ${missing.toList()}');
      });

      test('車種名が空でない', () {
        expect(allModels().where((m) => m.name.trim().isEmpty), isEmpty);
      });

      test('生産開始年が妥当な範囲にある', () {
        for (final m in allModels()) {
          final start = m.productionStartYear;
          if (start == null) continue;
          expect(start, greaterThanOrEqualTo(1930), reason: m.name);
          expect(start, lessThanOrEqualTo(2030), reason: m.name);
        }
      });

      test('生産終了年は開始年以降', () {
        for (final m in allModels()) {
          final start = m.productionStartYear;
          final end = m.productionEndYear;
          if (start == null || end == null) continue;
          expect(end, greaterThanOrEqualTo(start), reason: m.name);
        }
      });

      test('models に登録されている makerId は makers に存在する', () {
        final makerIds = VehicleMasterData.makers.map((m) => m['id']).toSet();
        for (final key in VehicleMasterData.models.keys) {
          expect(makerIds, contains(key), reason: '$key が makers に無い');
        }
      });
    });
  });
}
