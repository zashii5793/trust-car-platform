import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// メンテナンスタイプ（Phase 1.5 拡張版）
enum MaintenanceType {
  // 修理・整備
  repair('修理', Icons.build, Colors.red),

  // 法定点検
  legalInspection12('12ヶ月点検', Icons.assignment, Colors.blue),
  legalInspection24('24ヶ月点検', Icons.assignment_turned_in, Colors.indigo),

  // 車検
  carInspection('車検', Icons.verified, Colors.green),

  // オイル関連
  oilChange('オイル交換', Icons.opacity, Colors.amber),
  oilFilterChange('オイルフィルター交換', Icons.filter_alt, Colors.orange),

  // タイヤ関連
  tireChange('タイヤ交換', Icons.tire_repair, Colors.grey),
  tireRotation('タイヤローテーション', Icons.autorenew, Colors.blueGrey),
  wheelAlignment('ホイールアライメント', Icons.straighten, Colors.teal),

  // バッテリー
  batteryChange('バッテリー交換', Icons.battery_charging_full, Colors.lightGreen),

  // ブレーキ
  brakePadChange('ブレーキパッド交換', Icons.do_not_disturb, Colors.deepOrange),
  brakeFluidChange('ブレーキフルード交換', Icons.water_drop, Colors.brown),

  // 冷却系
  coolantChange('冷却水交換', Icons.ac_unit, Colors.cyan),

  // エアコン
  airConditionerService('エアコン整備', Icons.air, Colors.lightBlue),

  // フィルター
  airFilterChange('エアフィルター交換', Icons.filter_list, Colors.lime),
  cabinFilterChange('エアコンフィルター交換', Icons.filter_drama, Colors.purple),

  // ワイパー・ライト
  wiperChange('ワイパー交換', Icons.water, Colors.blueAccent),
  lightBulbChange('ライト交換', Icons.lightbulb, Colors.yellow),

  // トランスミッション
  transmissionFluidChange('ATF/CVTフルード交換', Icons.settings, Colors.deepPurple),

  // その他
  partsReplacement('部品交換', Icons.build_circle, Colors.grey),
  washing('洗車・コーティング', Icons.local_car_wash, Colors.blue),
  other('その他', Icons.more_horiz, Colors.grey);

  final String displayName;
  final IconData icon;
  final Color color;

  const MaintenanceType(this.displayName, this.icon, this.color);

  /// 文字列からMaintenanceTypeを取得
  static MaintenanceType fromString(String? value) {
    if (value == null) return MaintenanceType.repair;
    try {
      return MaintenanceType.values.firstWhere(
        (e) => e.name == value,
        orElse: () => MaintenanceType.repair,
      );
    } catch (_) {
      return MaintenanceType.repair;
    }
  }

  /// インデックスからMaintenanceTypeを取得（後方互換性のため）
  static MaintenanceType fromIndex(int? index) {
    if (index == null || index < 0 || index >= MaintenanceType.values.length) {
      return MaintenanceType.repair;
    }
    return MaintenanceType.values[index];
  }

  /// カテゴリ別にグループ化
  static Map<String, List<MaintenanceType>> get groupedTypes => {
    '点検・車検': [
      legalInspection12,
      legalInspection24,
      carInspection,
    ],
    'オイル関連': [
      oilChange,
      oilFilterChange,
    ],
    'タイヤ関連': [
      tireChange,
      tireRotation,
      wheelAlignment,
    ],
    'ブレーキ関連': [
      brakePadChange,
      brakeFluidChange,
    ],
    'フィルター関連': [
      airFilterChange,
      cabinFilterChange,
    ],
    'その他消耗品': [
      batteryChange,
      coolantChange,
      wiperChange,
      lightBulbChange,
      transmissionFluidChange,
    ],
    'サービス': [
      airConditionerService,
      washing,
      repair,
      partsReplacement,
      other,
    ],
  };

  /// 定期交換が必要なタイプかどうか
  bool get isPeriodicMaintenance => [
    oilChange,
    oilFilterChange,
    tireRotation,
    brakePadChange,
    brakeFluidChange,
    coolantChange,
    airFilterChange,
    cabinFilterChange,
    wiperChange,
    transmissionFluidChange,
  ].contains(this);

  /// 法定点検・車検かどうか
  bool get isLegalInspection => [
    legalInspection12,
    legalInspection24,
    carInspection,
  ].contains(this);
}

