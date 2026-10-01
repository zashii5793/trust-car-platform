import '../models/shop_ledger.dart';

/// 整備管理ソフトから書き出した CSV を、顧客台帳に取り込む形に読み解く。
///
/// `docs/SHOP_CRM_DESIGN_2026-09-27.md` §9-2。
///
/// **製品ごとに列名が違う**ので、よくある列名を先に当てておき、当たらない
/// 列は画面で人が対応づける。1行＝車両1台、顧客は顧客番号（無ければ
/// 名前＋電話）でまとめる。整備管理ソフトの書き出しは、ほぼこの形になる。
///
/// ここは Firestore に触らない（純粋な変換だけ）。書き込みは
/// `ShopLedgerService.importRows` が行う。

/// 取り込める項目。
enum LedgerImportField {
  customerExternalId('顧客番号'),
  customerName('顧客名'),
  customerKana('フリガナ'),
  corporateFlag('法人区分'),
  contactPerson('担当者'),
  phone('電話番号'),
  email('メール'),
  postalCode('郵便番号'),
  address('住所'),
  vehicleExternalId('車両番号'),
  plate('登録番号'),
  maker('メーカー'),
  model('車名'),
  modelCode('型式'),
  vin('車台番号'),
  year('年式'),
  inspectionExpiry('車検満了日'),
  lastVisitAt('最終入庫日'),
  mileage('走行距離');

  final String label;
  const LedgerImportField(this.label);

  /// 列名の候補。**空白・記号を落とした形**で比べる。
  List<String> get aliases => switch (this) {
        customerExternalId => [
            '顧客番号',
            '顧客コード',
            '顧客no',
            '顧客id',
            'お客様番号',
            'お客様コード',
            '得意先コード',
            '得意先番号'
          ],
        customerName => [
            '顧客名',
            '氏名',
            'お客様名',
            '得意先名',
            '名前',
            '会社名',
            '使用者名',
            '所有者名'
          ],
        customerKana => [
            'フリガナ',
            'ふりがな',
            'カナ',
            '顧客名カナ',
            '氏名カナ',
            'ヨミ',
            '顧客カナ',
            '得意先カナ'
          ],
        corporateFlag => ['法人区分', '個人法人', '法人個人', '顧客区分', '区分'],
        contactPerson => ['担当者', 'ご担当者', '担当者名', '連絡先担当'],
        phone => ['電話番号', '電話', 'tel', '携帯', '携帯電話', '連絡先'],
        email => ['メール', 'メールアドレス', 'email', 'mail', 'eメール'],
        postalCode => ['郵便番号', '〒', '郵便'],
        address => ['住所', '所在地', '住所1'],
        vehicleExternalId => [
            '車両番号',
            '車両コード',
            '車両no',
            '車両id',
            '管理番号',
            '車両管理番号'
          ],
        plate => ['登録番号', 'ナンバー', '車両ナンバー', '自動車登録番号', '車番'],
        maker => ['メーカー', 'メーカー名', '車メーカー'],
        model => ['車名', '車種', '車種名', '通称名'],
        modelCode => ['型式', '車両型式'],
        vin => ['車台番号', 'vin', 'シャシー番号'],
        year => ['年式', '初度登録', '初度登録年月', '初年度登録', '登録年'],
        inspectionExpiry => [
            '車検満了日',
            '車検有効期限',
            '有効期間の満了する日',
            '車検日',
            '車検満了',
            '車検期限'
          ],
        lastVisitAt => ['最終入庫日', '最終来店日', '前回入庫日', '最終作業日', '入庫日'],
        mileage => ['走行距離', '最終走行距離', 'km', '走行'],
      };
}

/// CSV の文字列を行と列に分ける（RFC 4180）。
///
/// 引用符の中のカンマ・改行・`""`（引用符そのもの）を扱う。
/// 住所や備考に改行が入っている書き出しは珍しくない。
List<List<String>> parseCsv(String input) {
  var text = input;
  // Excel の「CSV UTF-8」は先頭に BOM が付く
  if (text.startsWith('﻿')) text = text.substring(1);

  final rows = <List<String>>[];
  var row = <String>[];
  final field = StringBuffer();
  var inQuotes = false;
  var i = 0;

  void endField() {
    row.add(field.toString());
    field.clear();
  }

  void endRow() {
    endField();
    // 完全な空行は捨てる（末尾の改行など）
    if (!(row.length == 1 && row.first.isEmpty)) rows.add(row);
    row = <String>[];
  }

  while (i < text.length) {
    final c = text[i];
    if (inQuotes) {
      if (c == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          field.write('"');
          i += 2;
          continue;
        }
        inQuotes = false;
      } else {
        field.write(c);
      }
    } else if (c == '"') {
      inQuotes = true;
    } else if (c == ',') {
      endField();
    } else if (c == '\r') {
      // CRLF の CR は読み飛ばす
    } else if (c == '\n') {
      endRow();
    } else {
      field.write(c);
    }
    i++;
  }
  if (field.isNotEmpty || row.isNotEmpty) endRow();
  return rows;
}

