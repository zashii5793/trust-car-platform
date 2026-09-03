import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/error/app_error.dart';
import '../core/result/result.dart';

/// A single community trend insight for a specific maintenance type.
class CommunityTrendInsight {
  final String typeKey;
  final double? medianIntervalKm;
  final double? medianIntervalDays;
  final double? medianCost;
  final int sampleCount;
  final double? popularityPercent;
  final String? vehicleModel;

  const CommunityTrendInsight({
    required this.typeKey,
    this.medianIntervalKm,
    this.medianIntervalDays,
    this.medianCost,
    required this.sampleCount,
    this.popularityPercent,
    this.vehicleModel,
  });

  /// Human-readable Japanese description.
  String get description {
    final parts = <String>[];
    final modelLabel = vehicleModel != null ? vehicleModel! : '同車種';
    if (popularityPercent != null) {
      final pct = popularityPercent!.toStringAsFixed(0);
      parts.add('$modelLabel' 'オーナーの$pct%が実施');
    }
    if (medianIntervalKm != null) {
      final km = medianIntervalKm! >= 10000
          ? '${(medianIntervalKm! / 10000).toStringAsFixed(1)}万km'
          : '${medianIntervalKm!.toStringAsFixed(0)}km';
      parts.add('中央値$kmごとに交換');
    }
    if (parts.isEmpty) {
      return '$modelLabel オーナーのデータに基づく傾向';
    }
    return parts.join('・');
  }

  factory CommunityTrendInsight.fromMap(
    Map<String, dynamic> data, {
    String? vehicleModel,
  }) {
    return CommunityTrendInsight(
      typeKey: data['type'] as String? ?? '',
      medianIntervalKm: (data['medianIntervalKm'] as num?)?.toDouble(),
      medianIntervalDays: (data['medianIntervalDays'] as num?)?.toDouble(),
      medianCost: (data['medianCost'] as num?)?.toDouble(),
      sampleCount: data['sampleCount'] as int? ?? 0,
      popularityPercent: (data['popularityPercent'] as num?)?.toDouble(),
      vehicleModel: vehicleModel,
    );
  }

  Map<String, dynamic> toMap() => {
        'type': typeKey,
        if (medianIntervalKm != null) 'medianIntervalKm': medianIntervalKm,
        if (medianIntervalDays != null)
          'medianIntervalDays': medianIntervalDays,
        if (medianCost != null) 'medianCost': medianCost,
        'sampleCount': sampleCount,
        if (popularityPercent != null) 'popularityPercent': popularityPercent,
      };
}

/// Aggregated community maintenance trend data for a vehicle make+model.
class CommunityTrendData {
  final String maker;
  final String model;
  final int sampleVehicleCount;
  final DateTime lastUpdated;
  final List<CommunityTrendInsight> insights;

  const CommunityTrendData({
    required this.maker,
    required this.model,
    required this.sampleVehicleCount,
    required this.lastUpdated,
    required this.insights,
  });

  /// 同じ車種の人の、1年あたりのおおよその整備費用。
  ///
  /// 「あなたのクルマの1年」で比較の相手にする（docs/HABIT_DESIGN.md 打ち手2）。
  /// **自分の数字だけでは良し悪しが分からない。** 18万円が高いのか安いのかは、
  /// 同じ車に乗っている人と比べて初めて分かる。
  ///
  /// トレンドは「この整備を中央値で何日ごとに、いくらで」しか持っていないので、
  /// 1年あたりに割り戻して足し合わせる。半年ごと5,000円なら年10,000円、
  /// 2年ごと80,000円なら年40,000円。
  ///
  /// 使える項目が1つも無ければ null。**推定できないものを0円と書くと、
  /// 「同じ車種の人は年0円」という嘘になる。**
  int? get estimatedAnnualCost {
    var total = 0.0;
    var used = 0;

    for (final insight in insights) {
      final cost = insight.medianCost;
      final days = insight.medianIntervalDays;

      if (cost == null || days == null || days <= 0) continue;
      // 1台の実績を「平均」と呼ばない。
      if (insight.sampleCount < minimumSampleCount) continue;

      total += cost * (365.0 / days);
      used++;
    }

    if (used == 0) return null;
    return total.round();
  }

  /// これ未満の件数しかない項目は、平均として扱わない。
  static const int minimumSampleCount = 3;

