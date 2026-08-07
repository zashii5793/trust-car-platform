// VehicleEquipment Model Tests
//
// オプション・装備（ナビ / ドライブレコーダー / ETC など）のモデル。
//
// 方針: カタログに無いメーカー・型番を必ず手入力できること。
// メーカー・車種・グレードと同じで、一覧は入力補助にすぎない。
//
// Coverage:
//   - EquipmentItem の construction / fromMap / toMap / hasAnyValue
//   - VehicleEquipment の fromMap / toMap / hasAnyValue / summaryLabels
//   - Vehicle への統合（fromFirestore / toMap / copyWith）
//   - Edge cases（null, 空文字, 未知キー, 空白のみ, 極端に長い文字列）

import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/models/vehicle.dart';
import 'package:trust_car_platform/models/vehicle_equipment.dart';

void main() {
  group('EquipmentItem', () {
    test('defaults to not installed with no maker or model number', () {
      const item = EquipmentItem();
      expect(item.installed, isFalse);
      expect(item.maker, isNull);
      expect(item.modelNumber, isNull);
      expect(item.hasAnyValue, isFalse);
    });

    test('round-trips through toMap / fromMap', () {
      const item = EquipmentItem(
        installed: true,
        maker: 'カロッツェリア',
        modelNumber: 'AVIC-RQ720',
      );
      final restored = EquipmentItem.fromMap(item.toMap());
      expect(restored.installed, isTrue);
      expect(restored.maker, 'カロッツェリア');
      expect(restored.modelNumber, 'AVIC-RQ720');
    });

    test('accepts a maker that is not in the catalog', () {
      // カタログ非掲載メーカーを登録できないと詰むため、ここは仕様の中心。
      const item = EquipmentItem(installed: true, maker: '町工場オリジナル');
      expect(item.maker, '町工場オリジナル');
      expect(EquipmentItem.fromMap(item.toMap()).maker, '町工場オリジナル');
    });

    test('hasAnyValue is true when only installed is set', () {
      const item = EquipmentItem(installed: true);
      expect(item.hasAnyValue, isTrue);
    });

    test('displayLabel combines maker and model number', () {
      const item = EquipmentItem(
        installed: true,
        maker: 'コムテック',
        modelNumber: 'ZDR035',
      );
      expect(item.displayLabel, 'コムテック ZDR035');
    });

    test('displayLabel falls back to 装備あり when nothing else is known', () {
      const item = EquipmentItem(installed: true);
      expect(item.displayLabel, '装備あり');
    });

    group('Edge Cases', () {
      test('fromMap(null) returns an empty item', () {
        final item = EquipmentItem.fromMap(null);
        expect(item.hasAnyValue, isFalse);
      });

      test('empty strings are normalized to null', () {
        const item = EquipmentItem(installed: true, maker: '', modelNumber: '');
        expect(item.maker, isNull);
        expect(item.modelNumber, isNull);
      });

      test('whitespace-only strings are normalized to null', () {
        const item = EquipmentItem(installed: true, maker: '   ');
        expect(item.maker, isNull);
      });

      test('surrounding whitespace is trimmed', () {
        const item = EquipmentItem(maker: '  ケンウッド  ');
        expect(item.maker, 'ケンウッド');
      });

      test('non-string values in the map do not throw', () {
        final item = EquipmentItem.fromMap({
          'installed': 'yes',
          'maker': 123,
          'modelNumber': ['a'],
        });
        expect(item.installed, isFalse);
        expect(item.maker, isNull);
        expect(item.modelNumber, isNull);
      });

      test('a very long model number is kept as-is', () {
        final long = 'A' * 500;
        final item = EquipmentItem(installed: true, modelNumber: long);
        expect(item.modelNumber, long);
      });
    });
  });

  group('VehicleEquipment', () {
    test('is empty by default', () {
      const eq = VehicleEquipment();
      expect(eq.hasAnyValue, isFalse);
      expect(eq.summaryLabels, isEmpty);
    });

    test('round-trips through toMap / fromMap', () {
      const eq = VehicleEquipment(
        navigation: EquipmentItem(installed: true, maker: 'パナソニック'),
        driveRecorder: EquipmentItem(installed: true, maker: 'ユピテル'),
        etc: EquipmentItem(installed: true),
        features: {VehicleFeature.backCamera, VehicleFeature.sunroof},
        others: ['社外マフラー'],
      );
      final restored = VehicleEquipment.fromMap(eq.toMap());
      expect(restored.navigation.maker, 'パナソニック');
      expect(restored.driveRecorder.maker, 'ユピテル');
      expect(restored.etc.installed, isTrue);
      expect(restored.features,
          containsAll([VehicleFeature.backCamera, VehicleFeature.sunroof]));
      expect(restored.others, ['社外マフラー']);
    });

    test('summaryLabels lists what is actually installed', () {
      const eq = VehicleEquipment(
        navigation: EquipmentItem(installed: true, maker: 'カロッツェリア'),
        features: {VehicleFeature.backCamera},
      );
      expect(eq.summaryLabels, contains('カーナビ: カロッツェリア'));
      expect(eq.summaryLabels, contains(VehicleFeature.backCamera.label));
    });

    test('hasAnyValue is true when only a feature flag is set', () {
      const eq = VehicleEquipment(features: {VehicleFeature.etcCard});
      expect(eq.hasAnyValue, isTrue);
    });

    group('Edge Cases', () {
      test('fromMap(null) returns an empty equipment set', () {
        final eq = VehicleEquipment.fromMap(null);
        expect(eq.hasAnyValue, isFalse);
      });

      test('unknown feature names in stored data are ignored', () {
        // 旧バージョンのアプリが書いた未知の値でクラッシュしないこと。
        final eq = VehicleEquipment.fromMap({
          'features': ['backCamera', 'thisDoesNotExist'],
        });
        expect(eq.features, {VehicleFeature.backCamera});
      });

      test('a non-list features value does not throw', () {
        final eq = VehicleEquipment.fromMap({'features': 'backCamera'});
        expect(eq.features, isEmpty);
      });

      test('blank entries in others are dropped', () {
        final eq = VehicleEquipment.fromMap({
          'others': ['', '  ', '社外アルミ'],
        });
        expect(eq.others, ['社外アルミ']);
      });

      test('non-string entries in others are dropped', () {
        final eq = VehicleEquipment.fromMap({
          'others': [1, null, '牽引フック'],
        });
        expect(eq.others, ['牽引フック']);
      });
    });
  });

  group('VehicleFeature', () {
    test('every feature has a non-empty Japanese label', () {
      for (final f in VehicleFeature.values) {
        expect(f.label.trim(), isNotEmpty, reason: '${f.name} has no label');
      }
    });

    test('fromString resolves a known name', () {
      expect(
          VehicleFeature.fromString('backCamera'), VehicleFeature.backCamera);
    });

    test('fromString returns null for unknown or null input', () {
      expect(VehicleFeature.fromString('nope'), isNull);
      expect(VehicleFeature.fromString(null), isNull);
    });
  });

  group('Vehicle integration', () {
    Vehicle make({VehicleEquipment? equipment}) => Vehicle(
          id: 'v1',
          userId: 'u1',
          maker: 'Toyota',
          model: 'Prius',
          year: 2020,
          grade: 'S',
          mileage: 1000,
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
          equipment: equipment,
        );

    test('equipment defaults to null and is omitted from the map', () {
      expect(make().equipment, isNull);
      expect(make().toMap()['equipment'], isNull);
    });

    test('equipment is serialized into toMap', () {
      final v = make(
        equipment: const VehicleEquipment(
          navigation: EquipmentItem(installed: true, maker: 'アルパイン'),
        ),
      );
      final map = v.toMap()['equipment'] as Map<String, dynamic>;
      expect((map['navigation'] as Map)['maker'], 'アルパイン');
    });

    test('copyWith replaces equipment', () {
      final v = make().copyWith(
        equipment: const VehicleEquipment(etc: EquipmentItem(installed: true)),
      );
      expect(v.equipment?.etc.installed, isTrue);
    });

    group('Edge Cases', () {
      test('an empty equipment set is not persisted', () {
        // 空の装備を書き戻して既存データを潰さないこと。
        final v = make(equipment: const VehicleEquipment());
        expect(v.toMap()['equipment'], isNull);
      });
    });
  });
}