/// メンテナンス記録
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

  // Phase 1.5 追加フィールド
  final String? partNumber;        // 部品番号
  final String? partManufacturer;  // 部品メーカー
  final int? nextReplacementMileage;  // 次回交換推奨走行距離
  final DateTime? nextReplacementDate;  // 次回交換推奨日

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
    // Phase 1.5 追加
    this.partNumber,
    this.partManufacturer,
    this.nextReplacementMileage,
    this.nextReplacementDate,
  });

  // Firestoreからデータを取得
  factory MaintenanceRecord.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return MaintenanceRecord(
      id: doc.id,
      vehicleId: data['vehicleId'] ?? '',
      userId: data['userId'] ?? '',
      type: _parseMaintenanceType(data['type']),
      title: data['title'] ?? '',
      description: data['description'],
      cost: data['cost'] ?? 0,
      shopName: data['shopName'],
      date: _parseTimestamp(data['date']),
      mileageAtService: data['mileageAtService'],
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      createdAt: _parseTimestamp(data['createdAt']),
      // Phase 1.5 追加
      partNumber: data['partNumber'],
      partManufacturer: data['partManufacturer'],
      nextReplacementMileage: data['nextReplacementMileage'],
      nextReplacementDate: _parseTimestampNullable(data['nextReplacementDate']),
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

  // Timestampを安全にパース（nullの場合はnullを返す）
  static DateTime? _parseTimestampNullable(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is Timestamp) {
      return value.toDate();
    }
    return null;
  }

  // MaintenanceTypeを安全にパース
  static MaintenanceType _parseMaintenanceType(dynamic value) {
    if (value == null) {
      return MaintenanceType.repair;
    }
    // 文字列での保存に対応（推奨）
    if (value is String) {
      return MaintenanceType.fromString(value);
    }
    // 数値での保存にも対応（後方互換性）
    if (value is int) {
      // 旧バージョンとの互換性マッピング
      switch (value) {
        case 0: return MaintenanceType.repair;
        case 1: return MaintenanceType.legalInspection12; // 旧inspection
        case 2: return MaintenanceType.partsReplacement;
        case 3: return MaintenanceType.carInspection;
        default: return MaintenanceType.repair;
      }
    }
    return MaintenanceType.repair;
  }

  // Firestoreに保存するためのMap
  Map<String, dynamic> toMap() {
    return {
      'vehicleId': vehicleId,
      'userId': userId,
      'type': type.name, // 文字列で保存（新形式）
      'title': title,
      'description': description,
      'cost': cost,
      'shopName': shopName,
      'date': Timestamp.fromDate(date),
      'mileageAtService': mileageAtService,
      'imageUrls': imageUrls,
      'createdAt': Timestamp.fromDate(createdAt),
      // Phase 1.5 追加
      'partNumber': partNumber,
      'partManufacturer': partManufacturer,
      'nextReplacementMileage': nextReplacementMileage,
      'nextReplacementDate': nextReplacementDate != null
          ? Timestamp.fromDate(nextReplacementDate!)
          : null,
    };
  }

  // タイプの日本語表示（後方互換性）
  String get typeDisplayName => type.displayName;

  // タイプのアイコン
  IconData get typeIcon => type.icon;

  // タイプの色
  Color get typeColor => type.color;

  // 次回交換時期のアラート判定
  bool get isReplacementDueSoon {
    if (nextReplacementDate != null) {
      final days = nextReplacementDate!.difference(DateTime.now()).inDays;
      return days <= 30 && days >= 0;
    }
    return false;
  }

  // copyWith
  MaintenanceRecord copyWith({
    String? id,
    String? vehicleId,
    String? userId,
    MaintenanceType? type,
    String? title,
    String? description,
    int? cost,
    String? shopName,
    DateTime? date,
    int? mileageAtService,
    List<String>? imageUrls,
    DateTime? createdAt,
    String? partNumber,
    String? partManufacturer,
    int? nextReplacementMileage,
    DateTime? nextReplacementDate,
  }) {
    return MaintenanceRecord(
      id: id ?? this.id,
      vehicleId: vehicleId ?? this.vehicleId,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      title: title ?? this.title,
      description: description ?? this.description,
      cost: cost ?? this.cost,
      shopName: shopName ?? this.shopName,
      date: date ?? this.date,
      mileageAtService: mileageAtService ?? this.mileageAtService,
      imageUrls: imageUrls ?? this.imageUrls,
      createdAt: createdAt ?? this.createdAt,
      partNumber: partNumber ?? this.partNumber,
      partManufacturer: partManufacturer ?? this.partManufacturer,
      nextReplacementMileage: nextReplacementMileage ?? this.nextReplacementMileage,
      nextReplacementDate: nextReplacementDate ?? this.nextReplacementDate,
    );
  }

  @override
  String toString() {
    return 'MaintenanceRecord(id: $id, type: ${type.name}, title: $title, date: $date)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MaintenanceRecord && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
