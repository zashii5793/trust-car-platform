// 認証状態に追従するStreamのテスト
//
// 背景: 画面の initState から購読を開始する時点では、Web では
// FirebaseAuth の状態復元がまだ終わっておらず currentUser が null になる。
// 「未ログインなら空Streamを1回流して完結」する実装だと、その後ログインが
// 完了しても購読対象が切り替わらず、データがあるのに空表示のままになる。
//
// ここでは「購読開始時は未ログイン → 後からログイン」という順序で、
// ログイン後にデータが流れてくることを検証する。

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/core/utils/auth_scoped_stream.dart';
import 'package:trust_car_platform/models/vehicle.dart';
import 'package:trust_car_platform/services/firebase_service.dart';
import 'package:trust_car_platform/services/document_service.dart';
import 'package:trust_car_platform/services/invoice_service.dart';

const _uid = 'user-a';

Future<void> _seedVehicle(FakeFirebaseFirestore firestore) async {
  await firestore.collection('vehicles').doc('veh-a-sports').set({
    'userId': _uid,
    'maker': 'Mazda',
    'model': 'Roadster',
    'year': 2019,
    'grade': 'S',
    'mileage': 22000,
    'licensePlate': '品川 330 す 44-44',
    'createdAt': Timestamp.fromDate(DateTime(2026, 8, 16)),
    'updatedAt': Timestamp.fromDate(DateTime(2026, 8, 16)),
  });
}

Future<void> _seedDocument(FakeFirebaseFirestore firestore) async {
  await firestore.collection('documents').doc('doc-a').set({
    'userId': _uid,
    'vehicleId': 'veh-a-sports',
    'type': 'other',
    'mimeType': 'application/pdf',
    'fileName': 'test.pdf',
    'fileUrl': 'https://example.com/test.pdf',
    'isArchived': false,
    'uploadedAt': Timestamp.fromDate(DateTime(2026, 8, 16)),
    'createdAt': Timestamp.fromDate(DateTime(2026, 8, 16)),
    'updatedAt': Timestamp.fromDate(DateTime(2026, 8, 16)),
  });
}

Future<void> _seedInvoice(FakeFirebaseFirestore firestore) async {
  await firestore.collection('invoices').doc('inv-a').set({
    'userId': _uid,
    'vehicleId': 'veh-a-sports',
    'totalAmount': 12000,
    'issueDate': Timestamp.fromDate(DateTime(2026, 8, 16)),
    'createdAt': Timestamp.fromDate(DateTime(2026, 8, 16)),
    'updatedAt': Timestamp.fromDate(DateTime(2026, 8, 16)),
  });
}

