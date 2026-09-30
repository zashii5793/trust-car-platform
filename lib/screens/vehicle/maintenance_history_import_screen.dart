import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/spacing.dart';
import '../../core/encoding/csv_text_decoder.dart';
import '../../models/vehicle.dart';
import '../../services/ledger_csv_import.dart';
import '../../services/maintenance_history_import.dart';
import '../../services/invoice_ocr_service.dart';
import '../../services/maintenance_history_import_service.dart';
import 'invoice_photo_import_screen.dart';
import '../../widgets/common/app_card.dart';
import '../shop/ledger/ledger_csv_import_screen.dart'
    show CsvFilePicker, PickedCsvFile, pickCsvWithFilePicker;
import '../../core/utils/first_week_tracker.dart';
import '../../services/analytics_service.dart' show FirstWeekStep;

/// 記入用フォーマットを渡す関数。テストで差し替える。
typedef TemplateSharer = Future<void> Function(String csv);

Future<void> _shareTemplate(String csv) async {
  if (kIsWeb) return; // Web は画面の説明（列の並び）を見て作ってもらう
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/整備記録_記入用.csv');
  await file.writeAsString(csv);
  await Share.shareXFiles(
    [XFile(file.path, mimeType: 'text/csv')],
    subject: '整備記録の記入用フォーマット',
  );
}

String _yen(int v) => v.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (m) => '${m[1]},',
    );

String _date(DateTime d) => '${d.year}/${d.month}/${d.day}';

/// 過去の整備記録・請求書の内容を、まとめて移す。
///
/// 中古車は、新車でない限り必ず過去の記録がある。登録の日に入れてもらえば、
/// ふりかえりも車種別の維持費レポートも初日から効く。
///
/// 1. 記入用フォーマットを受け取る（メール・LINE・ファイルに保存）
/// 2. Excel などで記入する（整備記録簿・請求書を見ながら）
/// 3. 記入したファイルを選んで、取り込む
class MaintenanceHistoryImportScreen extends StatefulWidget {
  final Vehicle vehicle;
  final String userId;
  final MaintenanceHistoryImportService service;
  final CsvFilePicker pickFile;
  final TemplateSharer shareTemplate;

  /// 「今日」。未来の日付を弾くため。テストで止める。
  final DateTime? today;

  const MaintenanceHistoryImportScreen({
    super.key,
    required this.vehicle,
    required this.userId,
    required this.service,
    this.pickFile = pickCsvWithFilePicker,
    this.shareTemplate = _shareTemplate,
    this.today,
  });

  @override
  State<MaintenanceHistoryImportScreen> createState() =>
      _MaintenanceHistoryImportScreenState();
}

