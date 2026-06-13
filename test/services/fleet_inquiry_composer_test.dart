// FleetInquiryComposer Tests
//
// 総務担当が複数台の車検をまとめて整備工場へ問い合わせる際の
// 文面自動生成ロジックのテスト。

import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/models/vehicle.dart';
import 'package:trust_car_platform/services/fleet_inquiry_composer.dart';

Vehicle _make({
  String id = 'v1',
  String maker = 'Toyota',
  String model = 'Hiace',
  String? licensePlate,
  DateTime? inspectionExpiryDate,
  VehicleUseCategory? useCategory,
}) {
  return Vehicle(
    id: id,
    userId: 'u1',
    maker: maker,
    model: model,
    year: 2022,
    grade: 'DX',
    mileage: 50000,
    createdAt: DateTime(2024, 1, 1),
    updatedAt: DateTime(2024, 1, 1),
    licensePlate: licensePlate,
    inspectionExpiryDate: inspectionExpiryDate,
    useCategory: useCategory,
  );
}

void main() {
  group('FleetInquiryComposer.vehiclesNeedingInspection', () {
    test('車検60日以内の車両のみ抽出される', () {
      final vehicles = [
        _make(
            id: 'soon',
            inspectionExpiryDate: DateTime.now().add(const Duration(days: 30))),
        _make(
            id: 'far',
            inspectionExpiryDate:
                DateTime.now().add(const Duration(days: 300))),
      ];
      final result = FleetInquiryComposer.vehiclesNeedingInspection(vehicles);
      expect(result.map((v) => v.id), ['soon']);
    });

    test('期限切れの車両も含まれる', () {
      final vehicles = [
        _make(
            id: 'expired',
            inspectionExpiryDate:
                DateTime.now().subtract(const Duration(days: 10))),
      ];
      final result = FleetInquiryComposer.vehiclesNeedingInspection(vehicles);
      expect(result, hasLength(1));
    });

    test('車検日が近い順にソートされる', () {
      final vehicles = [
        _make(
            id: 'b',
            inspectionExpiryDate: DateTime.now().add(const Duration(days: 50))),
        _make(
            id: 'a',
            inspectionExpiryDate: DateTime.now().add(const Duration(days: 5))),
      ];
      final result = FleetInquiryComposer.vehiclesNeedingInspection(vehicles);
      expect(result.map((v) => v.id), ['a', 'b']);
    });

    group('Edge Cases', () {
      test('空リストなら空を返す', () {
        expect(FleetInquiryComposer.vehiclesNeedingInspection([]), isEmpty);
      });

      test('車検日未設定（null）の車両は除外される', () {
        final vehicles = [_make(inspectionExpiryDate: null)];
        expect(FleetInquiryComposer.vehiclesNeedingInspection(vehicles),
            isEmpty);
      });
    });
  });

  group('FleetInquiryComposer.compose', () {
    test('件名に台数が含まれる', () {
      final vehicles = [
        _make(
            id: 'v1',
            inspectionExpiryDate: DateTime.now().add(const Duration(days: 10))),
        _make(
            id: 'v2',
            inspectionExpiryDate: DateTime.now().add(const Duration(days: 20))),
      ];
      final draft = FleetInquiryComposer.compose(vehicles);
      expect(draft.subject, contains('2台'));
      expect(draft.subject, contains('車検'));
    });

    test('本文に車両ごとの情報（車種・ナンバー・満了日）が含まれる', () {
      final draft = FleetInquiryComposer.compose([
        _make(
          maker: 'Toyota',
          model: 'Hiace',
          licensePlate: '品川 400 あ 12-34',
          inspectionExpiryDate: DateTime(2026, 8, 1),
        ),
      ]);
      expect(draft.message, contains('Toyota Hiace'));
      expect(draft.message, contains('品川 400 あ 12-34'));
      expect(draft.message, contains('2026'));
      expect(draft.message, contains('8'));
    });

    test('ナンバー未登録の車両は「ナンバー未登録」と表示される', () {
      final draft = FleetInquiryComposer.compose([
        _make(
            licensePlate: null,
            inspectionExpiryDate: DateTime(2026, 8, 1)),
      ]);
      expect(draft.message, contains('ナンバー未登録'));
    });

    test('貨物車（毎年車検）は区分が明記される', () {
      final draft = FleetInquiryComposer.compose([
        _make(
          useCategory: VehicleUseCategory.cargo,
          inspectionExpiryDate: DateTime(2026, 8, 1),
        ),
      ]);
      expect(draft.message, contains('貨物'));
    });

    group('Edge Cases', () {
      test('空リストでもクラッシュせず件名は0台', () {
        final draft = FleetInquiryComposer.compose([]);
        expect(draft.subject, contains('0台'));
      });

      test('車検日nullの車両は「未設定」と表示される', () {
        final draft = FleetInquiryComposer.compose([
          _make(inspectionExpiryDate: null),
        ]);
        expect(draft.message, contains('未設定'));
      });

      test('20台でも全車両が本文に含まれる', () {
        final vehicles = List.generate(
          20,
          (i) => _make(
            id: 'v$i',
            licensePlate: 'プレート$i',
            inspectionExpiryDate: DateTime(2026, 8, 1),
          ),
        );
        final draft = FleetInquiryComposer.compose(vehicles);
        for (var i = 0; i < 20; i++) {
          expect(draft.message, contains('プレート$i'));
        }
      });
    });
  });
}