  factory CommunityTrendData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CommunityTrendData(
      maker: data['maker'] as String? ?? '',
      model: data['model'] as String? ?? '',
      sampleVehicleCount: data['sampleVehicleCount'] as int? ?? 0,
      lastUpdated:
          (data['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
      insights: ((data['insights'] as List<dynamic>?) ?? [])
          .map((e) => CommunityTrendInsight.fromMap(
                e as Map<String, dynamic>,
                vehicleModel: data['model'] as String?,
              ))
          .toList(),
    );
  }
}

/// Reads and writes anonymized community maintenance trends from Firestore.
/// Privacy: individual user data is never exposed — only pre-aggregated stats.
class CommunityTrendService {
  final FirebaseFirestore _firestore;

  static const _collection = 'community_maintenance_trends';

  CommunityTrendService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Returns pre-aggregated community trends for [maker] + [model].
  /// Returns a failure if no data exists for this make/model.
  Future<Result<CommunityTrendData, AppError>> getTrendsForVehicle({
    required String maker,
    required String model,
  }) async {
    if (maker.isEmpty || model.isEmpty) {
      return const Result.failure(
        AppError.validation('maker and model must not be empty'),
      );
    }

    try {
      final doc =
          await _firestore.collection(_collection).doc('${maker}_$model').get();

      if (!doc.exists) {
        return const Result.failure(
          AppError.notFound('insufficient data for this vehicle'),
        );
      }

      return Result.success(CommunityTrendData.fromFirestore(doc));
    } catch (e) {
      return Result.failure(AppError.unknown(e.toString(), originalError: e));
    }
  }

  /// Submits one vehicle's maintenance data to update community aggregates.
  /// Uses a running average to avoid re-reading all historical records.
  Future<Result<void, AppError>> submitVehicleTrendData({
    required String maker,
    required String model,
    required String maintenanceTypeKey,
    required int intervalKm,
    required int intervalDays,
    required int cost,
  }) async {
    if (maker.isEmpty || model.isEmpty) {
      return const Result.failure(
        AppError.validation('maker and model must not be empty'),
      );
    }
    if (intervalKm < 0 || intervalDays < 0 || cost < 0) {
      return const Result.failure(
        AppError.validation('interval and cost must be non-negative'),
      );
    }

    try {
      final docRef = _firestore.collection(_collection).doc('${maker}_$model');

      await _firestore.runTransaction((tx) async {
        final snapshot = await tx.get(docRef);

        if (!snapshot.exists) {
          tx.set(docRef, {
            'maker': maker,
            'model': model,
            'sampleVehicleCount': 1,
            'lastUpdated': FieldValue.serverTimestamp(),
            'insights': [
              {
                'type': maintenanceTypeKey,
                'medianIntervalKm': intervalKm.toDouble(),
                'medianIntervalDays': intervalDays.toDouble(),
                'medianCost': cost.toDouble(),
                'sampleCount': 1,
                'popularityPercent': 100.0,
              }
            ],
          });
          return;
        }

        final data = snapshot.data() as Map<String, dynamic>;
        final count = (data['sampleVehicleCount'] as int? ?? 0) + 1;
        final existingInsights = List<Map<String, dynamic>>.from(
          ((data['insights'] as List<dynamic>?) ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map)),
        );

        final idx =
            existingInsights.indexWhere((i) => i['type'] == maintenanceTypeKey);

        if (idx >= 0) {
          final old = existingInsights[idx];
          final oldCount = (old['sampleCount'] as int? ?? 1);
          final newCount = oldCount + 1;

          // Running average update
          existingInsights[idx] = {
            ...old,
            'medianIntervalKm':
                _runningAvg(old['medianIntervalKm'], intervalKm, oldCount),
            'medianIntervalDays':
                _runningAvg(old['medianIntervalDays'], intervalDays, oldCount),
            'medianCost': _runningAvg(old['medianCost'], cost, oldCount),
            'sampleCount': newCount,
          };
        } else {
          existingInsights.add({
            'type': maintenanceTypeKey,
            'medianIntervalKm': intervalKm.toDouble(),
            'medianIntervalDays': intervalDays.toDouble(),
            'medianCost': cost.toDouble(),
            'sampleCount': 1,
          });
        }

        tx.update(docRef, {
          'sampleVehicleCount': count,
          'lastUpdated': FieldValue.serverTimestamp(),
          'insights': existingInsights,
        });
      });

      return const Result.success(null);
    } catch (e) {
      return Result.failure(AppError.unknown(e.toString(), originalError: e));
    }
  }

  static double _runningAvg(dynamic oldAvg, num newValue, int oldCount) {
    final old = (oldAvg as num?)?.toDouble() ?? 0;
    return (old * oldCount + newValue) / (oldCount + 1);
  }
}
