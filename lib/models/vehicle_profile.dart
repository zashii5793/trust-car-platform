import 'package:cloud_firestore/cloud_firestore.dart';

import 'maintenance_record.dart';
import 'model_cost_report.dart';

/// 愛車ページ（公開）。`vehicle_profiles/{vehicleId}`
///
/// 「クルマをアバターに」（docs/internal の 2026-09-22 検討・案D）。人ではなく
/// 車を主役にして、その車の投稿・パーツ・公開ドライブを1か所に集める。
///
/// **車両（`vehicles`）そのものは非公開のまま。** 本人が公開を選んだときだけ、
/// 見せてよいものだけをここに写す。走行距離・ナンバー・車検満了日・金額は
/// 写さない。
///
/// 整備の記録は**既定で出さない**（故障歴は売るときに不利になりうる）。
/// 出すと決めたときも、種類と回数・最後の日付だけで、金額は出さない。
class VehicleProfile {
  final String vehicleId;
  final String ownerId;

  /// 持ち主の表示名（公開プロフィールの名前）。
  final String ownerName;
  final String maker;
  final String model;
  final int? year;
  final String? grade;

  /// 車の呼び名（「白いミニ」など）。無ければ 車種 を出す。
  final String? nickname;
  final String? bio;
  final String? imageUrl;

  /// 公開しているか。false の間は本人以外に見えない（ルールで止める）。
  final bool isPublic;

  /// 整備の記録を出すか（種類と回数・最後の日付だけ）。
  final bool showsMaintenance;
  final List<MaintenanceTally> maintenance;
  final DateTime updatedAt;

  const VehicleProfile({
    required this.vehicleId,
    required this.ownerId,
    required this.ownerName,
    required this.maker,
    required this.model,
    this.year,
    this.grade,
    this.nickname,
    this.bio,
    this.imageUrl,
    this.isPublic = false,
    this.showsMaintenance = false,
    this.maintenance = const [],
    required this.updatedAt,
  });

  String get title => (nickname != null && nickname!.trim().isNotEmpty)
      ? nickname!
      : '$maker $model';

  String get specLine => [
        '$maker $model',
        if (grade != null && grade!.isNotEmpty) grade!,
        if (year != null) '$year年式',
      ].join(' ');

  Map<String, dynamic> toMap() => {
        'vehicleId': vehicleId,
        'ownerId': ownerId,
        'ownerName': ownerName,
        'maker': maker,
        'model': model,
        'year': year,
        'grade': grade,
        'nickname': nickname,
        'bio': bio,
        'imageUrl': imageUrl,
        'isPublic': isPublic,
        'showsMaintenance': showsMaintenance,
        // 出さないと決めたときは、中身も書かない（ルールでも確かめる）
        'maintenance': showsMaintenance
            ? maintenance.map((m) => m.toMap()).toList()
            : <Map<String, dynamic>>[],
        'updatedAt': Timestamp.fromDate(updatedAt),
        // 同じ車種の愛車ページを引くためのキー（表記の揺れを揃えたもの）
        'makerKey': modelCostKey(maker),
        'modelKey': modelCostKey(model),
      };

  factory VehicleProfile.fromMap(Map<String, dynamic> m) => VehicleProfile(
        vehicleId: m['vehicleId'] as String? ?? '',
        ownerId: m['ownerId'] as String? ?? '',
        ownerName: m['ownerName'] as String? ?? '',
        maker: m['maker'] as String? ?? '',
        model: m['model'] as String? ?? '',
        year: (m['year'] as num?)?.toInt(),
        grade: m['grade'] as String?,
        nickname: m['nickname'] as String?,
        bio: m['bio'] as String?,
        imageUrl: m['imageUrl'] as String?,
        isPublic: m['isPublic'] as bool? ?? false,
        showsMaintenance: m['showsMaintenance'] as bool? ?? false,
        maintenance: ((m['maintenance'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => MaintenanceTally.fromMap(Map<String, dynamic>.from(e)))
            .toList(),
        updatedAt: (m['updatedAt'] as Timestamp?)?.toDate() ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );
}

/// 整備の種類ごとの回数と、最後にやった日。**金額は持たない。**
class MaintenanceTally {
  final String type;
  final int count;
  final DateTime lastDate;

  const MaintenanceTally({
    required this.type,
    required this.count,
    required this.lastDate,
  });

  Map<String, dynamic> toMap() => {
        'type': type,
        'count': count,
        'lastDate': Timestamp.fromDate(lastDate),
      };

  factory MaintenanceTally.fromMap(Map<String, dynamic> m) => MaintenanceTally(
        type: m['type'] as String? ?? '',
        count: (m['count'] as num?)?.toInt() ?? 0,
        lastDate: (m['lastDate'] as Timestamp?)?.toDate() ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );

  /// 整備記録から、種類ごとの回数と最後の日を数える（多い順）。
  static List<MaintenanceTally> fromRecords(List<MaintenanceRecord> records) {
    final byType = <String, List<DateTime>>{};
    for (final r in records) {
      byType.putIfAbsent(r.type.displayName, () => []).add(r.date);
    }
    final list = byType.entries
        .map((e) => MaintenanceTally(
              type: e.key,
              count: e.value.length,
              lastDate: e.value.reduce((a, b) => a.isAfter(b) ? a : b),
            ))
        .toList()
      ..sort((a, b) {
        final c = b.count.compareTo(a.count);
        return c != 0 ? c : b.lastDate.compareTo(a.lastDate);
      });
    return list;
  }
}
