import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// サービスカテゴリ
enum ServiceCategory {
  inspection('車検・点検', Icons.verified, Colors.green),
  maintenance('整備・修理', Icons.build, Colors.blue),
  oilChange('オイル関連', Icons.opacity, Colors.amber),
  tire('タイヤ関連', Icons.tire_repair, Colors.grey),
  bodyRepair('板金・塗装', Icons.format_paint, Colors.pink),
  coating('コーティング', Icons.auto_awesome, Colors.indigo),
  film('フィルム施工', Icons.filter_frames, Colors.blueGrey),
  customization('カスタム', Icons.star, Colors.orange),
  accessory('アクセサリー', Icons.add_circle, Colors.teal),
  washing('洗車', Icons.local_car_wash, Colors.lightBlue),
  other('その他', Icons.more_horiz, Colors.grey);

  final String displayName;
  final IconData icon;
  final Color color;
  const ServiceCategory(this.displayName, this.icon, this.color);

  static ServiceCategory fromString(String? value) {
    if (value == null) return ServiceCategory.other;
    try {
      return ServiceCategory.values.firstWhere((e) => e.name == value);
    } catch (_) {
      return ServiceCategory.other;
    }
  }
}

/// 料金タイプ
enum PricingType {
  fixed('固定料金'),
  perHour('時間単価'),
  estimate('要見積'),
  fromPrice('〜円から');

  final String displayName;
  const PricingType(this.displayName);

  static PricingType fromString(String? value) {
    if (value == null) return PricingType.fixed;
    try {
      return PricingType.values.firstWhere((e) => e.name == value);
    } catch (_) {
      return PricingType.fixed;
    }
  }
}

/// サービスメニューモデル
class ServiceMenu {
  final String id;
  final String shopId;                     // 店舗ID（BtoB用、個人はnull）

  final ServiceCategory category;
  final String name;                       // サービス名
  final String? description;               // 説明
  final String? details;                   // 詳細説明（長文）

  // 料金
  final PricingType pricingType;
  final int? basePrice;                    // 基本料金
  final int? maxPrice;                     // 最大料金（〜円から の場合）
  final int? laborCostPerHour;             // 時間単価

  // 作業時間
  final double? estimatedHours;            // 想定作業時間
  final double? minHours;                  // 最短作業時間
  final double? maxHours;                  // 最長作業時間

  // 対象車種
  final List<String> applicableVehicleTypes;  // 対象車種（軽自動車、普通車等）
  final bool isUniversal;                  // 全車種対応か

  // 状態
  final bool isActive;                     // 有効フラグ
  final bool isPopular;                    // 人気メニューか
  final bool isRecommended;                // おすすめか
  final int sortOrder;                     // 表示順

  // 画像
  final String? imageUrl;                  // サービス画像
  final List<String> galleryUrls;          // ギャラリー画像

  // メタデータ
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ServiceMenu({
    required this.id,
    this.shopId = '',
    required this.category,
    required this.name,
    this.description,
    this.details,
    this.pricingType = PricingType.fixed,
    this.basePrice,
    this.maxPrice,
    this.laborCostPerHour,
    this.estimatedHours,
    this.minHours,
    this.maxHours,
    this.applicableVehicleTypes = const [],
    this.isUniversal = true,
    this.isActive = true,
    this.isPopular = false,
    this.isRecommended = false,
    this.sortOrder = 0,
    this.imageUrl,
    this.galleryUrls = const [],
    this.metadata,
    required this.createdAt,
    required this.updatedAt,
  });

  /// 料金表示文字列
  String get priceDisplay {
    switch (pricingType) {
      case PricingType.fixed:
        return basePrice != null ? '¥${_formatNumber(basePrice!)}' : '要問合せ';
      case PricingType.perHour:
        return laborCostPerHour != null
            ? '¥${_formatNumber(laborCostPerHour!)}/時間'
            : '要問合せ';
      case PricingType.estimate:
        return '要見積';
      case PricingType.fromPrice:
        return basePrice != null ? '¥${_formatNumber(basePrice!)}〜' : '要問合せ';
    }
  }

