import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/services/vehicle_master_service.dart';

void main() {
  group('VehicleMasterService.recordCustomEntrySuggestion', () {
    late FakeFirebaseFirestore firestore;
    late VehicleMasterService service;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      service = VehicleMasterService(firestore: firestore);
    });

    test('メーカー候補を pending 状態で保存する', () async {
      final result = await service.recordCustomEntrySuggestion(
        userId: 'u1',
        type: 'maker',
        value: 'ニューカー',
      );

      expect(result.isFailure, isFalse);
      final snap =
          await firestore.collection('vehicle_master_suggestions').get();
      expect(snap.docs.length, 1);
      final data = snap.docs.first.data();
      expect(data['userId'], 'u1');
      expect(data['type'], 'maker');
      expect(data['value'], 'ニューカー');
      expect(data['status'], 'pending');
    });

    test('車種候補は makerName を含む', () async {
      await service.recordCustomEntrySuggestion(
        userId: 'u1',
        type: 'model',
        value: '新型モデル',
        makerName: 'トヨタ',
      );

      final snap =
          await firestore.collection('vehicle_master_suggestions').get();
      expect(snap.docs.first.data()['makerName'], 'トヨタ');
    });
  });
}
