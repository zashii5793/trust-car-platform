import '../models/maintenance_record.dart';
import '../models/shop_ledger.dart';
import 'ledger_csv_import.dart';

/// 車両を登録したときに、過去の整備記録・請求書の内容をまとめて移す。
///
/// 中古車は、新車でない限り必ず過去の整備記録がある。それを登録の日に
/// 入れてもらえれば、「この1年のふりかえり」も車種別の維持費レポートも
/// 初日から効く（レポートは1年以上の記録がある車から数える）。
///
/// 運用: アプリが記入用のフォーマット（CSV）を渡し、利用者が Excel などで
/// 記入して戻す。列名が多少違っても読めるように、よくある言い方を当てる。

/// 記入用フォーマットの見出し。
const List<String> historyTemplateHeader = [
  '実施日',
  '作業の種類',
  '内容',
  '金額',
  '走行距離',
  'お店',
  'メモ',
];

/// 記入用フォーマット（UTF-8・BOM付き。Excel でそのまま開ける）。
///
/// **「#」で始まる行は記入例で、取り込まない。** 例がそのまま記録に
/// なる事故を防ぐため。
String historyTemplateCsv() {
  const rows = [
    historyTemplateHeader,
    [
      '#2023/4/10',
      '車検',
      '24か月点検・車検',
      '128000',
      '42000',
      'タカヤモーター',
      '「#」で始まる行は記入例です。取り込みません',
    ],
    ['#R5.10.2', 'オイル交換', 'エンジンオイル・オイルフィルター', '8800', '45500', '', ''],
    [
      '#2024/1/20',
      'タイヤ交換',
      'スタッドレス4本',
      '92000',
      '',
      '',
      '日付は 2024/1/20 や R6.1.20 の形で'
    ],
  ];
  String cell(String v) =>
      v.contains(RegExp(r'[,"\n]')) ? '"${v.replaceAll('"', '""')}"' : v;
  return '﻿${rows.map((r) => r.map(cell).join(',')).join('\r\n')}\r\n';
}

enum HistoryField {
  date(['実施日', '日付', '作業日', '入庫日', '整備日', '伝票日付']),
  type(['作業の種類', '種類', '作業区分', '区分', '整備区分']),
  title(['内容', '作業内容', 'タイトル', '件名', '明細', '作業名']),
  cost(['金額', '費用', '合計金額', '請求金額', '税込金額', '合計', '料金']),
  mileage(['走行距離', '距離', 'km']),
  shop(['お店', '店名', '工場', '整備工場', '実施工場', '依頼先']),
  memo(['メモ', '備考', 'コメント']);

  final List<String> aliases;
  const HistoryField(this.aliases);
}

String _norm(String h) =>
    LedgerSearch.nameKey(h).replaceAll(RegExp(r'[()（）・\-_./:：]'), '');

Map<HistoryField, int> guessHistoryImportColumns(List<String> header) {
  final normalized = header.map(_norm).toList();
  final result = <HistoryField, int>{};
  final used = <int>{};
  for (final exact in [true, false]) {
    for (final f in HistoryField.values) {
      if (result.containsKey(f)) continue;
      for (final alias in f.aliases.map(_norm)) {
        int? found;
        for (var i = 0; i < normalized.length; i++) {
          if (used.contains(i)) continue;
          final h = normalized[i];
          if (exact ? h == alias : (alias.length >= 2 && h.contains(alias))) {
            found = i;
            break;
          }
        }
        if (found != null) {
          result[f] = found;
          used.add(found);
          break;
        }
      }
    }
  }
  return result;
}