/// 書き出しで式よけに付けた `'` を外す（`'=...` `'+81...` → `=...` `+81...`）。
///
/// 台帳の書き出し（`ledger_csv_export.dart`）は、`=` `+` `-` `@` で始まる値の
/// 先頭に `'` を付ける。外さないと、取り込み直すたびに `'` が増えていく。
String unguardCsvFormula(String value) {
  if (value.length >= 2 &&
      value[0] == "'" &&
      ['=', '+', '-', '@'].contains(value[1])) {
    return value.substring(1);
  }
  return value;
}

String _normalizeHeader(String h) =>
    LedgerSearch.nameKey(h).replaceAll(RegExp(r'[()（）・\-_./:：]'), '');

/// 見出し行から、各項目がどの列にあるかを推測する。見つからない項目は入れない。
Map<LedgerImportField, int> guessColumns(List<String> header) {
  final normalized = header.map(_normalizeHeader).toList();
  final result = <LedgerImportField, int>{};
  final used = <int>{};

  // 完全一致を先に、次に部分一致。「車検満了日」が「車検日」に取られないように。
  for (final exact in [true, false]) {
    for (final f in LedgerImportField.values) {
      if (result.containsKey(f)) continue;
      for (final alias in f.aliases.map(_normalizeHeader)) {
        final idx = _indexWhere(normalized, used, (h) {
          if (exact) return h == alias;
          return alias.length >= 2 && h.contains(alias);
        });
        if (idx != null) {
          result[f] = idx;
          used.add(idx);
          break;
        }
      }
    }
  }
  return result;
}

int? _indexWhere(List<String> list, Set<int> used, bool Function(String) test) {
  for (var i = 0; i < list.length; i++) {
    if (!used.contains(i) && test(list[i])) return i;
  }
  return null;
}

/// 和暦の元年（西暦 = 元年の西暦 + 年 - 1）。
const Map<String, int> _eras = {
  '令和': 2019,
  'r': 2019,
  '平成': 1989,
  'h': 1989,
  '昭和': 1926,
  's': 1926,
};

/// 日付の読み取り。整備管理ソフトの書き出しで見かける形を受ける。
///
/// - `2026/09/27` `2026-9-27` `2026.9.27` `20260927`
/// - `令和8年9月27日` `R8.9.27` `R08/09/27` `H30.1.5`
/// - `2026年9月27日`
///
/// 読めなければ null（**推測で埋めない**。1年ずれた満了日は、
/// 空欄より害が大きい）。
DateTime? parseLedgerDate(String? raw) {
  if (raw == null) return null;
  var s = LedgerSearch.nameKey(raw); // 全角→半角・空白除去・小文字化
  if (s.isEmpty) return null;
  s = s.replaceAll('元', '1');

  final compact = RegExp(r'^(\d{4})(\d{2})(\d{2})$').firstMatch(s);
  if (compact != null) {
    return _ymd(
      int.parse(compact.group(1)!),
      int.parse(compact.group(2)!),
      int.parse(compact.group(3)!),
    );
  }

  var base = 0;
  for (final e in _eras.entries) {
    if (s.startsWith(e.key)) {
      base = e.value - 1;
      s = s.substring(e.key.length);
      break;
    }
  }

  final m =
      RegExp(r'^(\d{1,4})[/\-.年](\d{1,2})[/\-.月](\d{1,2})日?').firstMatch(s);
  if (m == null) return null;
  var y = int.parse(m.group(1)!);
  if (base > 0) {
    y += base;
  } else if (y < 100) {
    return null; // 元号なしの2桁年は、どの世紀か決められない
  }
  return _ymd(y, int.parse(m.group(2)!), int.parse(m.group(3)!));
}

DateTime? _ymd(int y, int m, int d) {
  if (m < 1 || m > 12 || d < 1 || d > 31) return null;
  final date = DateTime(y, m, d);
  // 2月30日などは DateTime が翌月に繰り上げるので、はじく
  if (date.month != m) return null;
  return date;
}

