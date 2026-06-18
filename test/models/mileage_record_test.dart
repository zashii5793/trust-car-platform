import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/models/mileage_record.dart';

void main() {
  group('MileageRecord', () {
    test('toMap は必要フィールドを出力し、note 省略時はキーを含めない', () {
      final r = MileageRecord(
        id: '',
        userId: 'u1',
        mileage: 52000,
        recordedAt: DateTime(2026, 6, 18),
      );
      final m = r.toMap();
      expect(m['userId'], 'u1');
      expect(m['mileage'], 52000);
      expect(m['recordedAt'], isA<Timestamp>());
      expect(m.containsKey('note'), isFalse);
    });

    test('fromFirestore で round-trip する', () async {
      final fs = FakeFirebaseFirestore();
      final ref = await fs
          .collection('vehicles')
          .doc('v1')
          .collection('mileage_history')
          .add({
        'userId': 'u1',
        'mileage': 52000,
        'recordedAt': Timestamp.fromDate(DateTime(2026, 6, 18)),
        'note': '給油時',
      });
      final doc = await ref.get();
      final r = MileageRecord.fromFirestore(doc);
      expect(r.mileage, 52000);
      expect(r.userId, 'u1');
      expect(r.note, '給油時');
      expect(r.recordedAt, DateTime(2026, 6, 18));
    });

    group('Edge Cases', () {
      test('欠損フィールドは安全なデフォルトにフォールバック', () async {
        final fs = FakeFirebaseFirestore();
        final ref = await fs.collection('x').add(<String, dynamic>{});
        final doc = await ref.get();
        final r = MileageRecord.fromFirestore(doc);
        expect(r.mileage, 0);
        expect(r.userId, '');
        expect(r.note, isNull);
      });
    });
  });
}
