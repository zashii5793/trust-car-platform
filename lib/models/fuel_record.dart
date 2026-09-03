import 'package:cloud_firestore/cloud_firestore.dart';

/// One visit to the pump.
///
/// `docs/HABIT_DESIGN.md` 打ち手1。**唯一、月単位の接点を作れる行為。**
///
/// ```
///  給油        月2〜4回   ← ここに機能が無かった
///  整備・点検  年2〜4回
///  車検        2年に1回   ← いまの中心機能
/// ```
///
/// 入力は日付・給油量・金額・走行距離の4つまで。**増やすと続かない。**
class FuelRecord {
  final String id;
  final String vehicleId;
  final String userId;

  final DateTime date;

  /// 入れた量（L）。
  final double liters;

  /// 払った額（円）。0 を許す（携行缶・自社給油）。
  final int cost;

  /// そのときのオドメーター（km）。無いと燃費が出せない。
  final int? odometer;

  /// 満タンにしたか。**満タン法の要。**
  ///
  /// 満タンでない給油からは燃費を出せない。次に満タンにするまで、
  /// 何リットル使ったかが確定しないため。
  final bool isFullTank;

  final DateTime createdAt;

  const FuelRecord({
    required this.id,
    required this.vehicleId,
    required this.userId,
    required this.date,
    required this.liters,
    required this.cost,
    required this.isFullTank,
    required this.createdAt,
    this.odometer,
  });

  /// リットル単価。給油量が0なら出さない。
  double? get pricePerLiter {
    if (liters <= 0) return null;
    return cost / liters;
  }

  Map<String, dynamic> toMap() {
    return {
      'vehicleId': vehicleId,
      'userId': userId,
      'date': Timestamp.fromDate(date),
      'liters': liters,
      'cost': cost,
      if (odometer != null) 'odometer': odometer,
      'isFullTank': isFullTank,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory FuelRecord.fromMap(Map<String, dynamic> map, String id) {
    DateTime asDate(Object? v) {
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    return FuelRecord(
      id: id,
      vehicleId: map['vehicleId'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      date: asDate(map['date']),
      liters: (map['liters'] as num?)?.toDouble() ?? 0,
      cost: (map['cost'] as num?)?.toInt() ?? 0,
      odometer: (map['odometer'] as num?)?.toInt(),
      // 分からないものを満タン扱いにしない。でたらめな燃費が出る。
      isFullTank: map['isFullTank'] as bool? ?? false,
      createdAt: asDate(map['createdAt']),
    );
  }

  /// 乗用車のタンクは大きくても100L台。これを超えるのは桁の入力ミス。
  static const double maxLiters = 200;

  static String? validateLiters(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return '給油量を入力してください';

    final liters = double.tryParse(text);
    if (liters == null) return '給油量は数字で入力してください';
    if (liters <= 0) return '給油量を入力してください';
    if (liters > maxLiters) return '給油量が大きすぎます。桁をお確かめください';

    return null;
  }

  static String? validateCost(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return '金額を入力してください';

    final cost = int.tryParse(text.replaceAll(',', ''));
    if (cost == null) return '金額は数字で入力してください';
    if (cost < 0) return '金額を入力してください';

    return null;
  }
}

/// 満タン法で燃費を出す。
///
/// **出せないときは出さない。** でたらめな数字を見せるくらいなら、
/// 「まだ出せません」と言うほうがいい。給油記録は「毎回違う数字が返るから
/// 見たくなる」のが値打ちなので、その数字が嘘だと機能ごと死ぬ。
class FuelEfficiency {
  FuelEfficiency._();

  /// これを外れる値は入力ミスとして扱う。
  ///
  /// 軽トラの実燃費は 10 km/L を下回ることがあり、ハイブリッドは 30 km/L を
  /// 超える。桁の間違い（250 km/L や 0.02 km/L）だけを弾く幅にしてある。
  static const double minPlausible = 1;
  static const double maxPlausible = 100;

  /// 2件から燃費（km/L）を出す。出せなければ null。
  static double? calculate({
    required FuelRecord previousFull,
    required FuelRecord current,
  }) {
    // 今回が満タンでなければ、使った量が確定しない。
    if (!current.isFullTank) return null;

    final from = previousFull.odometer;
    final to = current.odometer;
    if (from == null || to == null) return null;

    final distance = to - from;
    if (distance <= 0) return null;

    if (current.liters <= 0) return null;

    final efficiency = distance / current.liters;
    if (efficiency < minPlausible || efficiency > maxPlausible) return null;

    return efficiency;
  }

  /// 履歴から最新の燃費を出す。出せなければ null。
  ///
  /// 満タンでない給油（継ぎ足し）は、**飛ばすのではなく量に足す。**
  /// 前の満タンから今回の満タンまでに入れた総量で割るのが満タン法。
  static double? latestFor(List<FuelRecord> records) {
    if (records.length < 2) return null;

    final sorted = List<FuelRecord>.from(records)
      ..sort((a, b) => a.date.compareTo(b.date));

    final last = sorted.last;
    if (!last.isFullTank) return null;

    // 直前の満タンを探す。
    var previousFullIndex = -1;
    for (var i = sorted.length - 2; i >= 0; i--) {
      if (sorted[i].isFullTank) {
        previousFullIndex = i;
        break;
      }
    }
    if (previousFullIndex < 0) return null;

    final previousFull = sorted[previousFullIndex];
    final from = previousFull.odometer;
    final to = last.odometer;
    if (from == null || to == null) return null;

    final distance = to - from;
    if (distance <= 0) return null;

    // 前の満タンより後に入れた分をすべて足す（継ぎ足しを含む）。
    var totalLiters = 0.0;
    for (var i = previousFullIndex + 1; i < sorted.length; i++) {
      totalLiters += sorted[i].liters;
    }
    if (totalLiters <= 0) return null;

    final efficiency = distance / totalLiters;
    if (efficiency < minPlausible || efficiency > maxPlausible) return null;

    return efficiency;
  }
}
