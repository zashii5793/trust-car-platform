// FirebaseService.maintenanceSummary のテスト
//
// なぜ要るか:
//   ホームの「メンテナンスの記録」は直近3件の合計しか出しておらず、
//   「この1年でいくら使ったか」が分からない。**積み上がった額が維持費の
//   実感**なので、件数と合計を集計クエリで取る（全件を読まない）。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/services/firebase_service.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late FirebaseService service;

  Future<void> addRecord({
    required String id,
    required String userId,
    required DateTime date,
    required int cost,
  }) async {
    await firestore.collection('maintenance_records').doc(id).set({
      'vehicleId': 'v1',
      'userId': userId,
      'type': 'oilChange',
      'title': 'エンジンオイル交換',
      'date': Timestamp.fromDate(date),
      'cost': cost,
      'createdAt': Timestamp.fromDate(date),
    });
  }

  setUp(() {
    firestore = FakeFirebaseFirestore();
    service = FirebaseService(
      firestore: firestore,
      auth: MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'u1', email: 'u1@example.com'),
      ),
    );
  });

  group('maintenanceSummary', () {
    test('件数と合計金額を返す', () async {
      final now = DateTime.now();
      await addRecord(id: 'm1', userId: 'u1', date: now, cost: 5000);
      await addRecord(
          id: 'm2',
          userId: 'u1',
          date: now.subtract(const Duration(days: 30)),
          cost: 138000);

      final summary = (await service.maintenanceSummary()).valueOrNull!;

      expect(summary.count, 2);
      expect(summary.totalCost, 143000);
    });

    test('他人の記録は数えない', () async {
      final now = DateTime.now();
      await addRecord(id: 'mine', userId: 'u1', date: now, cost: 5000);
      await addRecord(id: 'theirs', userId: 'u2', date: now, cost: 999999);

      final summary = (await service.maintenanceSummary()).valueOrNull!;

      expect(summary.count, 1);
      expect(summary.totalCost, 5000);
    });

    test('since を渡すと、その日以降だけを数える', () async {
      final now = DateTime.now();
      await addRecord(id: 'recent', userId: 'u1', date: now, cost: 5000);
      await addRecord(
          id: 'old',
          userId: 'u1',
          date: now.subtract(const Duration(days: 400)),
          cost: 200000);

      final summary = (await service.maintenanceSummary(
        since: now.subtract(const Duration(days: 365)),
      ))
          .valueOrNull!;

      expect(summary.count, 1);
      expect(summary.totalCost, 5000);
    });

    group('Edge Cases', () {
      test('1件も無ければ 0件・0円', () async {
        final summary = (await service.maintenanceSummary()).valueOrNull!;

        expect(summary.count, 0);
        expect(summary.totalCost, 0);
        expect(summary.isEmpty, isTrue);
      });
    });
  });
}
