import 'package:cloud_firestore/cloud_firestore.dart';

/// Body type of vehicle
enum BodyType {
  sedan('セダン'),
  suv('SUV'),
  minivan('ミニバン'),
  wagon('ワゴン'),
  hatchback('ハッチバック'),
  coupe('クーペ'),
  convertible('オープンカー'),
  kei('軽自動車'),
  truck('トラック'),
  van('バン'),
  other('その他');

  final String displayName;
  const BodyType(this.displayName);

  static BodyType? fromString(String? value) {
    if (value == null) return null;
    try {
      return BodyType.values.firstWhere((e) => e.name == value);
    } catch (_) {
      return null;
    }
  }
}

/// Vehicle maker master data
class VehicleMaker {
  final String id;
  final String name;         // Japanese name (e.g., "トヨタ")
  final String nameEn;       // English name (e.g., "Toyota")
  final String? logoUrl;
  final String country;      // "JP", "DE", "US", etc.
  final int displayOrder;
  final bool isActive;

  const VehicleMaker({
    required this.id,
    required this.name,
    required this.nameEn,
    this.logoUrl,
    required this.country,
    this.displayOrder = 0,
    this.isActive = true,
  });

  factory VehicleMaker.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return VehicleMaker(
      id: doc.id,
      name: data['name'] ?? '',
      nameEn: data['nameEn'] ?? '',
      logoUrl: data['logoUrl'],
      country: data['country'] ?? 'JP',
      displayOrder: data['displayOrder'] ?? 0,
      isActive: data['isActive'] ?? true,
    );
  }

  factory VehicleMaker.fromMap(Map<String, dynamic> data, String id) {
    return VehicleMaker(
      id: id,
      name: data['name'] ?? '',
      nameEn: data['nameEn'] ?? '',
      logoUrl: data['logoUrl'],
      country: data['country'] ?? 'JP',
      displayOrder: data['displayOrder'] ?? 0,
      isActive: data['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'nameEn': nameEn,
      'logoUrl': logoUrl,
      'country': country,
      'displayOrder': displayOrder,
      'isActive': isActive,
    };
  }

  @override
  String toString() => 'VehicleMaker($name)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is VehicleMaker && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Vehicle model master data
class VehicleModel {
  final String id;
  final String makerId;
  final String name;           // e.g., "プリウス", "RAV4"
  final String? nameEn;        // e.g., "Prius", "RAV4"
  final BodyType? bodyType;
  final int? productionStartYear;
  final int? productionEndYear;  // null means still in production
  final int displayOrder;
  final bool isActive;

  const VehicleModel({
    required this.id,
    required this.makerId,
    required this.name,
    this.nameEn,
    this.bodyType,
    this.productionStartYear,
    this.productionEndYear,
    this.displayOrder = 0,
    this.isActive = true,
  });

  /// Check if the model was available in the given year
  bool isAvailableInYear(int year) {
    if (productionStartYear != null && year < productionStartYear!) {
      return false;
    }
    if (productionEndYear != null && year > productionEndYear!) {
      return false;
    }
    return true;
  }

  /// Check if the model is currently in production
  bool get isCurrentlyProduced => productionEndYear == null;

  factory VehicleModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return VehicleModel(
      id: doc.id,
      makerId: data['makerId'] ?? '',
      name: data['name'] ?? '',
      nameEn: data['nameEn'],
      bodyType: BodyType.fromString(data['bodyType']),
      productionStartYear: data['productionStartYear'],
      productionEndYear: data['productionEndYear'],
      displayOrder: data['displayOrder'] ?? 0,
      isActive: data['isActive'] ?? true,
    );
  }

  factory VehicleModel.fromMap(Map<String, dynamic> data, String id) {
    return VehicleModel(
      id: id,
      makerId: data['makerId'] ?? '',
      name: data['name'] ?? '',
      nameEn: data['nameEn'],
      bodyType: BodyType.fromString(data['bodyType']),
      productionStartYear: data['productionStartYear'],
      productionEndYear: data['productionEndYear'],
      displayOrder: data['displayOrder'] ?? 0,
      isActive: data['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'makerId': makerId,
      'name': name,
      'nameEn': nameEn,
      'bodyType': bodyType?.name,
      'productionStartYear': productionStartYear,
      'productionEndYear': productionEndYear,
      'displayOrder': displayOrder,
      'isActive': isActive,
    };
  }

  @override
  String toString() => 'VehicleModel($name)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is VehicleModel && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Vehicle grade master data
class VehicleGrade {
  final String id;
  final String modelId;
  final String name;              // e.g., "S", "G", "Z"
  final int? engineDisplacement;  // cc
  final String? fuelType;         // maps to FuelType enum name
  final String? driveType;        // maps to DriveType enum name
  final String? transmissionType; // maps to TransmissionType enum name
  final int? availableFromYear;
  final int? availableUntilYear;
  final int displayOrder;
  final bool isActive;

  const VehicleGrade({
    required this.id,
    required this.modelId,
    required this.name,
    this.engineDisplacement,
    this.fuelType,
    this.driveType,
    this.transmissionType,
    this.availableFromYear,
    this.availableUntilYear,
    this.displayOrder = 0,
    this.isActive = true,
  });

  /// Check if the grade was available in the given year
  bool isAvailableInYear(int year) {
    if (availableFromYear != null && year < availableFromYear!) {
      return false;
    }
    if (availableUntilYear != null && year > availableUntilYear!) {
      return false;
    }
    return true;
  }

  factory VehicleGrade.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return VehicleGrade(
      id: doc.id,
      modelId: data['modelId'] ?? '',
      name: data['name'] ?? '',
      engineDisplacement: data['engineDisplacement'],
      fuelType: data['fuelType'],
      driveType: data['driveType'],
      transmissionType: data['transmissionType'],
      availableFromYear: data['availableFromYear'],
      availableUntilYear: data['availableUntilYear'],
      displayOrder: data['displayOrder'] ?? 0,
      isActive: data['isActive'] ?? true,
    );
  }

  factory VehicleGrade.fromMap(Map<String, dynamic> data, String id) {
    return VehicleGrade(
      id: id,
      modelId: data['modelId'] ?? '',
      name: data['name'] ?? '',
      engineDisplacement: data['engineDisplacement'],
      fuelType: data['fuelType'],
      driveType: data['driveType'],
      transmissionType: data['transmissionType'],
      availableFromYear: data['availableFromYear'],
      availableUntilYear: data['availableUntilYear'],
      displayOrder: data['displayOrder'] ?? 0,
      isActive: data['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'modelId': modelId,
      'name': name,
      'engineDisplacement': engineDisplacement,
      'fuelType': fuelType,
      'driveType': driveType,
      'transmissionType': transmissionType,
      'availableFromYear': availableFromYear,
      'availableUntilYear': availableUntilYear,
      'displayOrder': displayOrder,
      'isActive': isActive,
    };
  }

  @override
  String toString() => 'VehicleGrade($name)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is VehicleGrade && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
