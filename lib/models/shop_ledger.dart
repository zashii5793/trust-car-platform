import 'package:cloud_firestore/cloud_firestore.dart';

/// 店の顧客台帳（`docs/SHOP_CRM_DESIGN_2026-09-27.md` §4）。
///
/// **ユーザーの `vehicles` とは別物。** 同じ1台でも、ユーザーにとっては
/// 「自分の車」、店にとっては「お客さんの車」で、持ち主も見たいものも違う。
/// ここに入るのは店が自分で登録した・取り込んだ情報だけで、
/// ユーザーのアプリの中身は1つも写さない。

/// 個人か法人か。法人は1社で何十台も持つので、画面の出し方が変わる。
enum LedgerCustomerKind {
  individual('個人'),
  corporate('法人');

  final String label;
  const LedgerCustomerKind(this.label);

  static LedgerCustomerKind fromName(String? name) =>
      LedgerCustomerKind.values.firstWhere(
        (k) => k.name == name,
        orElse: () => LedgerCustomerKind.individual,
      );
}

/// 顧客がどこから台帳に入ったか。取込をやり直すときの判断に使う。
enum LedgerSource {
  manual,
  csv,
  invite;

  static LedgerSource fromName(String? name) => LedgerSource.values.firstWhere(
        (s) => s.name == name,
        orElse: () => LedgerSource.manual,
      );
}

/// 検索用の正規化。
///
/// Firestore には部分一致の検索が無いので、**前方一致（範囲クエリ）で引ける
/// 形に揃えて保存しておく**。入力する人によって「ヤマダ」「やまだ」「ﾔﾏﾀﾞ」
/// 「山田 太郎」と揺れるため、ここで1つの形にする。
class LedgerSearch {
  LedgerSearch._();

  /// 前方一致の上限に付ける文字。これより後ろに並ぶ文字は実質無い。
  static const String rangeEnd = '';

  /// 名前・フリガナの検索キー。
  ///
  /// - 半角カナ → 全角カナ（濁点・半濁点の結合を含む）
  /// - カタカナ → ひらがな
  /// - 全角英数 → 半角、英字は小文字
  /// - 空白（全角・半角）を取り除く
  static String nameKey(String input) {
    final halfToFull = _halfwidthKanaToFullwidth(input);
    final buffer = StringBuffer();
    for (final rune in halfToFull.runes) {
      var r = rune;
      // 全角英数・記号 → 半角
      if (r >= 0xFF01 && r <= 0xFF5E) r -= 0xFEE0;
      // カタカナ → ひらがな（ヴ・ヵ・ヶ を含む範囲）
      if (r >= 0x30A1 && r <= 0x30F6) r -= 0x60;
      if (r == 0x20 || r == 0x3000) continue;
      buffer.writeCharCode(r);
    }
    return buffer.toString().toLowerCase();
  }

