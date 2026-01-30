import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:trust_car_platform/models/vehicle.dart';

void main() {
  group('Vehicle', () {
    group('fromFirestore', () {
      test('正常なデータからVehicleを生成できる', () {
        final now = DateTime.now();
        final data = {
          'userId': 'user123',
          'maker': 'Toyota',
          'model': 'Prius',
          'year': 2020,
          'grade': 'S',
          'mileage': 50000,
          'imageUrl': 'https://example.com/image.jpg',
          'createdAt': Timestamp.fromDate(now),
          'updatedAt': Timestamp.fromDate(now),
        };

        final vehicle = Vehicle(
          id: 'vehicle123',
          userId: data['userId'] as String,
          maker: data['maker'] as String,
          model: data['model'] as String,
          year: data['year'] as int,
          grade: data['grade'] as String,
          mileage: data['mileage'] as int,
          imageUrl: data['imageUrl'] as String?,
          createdAt: (data['createdAt'] as Timestamp).toDate(),
          updatedAt: (data['updatedAt'] as Timestamp).toDate(),
        );

        expect(vehicle.id, 'vehicle123');
        expect(vehicle.userId, 'user123');
        expect(vehicle.maker, 'Toyota');
        expect(vehicle.model, 'Prius');
        expect(vehicle.year, 2020);
        expect(vehicle.grade, 'S');
        expect(vehicle.mileage, 50000);
        expect(vehicle.imageUrl, 'https://example.com/image.jpg');
      });

      test('nullフィールドがあってもVehicleを生成できる', () {
        final vehicle = Vehicle(
          id: 'vehicle123',
          userId: '',
          maker: '',
          model: '',
          year: 0,
          grade: '',
          mileage: 0,
          imageUrl: null,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(vehicle.userId, '');
        expect(vehicle.maker, '');
        expect(vehicle.imageUrl, null);
      });
    });

    group('toMap', () {
      test('VehicleをMapに変換できる', () {
        final now = DateTime.now();
        final vehicle = Vehicle(
          id: 'vehicle123',
          userId: 'user123',
          maker: 'Toyota',
          model: 'Prius',
          year: 2020,
          grade: 'S',
          mileage: 50000,
          imageUrl: 'https://example.com/image.jpg',
          createdAt: now,
          updatedAt: now,
        );

        final map = vehicle.toMap();

        expect(map['userId'], 'user123');
        expect(map['maker'], 'Toyota');
        expect(map['model'], 'Prius');
        expect(map['year'], 2020);
        expect(map['grade'], 'S');
        expect(map['mileage'], 50000);
        expect(map['imageUrl'], 'https://example.com/image.jpg');
        expect(map['createdAt'], isA<Timestamp>());
        expect(map['updatedAt'], isA<Timestamp>());
      });
    });

    group('copyWith', () {
      test('一部フィールドを変更したコピーを作成できる', () {
        final now = DateTime.now();
        final original = Vehicle(
          id: 'vehicle123',
          userId: 'user123',
          maker: 'Toyota',
          model: 'Prius',
          year: 2020,
          grade: 'S',
          mileage: 50000,
          imageUrl: null,
          createdAt: now,
          updatedAt: now,
        );

        final copied = original.copyWith(
          mileage: 60000,
          imageUrl: 'https://example.com/new.jpg',
        );

        // 変更したフィールド
        expect(copied.mileage, 60000);
        expect(copied.imageUrl, 'https://example.com/new.jpg');

        // 変更していないフィールド
        expect(copied.id, original.id);
        expect(copied.userId, original.userId);
        expect(copied.maker, original.maker);
        expect(copied.model, original.model);
        expect(copied.year, original.year);
        expect(copied.grade, original.grade);
      });
    });
  });
}