/// 年式の読み取り。`2019` `2019/04` `H31` `平成31年4月` `R1` を西暦の年にする。
int? parseLedgerYear(String? raw) {
  if (raw == null) return null;
  var s = LedgerSearch.nameKey(raw).replaceAll('元', '1');
  if (s.isEmpty) return null;
  for (final e in _eras.entries) {
    if (s.startsWith(e.key)) {
      final m = RegExp(r'^(\d{1,2})').firstMatch(s.substring(e.key.length));
      return m == null ? null : e.value - 1 + int.parse(m.group(1)!);
    }
  }
  final m = RegExp(r'^(\d{4})').firstMatch(s);
  if (m == null) return null;
  final y = int.parse(m.group(1)!);
  return (y >= 1950 && y <= 2100) ? y : null;
}

int? _parseInt(String? raw) {
  if (raw == null) return null;
  final digits = LedgerSearch.nameKey(raw).replaceAll(RegExp(r'[,km]'), '');
  return int.tryParse(digits);
}

bool _isCorporate(String? flag, String name) {
  final f = flag == null ? '' : LedgerSearch.nameKey(flag);
  if (f.isNotEmpty) {
    if (f.contains('法人') || f == '1' || f == 'c') return true;
    if (f.contains('個人') || f == '0' || f == 'p') return false;
  }
  // 区分の列が無いときは、社名らしさで判断する
  return RegExp(r'株式会社|有限会社|合同会社|合資会社|\(株\)|（株）|\(有\)|（有）|㈱|㈲|法人|組合|協会')
      .hasMatch(name);
}

/// 取り込む顧客1件（車両をまとめたもの）。
class LedgerImportCustomer {
  final String key;
  final String? externalId;
  final String name;
  final String? nameKana;
  final LedgerCustomerKind kind;
  final String? contactPerson;
  final String? phone;
  final String? email;
  final String? postalCode;
  final String? address;
  final List<LedgerImportVehicle> vehicles;

  const LedgerImportCustomer({
    required this.key,
    required this.externalId,
    required this.name,
    required this.nameKana,
    required this.kind,
    required this.contactPerson,
    required this.phone,
    required this.email,
    required this.postalCode,
    required this.address,
    required this.vehicles,
  });

  /// 顧客番号が無い CSV でも、取込をやり直して二重にならないためのID用の値。
  String get stableExternalId => externalId ?? key;
}

class LedgerImportVehicle {
  final String? externalId;
  final String? plate;
  final String maker;
  final String model;
  final String? modelCode;
  final String? vin;
  final int? year;
  final DateTime? inspectionExpiry;
  final DateTime? lastVisitAt;
  final int? mileage;

  const LedgerImportVehicle({
    required this.externalId,
    required this.plate,
    required this.maker,
    required this.model,
    required this.modelCode,
    required this.vin,
    required this.year,
    required this.inspectionExpiry,
    required this.lastVisitAt,
    required this.mileage,
  });

  /// 車両番号が無い CSV 用。ナンバー → 車台番号 → 車名の順で決める。
  String stableExternalId(String customerKey) =>
      externalId ??
      (plate != null ? 'p:${LedgerSearch.plateKey(plate!)}' : null) ??
      (vin != null ? 'vin:$vin' : null) ??
      '$customerKey:${LedgerSearch.nameKey('$maker$model')}';
}

/// 読めなかった行。**黙って捨てない。** 何行目の何が悪いかを人に見せる。
class LedgerImportProblem {
  /// 1始まり（見出し行を1行目として数える。Excel の行番号と揃える）。
  final int line;
  final String message;

  const LedgerImportProblem(this.line, this.message);
}

class LedgerImportPlan {
  final List<LedgerImportCustomer> customers;
  final List<LedgerImportProblem> problems;
  final int rowCount;

  const LedgerImportPlan({
    required this.customers,
    required this.problems,
    required this.rowCount,
  });

  int get vehicleCount =>
      customers.fold(0, (sum, c) => sum + c.vehicles.length);
}