  /// ナンバーの検索キー。
  ///
  /// 「品川 300 あ 12-34」「品川300あ1234」「１２－３４」を同じ形にする。
  /// 空白とハイフン（各種）を落とし、全角数字を半角にする。
  static String plateKey(String input) {
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      var r = rune;
      if (r >= 0xFF01 && r <= 0xFF5E) r -= 0xFEE0;
      if (r == 0x20 || r == 0x3000) continue;
      // - ‐ ‑ ‒ – — ― − ー（ナンバーの区切りに使われがちなもの）
      if (const {0x2D, 0x2010, 0x2011, 0x2012, 0x2013, 0x2014, 0x2015, 0x2212}
          .contains(r)) {
        continue;
      }
      if (r == 0x30FC && buffer.isNotEmpty && _isDigit(_lastRune(buffer))) {
        continue;
      }
      buffer.writeCharCode(r);
    }
    return buffer.toString().toLowerCase();
  }

  /// ナンバーの末尾の番号（一連指定番号）。「品川300あ12-34」なら "1234"。
  ///
  /// **窓口で聞かれるのは末尾の4桁**なので、そこだけで完全一致で引けるように
  /// しておく。地名から始まる前方一致では、4桁では引けない。
  static String? plateNumber(String input) {
    final match = RegExp(r'(\d{1,4})$').firstMatch(plateKey(input));
    return match?.group(1);
  }

  static bool _isDigit(int r) => r >= 0x30 && r <= 0x39;

  static int _lastRune(StringBuffer b) {
    final s = b.toString();
    return s.runes.last;
  }

  static const Map<String, String> _halfKana = {
    'ｦ': 'ヲ',
    'ｧ': 'ァ',
    'ｨ': 'ィ',
    'ｩ': 'ゥ',
    'ｪ': 'ェ',
    'ｫ': 'ォ',
    'ｬ': 'ャ',
    'ｭ': 'ュ',
    'ｮ': 'ョ',
    'ｯ': 'ッ',
    'ｰ': 'ー',
    'ｱ': 'ア',
    'ｲ': 'イ',
    'ｳ': 'ウ',
    'ｴ': 'エ',
    'ｵ': 'オ',
    'ｶ': 'カ',
    'ｷ': 'キ',
    'ｸ': 'ク',
    'ｹ': 'ケ',
    'ｺ': 'コ',
    'ｻ': 'サ',
    'ｼ': 'シ',
    'ｽ': 'ス',
    'ｾ': 'セ',
    'ｿ': 'ソ',
    'ﾀ': 'タ',
    'ﾁ': 'チ',
    'ﾂ': 'ツ',
    'ﾃ': 'テ',
    'ﾄ': 'ト',
    'ﾅ': 'ナ',
    'ﾆ': 'ニ',
    'ﾇ': 'ヌ',
    'ﾈ': 'ネ',
    'ﾉ': 'ノ',
    'ﾊ': 'ハ',
    'ﾋ': 'ヒ',
    'ﾌ': 'フ',
    'ﾍ': 'ヘ',
    'ﾎ': 'ホ',
    'ﾏ': 'マ',
    'ﾐ': 'ミ',
    'ﾑ': 'ム',
    'ﾒ': 'メ',
    'ﾓ': 'モ',
    'ﾔ': 'ヤ',
    'ﾕ': 'ユ',
    'ﾖ': 'ヨ',
    'ﾗ': 'ラ',
    'ﾘ': 'リ',
    'ﾙ': 'ル',
    'ﾚ': 'レ',
    'ﾛ': 'ロ',
    'ﾜ': 'ワ',
    'ﾝ': 'ン',
  };

  static const Map<String, String> _dakuten = {
    'カ': 'ガ',
    'キ': 'ギ',
    'ク': 'グ',
    'ケ': 'ゲ',
    'コ': 'ゴ',
    'サ': 'ザ',
    'シ': 'ジ',
    'ス': 'ズ',
    'セ': 'ゼ',
    'ソ': 'ゾ',
    'タ': 'ダ',
    'チ': 'ヂ',
    'ツ': 'ヅ',
    'テ': 'デ',
    'ト': 'ド',
    'ハ': 'バ',
    'ヒ': 'ビ',
    'フ': 'ブ',
    'ヘ': 'ベ',
    'ホ': 'ボ',
    'ウ': 'ヴ',
  };

  static const Map<String, String> _handakuten = {
    'ハ': 'パ',
    'ヒ': 'ピ',
    'フ': 'プ',
    'ヘ': 'ペ',
    'ホ': 'ポ',
  };

  static String _halfwidthKanaToFullwidth(String input) {
    final out = StringBuffer();
    final chars = input.split('');
    for (var i = 0; i < chars.length; i++) {
      final c = chars[i];
      final full = _halfKana[c];
      if (full == null) {
        out.write(c);
        continue;
      }
      final next = i + 1 < chars.length ? chars[i + 1] : null;
      if (next == 'ﾞ' && _dakuten.containsKey(full)) {
        out.write(_dakuten[full]);
        i++;
      } else if (next == 'ﾟ' && _handakuten.containsKey(full)) {
        out.write(_handakuten[full]);
        i++;
      } else {
        out.write(full);
      }
    }
    return out.toString();
  }
}

DateTime? _date(dynamic v) => v is Timestamp ? v.toDate() : null;

