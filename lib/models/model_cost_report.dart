import 'package:cloud_firestore/cloud_firestore.dart';

import 'shop_ledger.dart';

/// 車種別の維持費レポート（`docs/SHOP_CRM_DESIGN_2026-09-27.md` §8）。
///
/// サーバー（functions/src/modelCostReport.ts の aggregateModelCosts）が毎晩
/// 書く。**持ち主が5人以上いる車種・メーカーだけ**が入っている。

/// 表記の揺れを揃えたキー。
///
/// **サーバー側の normalizeKey と1文字も違わない規則にしてある**
/// （test/fixtures/model_cost_key_vectors.json を両方のテストが読む）。
/// ずれると、レポートがあるのに「まだありません」と出る。
String modelCostKey(String s) => LedgerSearch.nameKey(
      s.replaceAll(RegExp(r'[\t\n\r]'), ''),
    ).replaceAll('/', '_');

/// 車種のレポートのID。
String modelCostReportId(String maker, String model) =>
    '${modelCostKey(maker)}__${modelCostKey(model)}';

/// 中央値と幅（25%〜75%）。n は持ち主の人数。
class CostStat {
  final int median;
  final int p25;
  final int p75;
  final int n;

  const CostStat({
    required this.median,
    required this.p25,
    required this.p75,
    required this.n,
  });

  static CostStat? fromMap(Object? v) {
    if (v is! Map) return null;
    return CostStat(
      median: (v['median'] as num?)?.round() ?? 0,
      p25: (v['p25'] as num?)?.round() ?? 0,
      p75: (v['p75'] as num?)?.round() ?? 0,
      n: (v['n'] as num?)?.toInt() ?? 0,
    );
  }
}

class CostByAge {
  final String label;
  final int median;
  final int n;

  const CostByAge({required this.label, required this.median, required this.n});
}

class CostTopItem {
  final String type;
  final int owners;
  final int medianCost;

  const CostTopItem({
    required this.type,
    required this.owners,
    required this.medianCost,
  });
}

class ModelCostReport {
  final String id;

  /// 'model'（車種）か 'maker'（メーカー全体。車種で人数が足りないとき）。
  final bool isMakerLevel;
  final String maker;
  final String? model;
  final int ownerCount;
  final int vehicleCount;
  final CostStat? maintenanceAnnual;
  final CostStat? inspectionPerEvent;
  final CostStat? fuelAnnual;
  final int? annualEstimate;
  final List<CostByAge> byAge;
  final List<CostTopItem> topItems;
  final int appOwners;
  final int shopOwners;
  final DateTime? updatedAt;

  const ModelCostReport({
    required this.id,
    required this.isMakerLevel,
    required this.maker,
    required this.model,
    required this.ownerCount,
    required this.vehicleCount,
    this.maintenanceAnnual,
    this.inspectionPerEvent,
    this.fuelAnnual,
    this.annualEstimate,
    this.byAge = const [],
    this.topItems = const [],
    this.appOwners = 0,
    this.shopOwners = 0,
    this.updatedAt,
  });

  String get title => model == null ? '$maker（メーカー全体）' : '$maker $model';

  factory ModelCostReport.fromMap(String id, Map<String, dynamic> m) {
    final sources = m['sources'];
    return ModelCostReport(
      id: id,
      isMakerLevel: m['level'] == 'maker',
      maker: m['maker'] as String? ?? '',
      model: m['model'] as String?,
      ownerCount: (m['ownerCount'] as num?)?.toInt() ?? 0,
      vehicleCount: (m['vehicleCount'] as num?)?.toInt() ?? 0,
      maintenanceAnnual: CostStat.fromMap(m['maintenanceAnnual']),
      inspectionPerEvent: CostStat.fromMap(m['inspectionPerEvent']),
      fuelAnnual: CostStat.fromMap(m['fuelAnnual']),
      annualEstimate: (m['annualEstimate'] as num?)?.round(),
      byAge: ((m['byAge'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => CostByAge(
                label: e['label'] as String? ?? '',
                median: (e['median'] as num?)?.round() ?? 0,
                n: (e['n'] as num?)?.toInt() ?? 0,
              ))
          .toList(),
      topItems: ((m['topItems'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => CostTopItem(
                type: e['type'] as String? ?? '',
                owners: (e['owners'] as num?)?.toInt() ?? 0,
                medianCost: (e['medianCost'] as num?)?.round() ?? 0,
              ))
          .toList(),
      appOwners: sources is Map ? (sources['app'] as num?)?.toInt() ?? 0 : 0,
      shopOwners: sources is Map ? (sources['shop'] as num?)?.toInt() ?? 0 : 0,
      updatedAt: (m['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}
