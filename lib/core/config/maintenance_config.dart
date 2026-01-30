/// メンテナンス関連の設定
///
/// メンテナンス間隔、推奨事項などの設定を一元管理
/// 将来的にはRemote Configで動的に変更可能
class MaintenanceConfig {
  MaintenanceConfig._();

  static final MaintenanceConfig instance = MaintenanceConfig._();

  /// オイル交換の推奨間隔（日数）
  int get oilChangeIntervalDays => 180; // 6ヶ月

  /// オイル交換の推奨間隔（走行距離km）
  int get oilChangeIntervalKm => 5000;

  /// タイヤ交換の推奨間隔（日数）
  int get tireChangeIntervalDays => 730; // 2年

  /// タイヤ交換の推奨間隔（走行距離km）
  int get tireChangeIntervalKm => 30000;

  /// 定期点検の間隔（日数）
  int get inspectionIntervalDays => 365; // 1年

  /// 車検の間隔（日数）- 新車は3年、以降2年
  int getCarInspectionIntervalDays({required bool isFirstInspection}) {
    return isFirstInspection ? 1095 : 730; // 3年 or 2年
  }

  /// メンテナンス通知の事前日数
  int get reminderDaysBefore => 14; // 2週間前

  /// メンテナンス通知の緊急日数
  int get urgentReminderDaysBefore => 3; // 3日前

  /// 走行距離ベースの通知マージン（km）
  int get mileageReminderMarginKm => 500;

  /// 推奨メンテナンス項目
  List<MaintenanceItem> get recommendedItems => [
    MaintenanceItem(
      id: 'oil_change',
      name: 'エンジンオイル交換',
      category: MaintenanceCategory.engine,
      intervalDays: oilChangeIntervalDays,
      intervalKm: oilChangeIntervalKm,
      priority: MaintenancePriority.high,
      estimatedCostMin: 3000,
      estimatedCostMax: 8000,
    ),
    MaintenanceItem(
      id: 'oil_filter',
      name: 'オイルフィルター交換',
      category: MaintenanceCategory.engine,
      intervalDays: 365,
      intervalKm: 10000,
      priority: MaintenancePriority.medium,
      estimatedCostMin: 1000,
      estimatedCostMax: 3000,
    ),
    MaintenanceItem(
      id: 'air_filter',
      name: 'エアフィルター交換',
      category: MaintenanceCategory.engine,
      intervalDays: 730,
      intervalKm: 30000,
      priority: MaintenancePriority.medium,
      estimatedCostMin: 2000,
      estimatedCostMax: 5000,
    ),
    MaintenanceItem(
      id: 'tire_rotation',
      name: 'タイヤローテーション',
      category: MaintenanceCategory.tire,
      intervalDays: 180,
      intervalKm: 5000,
      priority: MaintenancePriority.medium,
      estimatedCostMin: 2000,
      estimatedCostMax: 5000,
    ),
    MaintenanceItem(
      id: 'tire_replacement',
      name: 'タイヤ交換',
      category: MaintenanceCategory.tire,
      intervalDays: tireChangeIntervalDays,
      intervalKm: tireChangeIntervalKm,
      priority: MaintenancePriority.high,
      estimatedCostMin: 40000,
      estimatedCostMax: 120000,
    ),
    MaintenanceItem(
      id: 'brake_pad',
      name: 'ブレーキパッド交換',
      category: MaintenanceCategory.brake,
      intervalDays: 730,
      intervalKm: 30000,
      priority: MaintenancePriority.high,
      estimatedCostMin: 10000,
      estimatedCostMax: 30000,
    ),
    MaintenanceItem(
      id: 'brake_fluid',
      name: 'ブレーキフルード交換',
      category: MaintenanceCategory.brake,
      intervalDays: 730,
      intervalKm: null,
      priority: MaintenancePriority.medium,
      estimatedCostMin: 3000,
      estimatedCostMax: 8000,
    ),
    MaintenanceItem(
      id: 'battery',
      name: 'バッテリー交換',
      category: MaintenanceCategory.electrical,
      intervalDays: 1095, // 3年
      intervalKm: null,
      priority: MaintenancePriority.medium,
      estimatedCostMin: 10000,
      estimatedCostMax: 30000,
    ),
    MaintenanceItem(
      id: 'coolant',
      name: 'クーラント交換',
      category: MaintenanceCategory.cooling,
      intervalDays: 730,
      intervalKm: 40000,
      priority: MaintenancePriority.medium,
      estimatedCostMin: 3000,
      estimatedCostMax: 8000,
    ),
    MaintenanceItem(
      id: 'transmission_fluid',
      name: 'トランスミッションフルード交換',
      category: MaintenanceCategory.transmission,
      intervalDays: 730,
      intervalKm: 40000,
      priority: MaintenancePriority.low,
      estimatedCostMin: 5000,
      estimatedCostMax: 15000,
    ),
    MaintenanceItem(
      id: 'wiper',
      name: 'ワイパーブレード交換',
      category: MaintenanceCategory.exterior,
      intervalDays: 365,
      intervalKm: null,
      priority: MaintenancePriority.low,
      estimatedCostMin: 1000,
      estimatedCostMax: 5000,
    ),
    MaintenanceItem(
      id: 'inspection',
      name: '定期点検',
      category: MaintenanceCategory.inspection,
      intervalDays: inspectionIntervalDays,
      intervalKm: null,
      priority: MaintenancePriority.high,
      estimatedCostMin: 10000,
      estimatedCostMax: 30000,
    ),
    MaintenanceItem(
      id: 'car_inspection',
      name: '車検',
      category: MaintenanceCategory.inspection,
      intervalDays: 730, // デフォルト2年
      intervalKm: null,
      priority: MaintenancePriority.critical,
      estimatedCostMin: 50000,
      estimatedCostMax: 150000,
    ),
  ];