/// CSV の行（見出しを除く）と列の対応から、取り込む顧客と車両を組み立てる。
LedgerImportPlan buildImportPlan(
  List<List<String>> rows,
  Map<LedgerImportField, int> columns,
) {
  final customers = <String, _CustomerBuilder>{};
  final problems = <LedgerImportProblem>[];

  String? cell(List<String> row, LedgerImportField f) {
    final idx = columns[f];
    if (idx == null || idx >= row.length) return null;
    final v = unguardCsvFormula(row[idx].trim());
    return v.isEmpty ? null : v;
  }

  for (var r = 0; r < rows.length; r++) {
    final row = rows[r];
    final line = r + 2; // 見出しが1行目
    final name = cell(row, LedgerImportField.customerName);
    if (name == null) {
      problems.add(LedgerImportProblem(line, '顧客名が空です'));
      continue;
    }
    if (name.length > 100) {
      problems.add(LedgerImportProblem(line, '顧客名が100文字を超えています'));
      continue;
    }

    final ext = cell(row, LedgerImportField.customerExternalId);
    final phone = cell(row, LedgerImportField.phone);
    // 顧客番号が無ければ、名前＋電話で同じ人とみなす
    final key = ext ??
        'n:${LedgerSearch.nameKey(name)}|${LedgerSearch.plateKey(phone ?? '')}';

    final builder = customers.putIfAbsent(
      key,
      () => _CustomerBuilder(
        key: key,
        externalId: ext,
        name: name,
        nameKana: cell(row, LedgerImportField.customerKana),
        kind: _isCorporate(cell(row, LedgerImportField.corporateFlag), name)
            ? LedgerCustomerKind.corporate
            : LedgerCustomerKind.individual,
        contactPerson: cell(row, LedgerImportField.contactPerson),
        phone: phone,
        email: cell(row, LedgerImportField.email),
        postalCode: cell(row, LedgerImportField.postalCode),
        address: cell(row, LedgerImportField.address),
      ),
    );

    final maker = cell(row, LedgerImportField.maker);
    final model = cell(row, LedgerImportField.model);
    final plate = cell(row, LedgerImportField.plate);
    if (maker == null && model == null && plate == null) {
      continue; // 車の無い顧客だけの行
    }
    if (model == null) {
      problems.add(LedgerImportProblem(line, '車名が空のため、車両を取り込めません'));
      continue;
    }

    final rawExpiry = cell(row, LedgerImportField.inspectionExpiry);
    final expiry = parseLedgerDate(rawExpiry);
    if (rawExpiry != null && expiry == null) {
      problems.add(LedgerImportProblem(
          line, '車検満了日「$rawExpiry」を日付として読めません（空欄として取り込みます）'));
    }
    final rawVisit = cell(row, LedgerImportField.lastVisitAt);
    final visit = parseLedgerDate(rawVisit);
    if (rawVisit != null && visit == null) {
      problems.add(LedgerImportProblem(
          line, '最終入庫日「$rawVisit」を日付として読めません（空欄として取り込みます）'));
    }

    builder.vehicles.add(LedgerImportVehicle(
      externalId: cell(row, LedgerImportField.vehicleExternalId),
      plate: plate,
      // メーカーの列が無い書き出しもある。空にはできないので「不明」とする
      maker: maker ?? '不明',
      model: model,
      modelCode: cell(row, LedgerImportField.modelCode),
      vin: cell(row, LedgerImportField.vin),
      year: parseLedgerYear(cell(row, LedgerImportField.year)),
      inspectionExpiry: expiry,
      lastVisitAt: visit,
      mileage: _parseInt(cell(row, LedgerImportField.mileage)),
    ));
  }

  return LedgerImportPlan(
    customers: customers.values.map((b) => b.build()).toList(),
    problems: problems,
    rowCount: rows.length,
  );
}

class _CustomerBuilder {
  final String key;
  final String? externalId;
  final String name;
  final String? nameKana;
  final LedgerCustomerKind kind;
  final String? contactPerson;
  final String? phone;
  final String? email;
  final String? postalCode;
  final String? address;
  final List<LedgerImportVehicle> vehicles = [];

  _CustomerBuilder({
    required this.key,
    required this.externalId,
    required this.name,
    required this.nameKana,
    required this.kind,
    required this.contactPerson,
    required this.phone,
    required this.email,
    required this.postalCode,
    required this.address,
  });

  LedgerImportCustomer build() => LedgerImportCustomer(
        key: key,
        externalId: externalId,
        name: name,
        nameKana: nameKana,
        kind: kind,
        contactPerson: contactPerson,
        phone: phone,
        email: email,
        postalCode: postalCode,
        address: address,
        vehicles: List.unmodifiable(vehicles),
      );
}

// ---------------------------------------------------------------------------
// 整備履歴（伝票）の取込
// ---------------------------------------------------------------------------

/// 整備履歴の CSV で取り込める項目。1行＝伝票1枚（作業1回）。
enum LedgerHistoryField {
  date('作業日'),
  slipNumber('伝票番号'),
  customerExternalId('顧客番号'),
  vehicleExternalId('車両番号'),
  plate('登録番号'),
  type('作業内容'),
  total('金額'),
  mileage('走行距離');

  final String label;
  const LedgerHistoryField(this.label);