String? _nonEmpty(String? v) {
  final t = v?.trim();
  return (t == null || t.isEmpty) ? null : t;
}

/// 台帳の顧客1件。`shops/{shopId}/customers/{id}`
class LedgerCustomer {
  final String id;
  final LedgerCustomerKind kind;

  /// 個人なら氏名、法人なら会社名。
  final String name;
  final String? nameKana;

  /// 法人の担当者。個人では使わない。
  final String? contactPerson;
  final String? phone;
  final String? email;
  final String? postalCode;
  final String? address;
  final String? note;

  /// 整備管理ソフトの顧客番号。**取込をやり直したときに二重にしないため。**
  final String? externalId;

  /// 以下は車両から計算して持たせる値（一覧で並べ替えるため）。
  final int vehicleCount;

  /// 持っている車のうち、いちばん近い（まだ来ていない）車検満了日。
  final DateTime? nextInspectionAt;
  final DateTime? lastVisitAt;

  /// アプリのユーザーとつながっているか。
  final String? linkedUserId;
  final LedgerSource source;
  final DateTime createdAt;
  final DateTime updatedAt;

  const LedgerCustomer({
    required this.id,
    required this.kind,
    required this.name,
    this.nameKana,
    this.contactPerson,
    this.phone,
    this.email,
    this.postalCode,
    this.address,
    this.note,
    this.externalId,
    this.vehicleCount = 0,
    this.nextInspectionAt,
    this.lastVisitAt,
    this.linkedUserId,
    this.source = LedgerSource.manual,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isLinked => linkedUserId != null;

  /// 検索キー。フリガナがあればフリガナ、無ければ名前から作る。
  ///
  /// **名前（漢字）では前方一致が役に立たない**（「山田」で引きたい人と
  /// 「やまだ」で引きたい人がいる）ので、フリガナを優先する。
  String get searchKey => LedgerSearch.nameKey(_nonEmpty(nameKana) ?? name);

  /// 並べ替え用のキー。検索キーと同じだが、意味が違うので分けて持つ。
  String get sortKey => searchKey;

  Map<String, dynamic> toMap() => {
        'kind': kind.name,
        'name': name.trim(),
        'nameKana': _nonEmpty(nameKana),
        'contactPerson': _nonEmpty(contactPerson),
        'phone': _nonEmpty(phone),
        'email': _nonEmpty(email),
        'postalCode': _nonEmpty(postalCode),
        'address': _nonEmpty(address),
        'note': _nonEmpty(note),
        'externalId': _nonEmpty(externalId),
        'searchKey': searchKey,
        'vehicleCount': vehicleCount,
        'nextInspectionAt': nextInspectionAt != null
            ? Timestamp.fromDate(nextInspectionAt!)
            : null,
        'lastVisitAt':
            lastVisitAt != null ? Timestamp.fromDate(lastVisitAt!) : null,
        'linkedUserId': linkedUserId,
        'isLinked': isLinked,
        'source': source.name,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  factory LedgerCustomer.fromMap(String id, Map<String, dynamic> m) {
    return LedgerCustomer(
      id: id,
      kind: LedgerCustomerKind.fromName(m['kind'] as String?),
      name: m['name'] as String? ?? '',
      nameKana: m['nameKana'] as String?,
      contactPerson: m['contactPerson'] as String?,
      phone: m['phone'] as String?,
      email: m['email'] as String?,
      postalCode: m['postalCode'] as String?,
      address: m['address'] as String?,
      note: m['note'] as String?,
      externalId: m['externalId'] as String?,
      vehicleCount: (m['vehicleCount'] as num?)?.toInt() ?? 0,
      nextInspectionAt: _date(m['nextInspectionAt']),
      lastVisitAt: _date(m['lastVisitAt']),
      linkedUserId: m['linkedUserId'] as String?,
      source: LedgerSource.fromName(m['source'] as String?),
      createdAt:
          _date(m['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          _date(m['updatedAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  LedgerCustomer copyWith({
    LedgerCustomerKind? kind,
    String? name,
    String? nameKana,
    String? contactPerson,
    String? phone,
    String? email,
    String? postalCode,
    String? address,
    String? note,
    int? vehicleCount,
    DateTime? nextInspectionAt,
    bool clearNextInspection = false,
    DateTime? lastVisitAt,
    DateTime? updatedAt,
  }) {
    return LedgerCustomer(
      id: id,
      kind: kind ?? this.kind,
      name: name ?? this.name,
      nameKana: nameKana ?? this.nameKana,
      contactPerson: contactPerson ?? this.contactPerson,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      postalCode: postalCode ?? this.postalCode,
      address: address ?? this.address,
      note: note ?? this.note,
      externalId: externalId,
      vehicleCount: vehicleCount ?? this.vehicleCount,
      nextInspectionAt: clearNextInspection
          ? null
          : (nextInspectionAt ?? this.nextInspectionAt),
      lastVisitAt: lastVisitAt ?? this.lastVisitAt,
      linkedUserId: linkedUserId,
      source: source,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// 台帳の車両1台。`shops/{shopId}/customer_vehicles/{id}`
///
/// **顧客の下ではなく店の直下に置く。** 「今月車検の車」を顧客をまたいで
/// 満了日順に出すため。サブコレクションにすると店全体で並べられない。
class LedgerVehicle {
  final String id;
  final String customerId;

  /// 一覧で顧客を引き直さずに済むよう、名前を写して持つ。
  final String customerName;
  final String? plate;
  final String maker;
  final String model;
  final int? year;
  final String? modelCode;
  final String? vin;
  final DateTime? inspectionExpiry;
  final DateTime? lastVisitAt;
  final int? lastMileage;
  final String? externalId;

  /// 車検の案内（はがき・DM の宛名）を書き出した日。
  final DateTime? inspectionNoticeAt;

  /// そのとき案内した満了日。**車検を通して満了日が進んだら、次の案内の
  /// 対象に戻す**ために、案内した日と別に持つ。
  final DateTime? inspectionNoticeExpiry;

  /// Date of the latest inspection (車検) service record for this car.
  ///
  /// Written by the service-record import so the loss report can tell
  /// "came back for the inspection" from the vehicle alone, without
  /// reading every service record. A stored `null` means "imported, and
  /// there is no inspection record"; a missing field means "not known yet"
  /// (data from before 2026-10-09).
  final DateTime? lastInspectionAt;

  /// The expiry that [lastInspectionAt] was for. Lets the loss report put
  /// a car whose expiry has already moved two years ahead (the roster was
  /// re-imported) back into the month it was due.
  final DateTime? lastInspectionDueAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const LedgerVehicle({
    required this.id,
    required this.customerId,
    required this.customerName,
    this.plate,
    required this.maker,
    required this.model,
    this.year,
    this.modelCode,
    this.vin,
    this.inspectionExpiry,
    this.lastVisitAt,
    this.lastMileage,
    this.externalId,
    this.inspectionNoticeAt,
    this.inspectionNoticeExpiry,
    this.lastInspectionAt,
    this.lastInspectionDueAt,
    required this.createdAt,
    required this.updatedAt,
  });

  String get displayName => '$maker $model'.trim();

  /// いまの満了日について、もう案内を出したか。
  bool get isNoticedForCurrentExpiry {
    final a = inspectionExpiry;
    final b = inspectionNoticeExpiry;
    if (a == null || b == null || inspectionNoticeAt == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Map<String, dynamic> toMap() => {
        'customerId': customerId,
        'customerName': customerName,
        'plate': _nonEmpty(plate),
        'plateKey': plate == null ? null : LedgerSearch.plateKey(plate!),
        'plateNumber': plate == null ? null : LedgerSearch.plateNumber(plate!),
        'maker': maker.trim(),
        'model': model.trim(),
        'year': year,
        'modelCode': _nonEmpty(modelCode),
        'vin': _nonEmpty(vin),
        'inspectionExpiry': inspectionExpiry != null
            ? Timestamp.fromDate(inspectionExpiry!)
            : null,
        'lastVisitAt':
            lastVisitAt != null ? Timestamp.fromDate(lastVisitAt!) : null,
        'lastMileage': lastMileage,
        'externalId': _nonEmpty(externalId),
        // 案内した日は、無いときは書かない。名簿の取込は merge で書くので、
        // null を書くと案内した日が消えてしまう。
        if (inspectionNoticeAt != null)
          'inspectionNoticeAt': Timestamp.fromDate(inspectionNoticeAt!),
        if (inspectionNoticeExpiry != null)
          'inspectionNoticeExpiry': Timestamp.fromDate(inspectionNoticeExpiry!),
        // Same as above: the roster import merges, so a null here would
        // erase what the service-record import found.
        if (lastInspectionAt != null)
          'lastInspectionAt': Timestamp.fromDate(lastInspectionAt!),
        if (lastInspectionDueAt != null)
          'lastInspectionDueAt': Timestamp.fromDate(lastInspectionDueAt!),
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  factory LedgerVehicle.fromMap(String id, Map<String, dynamic> m) {
    return LedgerVehicle(
      id: id,
      customerId: m['customerId'] as String? ?? '',
      customerName: m['customerName'] as String? ?? '',
      plate: m['plate'] as String?,
      maker: m['maker'] as String? ?? '',
      model: m['model'] as String? ?? '',
      year: (m['year'] as num?)?.toInt(),
      modelCode: m['modelCode'] as String?,
      vin: m['vin'] as String?,
      inspectionExpiry: _date(m['inspectionExpiry']),
      lastVisitAt: _date(m['lastVisitAt']),
      lastMileage: (m['lastMileage'] as num?)?.toInt(),
      externalId: m['externalId'] as String?,
      inspectionNoticeAt: _date(m['inspectionNoticeAt']),
      inspectionNoticeExpiry: _date(m['inspectionNoticeExpiry']),
      lastInspectionAt: _date(m['lastInspectionAt']),
      lastInspectionDueAt: _date(m['lastInspectionDueAt']),
      createdAt:
          _date(m['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          _date(m['updatedAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

/// 車検案内の宛名1件（車1台と、その持ち主）。
class InspectionNoticeTarget {
  final LedgerCustomer customer;
  final LedgerVehicle vehicle;

  const InspectionNoticeTarget({required this.customer, required this.vehicle});
}

/// 顧客の要約値を、持っている車両から計算し直す。
///
/// 一覧で「車検の近い順」「最後に来た日」を並べ替えるには、顧客の
/// ドキュメント自体にその値が要る（Firestore は別コレクションを見て
/// 並べられない）。車両を足し引きするたびにここで作り直す。
class LedgerCustomerSummary {
  final int vehicleCount;
  final DateTime? nextInspectionAt;
  final DateTime? lastVisitAt;

  const LedgerCustomerSummary({
    required this.vehicleCount,
    this.nextInspectionAt,
    this.lastVisitAt,
  });

  /// [today] より前の満了日は「次の車検」に数えない。
  /// **切れた車検を「いちばん近い」と出すと、案内の順番が狂う。**
  factory LedgerCustomerSummary.of(
    Iterable<LedgerVehicle> vehicles, {
    required DateTime today,
  }) {
    final startOfToday = DateTime(today.year, today.month, today.day);
    DateTime? next;
    DateTime? last;
    var count = 0;
    for (final v in vehicles) {
      count++;
      final exp = v.inspectionExpiry;
      if (exp != null &&
          !exp.isBefore(startOfToday) &&
          (next == null || exp.isBefore(next))) {
        next = exp;
      }
      final visit = v.lastVisitAt;
      if (visit != null && (last == null || visit.isAfter(last))) {
        last = visit;
      }
    }
    return LedgerCustomerSummary(
      vehicleCount: count,
      nextInspectionAt: next,
      lastVisitAt: last,
    );
  }
}

/// 台帳の件数（画面上部に出す）。
class LedgerCounts {
  final int total;
  final int individual;
  final int corporate;
  final int linked;

  const LedgerCounts({
    required this.total,
    required this.individual,
    required this.corporate,
    required this.linked,
  });

  static const empty =
      LedgerCounts(total: 0, individual: 0, corporate: 0, linked: 0);
}