/// 作業の種類（自由に書かれた言葉）から、整備種別を推し量る。
///
/// 名前がそのまま一致すればそれ。次に言葉の中身で当てる（「24ヶ月点検と
/// 車検」→ 車検）。当たらなければ「その他」にする（**推し量れないものを
/// 修理扱いにしない**。修理歴は売るときに効くので、盛らない）。
MaintenanceType guessMaintenanceType(String? raw) {
  final s = LedgerSearch.nameKey(raw ?? '');
  if (s.isEmpty) return MaintenanceType.other;
  for (final t in MaintenanceType.values) {
    if (LedgerSearch.nameKey(t.displayName) == s) return t;
  }
  bool has(String w) => s.contains(LedgerSearch.nameKey(w));
  if (has('車検')) return MaintenanceType.carInspection;
  if (has('24') && has('点検')) return MaintenanceType.legalInspection24;
  if (has('点検')) return MaintenanceType.legalInspection12;
  if (has('オイル') && has('フィルター')) return MaintenanceType.oilFilterChange;
  if (has('エレメント')) return MaintenanceType.oilFilterChange;
  if (has('オイル')) return MaintenanceType.oilChange;
  if (has('ローテーション')) return MaintenanceType.tireRotation;
  if (has('タイヤ')) return MaintenanceType.tireChange;
  if (has('アライメント')) return MaintenanceType.wheelAlignment;
  if (has('バッテリー')) return MaintenanceType.batteryChange;
  if (has('ブレーキ') && (has('フルード') || has('液'))) {
    return MaintenanceType.brakeFluidChange;
  }
  if (has('ブレーキ')) return MaintenanceType.brakePadChange;
  if (has('冷却') || has('クーラント') || has('LLC')) {
    return MaintenanceType.coolantChange;
  }
  if (has('エアコン') && has('フィルター')) return MaintenanceType.cabinFilterChange;
  if (has('エアコン')) return MaintenanceType.airConditionerService;
  if (has('エアフィルター') || has('エアクリ')) return MaintenanceType.airFilterChange;
  if (has('ワイパー')) return MaintenanceType.wiperChange;
  if (has('ATF') || has('CVT')) return MaintenanceType.transmissionFluidChange;
  if (has('板金') || has('塗装')) return MaintenanceType.bodyRepair;
  if (has('コーティング')) return MaintenanceType.bodyCoating;
  if (has('洗車')) return MaintenanceType.washing;
  if (has('修理')) return MaintenanceType.repair;
  if (has('交換')) return MaintenanceType.partsReplacement;
  return MaintenanceType.other;
}

class HistoryImportRow {
  final int line;
  final DateTime date;
  final MaintenanceType type;
  final String title;
  final int cost;
  final int? mileage;
  final String? shopName;
  final String? memo;

  const HistoryImportRow({
    required this.line,
    required this.date,
    required this.type,
    required this.title,
    required this.cost,
    this.mileage,
    this.shopName,
    this.memo,
  });
}

class HistoryImportPlan {
  final List<HistoryImportRow> rows;
  final List<LedgerImportProblem> problems;

  const HistoryImportPlan({required this.rows, required this.problems});

  int get totalCost => rows.fold(0, (a, r) => a + r.cost);
  DateTime? get from => rows.isEmpty
      ? null
      : rows.map((r) => r.date).reduce((a, b) => a.isBefore(b) ? a : b);
  DateTime? get to => rows.isEmpty
      ? null
      : rows.map((r) => r.date).reduce((a, b) => a.isAfter(b) ? a : b);
}

int? _int(String? raw) {
  if (raw == null) return null;
  final s = LedgerSearch.nameKey(raw).replaceAll(RegExp(r'[,円¥￥\\km]'), '');
  return int.tryParse(s);
}

/// CSV の行（見出しを除く）から、取り込む記録を組み立てる。
///
/// [today] より先の日付は取り込まない（予定を記録にしない）。
HistoryImportPlan buildHistoryImportPlan(
  List<List<String>> rows,
  Map<HistoryField, int> columns, {
  required DateTime today,
}) {
  final out = <HistoryImportRow>[];
  final problems = <LedgerImportProblem>[];
  String? cell(List<String> row, HistoryField f) {
    final i = columns[f];
    if (i == null || i >= row.length) return null;
    final v = row[i].trim();
    return v.isEmpty ? null : v;
  }

  for (var r = 0; r < rows.length; r++) {
    final row = rows[r];
    final line = r + 2;
    // 記入例（# で始まる行）と、全部空の行は飛ばす
    if (row.isNotEmpty && row.first.trim().startsWith('#')) continue;
    if (row.every((c) => c.trim().isEmpty)) continue;

    final rawDate = cell(row, HistoryField.date);
    final date = parseLedgerDate(rawDate);
    if (date == null) {
      problems.add(LedgerImportProblem(
          line, rawDate == null ? '実施日が空です' : '実施日「$rawDate」を日付として読めません'));
      continue;
    }
    if (date.isAfter(today)) {
      problems.add(LedgerImportProblem(line, '実施日が未来の日付です（予定は取り込みません）'));
      continue;
    }
    final rawCost = cell(row, HistoryField.cost);
    final cost = rawCost == null ? 0 : _int(rawCost);
    if (cost == null || cost < 0) {
      problems.add(LedgerImportProblem(line, '金額「$rawCost」を数字として読めません'));
      continue;
    }
    final type = guessMaintenanceType(
        cell(row, HistoryField.type) ?? cell(row, HistoryField.title));
    final title = cell(row, HistoryField.title) ??
        cell(row, HistoryField.type) ??
        type.displayName;
    if (title.length > 100) {
      problems.add(LedgerImportProblem(line, '内容が100文字を超えています'));
      continue;
    }
    out.add(HistoryImportRow(
      line: line,
      date: date,
      type: type,
      title: title,
      cost: cost,
      mileage: _int(cell(row, HistoryField.mileage)),
      shopName: cell(row, HistoryField.shop),
      memo: cell(row, HistoryField.memo),
    ));
  }
  return HistoryImportPlan(rows: out, problems: problems);
}