  List<String> get aliases => switch (this) {
        date => ['作業日', '入庫日', '伝票日付', '売上日', '日付', '作業完了日', '納車日'],
        slipNumber => ['伝票番号', '伝票no', '売上番号', '作業番号', '受付番号'],
        customerExternalId => ['顧客番号', '顧客コード', 'お客様コード', 'お客様番号', '得意先コード'],
        vehicleExternalId => ['車両番号', '車両コード', '管理番号', '車両管理番号'],
        plate => ['登録番号', 'ナンバー', '車番', '自動車登録番号'],
        type => ['作業内容', '作業区分', '整備区分', '区分', '作業名', '内容', '件名'],
        total => ['合計金額', '請求金額', '税込金額', '売上金額', '合計', '金額', '税込合計'],
        mileage => ['走行距離', '入庫時走行距離', 'km'],
      };
}

Map<LedgerHistoryField, int> guessHistoryColumns(List<String> header) {
  final normalized = header.map(_normalizeHeader).toList();
  final result = <LedgerHistoryField, int>{};
  final used = <int>{};
  for (final exact in [true, false]) {
    for (final f in LedgerHistoryField.values) {
      if (result.containsKey(f)) continue;
      for (final alias in f.aliases.map(_normalizeHeader)) {
        final idx = _indexWhere(normalized, used, (h) {
          if (exact) return h == alias;
          return alias.length >= 2 && h.contains(alias);
        });
        if (idx != null) {
          result[f] = idx;
          used.add(idx);
          break;
        }
      }
    }
  }
  return result;
}

/// 整備履歴の1行。どの車かは、書き込むときに台帳と突き合わせて決める。
class LedgerHistoryRow {
  final int line;
  final DateTime date;
  final String? slipNumber;
  final String? customerExternalId;
  final String? vehicleExternalId;
  final String? plate;
  final String type;
  final int total;
  final int? mileage;

  const LedgerHistoryRow({
    required this.line,
    required this.date,
    required this.slipNumber,
    required this.customerExternalId,
    required this.vehicleExternalId,
    required this.plate,
    required this.type,
    required this.total,
    required this.mileage,
  });
}

class LedgerHistoryPlan {
  final List<LedgerHistoryRow> rows;
  final List<LedgerImportProblem> problems;
  final int rowCount;

  const LedgerHistoryPlan({
    required this.rows,
    required this.problems,
    required this.rowCount,
  });
}

LedgerHistoryPlan buildHistoryPlan(
  List<List<String>> rows,
  Map<LedgerHistoryField, int> columns,
) {
  final out = <LedgerHistoryRow>[];
  final problems = <LedgerImportProblem>[];

  String? cell(List<String> row, LedgerHistoryField f) {
    final idx = columns[f];
    if (idx == null || idx >= row.length) return null;
    final v = row[idx].trim();
    return v.isEmpty ? null : v;
  }

  for (var r = 0; r < rows.length; r++) {
    final row = rows[r];
    final line = r + 2;
    final rawDate = cell(row, LedgerHistoryField.date);
    final date = parseLedgerDate(rawDate);
    if (date == null) {
      problems.add(LedgerImportProblem(
          line, rawDate == null ? '作業日が空です' : '作業日「$rawDate」を日付として読めません'));
      continue;
    }
    final rawTotal = cell(row, LedgerHistoryField.total);
    final total = _parseInt(rawTotal?.replaceAll(RegExp(r'[円¥￥\\]'), ''));
    if (total == null || total < 0) {
      problems.add(LedgerImportProblem(
          line, rawTotal == null ? '金額が空です' : '金額「$rawTotal」を数字として読めません'));
      continue;
    }
    final customerExt = cell(row, LedgerHistoryField.customerExternalId);
    final vehicleExt = cell(row, LedgerHistoryField.vehicleExternalId);
    final plate = cell(row, LedgerHistoryField.plate);
    if (customerExt == null && vehicleExt == null && plate == null) {
      problems.add(
          LedgerImportProblem(line, 'どの車の作業か分かりません（顧客番号・車両番号・登録番号のどれかが要ります）'));
      continue;
    }
    out.add(LedgerHistoryRow(
      line: line,
      date: date,
      slipNumber: cell(row, LedgerHistoryField.slipNumber),
      customerExternalId: customerExt,
      vehicleExternalId: vehicleExt,
      plate: plate,
      type: cell(row, LedgerHistoryField.type) ?? '整備',
      total: total,
      mileage: _parseInt(cell(row, LedgerHistoryField.mileage)),
    ));
  }
  return LedgerHistoryPlan(
      rows: out, problems: problems, rowCount: rows.length);
}
