import '../models/vehicle.dart';
import '../models/maintenance_record.dart';
import '../models/app_notification.dart';

/// メンテナンス推奨のルール
class MaintenanceRule {
  final String name;
  final MaintenanceType type;
  final int intervalMonths;
  final int intervalKm;
  final String description;

  const MaintenanceRule({
    required this.name,
    required this.type,
    required this.intervalMonths,
    required this.intervalKm,
    required this.description,
  });
}

/// レコメンドサービス
/// ルールベースでメンテナンス推奨を生成
class RecommendationService {
  /// メンテナンスルール定義（Phase 1.5 更新）
  static const List<MaintenanceRule> _rules = [
    // エンジンオイル交換
    MaintenanceRule(
      name: 'エンジンオイル交換',
      type: MaintenanceType.oilChange,
      intervalMonths: 6,
      intervalKm: 5000,
      description: 'エンジンの潤滑を保ち、摩耗を防ぐために定期的な交換が必要です。',
    ),
    // オイルフィルター交換
    MaintenanceRule(
      name: 'オイルフィルター交換',
      type: MaintenanceType.oilFilterChange,
      intervalMonths: 12,
      intervalKm: 10000,
      description: 'エンジンオイルの汚れを除去し、エンジンを保護します。',
    ),
    // エアフィルター交換
    MaintenanceRule(
      name: 'エアフィルター交換',
      type: MaintenanceType.airFilterChange,
      intervalMonths: 24,
      intervalKm: 20000,
      description: '燃費と加速性能を維持するために定期的な交換が推奨されます。',
    ),
    // ブレーキパッド点検・交換
    MaintenanceRule(
      name: 'ブレーキパッド点検',
      type: MaintenanceType.brakePadChange,
      intervalMonths: 12,
      intervalKm: 10000,
      description: '安全のため定期的なブレーキパッドの点検が必要です。',
    ),
    // タイヤローテーション
    MaintenanceRule(
      name: 'タイヤローテーション',
      type: MaintenanceType.tireRotation,
      intervalMonths: 6,
      intervalKm: 5000,
      description: 'タイヤの均等な摩耗を促し、寿命を延ばします。',
    ),
    // バッテリー点検
    MaintenanceRule(
      name: 'バッテリー点検',
      type: MaintenanceType.batteryChange,
      intervalMonths: 12,
      intervalKm: 15000,
      description: '突然の始動不良を防ぐために定期的な点検が必要です。',
    ),
    // 冷却水交換
    MaintenanceRule(
      name: '冷却水交換',
      type: MaintenanceType.coolantChange,
      intervalMonths: 24,
      intervalKm: 40000,
      description: 'エンジンのオーバーヒートを防ぎ、冷却システムを保護します。',
    ),
    // ブレーキフルード交換
    MaintenanceRule(
      name: 'ブレーキフルード交換',
      type: MaintenanceType.brakeFluidChange,
      intervalMonths: 24,
      intervalKm: 40000,
      description: 'ブレーキの効きを維持するために定期的な交換が必要です。',
    ),
    // ATF/CVTフルード交換
    MaintenanceRule(
      name: 'ATF/CVTフルード交換',
      type: MaintenanceType.transmissionFluidChange,
      intervalMonths: 48,
      intervalKm: 80000,
      description: 'スムーズな変速を維持するために交換が推奨されます。',
    ),
    // エアコンフィルター交換
    MaintenanceRule(
      name: 'エアコンフィルター交換',
      type: MaintenanceType.cabinFilterChange,
      intervalMonths: 12,
      intervalKm: 15000,
      description: '車内の空気品質を保つために定期的な交換が推奨されます。',
    ),
    // ワイパー交換
    MaintenanceRule(
      name: 'ワイパー交換',
      type: MaintenanceType.wiperChange,
      intervalMonths: 12,
      intervalKm: 0,
      description: '視界確保のため、ゴムの劣化に応じて交換が必要です。',
    ),
    // 12ヶ月法定点検
    MaintenanceRule(
      name: '12ヶ月点検',
      type: MaintenanceType.legalInspection12,
      intervalMonths: 12,
      intervalKm: 0, // 走行距離に関係なく実施
      description: '法律で定められた定期点検です。',
    ),
    // 24ヶ月法定点検
    MaintenanceRule(
      name: '24ヶ月点検',
      type: MaintenanceType.legalInspection24,
      intervalMonths: 24,
      intervalKm: 0,
      description: '法律で定められた定期点検です。車検時に実施することが多いです。',
    ),
  ];

