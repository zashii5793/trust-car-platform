import 'package:cloud_firestore/cloud_firestore.dart';

/// Vehicle listing status
enum ListingStatus {
  active,     // 販売中
  reserved,   // 商談中
  sold,       // 売約済み
  withdrawn,  // 取り下げ
  ;

  static ListingStatus? fromString(String? value) {
    if (value == null) return null;
    return ListingStatus.values.where((e) => e.name == value).firstOrNull;
  }

  String get displayName {
    switch (this) {
      case ListingStatus.active:
        return '販売中';
      case ListingStatus.reserved:
        return '商談中';
      case ListingStatus.sold:
        return '売約済み';
      case ListingStatus.withdrawn:
        return '取り下げ';
    }
  }
}

/// Vehicle condition grade
enum ConditionGrade {
  s,    // 新車・未使用車
  a,    // 極上車
  b,    // 良好
  c,    // 普通
  d,    // 要整備
  ;

  static ConditionGrade? fromString(String? value) {
    if (value == null) return null;
    return ConditionGrade.values.where((e) => e.name == value).firstOrNull;
  }

  String get displayName {
    switch (this) {
      case ConditionGrade.s:
        return 'S（新車・未使用車）';
      case ConditionGrade.a:
        return 'A（極上車）';
      case ConditionGrade.b:
        return 'B（良好）';
      case ConditionGrade.c:
        return 'C（普通）';
      case ConditionGrade.d:
        return 'D（要整備）';
    }
  }

  String get shortName {
    switch (this) {
      case ConditionGrade.s:
        return 'S';
      case ConditionGrade.a:
        return 'A';
      case ConditionGrade.b:
        return 'B';
      case ConditionGrade.c:
        return 'C';
      case ConditionGrade.d:
        return 'D';
    }
  }
}

/// Transmission type
enum TransmissionType {
  at,     // オートマチック
  mt,     // マニュアル
  cvt,    // CVT
  dct,    // デュアルクラッチ
  ;

  static TransmissionType? fromString(String? value) {
    if (value == null) return null;
    return TransmissionType.values.where((e) => e.name == value).firstOrNull;
  }

  String get displayName {
    switch (this) {
      case TransmissionType.at:
        return 'AT';
      case TransmissionType.mt:
        return 'MT';
      case TransmissionType.cvt:
        return 'CVT';
      case TransmissionType.dct:
        return 'DCT';
    }
  }
}

/// Fuel type
enum FuelType {
  gasoline,   // ガソリン
  diesel,     // ディーゼル
  hybrid,     // ハイブリッド
  phev,       // プラグインハイブリッド
  ev,         // 電気自動車
  lpg,        // LPG
  ;

  static FuelType? fromString(String? value) {
    if (value == null) return null;
    return FuelType.values.where((e) => e.name == value).firstOrNull;
  }

  String get displayName {
    switch (this) {
      case FuelType.gasoline:
        return 'ガソリン';
      case FuelType.diesel:
        return 'ディーゼル';
      case FuelType.hybrid:
        return 'ハイブリッド';
      case FuelType.phev:
        return 'PHEV';
      case FuelType.ev:
        return 'EV';
      case FuelType.lpg:
        return 'LPG';
    }
  }
}

/// Drive type
enum DriveType {
  fwd,    // 前輪駆動
  rwd,    // 後輪駆動
  awd,    // 四輪駆動
  fourWd, // 4WD
  ;

  static DriveType? fromString(String? value) {
    if (value == null) return null;
    if (value == '4wd') return DriveType.fourWd;
    return DriveType.values.where((e) => e.name == value).firstOrNull;
  }

  String get displayName {
    switch (this) {
      case DriveType.fwd:
        return 'FF（前輪駆動）';
      case DriveType.rwd:
        return 'FR（後輪駆動）';
      case DriveType.awd:
        return 'AWD';
      case DriveType.fourWd:
        return '4WD';
    }
  }

  String get storageName {
    if (this == DriveType.fourWd) return '4wd';
    return name;
  }
}

/// Vehicle listing image
class ListingImage {
  final String url;
  final String? thumbnailUrl;
  final int order;
  final bool isPrimary;
  final String? caption;

