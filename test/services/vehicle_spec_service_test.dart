// VehicleSpecService Unit Tests
//
// Tests community-contributed vehicle spec data read/write.

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/core/result/result.dart';
import 'package:trust_car_platform/models/vehicle_master.dart';
import 'package:trust_car_platform/services/vehicle_spec_service.dart';

VehicleGrade _makeGrade({
  int? engineDisplacement,
  String? fuelType,
  int? seatingCapacity,
  int? vehicleWeight,
  List<String> standardEquipment = const [],
}) =>
    VehicleGrade(
      id: 'g1',
      modelId: 'm1',
      name: 'S',
      engineDisplacement: engineDisplacement,
      fuelType: fuelType,
      seatingCapacity: seatingCapacity,
      vehicleWeight: vehicleWeight,
      standardEquipment: standardEquipment,
    );

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late VehicleSpecService service;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    service = VehicleSpecService(firestore: fakeFirestore);
  });

  // ---------------------------------------------------------------------------
  // fetchSpec
  // ---------------------------------------------------------------------------

  group('fetchSpec', () {
    test('ドキュメントなし → null を返す', () async {
      final result = await service.fetchSpec('トヨタ', 'プリウス', 2022, 'S');
      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull, isNull);
    });

    test('ドキュメントあり → VehicleSpecResult に変換して返す', () async {
      await fakeFirestore
          .collection('vehicle_grade_specs')
          .doc('トヨタ_プリウス_2022_s')
          .set({
        'maker': 'トヨタ',
        'model': 'プリウス',
        'year': 2022,
        'grade': 'S',
        'engineDisplacement': 1800,
        'fuelType': 'hybrid',
        'seatingCapacity': 5,
        'vehicleWeight': 1380,
        'standardEquipment': ['スマートエントリー', 'バックカメラ'],
        'contributorCount': 3,
        'updatedAt': 0,
      });

      final result = await service.fetchSpec('トヨタ', 'プリウス', 2022, 'S');

      expect(result.isSuccess, isTrue);
      final spec = result.valueOrNull!;
      expect(spec.grade.engineDisplacement, 1800);
      expect(spec.grade.fuelType, 'hybrid');
      expect(spec.grade.seatingCapacity, 5);
      expect(spec.grade.vehicleWeight, 1380);
      expect(spec.grade.standardEquipment, ['スマートエントリー', 'バックカメラ']);
      expect(spec.contributorCount, 3);
    });

    test('maker が空文字 → AppError を返す', () async {
      final result = await service.fetchSpec('', 'プリウス', 2022, 'S');
      expect(result.isFailure, isTrue);
    });

    test('model が空文字 → AppError を返す', () async {
      final result = await service.fetchSpec('トヨタ', '', 2022, 'S');
      expect(result.isFailure, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // saveSpec
  // ---------------------------------------------------------------------------

  group('saveSpec', () {
    test('新規作成 → contributorCount: 1 で保存される', () async {
      final grade = _makeGrade(engineDisplacement: 1800, fuelType: 'hybrid');

      final result =
          await service.saveSpec('トヨタ', 'プリウス', 2022, 'S', grade);
      expect(result.isSuccess, isTrue);

      final doc = await fakeFirestore
          .collection('vehicle_grade_specs')
          .doc('トヨタ_プリウス_2022_s')
          .get();
      expect(doc.exists, isTrue);
      expect(doc.data()!['contributorCount'], 1);
      expect(doc.data()!['engineDisplacement'], 1800);
    });

    test('既存あり → contributorCount のみ++ される（データは変わらない）', () async {
      await fakeFirestore
          .collection('vehicle_grade_specs')
          .doc('トヨタ_プリウス_2022_s')
          .set({
        'maker': 'トヨタ',
        'model': 'プリウス',
        'year': 2022,
        'grade': 'S',
        'engineDisplacement': 1800,
        'fuelType': 'hybrid',
        'seatingCapacity': 5,
        'vehicleWeight': 1380,
        'standardEquipment': ['スマートエントリー'],
        'contributorCount': 2,
        'updatedAt': 0,
      });

      // Save with different engineDisplacement — should NOT overwrite
      final grade = _makeGrade(engineDisplacement: 9999, fuelType: 'gasoline');
      await service.saveSpec('トヨタ', 'プリウス', 2022, 'S', grade);

      final doc = await fakeFirestore
          .collection('vehicle_grade_specs')
          .doc('トヨタ_プリウス_2022_s')
          .get();
      expect(doc.data()!['contributorCount'], 3);
      expect(doc.data()!['engineDisplacement'], 1800); // unchanged
    });

    test('maker が空文字 → AppError を返す', () async {
      final grade = _makeGrade();
      final result = await service.saveSpec('', 'プリウス', 2022, 'S', grade);
      expect(result.isFailure, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // sampleImageUrl (community vehicle photo)
  // ---------------------------------------------------------------------------

  group('sampleImageUrl', () {
    test('saveSpec に imageUrl を渡す → sampleImageUrl が保存される', () async {
      final grade = _makeGrade(engineDisplacement: 1800);
      await service.saveSpec('トヨタ', 'プリウス', 2022, 'S', grade,
          imageUrl: 'https://example.com/prius.jpg');

      final doc = await fakeFirestore
          .collection('vehicle_grade_specs')
          .doc('トヨタ_プリウス_2022_s')
          .get();
      expect(doc.data()!['sampleImageUrl'], 'https://example.com/prius.jpg');
    });

    test('fetchSpec → sampleImageUrl が VehicleSpecResult に含まれる', () async {
      await fakeFirestore
          .collection('vehicle_grade_specs')
          .doc('トヨタ_プリウス_2022_s')
          .set({
        'maker': 'トヨタ',
        'model': 'プリウス',
        'year': 2022,
        'grade': 'S',
        'engineDisplacement': 1800,
        'sampleImageUrl': 'https://example.com/prius.jpg',
        'contributorCount': 1,
        'updatedAt': 0,
      });

      final result = await service.fetchSpec('トヨタ', 'プリウス', 2022, 'S');
      expect(result.valueOrNull!.sampleImageUrl,
          'https://example.com/prius.jpg');
    });

    test('既存ドキュメントに sampleImageUrl がない → 後続投稿者の写真で補完される', () async {
      await fakeFirestore
          .collection('vehicle_grade_specs')
          .doc('トヨタ_プリウス_2022_s')
          .set({
        'maker': 'トヨタ',
        'model': 'プリウス',
        'year': 2022,
        'grade': 'S',
        'engineDisplacement': 1800,
        'contributorCount': 1,
        'updatedAt': 0,
      });

      final grade = _makeGrade(engineDisplacement: 9999);
      await service.saveSpec('トヨタ', 'プリウス', 2022, 'S', grade,
          imageUrl: 'https://example.com/late.jpg');

      final doc = await fakeFirestore
          .collection('vehicle_grade_specs')
          .doc('トヨタ_プリウス_2022_s')
          .get();
      expect(doc.data()!['sampleImageUrl'], 'https://example.com/late.jpg');
      expect(doc.data()!['engineDisplacement'], 1800); // spec unchanged
      expect(doc.data()!['contributorCount'], 2);
    });

    test('既存ドキュメントに sampleImageUrl がある → 上書きされない', () async {
      await fakeFirestore
          .collection('vehicle_grade_specs')
          .doc('トヨタ_プリウス_2022_s')
          .set({
        'maker': 'トヨタ',
        'model': 'プリウス',
        'year': 2022,
        'grade': 'S',
        'sampleImageUrl': 'https://example.com/first.jpg',
        'contributorCount': 1,
        'updatedAt': 0,
      });

      final grade = _makeGrade();
      await service.saveSpec('トヨタ', 'プリウス', 2022, 'S', grade,
          imageUrl: 'https://example.com/second.jpg');

      final doc = await fakeFirestore
          .collection('vehicle_grade_specs')
          .doc('トヨタ_プリウス_2022_s')
          .get();
      expect(doc.data()!['sampleImageUrl'], 'https://example.com/first.jpg');
    });
  });

  // ---------------------------------------------------------------------------
  // isVerified (community trust badge)
  // ---------------------------------------------------------------------------

  group('isVerified', () {
    test('contributorCount >= 3 → isVerified が true', () async {
      await fakeFirestore
          .collection('vehicle_grade_specs')
          .doc('トヨタ_プリウス_2022_s')
          .set({
        'maker': 'トヨタ',
        'model': 'プリウス',
        'year': 2022,
        'grade': 'S',
        'contributorCount': 3,
        'updatedAt': 0,
      });

      final result = await service.fetchSpec('トヨタ', 'プリウス', 2022, 'S');
      expect(result.valueOrNull!.isVerified, isTrue);
    });

    test('contributorCount < 3 → isVerified が false', () async {
      await fakeFirestore
          .collection('vehicle_grade_specs')
          .doc('トヨタ_プリウス_2022_s')
          .set({
        'maker': 'トヨタ',
        'model': 'プリウス',
        'year': 2022,
        'grade': 'S',
        'contributorCount': 2,
        'updatedAt': 0,
      });

      final result = await service.fetchSpec('トヨタ', 'プリウス', 2022, 'S');
      expect(result.valueOrNull!.isVerified, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // specId generation
  // ---------------------------------------------------------------------------

  group('specId生成', () {
    test('大文字・スペースが正規化される', () async {
      final grade = _makeGrade(engineDisplacement: 2000);
      await service.saveSpec('Toyota', 'Prius', 2022, 'S', grade);

      final doc = await fakeFirestore
          .collection('vehicle_grade_specs')
          .doc('toyota_prius_2022_s')
          .get();
      expect(doc.exists, isTrue);
    });

    test('スペース入りメーカー名がアンダースコアに変換される', () async {
      final grade = _makeGrade(engineDisplacement: 2500);
      await service.saveSpec('Land Rover', 'Range Rover', 2022, 'HSE', grade);

      final doc = await fakeFirestore
          .collection('vehicle_grade_specs')
          .doc('land_rover_range_rover_2022_hse')
          .get();
      expect(doc.exists, isTrue);
    });
  });
}
