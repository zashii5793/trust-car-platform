import 'package:cloud_firestore/cloud_firestore.dart';

class Vehicle {
  final String id;
  final String userId;
  final String maker;
  final String model;
  final int year;
  final String grade;
  final int mileage;
  final String? imageUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  Vehicle({
    required this.id,
    required this.userId,
    required this.maker,
    required this.model,
    required this.year,
    required this.grade,
    required this.mileage,
    this.imageUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  // Firestoreからデータを取得
  factory Vehicle.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Vehicle(
      id: doc.id,
      userId: data['userId'] ?? '',
      maker: data['maker'] ?? '',
      model: data['model'] ?? '',
      year: data['year'] ?? 0,
      grade: data['grade'] ?? '',
      mileage: data['mileage'] ?? 0,
      imageUrl: data['imageUrl'],
      createdAt: _parseTimestamp(data['createdAt']),
      updatedAt: _parseTimestamp(data['updatedAt']),
    );
  }

  // Timestampを安全にパース（nullの場合は現在時刻を返す）
  static DateTime _parseTimestamp(dynamic value) {
    if (value == null) {
      return DateTime.now();
    }
    if (value is Timestamp) {
      return value.toDate();
    }
    return DateTime.now();
  }

  // Firestoreに保存するためのMap
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'maker': maker,
      'model': model,
      'year': year,
      'grade': grade,
      'mileage': mileage,
      'imageUrl': imageUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  // コピーメソッド
  Vehicle copyWith({
    String? id,
    String? userId,
    String? maker,
    String? model,
    int? year,
    String? grade,
    int? mileage,
    String? imageUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Vehicle(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      maker: maker ?? this.maker,
      model: model ?? this.model,
      year: year ?? this.year,
      grade: grade ?? this.grade,
      mileage: mileage ?? this.mileage,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