  /// IDでメンテナンス項目を取得
  MaintenanceItem? getItemById(String id) {
    try {
      return recommendedItems.firstWhere((item) => item.id == id);
    } catch (_) {
      return null;
    }
  }

  /// カテゴリでメンテナンス項目をフィルタ
  List<MaintenanceItem> getItemsByCategory(MaintenanceCategory category) {
    return recommendedItems.where((item) => item.category == category).toList();
  }
}

/// メンテナンス項目
class MaintenanceItem {
  final String id;
  final String name;
  final MaintenanceCategory category;
  final int intervalDays;
  final int? intervalKm;
  final MaintenancePriority priority;
  final int estimatedCostMin;
  final int estimatedCostMax;

  const MaintenanceItem({
    required this.id,
    required this.name,
    required this.category,
    required this.intervalDays,
    this.intervalKm,
    required this.priority,
    required this.estimatedCostMin,
    required this.estimatedCostMax,
  });

  /// 推定コストの平均
  int get estimatedCostAverage => (estimatedCostMin + estimatedCostMax) ~/ 2;

  /// 推定コストの表示文字列
  String get estimatedCostDisplay =>
      '¥${_formatNumber(estimatedCostMin)} 〜 ¥${_formatNumber(estimatedCostMax)}';

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    );
  }
}

/// メンテナンスカテゴリ
enum MaintenanceCategory {
  engine('エンジン'),
  transmission('トランスミッション'),
  brake('ブレーキ'),
  tire('タイヤ'),
  electrical('電装'),
  cooling('冷却'),
  exterior('外装'),
  interior('内装'),
  inspection('点検・車検');

  final String displayName;
  const MaintenanceCategory(this.displayName);
}

/// メンテナンス優先度
enum MaintenancePriority {
  low('低'),
  medium('中'),
  high('高'),
  critical('緊急');

  final String displayName;
  const MaintenancePriority(this.displayName);
}

/// ショートカット
MaintenanceConfig get maintenanceConfig => MaintenanceConfig.instance;