  /// 作業時間表示文字列
  String get estimatedTimeDisplay {
    if (estimatedHours != null) {
      if (estimatedHours! < 1) {
        return '約${(estimatedHours! * 60).toInt()}分';
      }
      return '約${estimatedHours!.toStringAsFixed(1)}時間';
    }
    if (minHours != null && maxHours != null) {
      return '${minHours!.toStringAsFixed(1)}〜${maxHours!.toStringAsFixed(1)}時間';
    }
    return '要問合せ';
  }

  static String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  factory ServiceMenu.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ServiceMenu(
      id: doc.id,
      shopId: data['shopId'] ?? '',
      category: ServiceCategory.fromString(data['category']),
      name: data['name'] ?? '',
      description: data['description'],
      details: data['details'],
      pricingType: PricingType.fromString(data['pricingType']),
      basePrice: data['basePrice'],
      maxPrice: data['maxPrice'],
      laborCostPerHour: data['laborCostPerHour'],
      estimatedHours: (data['estimatedHours'] as num?)?.toDouble(),
      minHours: (data['minHours'] as num?)?.toDouble(),
      maxHours: (data['maxHours'] as num?)?.toDouble(),
      applicableVehicleTypes: List<String>.from(data['applicableVehicleTypes'] ?? []),
      isUniversal: data['isUniversal'] ?? true,
      isActive: data['isActive'] ?? true,
      isPopular: data['isPopular'] ?? false,
      isRecommended: data['isRecommended'] ?? false,
      sortOrder: data['sortOrder'] ?? 0,
      imageUrl: data['imageUrl'],
      galleryUrls: List<String>.from(data['galleryUrls'] ?? []),
      metadata: data['metadata'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'shopId': shopId,
      'category': category.name,
      'name': name,
      'description': description,
      'details': details,
      'pricingType': pricingType.name,
      'basePrice': basePrice,
      'maxPrice': maxPrice,
      'laborCostPerHour': laborCostPerHour,
      'estimatedHours': estimatedHours,
      'minHours': minHours,
      'maxHours': maxHours,
      'applicableVehicleTypes': applicableVehicleTypes,
      'isUniversal': isUniversal,
      'isActive': isActive,
      'isPopular': isPopular,
      'isRecommended': isRecommended,
      'sortOrder': sortOrder,
      'imageUrl': imageUrl,
      'galleryUrls': galleryUrls,
      'metadata': metadata,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  ServiceMenu copyWith({
    String? id,
    String? shopId,
    ServiceCategory? category,
    String? name,
    String? description,
    String? details,
    PricingType? pricingType,
    int? basePrice,
    int? maxPrice,
    int? laborCostPerHour,
    double? estimatedHours,
    double? minHours,
    double? maxHours,
    List<String>? applicableVehicleTypes,
    bool? isUniversal,
    bool? isActive,
    bool? isPopular,
    bool? isRecommended,
    int? sortOrder,
    String? imageUrl,
    List<String>? galleryUrls,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ServiceMenu(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      category: category ?? this.category,
      name: name ?? this.name,
      description: description ?? this.description,
      details: details ?? this.details,
      pricingType: pricingType ?? this.pricingType,
      basePrice: basePrice ?? this.basePrice,
      maxPrice: maxPrice ?? this.maxPrice,
      laborCostPerHour: laborCostPerHour ?? this.laborCostPerHour,
      estimatedHours: estimatedHours ?? this.estimatedHours,
      minHours: minHours ?? this.minHours,
      maxHours: maxHours ?? this.maxHours,
      applicableVehicleTypes: applicableVehicleTypes ?? this.applicableVehicleTypes,
      isUniversal: isUniversal ?? this.isUniversal,
      isActive: isActive ?? this.isActive,
      isPopular: isPopular ?? this.isPopular,
      isRecommended: isRecommended ?? this.isRecommended,
      sortOrder: sortOrder ?? this.sortOrder,
      imageUrl: imageUrl ?? this.imageUrl,
      galleryUrls: galleryUrls ?? this.galleryUrls,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'ServiceMenu(id: $id, name: $name, category: ${category.displayName}, price: $priceDisplay)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ServiceMenu && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
