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

  // 板金・塗装
  bodyRepair('板金・塗装', Icons.format_paint, Colors.pink),
  paintCorrection('磨き・補修', Icons.brush, Colors.pinkAccent),

  // コーティング
  glassCoating('ガラスコーティング', Icons.auto_awesome, Colors.indigo),
  bodyCoating('ボディコーティング', Icons.layers, Colors.indigoAccent),

  // フィルム
  carFilm('カーフィルム', Icons.filter_frames, Colors.blueGrey),
  protectionFilm('プロテクションフィルム', Icons.security, Colors.grey),

  // カスタム・ドレスアップ
  customization('カスタム・ドレスアップ', Icons.star, Colors.amber),
  audioInstall('オーディオ取付', Icons.speaker, Colors.deepPurple),
  accessoryInstall('アクセサリー取付', Icons.add_circle, Colors.teal),

  // その他
  partsReplacement('部品交換', Icons.build_circle, Colors.grey),
  washing('洗車', Icons.local_car_wash, Colors.blue),
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
    '板金・塗装': [
      bodyRepair,
      paintCorrection,
    ],
    'コーティング': [
      glassCoating,
      bodyCoating,
      washing,
    ],
    'フィルム施工': [
      carFilm,
      protectionFilm,
    ],
    'カスタム': [
      customization,
      audioInstall,
      accessoryInstall,
    ],
    'その他サービス': [
      airConditionerService,
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

  /// 板金・塗装・コーティング系かどうか
  bool get isBodyWork => [
    bodyRepair,
    paintCorrection,
    glassCoating,
    bodyCoating,
    carFilm,
    protectionFilm,
  ].contains(this);

  /// カスタム系かどうか
  bool get isCustomization => [
    customization,
    audioInstall,
    accessoryInstall,
  ].contains(this);
}

/// 車検・点検結果
enum InspectionResult {
  passed('合格'),
  failed('不合格'),
  conditionalPass('条件付合格');

  final String displayName;
  const InspectionResult(this.displayName);

  static InspectionResult? fromString(String? value) {
    if (value == null) return null;
    try {
      return InspectionResult.values.firstWhere((e) => e.name == value);
    } catch (_) {
      return null;
    }
  }
}

/// 作業項目
class WorkItem {
  final String name;              // 作業項目名
  final String? description;      // 詳細説明
  final int laborCost;            // 工賃
  final double? laborHours;       // 作業時間
  final String? workerName;       // 作業者名

  const WorkItem({
    required this.name,
    this.description,
    required this.laborCost,
    this.laborHours,
    this.workerName,
  });

  factory WorkItem.fromMap(Map<String, dynamic> map) {
    return WorkItem(
      name: map['name'] ?? '',
      description: map['description'],
      laborCost: map['laborCost'] ?? 0,
      laborHours: (map['laborHours'] as num?)?.toDouble(),
      workerName: map['workerName'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'laborCost': laborCost,
      'laborHours': laborHours,
      'workerName': workerName,
    };
  }
}

/// 使用部品
class Part {
  final String partNumber;        // 部品番号
  final String name;              // 部品名
  final String? manufacturer;     // メーカー
  final int unitPrice;            // 単価
  final int quantity;             // 数量

  const Part({
    required this.partNumber,
    required this.name,
    this.manufacturer,
    required this.unitPrice,
    required this.quantity,
  });

  int get subtotal => unitPrice * quantity;

  factory Part.fromMap(Map<String, dynamic> map) {
    return Part(
      partNumber: map['partNumber'] ?? '',
      name: map['name'] ?? '',
      manufacturer: map['manufacturer'],
      unitPrice: map['unitPrice'] ?? 0,
      quantity: map['quantity'] ?? 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'partNumber': partNumber,
      'name': name,
      'manufacturer': manufacturer,
      'unitPrice': unitPrice,
      'quantity': quantity,
    };
  }
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
  final String? partNumber;        // 部品番号（単一部品用、後方互換）
  final String? partManufacturer;  // 部品メーカー（単一部品用、後方互換）
  final int? nextReplacementMileage;  // 次回交換推奨走行距離
  final DateTime? nextReplacementDate;  // 次回交換推奨日

