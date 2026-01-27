import 'package:cloud_firestore/cloud_firestore.dart';

enum MaintenanceType {
  repair, // 修理
  inspection, // 点検
  partsReplacement, // 消耗品交換
  carInspection, // 車検
}

class MaintenanceRecord {
  final String id;
  final String vehicleId;
  final String userId;
  final MaintenanceType type;
  final String title;
  final String? description;
  final int cost;
  final String? shopName;
  final DateTime date;
  final int? mileageAtService;
  final List<String> imageUrls;
  final DateTime createdAt;

  MaintenanceRecord({
    required this.id,
    required this.vehicleId,
    required this.userId,
    required this.type,
    required this.title,
    this.description,
    required this.cost,
    this.shopName,
    required this.date,
    this.mileageAtService,
    this.imageUrls = const [],
    required this.createdAt,
  });

  // Firestoreからデータを取得
  factory MaintenanceRecord.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return MaintenanceRecord(
      id: doc.id,
      vehicleId: data['vehicleId'] ?? '',
      userId: data['userId'] ?? '',
      type: MaintenanceType.values[data['type'] ?? 0],
      title: data['title'] ?? '',
      description: data['description'],
      cost: data['cost'] ?? 0,
      shopName: data['shopName'],
      date: (data['date'] as Timestamp).toDate(),
      mileageAtService: data['mileageAtService'],
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  // Firestoreに保存するためのMap
  Map<String, dynamic> toMap() {
    return {
      'vehicleId': vehicleId,
      'userId': userId,
      'type': type.index,
      'title': title,
      'description': description,
      'cost': cost,
      'shopName': shopName,
      'date': Timestamp.fromDate(date),
      'mileageAtService': mileageAtService,
      'imageUrls': imageUrls,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  // タイプの日本語表示
  String get typeDisplayName {
    switch (type) {
      case MaintenanceType.repair:
        return '修理';
      case MaintenanceType.inspection:
        return '点検';
      case MaintenanceType.partsReplacement:
        return '消耗品交換';
      case MaintenanceType.carInspection:
        return '車検';
    }
  }
}
