import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/models/maintenance_record.dart';
import 'package:trust_car_platform/models/shop.dart';
import 'package:trust_car_platform/models/shop_ledger.dart';
import 'package:trust_car_platform/models/user.dart';
import 'package:trust_car_platform/models/vehicle.dart';
import 'package:trust_car_platform/models/vehicle_share.dart';

/// 古い版のアプリが書いた文書（項目が足りない）でも、今のモデルが読めること。
///
/// Firestore には版の番号が無く、項目を足すたびに「足す前の文書」が残る。
/// 読み込みで必須の項目を増やすと、**その日から古い文書を開いた人だけ画面が落ちる**。
/// 単体テストは新しい形の文書しか作らないので、この壊れ方はここでしか見つからない。
///
/// 決まり（docs/SCHEMA_MIGRATION_STRATEGY.md §0）: 項目は足すだけ。読むときは
/// 無い項目を既定値で補う。名前を変える・意味を変えるときは移行を書く。
///
/// 中心のモデル（店が払う理由と、利用者の記録）に絞って見張る。
void main() {
  late FakeFirebaseFirestore db;

  setUp(() => db = FakeFirebaseFirestore());

  Future<T> readEmpty<T>(String col, T Function(dynamic doc) from) async {
    await db.collection(col).doc('old').set(<String, dynamic>{});
    final doc = await db.collection(col).doc('old').get();
    return from(doc);
  }

  group('項目が1つも無い文書でも読める', () {
    test('車両', () async {
      await expectLater(
          readEmpty('vehicles', (d) => Vehicle.fromFirestore(d)), completes);
    });

    test('整備記録', () async {
      await expectLater(
          readEmpty(
              'maintenance_records', (d) => MaintenanceRecord.fromFirestore(d)),
          completes);
    });

    test('店', () async {
      await expectLater(
          readEmpty('shops', (d) => Shop.fromFirestore(d)), completes);
    });

    test('利用者', () async {
      await expectLater(
          readEmpty('users', (d) => AppUser.fromFirestore(d)), completes);
    });

    test('店の顧客台帳（顧客・車両）', () {
      expect(() => LedgerCustomer.fromMap('old', <String, dynamic>{}),
          returnsNormally);
      expect(() => LedgerVehicle.fromMap('old', <String, dynamic>{}),
          returnsNormally);
    });

    test('店への共有', () {
      expect(() => VehicleShare.fromMap(<String, dynamic>{}), returnsNormally);
    });
  });
}