  /// 車検ルール（新車は3年、以降2年）
  static const int _firstInspectionYears = 3;
  static const int _subsequentInspectionYears = 2;

  /// 車両とメンテナンス履歴から推奨を生成
  List<AppNotification> generateRecommendations({
    required Vehicle vehicle,
    required List<MaintenanceRecord> records,
    required String userId,
  }) {
    final recommendations = <AppNotification>[];
    final now = DateTime.now();

    // 車検日が設定されている場合はそれを使用
    if (vehicle.inspectionExpiryDate != null) {
      final inspectionNotification = _checkInspectionExpiryDate(
        vehicle: vehicle,
        userId: userId,
        now: now,
      );
      if (inspectionNotification != null) {
        recommendations.add(inspectionNotification);
      }
    } else {
      // 車検日が未設定の場合は履歴から推測
      final inspectionRecommendation = _checkCarInspection(
        vehicle: vehicle,
        records: records,
        userId: userId,
        now: now,
      );
      if (inspectionRecommendation != null) {
        recommendations.add(inspectionRecommendation);
      }
    }

    // 自賠責保険チェック
    if (vehicle.insuranceExpiryDate != null) {
      final insuranceNotification = _checkInsuranceExpiryDate(
        vehicle: vehicle,
        userId: userId,
        now: now,
      );
      if (insuranceNotification != null) {
        recommendations.add(insuranceNotification);
      }
    }

    // 各ルールをチェック
    for (final rule in _rules) {
      final recommendation = _checkRule(
        rule: rule,
        vehicle: vehicle,
        records: records,
        userId: userId,
        now: now,
      );
      if (recommendation != null) {
        recommendations.add(recommendation);
      }
    }

    // 優先度でソート
    recommendations.sort((a, b) {
      final priorityCompare = b.priority.index.compareTo(a.priority.index);
      if (priorityCompare != 0) return priorityCompare;
      return (a.actionDate ?? now).compareTo(b.actionDate ?? now);
    });

    return recommendations;
  }

  /// 車検満了日からの通知生成（Phase 1.5 新機能）
  AppNotification? _checkInspectionExpiryDate({
    required Vehicle vehicle,
    required String userId,
    required DateTime now,
  }) {
    final daysUntil = vehicle.daysUntilInspection!;

    NotificationPriority priority;
    if (daysUntil <= 0) {
      priority = NotificationPriority.high;
    } else if (daysUntil <= 30) {
      priority = NotificationPriority.high;
    } else if (daysUntil <= 90) {
      priority = NotificationPriority.medium;
    } else if (daysUntil <= 180) {
      priority = NotificationPriority.low;
    } else {
      return null;
    }

    String message;
    if (daysUntil <= 0) {
      message = '${vehicle.displayName}の車検期限が過ぎています！早急に車検を受けてください。';
    } else if (daysUntil <= 7) {
      message = '${vehicle.displayName}の車検期限まであと$daysUntil日です。すぐに予約してください。';
    } else if (daysUntil <= 30) {
      message = '${vehicle.displayName}の車検期限まであと$daysUntil日です。予約をお忘れなく。';
    } else {
      message = '${vehicle.displayName}の車検期限まであと約${(daysUntil / 30).round()}ヶ月です。';
    }

    return AppNotification(
      id: '${vehicle.id}_inspection_expiry_${now.millisecondsSinceEpoch}',
      userId: userId,
      vehicleId: vehicle.id,
      type: NotificationType.inspectionReminder,
      title: '車検のお知らせ',
      message: message,
      priority: priority,
      createdAt: now,
      actionDate: vehicle.inspectionExpiryDate,
      metadata: {
        'inspectionExpiryDate': vehicle.inspectionExpiryDate!.toIso8601String(),
        'daysUntilInspection': daysUntil,
      },
    );
  }