  // Phase 5 追加フィールド: 車検・点検詳細
  final String? staffId;                    // 担当スタッフID
  final String? staffName;                  // 担当スタッフ名
  final InspectionResult? inspectionResult; // 合否結果（車検・点検時）
  final bool certificateUpdated;            // 車検証更新済みフラグ
  final String? safetyStandardsCertificate; // 保安基準適合証番号

  // Phase 5 追加フィールド: 作業・部品詳細
  final List<WorkItem> workItems;           // 作業項目リスト
  final List<Part> parts;                   // 使用部品リスト

  // Phase 5 追加フィールド: 金額内訳
  final int? partsCost;                     // 部品代合計
  final int? laborCost;                     // 工賃合計
  final int? miscCost;                      // 諸費用（印紙代等）
  final int? taxAmount;                     // 消費税額
  final int? discountAmount;                // 割引額

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
    // Phase 5 追加
    this.staffId,
    this.staffName,
    this.inspectionResult,
    this.certificateUpdated = false,
    this.safetyStandardsCertificate,
    this.workItems = const [],
    this.parts = const [],
    this.partsCost,
    this.laborCost,
    this.miscCost,
    this.taxAmount,
    this.discountAmount,
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
      // Phase 5 追加
      staffId: data['staffId'],
      staffName: data['staffName'],
      inspectionResult: InspectionResult.fromString(data['inspectionResult']),
      certificateUpdated: data['certificateUpdated'] ?? false,
      safetyStandardsCertificate: data['safetyStandardsCertificate'],
      workItems: (data['workItems'] as List<dynamic>?)
          ?.map((e) => WorkItem.fromMap(e as Map<String, dynamic>))
          .toList() ?? [],
      parts: (data['parts'] as List<dynamic>?)
          ?.map((e) => Part.fromMap(e as Map<String, dynamic>))
          .toList() ?? [],
      partsCost: data['partsCost'],
      laborCost: data['laborCost'],
      miscCost: data['miscCost'],
      taxAmount: data['taxAmount'],
      discountAmount: data['discountAmount'],
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
      // Phase 5 追加
      'staffId': staffId,
      'staffName': staffName,
      'inspectionResult': inspectionResult?.name,
      'certificateUpdated': certificateUpdated,
      'safetyStandardsCertificate': safetyStandardsCertificate,
      'workItems': workItems.map((e) => e.toMap()).toList(),
      'parts': parts.map((e) => e.toMap()).toList(),
      'partsCost': partsCost,
      'laborCost': laborCost,
      'miscCost': miscCost,
      'taxAmount': taxAmount,
      'discountAmount': discountAmount,
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

  /// 合計金額（内訳から計算）
  int get calculatedTotal {
    final parts = partsCost ?? 0;
    final labor = laborCost ?? 0;
    final misc = miscCost ?? 0;
    final tax = taxAmount ?? 0;
    final discount = discountAmount ?? 0;
    return parts + labor + misc + tax - discount;
  }

  /// 部品代合計（partsリストから計算）
  int get calculatedPartsCost {
    return parts.fold(0, (total, p) => total + p.subtotal);
  }

  /// 工賃合計（workItemsリストから計算）
  int get calculatedLaborCost {
    return workItems.fold(0, (total, w) => total + w.laborCost);
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
    // Phase 5 追加
    String? staffId,
    String? staffName,
    InspectionResult? inspectionResult,
    bool? certificateUpdated,
    String? safetyStandardsCertificate,
    List<WorkItem>? workItems,
    List<Part>? parts,
    int? partsCost,
    int? laborCost,
    int? miscCost,
    int? taxAmount,
    int? discountAmount,
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
      // Phase 5 追加
      staffId: staffId ?? this.staffId,
      staffName: staffName ?? this.staffName,
      inspectionResult: inspectionResult ?? this.inspectionResult,
      certificateUpdated: certificateUpdated ?? this.certificateUpdated,
      safetyStandardsCertificate: safetyStandardsCertificate ?? this.safetyStandardsCertificate,
      workItems: workItems ?? this.workItems,
      parts: parts ?? this.parts,
      partsCost: partsCost ?? this.partsCost,
      laborCost: laborCost ?? this.laborCost,
      miscCost: miscCost ?? this.miscCost,
      taxAmount: taxAmount ?? this.taxAmount,
      discountAmount: discountAmount ?? this.discountAmount,
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
