import 'package:cloud_firestore/cloud_firestore.dart';
import 'maintenance_record.dart';

/// 1つの整備項目に対するユーザーのカスタム交換間隔。
///
/// 値が null のフィールドは「標準値を使う」を意味する。
class IntervalOverride {
  final int? intervalKm;
  final int? intervalMonths;

  const IntervalOverride({this.intervalKm, this.intervalMonths});

  bool get isEmpty => intervalKm == null && intervalMonths == null;

  Map<String, dynamic> toMap() => {
        if (intervalKm != null) 'intervalKm': intervalKm,
        if (intervalMonths != null) 'intervalMonths': intervalMonths,
      };

  factory IntervalOverride.fromMap(Map<String, dynamic> m) => IntervalOverride(
        intervalKm: (m['intervalKm'] as num?)?.toInt(),
        intervalMonths: (m['intervalMonths'] as num?)?.toInt(),
      );
}

/// 車両ごとの「交換目安」ユーザー設定。
///
/// 乗り方によって最適な交換間隔は変わるため、標準値を上書きできるようにする。
/// キーは [MaintenanceType.name]。
class MaintenancePreferences {
  final String vehicleId;
  final String userId;
  final Map<String, IntervalOverride> overrides;

  const MaintenancePreferences({
    required this.vehicleId,
    required this.userId,
    this.overrides = const {},
  });

  factory MaintenancePreferences.empty(String vehicleId, String userId) =>
      MaintenancePreferences(vehicleId: vehicleId, userId: userId);

  /// 指定タイプのユーザー上書き（無ければ null = 標準値）。
  IntervalOverride? forType(MaintenanceType type) => overrides[type.name];

  /// 上書きを設定／解除した新しいインスタンスを返す。
  MaintenancePreferences withOverride(
      MaintenanceType type, IntervalOverride? override) {
    final next = Map<String, IntervalOverride>.from(overrides);
    if (override == null || override.isEmpty) {
      next.remove(type.name);
    } else {
      next[type.name] = override;
    }
    return MaintenancePreferences(
      vehicleId: vehicleId,
      userId: userId,
      overrides: next,
    );
  }

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'overrides': overrides.map((k, v) => MapEntry(k, v.toMap())),
        'updatedAt': Timestamp.now(),
      };

  factory MaintenancePreferences.fromFirestore(
    String vehicleId,
    DocumentSnapshot doc,
  ) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final raw = (data['overrides'] as Map<String, dynamic>?) ?? {};
    return MaintenancePreferences(
      vehicleId: vehicleId,
      userId: (data['userId'] ?? '') as String,
      overrides: raw.map(
        (k, v) => MapEntry(
          k,
          IntervalOverride.fromMap(Map<String, dynamic>.from(v as Map)),
        ),
      ),
    );
  }
}