  /// 自賠責保険期限からの通知生成（Phase 1.5 新機能）
  AppNotification? _checkInsuranceExpiryDate({
    required Vehicle vehicle,
    required String userId,
    required DateTime now,
  }) {
    final daysUntil = vehicle.daysUntilInsuranceExpiry!;

    if (daysUntil > 60) return null; // 60日以上先は通知不要

    NotificationPriority priority;
    if (daysUntil <= 0) {
      priority = NotificationPriority.high;
    } else if (daysUntil <= 14) {
      priority = NotificationPriority.high;
    } else if (daysUntil <= 30) {
      priority = NotificationPriority.medium;
    } else {
      priority = NotificationPriority.low;
    }

    String message;
    if (daysUntil <= 0) {
      message = '${vehicle.displayName}の自賠責保険が期限切れです！';
    } else {
      message = '${vehicle.displayName}の自賠責保険期限まであと$daysUntil日です。';
    }

    return AppNotification(
      id: '${vehicle.id}_insurance_expiry_${now.millisecondsSinceEpoch}',
      userId: userId,
      vehicleId: vehicle.id,
      type: NotificationType.maintenanceRecommendation,
      title: '自賠責保険のお知らせ',
      message: message,
      priority: priority,
      createdAt: now,
      actionDate: vehicle.insuranceExpiryDate,
      metadata: {
        'insuranceExpiryDate': vehicle.insuranceExpiryDate!.toIso8601String(),
        'daysUntilExpiry': daysUntil,
      },
    );
  }

  /// 個別ルールのチェック
  AppNotification? _checkRule({
    required MaintenanceRule rule,
    required Vehicle vehicle,
    required List<MaintenanceRecord> records,
    required String userId,
    required DateTime now,
  }) {
    // 該当するメンテナンス記録を検索
    final relevantRecords = records.where((r) {
      // タイプで判定（優先）
      if (r.type == rule.type) return true;
      // タイトルに含まれるキーワードで判定（後方互換性）
      final titleLower = r.title.toLowerCase();
      final ruleNameLower = rule.name.toLowerCase();
      return titleLower.contains(ruleNameLower) ||
          _matchesKeywords(titleLower, rule.name);
    }).toList();

    DateTime? lastMaintenanceDate;
    int? lastMaintenanceMileage;

    if (relevantRecords.isNotEmpty) {
      // 最新の記録を取得
      relevantRecords.sort((a, b) => b.date.compareTo(a.date));
      lastMaintenanceDate = relevantRecords.first.date;
      lastMaintenanceMileage = relevantRecords.first.mileageAtService;
    }

    // 推奨日を計算
    DateTime recommendedDate;
    NotificationPriority priority;

    if (lastMaintenanceDate == null) {
      // 履歴がない場合は車両登録日から計算
      recommendedDate =
          vehicle.createdAt.add(Duration(days: rule.intervalMonths * 30));
    } else {
      recommendedDate =
          lastMaintenanceDate.add(Duration(days: rule.intervalMonths * 30));
    }

    // 走行距離ベースのチェック
    if (rule.intervalKm > 0 && lastMaintenanceMileage != null) {
      final kmSinceLastMaintenance = vehicle.mileage - lastMaintenanceMileage;
      if (kmSinceLastMaintenance >= rule.intervalKm) {
        // 走行距離超過 - 即時推奨
        recommendedDate = now;
      }
    }

    // 優先度を計算
    final daysUntilDue = recommendedDate.difference(now).inDays;
    if (daysUntilDue <= 0) {
      priority = NotificationPriority.high;
    } else if (daysUntilDue <= 30) {
      priority = NotificationPriority.medium;
    } else if (daysUntilDue <= 90) {
      priority = NotificationPriority.low;
    } else {
      // 90日以上先は通知不要
      return null;
    }

    // 通知を生成
    return AppNotification(
      id: '${vehicle.id}_${rule.name}_${now.millisecondsSinceEpoch}',
      userId: userId,
      vehicleId: vehicle.id,
      type: NotificationType.maintenanceRecommendation,
      title: '${rule.name}の時期です',
      message: _generateMessage(rule, daysUntilDue, vehicle),
      priority: priority,
      createdAt: now,
      actionDate: recommendedDate,
      metadata: {
        'ruleName': rule.name,
        'intervalMonths': rule.intervalMonths,
        'intervalKm': rule.intervalKm,
      },
    );
  }