class _MaintenanceHistoryImportScreenState
    extends State<MaintenanceHistoryImportScreen> {
  String? _fileName;
  HistoryImportPlan? _plan;
  String? _error;
  bool _importing = false;
  HistoryImportResult? _result;

  Future<void> _pick() async {
    setState(() => _error = null);
    final PickedCsvFile? file;
    try {
      file = await widget.pickFile();
    } catch (e) {
      setState(() => _error = 'ファイルを開けませんでした: $e');
      return;
    }
    if (file == null || !mounted) return;
    final table = parseCsv(decodeCsvBytes(file.bytes).text);
    if (table.length < 2) {
      setState(() {
        _fileName = file!.name;
        _plan = null;
        _error = '見出しの行と、記入した行が必要です。';
      });
      return;
    }
    final columns = guessHistoryImportColumns(table.first);
    if (!columns.containsKey(HistoryField.date)) {
      setState(() {
        _fileName = file!.name;
        _plan = null;
        _error = '「実施日」の列が見つかりません。記入用フォーマットの見出しを'
            'そのまま使ってください。';
      });
      return;
    }
    setState(() {
      _fileName = file!.name;
      _plan = buildHistoryImportPlan(
        table.sublist(1),
        columns,
        today: widget.today ?? DateTime.now(),
      );
      _result = null;
    });
  }

  Future<void> _import() async {
    final plan = _plan;
    if (plan == null) return;
    setState(() {
      _importing = true;
      _error = null;
    });
    final r = await widget.service.importRows(
      userId: widget.userId,
      vehicleId: widget.vehicle.id,
      rows: plan.rows,
    );
    if (!mounted) return;
    r.when(
      success: (res) {
        trackFirstWeekStep(FirstWeekStep.pastRecordsImported);
        setState(() {
          _result = res;
          _importing = false;
        });
      },
      failure: (e) => setState(() {
        _error = '取り込みに失敗しました: ${e.userMessage}\n'
            'もう一度取り込んでも二重にはなりません。';
        _importing = false;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final plan = _plan;
    final result = _result;

    return Scaffold(
      appBar: AppBar(title: const Text('過去の整備記録を移す')),
      body: ListView(
        padding: AppSpacing.paddingScreen,
        children: [
          Text(
            '${widget.vehicle.displayName} のこれまでの整備記録簿・請求書の内容を、'
            'まとめて移せます。',
          ),
          AppSpacing.verticalMd,
          if (result != null)
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle, color: AppColors.success),
                      AppSpacing.horizontalXs,
                      Text('移しました', style: theme.textTheme.titleMedium),
                    ],
                  ),
                  AppSpacing.verticalXs,
                  Text(
                    '${result.added}件を追加しました'
                    '${result.skipped > 0 ? '（${result.skipped}件は取り込み済み）' : ''}',
                    key: const Key('history_import_result'),
                  ),
                  AppSpacing.verticalMd,
                  FilledButton(
                    key: const Key('history_import_done'),
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('車両の画面へ'),
                  ),
                ],
              ),
            )
          else ...[
            // 写真から読むのは端末の中（ML Kit）なので、スマートフォンだけ
            if (InvoiceOcrService.isSupported) ...[
              Card(
                child: ListTile(
                  key: const Key('history_from_photos'),
                  leading: const Icon(Icons.photo_camera_outlined,
                      color: AppColors.primary),
                  title: const Text('請求書の写真から移す'),
                  subtitle: const Text('手元に請求書があれば、写真を選ぶだけ'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final done = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => InvoicePhotoImportScreen(
                          vehicle: widget.vehicle,
                          userId: widget.userId,
                          service: widget.service,
                          today: widget.today,
                        ),
                      ),
                    );
                    if (done == true && context.mounted) {
                      Navigator.pop(context, true);
                    }
                  },
                ),
              ),
              AppSpacing.verticalSm,
              const Text('または、記入用フォーマットで：'),
              AppSpacing.verticalSm,
            ],
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('1. 記入用フォーマットを受け取る', style: theme.textTheme.titleMedium),
                  AppSpacing.verticalXs,
                  Text(
                    '列は「${historyTemplateHeader.join('・')}」です。'
                    'Excel・Numbers・Google スプレッドシートで開けます。'
                    '「#」で始まる行は記入例なので、消しても残してもかまいません。',
                  ),
                  AppSpacing.verticalSm,
                  OutlinedButton.icon(
                    key: const Key('history_template'),
                    onPressed: () => widget.shareTemplate(historyTemplateCsv()),
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('記入用フォーマットを受け取る'),
                  ),
                  AppSpacing.verticalMd,
                  Text('2. 整備記録簿・請求書を見ながら記入する',
                      style: theme.textTheme.titleMedium),
                  AppSpacing.verticalXs,
                  const Text('実施日は必須です。金額・走行距離・お店は分かる範囲で。'
                      '日付は 2023/4/10 や R5.4.10 の形で書けます。'),
                  AppSpacing.verticalMd,
                  Text('3. 記入したファイルを選ぶ', style: theme.textTheme.titleMedium),
                  AppSpacing.verticalSm,
                  OutlinedButton.icon(
                    key: const Key('history_pick'),
                    onPressed: _importing ? null : _pick,
                    icon: const Icon(Icons.upload_file),
                    label: Text(_fileName == null ? 'ファイルを選ぶ' : '別のファイルを選ぶ'),
                  ),
                ],
              ),
            ),
            if (plan != null) ...[
              AppSpacing.verticalMd,
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.rows.isEmpty
                          ? '取り込める行がありません'
                          : '${plan.rows.length}件を移します',
                      key: const Key('history_plan_summary'),
                      style: theme.textTheme.titleMedium,
                    ),
                    if (plan.rows.isNotEmpty)
                      Text(
                        '${_date(plan.from!)}〜${_date(plan.to!)}・'
                        '合計 ${_yen(plan.totalCost)}円',
                      ),
                    AppSpacing.verticalXs,
                    for (final r in plan.rows.take(5))
                      Text(
                        '${_date(r.date)}  ${r.title}（${r.type.displayName}）'
                        '  ${_yen(r.cost)}円',
                        style: theme.textTheme.bodySmall,
                      ),
                    if (plan.rows.length > 5)
                      Text('ほか ${plan.rows.length - 5}件',
                          style: theme.textTheme.bodySmall),
                    if (plan.problems.isNotEmpty) ...[
                      AppSpacing.verticalSm,
                      Text(
                        '取り込めない行が ${plan.problems.length} 件あります',
                        style: const TextStyle(color: AppColors.warning),
                      ),
                      for (final p in plan.problems.take(20))
                        Text('${p.line}行目: ${p.message}',
                            style: theme.textTheme.bodySmall),
                    ],
                    AppSpacing.verticalMd,
                    FilledButton.icon(
                      key: const Key('history_import_run'),
                      onPressed:
                          (_importing || plan.rows.isEmpty) ? null : _import,
                      icon: const Icon(Icons.download_done),
                      label: Text(_importing ? '移しています…' : '移す'),
                      style: FilledButton.styleFrom(
                        minimumSize:
                            const Size.fromHeight(AppSpacing.tapTargetMin),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
          if (_error != null) ...[
            AppSpacing.verticalMd,
            Text(
              _error!,
              key: const Key('history_import_error'),
              style: const TextStyle(color: AppColors.error),
            ),
          ],
          AppSpacing.verticalXl,
        ],
      ),
    );
  }
}