void main() {
  group('未ログイン中に購読を開始してもログイン後にデータが流れる', () {
    test('FirebaseService.getUserVehicles', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedVehicle(firestore);

      // 購読開始時点では未ログイン（Web の初期化直後を再現）
      final auth =
          MockFirebaseAuth(signedIn: false, mockUser: MockUser(uid: _uid));
      final service = FirebaseService(firestore: firestore, auth: auth);

      final emissions = <List<Vehicle>>[];
      final sub = service.getUserVehicles().listen(emissions.add);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(emissions.last, isEmpty, reason: '未ログイン中は空であるべき');

      // ここでログインが完了する
      await auth.signInWithCustomToken('token');
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(
        emissions.last.map((v) => v.model).toList(),
        ['Roadster'],
        reason: 'ログイン完了後は購読対象が切り替わり車両が流れてくるべき',
      );

      await sub.cancel();
    });

    test('DocumentService.getUserDocuments', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedDocument(firestore);

      final auth =
          MockFirebaseAuth(signedIn: false, mockUser: MockUser(uid: _uid));
      final service = DocumentService(firestore: firestore, auth: auth);

      final emissions = <List<dynamic>>[];
      final sub = service.getUserDocuments().listen(emissions.add);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(emissions.last, isEmpty);

      await auth.signInWithCustomToken('token');
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(emissions.last, hasLength(1),
          reason: 'ログイン完了後は書類が流れてくるべき');

      await sub.cancel();
    });

    test('InvoiceService.getUserInvoices', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedInvoice(firestore);

      final auth =
          MockFirebaseAuth(signedIn: false, mockUser: MockUser(uid: _uid));
      final service = InvoiceService(firestore: firestore, auth: auth);

      final emissions = <List<dynamic>>[];
      final sub = service.getUserInvoices().listen(emissions.add);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(emissions.last, isEmpty);

      await auth.signInWithCustomToken('token');
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(emissions.last, hasLength(1),
          reason: 'ログイン完了後は請求書が流れてくるべき');

      await sub.cancel();
    });
  });

  group('authStateChanges が過去のログインを再送しない場合', () {
    // Web の FlutterFire では、ログイン完了後に購読を始めた subscriber へ
    // 直前の認証イベントが流れてこないことがある。画面は initState から
    // 購読するため、この順序（ログイン完了 → 購読開始）が実機で起きる。
    // イベントを一切流さない authChanges で、その状況を再現する。
    test('購読開始時点のログイン状態からデータが流れる', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedVehicle(firestore);

      final user = MockUser(uid: _uid);
      final silentAuthChanges = StreamController<User?>();
      addTearDown(silentAuthChanges.close);

      final vehicles = <List<Vehicle>>[];
      final sub = authScopedStream<List<Vehicle>>(
        authChanges: silentAuthChanges.stream,
        currentUser: () => user,
        signedOutValue: const <Vehicle>[],
        onSignedIn: (u) => firestore
            .collection('vehicles')
            .where('userId', isEqualTo: u.uid)
            .orderBy('createdAt', descending: true)
            .snapshots()
            .map((s) => s.docs.map(Vehicle.fromFirestore).toList()),
      ).listen(vehicles.add);

      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(
        vehicles.last.map((v) => v.model).toList(),
        ['Roadster'],
        reason: '認証イベントが来なくても購読時点のセッションで読み込むべき',
      );

      await sub.cancel();
    });

    test('購読開始時点が未ログインなら空を流す', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedVehicle(firestore);

      final silentAuthChanges = StreamController<User?>();
      addTearDown(silentAuthChanges.close);

      final vehicles = <List<Vehicle>>[];
      final sub = authScopedStream<List<Vehicle>>(
        authChanges: silentAuthChanges.stream,
        currentUser: () => null,
        signedOutValue: const <Vehicle>[],
        onSignedIn: (u) => const Stream<List<Vehicle>>.empty(),
      ).listen(vehicles.add);

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(vehicles.last, isEmpty);

      await sub.cancel();
    });
  });

  group('Edge Cases', () {
    test('ログイン後にログアウトすると空に戻る', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedVehicle(firestore);

      final auth = MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: _uid));
      final service = FirebaseService(firestore: firestore, auth: auth);

      final emissions = <List<Vehicle>>[];
      final sub = service.getUserVehicles().listen(emissions.add);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(emissions.last, hasLength(1));

      await auth.signOut();
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(emissions.last, isEmpty, reason: 'ログアウト後は他人のデータを残さない');

      await sub.cancel();
    });

    test('他ユーザーの車両は流れてこない', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedVehicle(firestore);
      await firestore.collection('vehicles').doc('veh-other').set({
        'userId': 'someone-else',
        'maker': 'Toyota',
        'model': 'Hiace',
        'year': 2020,
        'grade': '',
        'mileage': 1000,
        'createdAt': Timestamp.fromDate(DateTime(2026, 8, 16)),
        'updatedAt': Timestamp.fromDate(DateTime(2026, 8, 16)),
      });

      final auth =
          MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: _uid));
      final service = FirebaseService(firestore: firestore, auth: auth);

      final vehicles = await service.getUserVehicles().first;

      expect(vehicles.map((v) => v.model).toList(), ['Roadster']);
    });
  });
}
