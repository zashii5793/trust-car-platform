import 'package:cloud_firestore/cloud_firestore.dart';

/// 初めて行く店に渡す「この車のこれまで」の写し。
///
/// `docs/SHOP_CRM_DESIGN_2026-09-27.md` §7。`shops/{shopId}/shared_vehicles/{vehicleId}`
///
/// **生きたデータを開けずに、写しを渡す。** カルテを手渡しするのと同じで、
/// 何を・いつ・どこに渡したかがはっきりする。店に `vehicles` や
/// `maintenance_records` を開けると、取り消したあとに何が残ったかが
/// 分からなくなる。
///
/// 中身はユーザーが選ぶ（ナンバーを出すか、費用を出すか、連絡先を出すか）。

/// 写しに入れる整備記録1件。店が読むのに要るものだけ。
class SharedRecord {
  final DateTime date;
  final String type;
  final String title;
  final int? cost;
  final int? mileage;
  final String? shopName;

  const SharedRecord({
    required this.date,
    required this.type,
    required this.title,
    this.cost,
    this.mileage,
    this.shopName,
  });

  Map<String, dynamic> toMap() => {
        'date': Timestamp.fromDate(date),
        'type': type,
        'title': title,
        if (cost != null) 'cost': cost,
        if (mileage != null) 'mileage': mileage,
        if (shopName != null && shopName!.isNotEmpty) 'shopName': shopName,
      };

  factory SharedRecord.fromMap(Map<String, dynamic> m) => SharedRecord(
        date: (m['date'] as Timestamp?)?.toDate() ??
            DateTime.fromMillisecondsSinceEpoch(0),
        type: m['type'] as String? ?? '',
        title: m['title'] as String? ?? '',
        cost: (m['cost'] as num?)?.toInt(),
        mileage: (m['mileage'] as num?)?.toInt(),
        shopName: m['shopName'] as String?,
      );
}

class VehicleShare {
  /// = 車両ID。同じ車を同じ店にもう一度渡したら、上書きになる。
  final String vehicleId;
  final String shopId;
  final String shopName;
  final String ownerId;

  /// 連絡先。**渡すかどうかはユーザーが決める。** 渡さなければ null。
  final String? contactName;
  final String? contactPhone;

  /// 店への一言（「車検の見積もりをお願いします」など）。
  final String? message;

  final String maker;
  final String model;
  final int? year;
  final String? grade;
  final String? plate;
  final int? mileage;
  final DateTime? inspectionExpiry;

  final List<SharedRecord> records;

  /// 費用を含めたか。含めないときは records の cost が全部 null。
  final bool includesCosts;

  final DateTime sharedAt;
  final DateTime expiresAt;

  /// 店が開いた日時・台帳に登録した顧客ID。店側だけが書く。
  final DateTime? seenAt;
  final String? importedCustomerId;

  const VehicleShare({
    required this.vehicleId,
    required this.shopId,
    required this.shopName,
    required this.ownerId,
    this.contactName,
    this.contactPhone,
    this.message,
    required this.maker,
    required this.model,
    this.year,
    this.grade,
    this.plate,
    this.mileage,
    this.inspectionExpiry,
    this.records = const [],
    this.includesCosts = false,
    required this.sharedAt,
    required this.expiresAt,
    this.seenAt,
    this.importedCustomerId,
  });

  String get displayName => '$maker $model'.trim();

  bool isExpiredAt(DateTime now) => !expiresAt.isAfter(now);

  Map<String, dynamic> toMap() => {
        'vehicleId': vehicleId,
        'shopId': shopId,
        'shopName': shopName,
        'ownerId': ownerId,
        'contactName': contactName,
        'contactPhone': contactPhone,
        'message': message,
        'maker': maker,
        'model': model,
        'year': year,
        'grade': grade,
        'plate': plate,
        'mileage': mileage,
        'inspectionExpiry': inspectionExpiry == null
            ? null
            : Timestamp.fromDate(inspectionExpiry!),
        'records': records.map((r) => r.toMap()).toList(),
        'includesCosts': includesCosts,
        'sharedAt': Timestamp.fromDate(sharedAt),
        'expiresAt': Timestamp.fromDate(expiresAt),
      };

  factory VehicleShare.fromMap(Map<String, dynamic> m) {
    DateTime? d(String k) => (m[k] as Timestamp?)?.toDate();
    final epoch = DateTime.fromMillisecondsSinceEpoch(0);
    return VehicleShare(
      vehicleId: m['vehicleId'] as String? ?? '',
      shopId: m['shopId'] as String? ?? '',
      shopName: m['shopName'] as String? ?? '',
      ownerId: m['ownerId'] as String? ?? '',
      contactName: m['contactName'] as String?,
      contactPhone: m['contactPhone'] as String?,
      message: m['message'] as String?,
      maker: m['maker'] as String? ?? '',
      model: m['model'] as String? ?? '',
      year: (m['year'] as num?)?.toInt(),
      grade: m['grade'] as String?,
      plate: m['plate'] as String?,
      mileage: (m['mileage'] as num?)?.toInt(),
      inspectionExpiry: d('inspectionExpiry'),
      records: ((m['records'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => SharedRecord.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      includesCosts: m['includesCosts'] as bool? ?? false,
      sharedAt: d('sharedAt') ?? epoch,
      expiresAt: d('expiresAt') ?? epoch,
      seenAt: d('seenAt'),
      importedCustomerId: m['importedCustomerId'] as String?,
    );
  }
}

/// 「どの店に共有中か」（本人が見る一覧の1行）。
class ActiveShare {
  final String shopId;
  final String shopName;
  final DateTime? expiresAt;

  const ActiveShare({
    required this.shopId,
    required this.shopName,
    this.expiresAt,
  });
}
