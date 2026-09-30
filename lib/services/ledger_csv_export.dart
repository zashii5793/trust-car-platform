import '../models/shop_ledger.dart';
import 'ledger_csv_import.dart';

/// 顧客台帳を CSV に書き出す（2026-09-29 プロダクト評価 #8・#2）。
///
/// - [buildLedgerCsv]: 台帳の全件。**やめるときに持ち出せる**こと、そして
///   **書き出したものをそのまま取り込み直せる**ことを先に決めてある。
///   見出しは取込（`ledger_csv_import.dart`）の列名と同じにしてある
/// - [buildInspectionNoticeCsv]: 車検案内のはがき・DM を業者に頼むときの宛名
///
/// どちらも Excel で開かれる前提で、先頭に BOM を付ける（付けないと
/// Windows の Excel が Shift_JIS として読み、文字化けする）。
///
/// ここは Firestore に触らない（純粋な変換だけ）。読むのは
/// `ShopLedgerService.exportAll` / `inspectionNoticeTargets`。

const String _bom = '\u{FEFF}';

/// 取込に無い項目。取り込み直すときは読まれない（店が手で入れた情報は
/// 取込で上書きしない、という取込の決まりのとおり）。
const String _noteHeader = 'メモ';
const String _noticeHeader = '車検案内日';

/// 台帳の全件の見出し。取込の項目の並び＋取込に無い項目。
List<String> get ledgerExportHeaders => [
      for (final f in LedgerImportField.values) f.label,
      _noteHeader,
      _noticeHeader,
    ];

/// 車検案内の宛名の見出し。業者に渡す最小限の7列。
const List<String> inspectionNoticeHeaders = [
  '氏名',
  '郵便番号',
  '住所',
  '電話番号',
  '車名',
  '登録番号',
  '車検満了日',
];

/// 台帳の全件を、1行＝車両1台で書き出す。車の無い顧客は1行（車の欄は空）。
///
/// - 顧客はフリガナ順、同じ顧客の車は満了日の近い順
/// - 顧客番号・車両番号の無い（手で登録した）ものは、台帳のIDをその欄に
///   入れる。取込はそれを見て同じ顧客・車両に書き戻す（二重にしない）
/// - 持ち主が見つからない車も落とさない（車に写してある名前で出す）
String buildLedgerCsv({
  required List<LedgerCustomer> customers,
  required List<LedgerVehicle> vehicles,
}) {
  final buffer = StringBuffer(_bom);
  buffer.writeln(ledgerExportHeaders.map(_escape).join(','));

  final byCustomer = <String, List<LedgerVehicle>>{};
  for (final v in vehicles) {
    byCustomer.putIfAbsent(v.customerId, () => []).add(v);
  }
  for (final list in byCustomer.values) {
    list.sort(_byExpiry);
  }

  final sorted = List<LedgerCustomer>.from(customers)
    ..sort((a, b) => a.sortKey.compareTo(b.sortKey));

  for (final c in sorted) {
    final own = byCustomer.remove(c.id) ?? const <LedgerVehicle>[];
    if (own.isEmpty) {
      buffer.writeln(_ledgerRow(c, null));
    } else {
      for (final v in own) {
        buffer.writeln(_ledgerRow(c, v));
      }
    }
  }

  // 持ち主のいない車（本来は無い。消し損ねなど）
  for (final entry in byCustomer.entries) {
    for (final v in entry.value) {
      final orphan = LedgerCustomer(
        id: entry.key,
        kind: LedgerCustomerKind.individual,
        name: v.customerName.isEmpty ? '（持ち主不明）' : v.customerName,
        createdAt: v.createdAt,
        updatedAt: v.updatedAt,
      );
      buffer.writeln(_ledgerRow(orphan, v));
    }
  }

  return buffer.toString();
}

String _ledgerRow(LedgerCustomer c, LedgerVehicle? v) {
  String value(LedgerImportField f) => switch (f) {
        LedgerImportField.customerExternalId => c.externalId ?? c.id,
        LedgerImportField.customerName => c.name,
        LedgerImportField.customerKana => c.nameKana ?? '',
        LedgerImportField.corporateFlag =>
          c.kind == LedgerCustomerKind.corporate ? '法人' : '個人',
        LedgerImportField.contactPerson => c.contactPerson ?? '',
        LedgerImportField.phone => c.phone ?? '',
        LedgerImportField.email => c.email ?? '',
        LedgerImportField.postalCode => c.postalCode ?? '',
        LedgerImportField.address => c.address ?? '',
        LedgerImportField.vehicleExternalId =>
          v == null ? '' : (v.externalId ?? v.id),
        LedgerImportField.plate => v?.plate ?? '',
        LedgerImportField.maker => v?.maker ?? '',
        LedgerImportField.model => v?.model ?? '',
        LedgerImportField.modelCode => v?.modelCode ?? '',
        LedgerImportField.vin => v?.vin ?? '',
        LedgerImportField.year => v?.year?.toString() ?? '',
        LedgerImportField.inspectionExpiry => _date(v?.inspectionExpiry),
        LedgerImportField.lastVisitAt => _date(v?.lastVisitAt),
        LedgerImportField.mileage => v?.lastMileage?.toString() ?? '',
      };

  return [
    for (final f in LedgerImportField.values) value(f),
    c.note ?? '',
    _date(v?.inspectionNoticeAt),
  ].map(_escape).join(',');
}

/// 車検案内の宛名を、満了日の近い順に書き出す。1行＝車1台。
String buildInspectionNoticeCsv(List<InspectionNoticeTarget> targets) {
  final buffer = StringBuffer(_bom);
  buffer.writeln(inspectionNoticeHeaders.map(_escape).join(','));

  final sorted = List<InspectionNoticeTarget>.from(targets)
    ..sort((a, b) => _byExpiry(a.vehicle, b.vehicle));
  for (final t in sorted) {
    final c = t.customer;
    final v = t.vehicle;
    buffer.writeln([
      c.name,
      c.postalCode ?? '',
      c.address ?? '',
      c.phone ?? '',
      v.displayName,
      v.plate ?? '',
      _date(v.inspectionExpiry),
    ].map(_escape).join(','));
  }
  return buffer.toString();
}

int _byExpiry(LedgerVehicle a, LedgerVehicle b) {
  final x = a.inspectionExpiry;
  final y = b.inspectionExpiry;
  if (x == null && y == null) return 0;
  if (x == null) return 1;
  if (y == null) return -1;
  return x.compareTo(y);
}

/// `2026/09/05`。取込（parseLedgerDate）がそのまま読める形。
String _date(DateTime? d) {
  if (d == null) return '';
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '${d.year}/$m/$day';
}

/// 値を CSV の1項目にする。
///
/// ほかの書き出し（整備記録・フリート）と同じく、`=` `+` `-` `@` で始まる値は
/// 表計算ソフトが式として実行するので、先頭に `'` を付ける。取込は
/// この印を外して読む（`buildImportPlan`）。そのうえで RFC 4180 の引用。
String _escape(String value) {
  var v = value;
  if (v.isNotEmpty && ['=', '+', '-', '@'].contains(v[0])) {
    v = "'$v";
  }
  if (v.contains(',') ||
      v.contains('"') ||
      v.contains('\n') ||
      v.contains('\r')) {
    return '"${v.replaceAll('"', '""')}"';
  }
  return v;
}
