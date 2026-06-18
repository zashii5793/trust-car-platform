import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/data/vehicle_master_data.dart';

/// 車種マスタの網羅度を固定するテスト（#20 拡充の回帰防止）。
void main() {
  group('VehicleMasterData 拡充', () {
    test('国産＋主要輸入メーカーを網羅する', () {
      final makerNames =
          VehicleMasterData.getMakers().map((m) => m.name).toList();
      // 国産主要
      for (final name in ['トヨタ', 'ホンダ', '日産', 'スズキ', 'ダイハツ', 'レクサス']) {
        expect(makerNames, contains(name));
      }
      // 主要輸入
      for (final name in ['メルセデス・ベンツ', 'BMW', 'フォルクスワーゲン', 'テスラ']) {
        expect(makerNames, contains(name));
      }
      // 「その他」は末尾
      expect(makerNames.last, 'その他');
    });

    test('トヨタの人気モデルが拡充されている', () {
      final names = VehicleMasterData.getModelsForMaker('toyota')
          .map((m) => m.name)
          .toList();
      for (final n in ['プリウス', 'ノア', 'ライズ', 'ハイエース']) {
        expect(names, contains(n));
      }
      expect(names.last, 'その他'); // その他は末尾
    });

    test('輸入メーカーにもモデルと「その他」がある', () {
      final bmw = VehicleMasterData.getModelsForMaker('bmw')
          .map((m) => m.name)
          .toList();
      expect(bmw, contains('3シリーズ'));
      expect(bmw, contains('X3'));
      expect(bmw.last, 'その他');
    });

    test('各メーカーのモデル末尾は必ず「その他」', () {
      for (final maker in VehicleMasterData.getMakers()) {
        if (maker.id == 'other') continue;
        final models = VehicleMasterData.getModelsForMaker(maker.id);
        expect(models, isNotEmpty, reason: '${maker.name} のモデルが空');
        expect(models.last.name, 'その他', reason: '${maker.name} の末尾が「その他」でない');
      }
    });
  });
}
