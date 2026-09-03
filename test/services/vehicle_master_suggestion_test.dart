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

    Future<int> suggestionCount() async {
      final snap =
          await firestore.collection('vehicle_master_suggestions').get();
      return snap.docs.length;
    }

    test('カタログ外メーカーを pending 候補として記録する', () async {
      final result = await service.recordCustomEntrySuggestion(
        userId: 'u1',
        type: 'maker',
        value: 'ニューブランド',
      );

      expect(result.isFailure, isFalse);
      final snap =
          await firestore.collection('vehicle_master_suggestions').get();
      expect(snap.docs.length, 1);
      final data = snap.docs.first.data();
      expect(data['userId'], 'u1');
      expect(data['type'], 'maker');
      expect(data['value'], 'ニューブランド');
      expect(data['status'], 'pending');
    });

    test('カタログ外車種は makerName を含めて記録する', () async {
      // makerName 自体がカタログ外なので、車種もカタログには存在し得ない。
      await service.recordCustomEntrySuggestion(
        userId: 'u1',
        type: 'model',
        value: 'ニューモデル',
        makerName: 'ニューブランド',
      );

      final snap =
          await firestore.collection('vehicle_master_suggestions').get();
      expect(snap.docs.first.data()['makerName'], 'ニューブランド');
    });

    group('Edge Cases', () {
      test('空文字・空白のみは記録しない', () async {
        final result = await service.recordCustomEntrySuggestion(
          userId: 'u1',
          type: 'maker',
          value: '   ',
        );

        expect(result.isFailure, isTrue);
        expect(await suggestionCount(), 0);
      });

      test('同じ値の重複入力は1件に集約される', () async {
        await service.recordCustomEntrySuggestion(
          userId: 'u1',
          type: 'maker',
          value: 'ニューブランド',
        );
        await service.recordCustomEntrySuggestion(
          userId: 'u2',
          type: 'maker',
          value: 'ニューブランド',
        );

        expect(await suggestionCount(), 1);
      });

      test('カタログに存在するメーカーは候補にしない', () async {
        // 'トヨタ' は静的カタログに存在するため記録しない（成功のno-op）。
        final result = await service.recordCustomEntrySuggestion(
          userId: 'u1',
          type: 'maker',
          value: 'トヨタ',
        );

        expect(result.isFailure, isFalse);
        expect(await suggestionCount(), 0);
      });
    });
  });
}
