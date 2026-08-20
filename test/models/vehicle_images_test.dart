// 車両の複数画像対応のテスト。
//
// 従来は imageUrl（単数）だけだった。好きな角度の写真を複数残したいという
// 要望に合わせて imageUrls を追加するが、既存データは imageUrl しか持たない。
// 新旧どちらの形でも読めること、書き戻しても情報が落ちないことを固定する。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/models/vehicle.dart';

Future<DocumentSnapshot<Map<String, dynamic>>> _doc(
  Map<String, dynamic> data,
) async {
  final fs = FakeFirebaseFirestore();
  await fs.collection('vehicles').doc('v1').set({
    'userId': 'user-a',
    'maker': 'Mazda',
    'model': 'Roadster',
    'year': 2019,
    'grade': 'S',
    'mileage': 22000,
    'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
    'updatedAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
    ...data,
  });
  return fs.collection('vehicles').doc('v1').get();
}

void main() {
  group('Vehicle.imageUrls — 旧データの読み取り', () {
    test('imageUrl だけの既存データは imageUrls に引き上げられる', () async {
      final snap = await _doc({'imageUrl': 'https://example.com/a.jpg'});
      final vehicle = Vehicle.fromFirestore(snap);

      expect(vehicle.imageUrls, ['https://example.com/a.jpg']);
      expect(vehicle.imageUrl, 'https://example.com/a.jpg',
          reason: '既存の参照箇所が壊れないよう imageUrl も引き続き読めるべき');
    });

    test('画像が無いデータは空リストになる', () async {
      final snap = await _doc({});
      final vehicle = Vehicle.fromFirestore(snap);

      expect(vehicle.imageUrls, isEmpty);
      expect(vehicle.imageUrl, isNull);
    });
  });

  group('Vehicle.imageUrls — 新データ', () {
    test('imageUrls を読める', () async {
      final snap = await _doc({
        'imageUrls': ['https://example.com/a.jpg', 'https://example.com/b.jpg'],
      });
      final vehicle = Vehicle.fromFirestore(snap);

      expect(vehicle.imageUrls, hasLength(2));
      expect(vehicle.imageUrl, 'https://example.com/a.jpg',
          reason: '一覧のサムネイルは先頭画像を使う');
    });

    test('imageUrls と imageUrl が両方あれば imageUrls を優先する', () async {
      final snap = await _doc({
        'imageUrl': 'https://example.com/old.jpg',
        'imageUrls': [
          'https://example.com/new1.jpg',
          'https://example.com/new2.jpg'
        ],
      });
      final vehicle = Vehicle.fromFirestore(snap);

      expect(vehicle.imageUrls.first, 'https://example.com/new1.jpg');
    });
  });

  group('Vehicle.toMap — 書き戻し', () {
    test('imageUrls と先頭を指す imageUrl の両方を書く', () {
      final vehicle = Vehicle(
        id: 'v1',
        userId: 'user-a',
        maker: 'Mazda',
        model: 'Roadster',
        year: 2019,
        grade: 'S',
        mileage: 22000,
        imageUrls: const [
          'https://example.com/1.jpg',
          'https://example.com/2.jpg'
        ],
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      final map = vehicle.toMap();

      expect(map['imageUrls'], hasLength(2));
      expect(map['imageUrl'], 'https://example.com/1.jpg',
          reason: '旧バージョンのアプリからも1枚目が見えるようにする');
    });

    test('画像なしなら imageUrl は null、imageUrls は空', () {
      final vehicle = Vehicle(
        id: 'v1',
        userId: 'user-a',
        maker: 'Mazda',
        model: 'Roadster',
        year: 2019,
        grade: 'S',
        mileage: 22000,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      final map = vehicle.toMap();

      expect(map['imageUrl'], isNull);
      expect(map['imageUrls'], isEmpty);
    });
  });

  group('Edge Cases', () {
    test('imageUrls に空文字が混ざっていても除外される', () async {
      final snap = await _doc({
        'imageUrls': ['https://example.com/a.jpg', '', '  '],
      });
      final vehicle = Vehicle.fromFirestore(snap);

      expect(vehicle.imageUrls, ['https://example.com/a.jpg']);
    });

    test('imageUrl が空文字なら画像なし扱い', () async {
      final snap = await _doc({'imageUrl': ''});
      final vehicle = Vehicle.fromFirestore(snap);

      expect(vehicle.imageUrls, isEmpty);
      expect(vehicle.imageUrl, isNull);
    });
  });
}
