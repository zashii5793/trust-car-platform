import 'package:cloud_firestore/cloud_firestore.dart';

/// 燃料タイプ
enum FuelType {
  gasoline('ガソリン'),
  diesel('ディーゼル'),
  hybrid('ハイブリッド'),
  electric('電気'),
  phev('プラグインハイブリッド'),
  hydrogen('水素');

  final String displayName;
  const FuelType(this.displayName);

  /// 文字列からFuelTypeを取得
  static FuelType? fromString(String? value) {
    if (value == null) return null;
    try {
      return FuelType.values.firstWhere((e) => e.name == value);
    } catch (_) {
      return null;
    }
  }
}

/// 車両情報
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

  // Phase 1.5 追加フィールド: 識別情報
  final String? licensePlate;     // ナンバープレート（例: "品川 300 あ 12-34"）
  final String? vinNumber;        // 車台番号（17桁）
  final String? modelCode;        // 型式（例: "DBA-GRB"）

  // Phase 1.5 追加フィールド: 車検・保険
  final DateTime? inspectionExpiryDate;  // 車検満了日 ★最重要
  final DateTime? insuranceExpiryDate;   // 自賠責保険期限

  // Phase 1.5 追加フィールド: 詳細情報
  final String? color;            // 車体色
  final int? engineDisplacement;  // 排気量(cc)
  final FuelType? fuelType;       // 燃料タイプ
  final DateTime? purchaseDate;   // 購入日/納車日

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
    // Phase 1.5 追加
    this.licensePlate,
    this.vinNumber,
    this.modelCode,
    this.inspectionExpiryDate,
    this.insuranceExpiryDate,
    this.color,
    this.engineDisplacement,
    this.fuelType,
    this.purchaseDate,
  });

  /// 車検までの残日数（null: 車検日未設定）
  int? get daysUntilInspection {
    if (inspectionExpiryDate == null) return null;
    return inspectionExpiryDate!.difference(DateTime.now()).inDays;
  }

  /// 車検期限が近いか（30日以内）
  bool get isInspectionDueSoon {
    final days = daysUntilInspection;
    return days != null && days <= 30 && days >= 0;
  }

  /// 車検期限切れか
  bool get isInspectionExpired {
    final days = daysUntilInspection;
    return days != null && days < 0;
  }

  /// 自賠責保険までの残日数
  int? get daysUntilInsuranceExpiry {
    if (insuranceExpiryDate == null) return null;
    return insuranceExpiryDate!.difference(DateTime.now()).inDays;
  }

  /// 自賠責保険期限が近いか（30日以内）
  bool get isInsuranceDueSoon {
    final days = daysUntilInsuranceExpiry;
    return days != null && days <= 30 && days >= 0;
  }

  /// 車両の表示名（メーカー + 車種）
  String get displayName => '$maker $model';

  /// 車両の完全な表示名（メーカー + 車種 + グレード）
  String get fullDisplayName => grade.isNotEmpty ? '$maker $model $grade' : '$maker $model';

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
      // Phase 1.5 追加フィールド
      licensePlate: data['licensePlate'],
      vinNumber: data['vinNumber'],
      modelCode: data['modelCode'],
      inspectionExpiryDate: _parseTimestampNullable(data['inspectionExpiryDate']),
      insuranceExpiryDate: _parseTimestampNullable(data['insuranceExpiryDate']),
      color: data['color'],
      engineDisplacement: data['engineDisplacement'],
      fuelType: FuelType.fromString(data['fuelType']),
      purchaseDate: _parseTimestampNullable(data['purchaseDate']),
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
      // Phase 1.5 追加フィールド
      'licensePlate': licensePlate,
      'vinNumber': vinNumber,
      'modelCode': modelCode,
      'inspectionExpiryDate': inspectionExpiryDate != null
          ? Timestamp.fromDate(inspectionExpiryDate!)
          : null,
      'insuranceExpiryDate': insuranceExpiryDate != null
          ? Timestamp.fromDate(insuranceExpiryDate!)
          : null,
      'color': color,
      'engineDisplacement': engineDisplacement,
      'fuelType': fuelType?.name,
      'purchaseDate': purchaseDate != null
          ? Timestamp.fromDate(purchaseDate!)
          : null,
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
    // Phase 1.5 追加
    String? licensePlate,
    String? vinNumber,
    String? modelCode,
    DateTime? inspectionExpiryDate,
    DateTime? insuranceExpiryDate,
    String? color,
    int? engineDisplacement,
    FuelType? fuelType,
    DateTime? purchaseDate,
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
      // Phase 1.5 追加
      licensePlate: licensePlate ?? this.licensePlate,
      vinNumber: vinNumber ?? this.vinNumber,
      modelCode: modelCode ?? this.modelCode,
      inspectionExpiryDate: inspectionExpiryDate ?? this.inspectionExpiryDate,
      insuranceExpiryDate: insuranceExpiryDate ?? this.insuranceExpiryDate,
      color: color ?? this.color,
      engineDisplacement: engineDisplacement ?? this.engineDisplacement,
      fuelType: fuelType ?? this.fuelType,
      purchaseDate: purchaseDate ?? this.purchaseDate,
    );
  }

  @override
  String toString() {
    return 'Vehicle(id: $id, $displayName, year: $year, mileage: $mileage km)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Vehicle && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
