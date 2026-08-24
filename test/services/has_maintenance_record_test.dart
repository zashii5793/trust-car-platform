// 「整備記録を1件でも付けたか」の判定。
//
// はじめの3ステップの最後の項目に使う。件数も中身も要らないので、
// 1件あるかどうかだけを最小のクエリで確かめる。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/services/firebase_service.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late FirebaseService service;

  FirebaseService buildService({String? uid = 'user1'}) {
    return FirebaseService(
      firestore: firestore,
      auth: MockFirebaseAuth(
        signedIn: uid != null,
        mockUser: uid == null ? null : MockUser(uid: uid),
      ),
    );
  }

  Future<void> addRecord({String userId = 'user1'}) async {
    await firestore.collection('maintenance_records').add({
      'userId': userId,
      'vehicleId': 'veh1',
      'type': 'oilChange',
      'title': 'オイル交換',
      'cost': 5000,
      'date': Timestamp.fromDate(DateTime(2026, 8, 1)),
      'createdAt': Timestamp.fromDate(DateTime(2026, 8, 1)),
      'updatedAt': Timestamp.fromDate(DateTime(2026, 8, 1)),
    });
  }

  setUp(() {
    firestore = FakeFirebaseFirestore();
    service = buildService();
  });

  group('FirebaseService.hasAnyMaintenanceRecord', () {
    test('1件もなければ false', () async {
      final result = await service.hasAnyMaintenanceRecord();

      expect(result.valueOrNull, isFalse);
    });

    test('自分の記録が1件あれば true', () async {
      await addRecord();

      final result = await service.hasAnyMaintenanceRecord();

      expect(result.valueOrNull, isTrue);
    });

    test('複数あっても true', () async {
      await addRecord();
      await addRecord();

      expect((await service.hasAnyMaintenanceRecord()).valueOrNull, isTrue);
    });
  });

  group('FirebaseService.hasAnyMaintenanceRecord — Edge Cases', () {
    test('他人の記録は数えない', () async {
      await addRecord(userId: 'someone-else');

      expect((await service.hasAnyMaintenanceRecord()).valueOrNull, isFalse);
    });

    test('未ログインなら false を返す（失敗にはしない）', () async {
      service = buildService(uid: null);
      await addRecord();

      final result = await service.hasAnyMaintenanceRecord();

      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull, isFalse);
    });
  });
}