  const ListingImage({
    required this.url,
    this.thumbnailUrl,
    this.order = 0,
    this.isPrimary = false,
    this.caption,
  });

  factory ListingImage.fromMap(Map<String, dynamic> map) {
    return ListingImage(
      url: map['url'] ?? '',
      thumbnailUrl: map['thumbnailUrl'],
      order: map['order'] ?? 0,
      isPrimary: map['isPrimary'] ?? false,
      caption: map['caption'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'url': url,
      if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
      'order': order,
      'isPrimary': isPrimary,
      if (caption != null) 'caption': caption,
    };
  }
}

/// Vehicle specifications
class VehicleSpecs {
  final int? engineDisplacement;    // 排気量 (cc)
  final int? maxPower;              // 最高出力 (ps)
  final int? maxTorque;             // 最大トルク (Nm)
  final double? fuelEfficiency;     // 燃費 (km/L)
  final int? seatingCapacity;       // 乗車定員
  final int? doorCount;             // ドア数
  final TransmissionType? transmission;
  final FuelType? fuelType;
  final DriveType? driveType;

  const VehicleSpecs({
    this.engineDisplacement,
    this.maxPower,
    this.maxTorque,
    this.fuelEfficiency,
    this.seatingCapacity,
    this.doorCount,
    this.transmission,
    this.fuelType,
    this.driveType,
  });

  factory VehicleSpecs.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const VehicleSpecs();
    return VehicleSpecs(
      engineDisplacement: map['engineDisplacement'],
      maxPower: map['maxPower'],
      maxTorque: map['maxTorque'],
      fuelEfficiency: (map['fuelEfficiency'] as num?)?.toDouble(),
      seatingCapacity: map['seatingCapacity'],
      doorCount: map['doorCount'],
      transmission: TransmissionType.fromString(map['transmission']),
      fuelType: FuelType.fromString(map['fuelType']),
      driveType: DriveType.fromString(map['driveType']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (engineDisplacement != null) 'engineDisplacement': engineDisplacement,
      if (maxPower != null) 'maxPower': maxPower,
      if (maxTorque != null) 'maxTorque': maxTorque,
      if (fuelEfficiency != null) 'fuelEfficiency': fuelEfficiency,
      if (seatingCapacity != null) 'seatingCapacity': seatingCapacity,
      if (doorCount != null) 'doorCount': doorCount,
      if (transmission != null) 'transmission': transmission!.name,
      if (fuelType != null) 'fuelType': fuelType!.name,
      if (driveType != null) 'driveType': driveType!.storageName,
    };
  }
}

/// Vehicle listing model (for sale)
class VehicleListing {
  final String id;
  final String sellerId;            // 出品者（個人 or 販売店）
  final String? shopId;             // 販売店ID（販売店出品の場合）
  final ListingStatus status;

  // 車両基本情報
  final String makerId;
  final String makerName;
  final String modelId;
  final String modelName;
  final String? gradeId;
  final String? gradeName;
  final int modelYear;              // 年式
  final String? bodyType;
  final String? color;
  final String? colorCode;

  // 状態情報
  final int mileage;                // 走行距離 (km)
  final ConditionGrade conditionGrade;
  final String? inspectionDate;     // 車検満了日 (YYYY-MM)
  final bool hasAccidentHistory;    // 修復歴
  final bool hasSmokingHistory;     // 喫煙歴
  final bool isOneOwner;            // ワンオーナー
  final String? conditionNote;      // 状態備考

  // スペック
  final VehicleSpecs specs;

  // 装備
  final List<String> features;      // 装備・オプション

  // 価格
  final int price;                  // 車両本体価格
  final int? totalPrice;            // 支払総額
  final bool isPriceNegotiable;     // 価格交渉可

  // 画像
  final List<ListingImage> images;

  // 説明
  final String? description;
  final String? sellerComment;

  // 所在地
  final String prefecture;
  final String? city;

  // 統計
  final int viewCount;
  final int favoriteCount;
  final int inquiryCount;

  // タイムスタンプ
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? soldAt;