  /// 車検チェック（履歴ベース、inspectionExpiryDate未設定時のフォールバック）
  AppNotification? _checkCarInspection({
    required Vehicle vehicle,
    required List<MaintenanceRecord> records,
    required String userId,
    required DateTime now,
  }) {
    // 車検記録を検索
    final inspectionRecords = records
        .where((r) => r.type == MaintenanceType.carInspection)
        .toList();

    DateTime nextInspectionDate;

    if (inspectionRecords.isEmpty) {
      // 車検履歴がない場合、年式から計算
      final vehicleAge = now.year - vehicle.year;
      if (vehicleAge < _firstInspectionYears) {
        // 新車初回車検
        nextInspectionDate =
            DateTime(vehicle.year + _firstInspectionYears, now.month, now.day);
      } else {
        // 車検期限不明 - 警告を出す
        return AppNotification(
          id: '${vehicle.id}_inspection_unknown_${now.millisecondsSinceEpoch}',
          userId: userId,
          vehicleId: vehicle.id,
          type: NotificationType.inspectionReminder,
          title: '車検情報を登録してください',
          message:
              '${vehicle.displayName}の車検満了日が未設定です。車両情報を編集して登録してください。',
          priority: NotificationPriority.medium,
          createdAt: now,
        );
      }
    } else {
      // 最新の車検から2年後
      inspectionRecords.sort((a, b) => b.date.compareTo(a.date));
      final lastInspection = inspectionRecords.first.date;
      nextInspectionDate = DateTime(
        lastInspection.year + _subsequentInspectionYears,
        lastInspection.month,
        lastInspection.day,
      );
    }

    // 期限までの日数を計算
    final daysUntilInspection = nextInspectionDate.difference(now).inDays;

    NotificationPriority priority;
    if (daysUntilInspection <= 0) {
      priority = NotificationPriority.high;
    } else if (daysUntilInspection <= 30) {
      priority = NotificationPriority.high;
    } else if (daysUntilInspection <= 90) {
      priority = NotificationPriority.medium;
    } else if (daysUntilInspection <= 180) {
      priority = NotificationPriority.low;
    } else {
      // 6ヶ月以上先は通知不要
      return null;
    }

    String message;
    if (daysUntilInspection <= 0) {
      message =
          '${vehicle.displayName}の車検期限が過ぎています。早急に車検を受けてください。';
    } else if (daysUntilInspection <= 30) {
      message =
          '${vehicle.displayName}の車検期限まであと$daysUntilInspection日です。予約をお忘れなく。';
    } else {
      message =
          '${vehicle.displayName}の車検期限まであと約${(daysUntilInspection / 30).round()}ヶ月です。';
    }

    return AppNotification(
      id: '${vehicle.id}_inspection_${now.millisecondsSinceEpoch}',
      userId: userId,
      vehicleId: vehicle.id,
      type: NotificationType.inspectionReminder,
      title: '車検のお知らせ',
      message: message,
      priority: priority,
      createdAt: now,
      actionDate: nextInspectionDate,
      metadata: {
        'nextInspectionDate': nextInspectionDate.toIso8601String(),
        'daysUntilInspection': daysUntilInspection,
      },
    );
  }

  /// メッセージ生成
  String _generateMessage(MaintenanceRule rule, int daysUntilDue, Vehicle vehicle) {
    final vehicleName = vehicle.displayName;

    if (daysUntilDue <= 0) {
      return '$vehicleNameの${rule.name}の時期を過ぎています。${rule.description}';
    } else if (daysUntilDue <= 7) {
      return '$vehicleNameの${rule.name}まであと$daysUntilDue日です。${rule.description}';
    } else if (daysUntilDue <= 30) {
      return '$vehicleNameの${rule.name}まであと約${(daysUntilDue / 7).round()}週間です。';
    } else {
      return '$vehicleNameの${rule.name}まであと約${(daysUntilDue / 30).round()}ヶ月です。';
    }
  }

  /// キーワードマッチング
  bool _matchesKeywords(String title, String ruleName) {
    final keywords = <String, List<String>>{
      'エンジンオイル交換': ['オイル交換', 'エンジンオイル', 'オイル'],
      'オイルフィルター交換': ['オイルフィルター', 'オイルエレメント'],
      'エアフィルター交換': ['エアフィルター', 'エアクリーナー'],
      'ブレーキパッド点検': ['ブレーキ', 'ブレーキパッド'],
      'タイヤローテーション': ['タイヤ', 'ローテーション'],
      'バッテリー点検': ['バッテリー'],
      '冷却水交換': ['冷却水', 'クーラント', 'LLC'],
      '12ヶ月点検': ['法定点検', '12ヶ月点検', '1年点検', '12ヵ月点検'],
      '24ヶ月点検': ['24ヶ月点検', '2年点検', '24ヵ月点検'],
      'ブレーキフルード交換': ['ブレーキフルード', 'ブレーキオイル'],
      'ATF/CVTフルード交換': ['ATF', 'CVT', 'ミッションオイル'],
      'エアコンフィルター交換': ['エアコンフィルター', 'キャビンフィルター'],
      'ワイパー交換': ['ワイパー', 'ワイパーブレード'],
    };

    final ruleKeywords = keywords[ruleName];
    if (ruleKeywords == null) return false;

    return ruleKeywords.any((keyword) => title.contains(keyword));
  }
}
