// 整備記録の費用を「未入力」で持てるようにする。
//
// なぜ要るか（使用感テスト 2026-10-09）:
//   金額を覚えていない人がいる。費用が必須だったので 0円を入れて保存し、
//   記録に「¥0」と残った。未入力は 0円ではなく「未入力」として保存・表示する。
//   既存データの 0 は 0円のまま、null は未入力として読む。
//   合計は未入力を足さない（0 として扱う）。平均には入れない。

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/models/maintenance_record.dart';
import 'package:trust_car_platform/services/maintenance_trend_service.dart';

MaintenanceRecord _record({int cost = 5000, bool hasCost = true}) =>
    MaintenanceRecord(
      id: 'r1',
      vehicleId: 'v1',
      userId: 'u1',
      type: MaintenanceType.oilChange,
      title: 'オイル交換',
      cost: cost,
      hasCost: hasCost,
      date: DateTime(2026, 4, 10),
      createdAt: DateTime(2026, 4, 10),
    );

void main() {
  group('費用の未入力', () {
    late FakeFirebaseFirestore firestore;

    setUp(() => firestore = FakeFirebaseFirestore());

    Future<MaintenanceRecord> read(Map<String, dynamic> data) async {
      await firestore.collection('maintenance_records').doc('r1').set({
        'vehicleId': 'v1',
        'userId': 'u1',
        'type': 'oilChange',
        'title': 'オイル交換',
        ...data,
      });
      final doc =
          await firestore.collection('maintenance_records').doc('r1').get();
      return MaintenanceRecord.fromFirestore(doc);
    }

    test('未入力は null で保存する（0円にしない）', () {
      final map = _record(cost: 0, hasCost: false).toMap();
      expect(map.containsKey('cost'), isTrue);
      expect(map['cost'], isNull);
    });

    test('入力した金額はそのまま保存する', () {
      expect(_record(cost: 15000).toMap()['cost'], 15000);
    });

    test('null の記録は未入力として読む', () async {
      final r = await read({'cost': null});
      expect(r.hasCost, isFalse);
      expect(r.cost, 0);
      expect(r.costLabel, '未入力');
    });

    test('金額のある記録は円で出す', () {
      expect(_record(cost: 15000).costLabel, '¥15,000');
    });

    test('copyWith は未入力を保つ', () {
      final r = _record(cost: 0, hasCost: false).copyWith(title: '交換');
      expect(r.hasCost, isFalse);
    });

    test('copyWith で金額を入れ直せる', () {
      final r =
          _record(cost: 0, hasCost: false).copyWith(cost: 3000, hasCost: true);
      expect(r.hasCost, isTrue);
      expect(r.cost, 3000);
    });

    test('平均費用には未入力を入れない', () {
      final records = [
        _record(cost: 6000).copyWith(id: 'a', date: DateTime(2025, 4, 1)),
        _record(cost: 0, hasCost: false)
            .copyWith(id: 'b', date: DateTime(2025, 10, 1)),
        _record(cost: 4000).copyWith(id: 'c', date: DateTime(2026, 4, 1)),
      ];
      final insight =
          const MaintenanceTrendService().analyzeHistory(records).single;
      expect(insight.averageCost, 5000);
    });

    group('Edge Cases', () {
      test('既存データの 0 は 0円のまま', () async {
        final r = await read({'cost': 0});
        expect(r.hasCost, isTrue);
        expect(r.costLabel, '¥0');
      });

      test('cost の欄そのものが無い古い記録も未入力として読む', () async {
        final r = await read({});
        expect(r.hasCost, isFalse);
      });

      test('withEdits で金額を空にすると未入力になる', () {
        final edited = _record(cost: 5000).withEdits(
          type: MaintenanceType.oilChange,
          title: 'オイル交換',
          description: null,
          cost: null,
          shopName: null,
          date: DateTime(2026, 4, 10),
          mileageAtService: null,
          partNumber: null,
          partManufacturer: null,
          tireSize: null,
          tirePosition: null,
        );
        expect(edited.hasCost, isFalse);
        expect(edited.toMap()['cost'], isNull);
      });

      test('全部未入力なら平均費用は出さない', () {
        final records = [
          _record(cost: 0, hasCost: false)
              .copyWith(id: 'a', date: DateTime(2025, 4, 1)),
          _record(cost: 0, hasCost: false)
              .copyWith(id: 'b', date: DateTime(2026, 4, 1)),
        ];
        final insight =
            const MaintenanceTrendService().analyzeHistory(records).single;
        expect(insight.averageCost, isNull);
      });
    });
  });
}