  const VehicleListing({
    required this.id,
    required this.sellerId,
    this.shopId,
    required this.status,
    required this.makerId,
    required this.makerName,
    required this.modelId,
    required this.modelName,
    this.gradeId,
    this.gradeName,
    required this.modelYear,
    this.bodyType,
    this.color,
    this.colorCode,
    required this.mileage,
    required this.conditionGrade,
    this.inspectionDate,
    this.hasAccidentHistory = false,
    this.hasSmokingHistory = false,
    this.isOneOwner = false,
    this.conditionNote,
    this.specs = const VehicleSpecs(),
    this.features = const [],
    required this.price,
    this.totalPrice,
    this.isPriceNegotiable = false,
    this.images = const [],
    this.description,
    this.sellerComment,
    required this.prefecture,
    this.city,
    this.viewCount = 0,
    this.favoriteCount = 0,
    this.inquiryCount = 0,
    required this.createdAt,
    required this.updatedAt,
    this.soldAt,
  });

  factory VehicleListing.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return VehicleListing(
      id: doc.id,
      sellerId: data['sellerId'] ?? '',
      shopId: data['shopId'],
      status: ListingStatus.fromString(data['status']) ?? ListingStatus.active,
      makerId: data['makerId'] ?? '',
      makerName: data['makerName'] ?? '',
      modelId: data['modelId'] ?? '',
      modelName: data['modelName'] ?? '',
      gradeId: data['gradeId'],
      gradeName: data['gradeName'],
      modelYear: data['modelYear'] ?? 0,
      bodyType: data['bodyType'],
      color: data['color'],
      colorCode: data['colorCode'],
      mileage: data['mileage'] ?? 0,
      conditionGrade: ConditionGrade.fromString(data['conditionGrade']) ?? ConditionGrade.c,
      inspectionDate: data['inspectionDate'],
      hasAccidentHistory: data['hasAccidentHistory'] ?? false,
      hasSmokingHistory: data['hasSmokingHistory'] ?? false,
      isOneOwner: data['isOneOwner'] ?? false,
      conditionNote: data['conditionNote'],
      specs: VehicleSpecs.fromMap(data['specs']),
      features: List<String>.from(data['features'] ?? []),
      price: data['price'] ?? 0,
      totalPrice: data['totalPrice'],
      isPriceNegotiable: data['isPriceNegotiable'] ?? false,
      images: (data['images'] as List<dynamic>?)
          ?.map((e) => ListingImage.fromMap(e as Map<String, dynamic>))
          .toList() ?? [],
      description: data['description'],
      sellerComment: data['sellerComment'],
      prefecture: data['prefecture'] ?? '',
      city: data['city'],
      viewCount: data['viewCount'] ?? 0,
      favoriteCount: data['favoriteCount'] ?? 0,
      inquiryCount: data['inquiryCount'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      soldAt: (data['soldAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sellerId': sellerId,
      if (shopId != null) 'shopId': shopId,
      'status': status.name,
      'makerId': makerId,
      'makerName': makerName,
      'modelId': modelId,
      'modelName': modelName,
      if (gradeId != null) 'gradeId': gradeId,
      if (gradeName != null) 'gradeName': gradeName,
      'modelYear': modelYear,
      if (bodyType != null) 'bodyType': bodyType,
      if (color != null) 'color': color,
      if (colorCode != null) 'colorCode': colorCode,
      'mileage': mileage,
      'conditionGrade': conditionGrade.name,
      if (inspectionDate != null) 'inspectionDate': inspectionDate,
      'hasAccidentHistory': hasAccidentHistory,
      'hasSmokingHistory': hasSmokingHistory,
      'isOneOwner': isOneOwner,
      if (conditionNote != null) 'conditionNote': conditionNote,
      'specs': specs.toMap(),
      'features': features,
      'price': price,
      if (totalPrice != null) 'totalPrice': totalPrice,
      'isPriceNegotiable': isPriceNegotiable,
      'images': images.map((e) => e.toMap()).toList(),
      if (description != null) 'description': description,
      if (sellerComment != null) 'sellerComment': sellerComment,
      'prefecture': prefecture,
      if (city != null) 'city': city,
      'viewCount': viewCount,
      'favoriteCount': favoriteCount,
      'inquiryCount': inquiryCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      if (soldAt != null) 'soldAt': Timestamp.fromDate(soldAt!),
    };
  }

  VehicleListing copyWith({
    String? id,
    String? sellerId,
    String? shopId,
    ListingStatus? status,
    String? makerId,
    String? makerName,
    String? modelId,
    String? modelName,
    String? gradeId,
    String? gradeName,
    int? modelYear,
    String? bodyType,
    String? color,
    String? colorCode,
    int? mileage,
    ConditionGrade? conditionGrade,
    String? inspectionDate,
    bool? hasAccidentHistory,
    bool? hasSmokingHistory,
    bool? isOneOwner,
    String? conditionNote,
    VehicleSpecs? specs,
    List<String>? features,
    int? price,
    int? totalPrice,
    bool? isPriceNegotiable,
    List<ListingImage>? images,
    String? description,
    String? sellerComment,
    String? prefecture,
    String? city,
    int? viewCount,
    int? favoriteCount,
    int? inquiryCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? soldAt,
  }) {
    return VehicleListing(
      id: id ?? this.id,
      sellerId: sellerId ?? this.sellerId,
      shopId: shopId ?? this.shopId,
      status: status ?? this.status,
      makerId: makerId ?? this.makerId,
      makerName: makerName ?? this.makerName,
      modelId: modelId ?? this.modelId,
      modelName: modelName ?? this.modelName,
      gradeId: gradeId ?? this.gradeId,
      gradeName: gradeName ?? this.gradeName,
      modelYear: modelYear ?? this.modelYear,
      bodyType: bodyType ?? this.bodyType,
      color: color ?? this.color,
      colorCode: colorCode ?? this.colorCode,
      mileage: mileage ?? this.mileage,
      conditionGrade: conditionGrade ?? this.conditionGrade,
      inspectionDate: inspectionDate ?? this.inspectionDate,
      hasAccidentHistory: hasAccidentHistory ?? this.hasAccidentHistory,
      hasSmokingHistory: hasSmokingHistory ?? this.hasSmokingHistory,
      isOneOwner: isOneOwner ?? this.isOneOwner,
      conditionNote: conditionNote ?? this.conditionNote,
      specs: specs ?? this.specs,
      features: features ?? this.features,
      price: price ?? this.price,
      totalPrice: totalPrice ?? this.totalPrice,
      isPriceNegotiable: isPriceNegotiable ?? this.isPriceNegotiable,
      images: images ?? this.images,
      description: description ?? this.description,
      sellerComment: sellerComment ?? this.sellerComment,
      prefecture: prefecture ?? this.prefecture,
      city: city ?? this.city,
      viewCount: viewCount ?? this.viewCount,
      favoriteCount: favoriteCount ?? this.favoriteCount,
      inquiryCount: inquiryCount ?? this.inquiryCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      soldAt: soldAt ?? this.soldAt,
    );
  }

  /// 表示用タイトル
  String get displayTitle => '$makerName $modelName${gradeName != null ? ' $gradeName' : ''}';

  /// 価格表示
  String get displayPrice => '¥${_formatPrice(price)}';

  /// 支払総額表示
  String? get displayTotalPrice => totalPrice != null ? '¥${_formatPrice(totalPrice!)}' : null;

  /// 走行距離表示
  String get displayMileage {
    if (mileage >= 10000) {
      return '${(mileage / 10000).toStringAsFixed(1)}万km';
    }
    return '${mileage}km';
  }

  /// プライマリ画像URL
  String? get primaryImageUrl {
    final primary = images.where((img) => img.isPrimary).firstOrNull;
    return primary?.url ?? images.firstOrNull?.url;
  }

  /// 販売店出品か
  bool get isShopListing => shopId != null;

  /// アクティブか
  bool get isActive => status == ListingStatus.active;

  static String _formatPrice(int price) {
    final str = price.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(str[i]);
    }
    return buffer.toString();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VehicleListing && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'VehicleListing($displayTitle, $displayPrice)';
}

/// Favorite record for listings
class ListingFavorite {
  final String id;
  final String listingId;
  final String userId;
  final DateTime createdAt;

  const ListingFavorite({
    required this.id,
    required this.listingId,
    required this.userId,
    required this.createdAt,
  });

  factory ListingFavorite.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ListingFavorite(
      id: doc.id,
      listingId: data['listingId'] ?? '',
      userId: data['userId'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'listingId': listingId,
      'userId': userId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
