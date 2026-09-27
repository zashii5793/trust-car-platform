import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/spacing.dart';
import '../../../core/encoding/csv_text_decoder.dart';
import '../../../services/ledger_csv_import.dart';
import '../../../services/shop_ledger_service.dart';
import '../../../widgets/common/app_card.dart';

/// 選んだファイル。テストでファイル選択を差し替えられるように分けてある。
class PickedCsvFile {
  final String name;
  final List<int> bytes;

  const PickedCsvFile(this.name, this.bytes);
}

typedef CsvFilePicker = Future<PickedCsvFile?> Function();

Future<PickedCsvFile?> _pickWithFilePicker() async {
  final result = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['csv', 'txt'],
    withData: true,
  );
  final file = result?.files.singleOrNull;
  final bytes = file?.bytes;
  if (file == null || bytes == null) return null;
  return PickedCsvFile(file.name, bytes);
}

/// 整備管理ソフトの CSV から、顧客台帳へ一括で取り込む。
///
/// `docs/SHOP_CRM_DESIGN_2026-09-27.md` §9-2。何千人分を手で打ち直すのは
/// 現実的でないので、今ある名簿をそのまま流し込めるようにする。
///
/// 1. ファイルを選ぶ（UTF-8 でも Windows の Shift_JIS でもよい）
/// 2. 列の対応を確かめる（よくある列名は自動で当てる）
/// 3. 何人・何台入るか、読めなかった行はどこかを確かめる
/// 4. 取り込む（やり直しても二重にならない）
///
/// 取り込んだら true を返して閉じる。
class LedgerCsvImportScreen extends StatefulWidget {
  final ShopLedgerService service;
  final String shopId;
  final CsvFilePicker pickFile;

  const LedgerCsvImportScreen({
    super.key,
    required this.service,
    required this.shopId,
    this.pickFile = _pickWithFilePicker,
  });

  @override
  State<LedgerCsvImportScreen> createState() => _LedgerCsvImportScreenState();
}

class _LedgerCsvImportScreenState extends State<LedgerCsvImportScreen> {
  String? _fileName;
  DecodedCsvText? _decoded;
  List<String> _header = const [];
  List<List<String>> _rows = const [];
  Map<LedgerImportField, int> _columns = {};
  String? _error;

  bool _importing = false;
  int _done = 0;
  int _total = 0;
  LedgerImportResult? _result;

  LedgerImportPlan get _plan => buildImportPlan(_rows, _columns);

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

    final decoded = decodeCsvBytes(file.bytes);
    final table = parseCsv(decoded.text);
    if (table.length < 2) {
      setState(() {
        _error = '見出しの行と、1行以上のデータが必要です。';
        _fileName = file!.name;
        _decoded = null;
      });
      return;
    }
    setState(() {
      _fileName = file!.name;
      _decoded = decoded;
      _header = table.first;
      _rows = table.sublist(1);
      _columns = guessColumns(_header);
      _result = null;
    });
  }

  Future<void> _import() async {
    final plan = _plan;
    setState(() {
      _importing = true;
      _done = 0;
      _total = 0;
      _error = null;
    });
    final result = await widget.service.importPlan(
      shopId: widget.shopId,
      plan: plan,
      onProgress: (done, total) {
        if (mounted) {
          setState(() {
            _done = done;
            _total = total;
          });
        }
      },
    );
    if (!mounted) return;
    result.when(
      success: (r) => setState(() {
        _result = r;
        _importing = false;
      }),
      failure: (e) => setState(() {
        _error = '取り込みに失敗しました: ${e.userMessage}\n'
            'もう一度取り込んでも二重にはなりません。';
        _importing = false;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_importing,
      child: Scaffold(
        appBar: AppBar(title: const Text('CSVから取り込む')),
        body: ListView(
          padding: AppSpacing.paddingScreen,
          children: [
            if (_result != null)
              _ResultCard(
                result: _result!,
                onDone: () => Navigator.pop(context, true),
              )
            else ...[
              _stepFile(context),
              if (_decoded != null) ...[
                AppSpacing.verticalMd,
                _stepColumns(context),
                AppSpacing.verticalMd,
                _stepPreview(context),
              ],
            ],
            if (_error != null) ...[
              AppSpacing.verticalMd,
              Text(
                _error!,
                key: const Key('csv_import_error'),
                style: const TextStyle(color: AppColors.error),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _stepFile(BuildContext context) {
    final theme = Theme.of(context);
    final decoded = _decoded;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('1. ファイルを選ぶ', style: theme.textTheme.titleMedium),
          AppSpacing.verticalXs,
          const Text(
            '整備管理ソフトから書き出した CSV を選んでください。'
            '1行に車1台の形を想定しています（同じ顧客番号の行は1人にまとめます）。',
          ),
          AppSpacing.verticalSm,
          OutlinedButton.icon(
            key: const Key('csv_pick'),
            onPressed: _importing ? null : _pick,
            icon: const Icon(Icons.upload_file),
            label: Text(_fileName == null ? 'ファイルを選ぶ' : '別のファイルを選ぶ'),
          ),
          if (decoded != null) ...[
            AppSpacing.verticalSm,
            Text(
              '$_fileName ・ ${_rows.length}行 ・ ${decoded.encoding.label}',
              key: const Key('csv_file_summary'),
            ),
            if (decoded.malformed > 0)
              Text(
                '読めない文字が ${decoded.malformed} か所ありました（「�」で表示されます）。',
                style: const TextStyle(color: AppColors.warning),
              ),
          ],
        ],
      ),
    );
  }

  Widget _stepColumns(BuildContext context) {
    final theme = Theme.of(context);
    final sample = _rows.first;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('2. 列の対応を確かめる', style: theme.textTheme.titleMedium),
          AppSpacing.verticalXs,
          const Text('列名から自動で当てています。違っていたら選び直してください。'),
          AppSpacing.verticalSm,
          for (final field in LedgerImportField.values)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  SizedBox(
                    width: 96,
                    child: Text(
                      field == LedgerImportField.customerName
                          ? '${field.label} *'
                          : field.label,
                    ),
                  ),
                  Expanded(
                    child: DropdownButton<int?>(
                      key: Key('csv_col_${field.name}'),
                      isExpanded: true,
                      value: _columns[field],
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('（使わない）'),
                        ),
                        for (var i = 0; i < _header.length; i++)
                          DropdownMenuItem(
                            value: i,
                            child: Text(
                              _header[i].isEmpty ? '（${i + 1}列目）' : _header[i],
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: _importing
                          ? null
                          : (v) => setState(() {
                                // 1つの列を2つの項目に当てない
                                _columns.removeWhere((_, idx) => idx == v);
                                if (v == null) {
                                  _columns.remove(field);
                                } else {
                                  _columns[field] = v;
                                }
                              }),
                    ),
                  ),
                  AppSpacing.horizontalXs,
                  SizedBox(
                    width: 96,
                    child: Text(
                      _columns[field] != null &&
                              _columns[field]! < sample.length
                          ? sample[_columns[field]!]
                          : '',
                      style: theme.textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _stepPreview(BuildContext context) {
    final theme = Theme.of(context);
    final hasName = _columns.containsKey(LedgerImportField.customerName);
    final plan = hasName ? _plan : null;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('3. 取り込む', style: theme.textTheme.titleMedium),
          AppSpacing.verticalXs,
          if (plan == null)
            const Text('「顧客名」の列を選んでください。')
          else ...[
            Text(
              '顧客 ${plan.customers.length}人・車両 ${plan.vehicleCount}台 を取り込みます。',
              key: const Key('csv_plan_summary'),
              style: theme.textTheme.bodyLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Text(
              '同じ顧客番号・同じナンバーの人と車は上書きします。'
              '台帳に手で書いたメモ、アプリとのつながりは消えません。',
            ),
            if (plan.problems.isNotEmpty) ...[
              AppSpacing.verticalSm,
              Text(
                '確かめてほしい行が ${plan.problems.length} 件あります',
                key: const Key('csv_problem_count'),
                style: const TextStyle(color: AppColors.warning),
              ),
              for (final p in plan.problems.take(20))
                Text('${p.line}行目: ${p.message}',
                    style: theme.textTheme.bodySmall),
              if (plan.problems.length > 20)
                Text('ほか ${plan.problems.length - 20} 件',
                    style: theme.textTheme.bodySmall),
            ],
          ],
          AppSpacing.verticalMd,
          if (_importing) ...[
            LinearProgressIndicator(
              value: _total == 0 ? null : _done / _total,
            ),
            AppSpacing.verticalXs,
            Text('取り込んでいます… $_done / $_total'),
          ] else
            FilledButton.icon(
              key: const Key('csv_import_run'),
              onPressed:
                  (plan == null || plan.customers.isEmpty) ? null : _import,
              icon: const Icon(Icons.download_done),
              label: const Text('取り込む'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(AppSpacing.tapTargetMin),
              ),
            ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final LedgerImportResult result;
  final VoidCallback onDone;

  const _ResultCard({required this.result, required this.onDone});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle, color: AppColors.success),
              AppSpacing.horizontalXs,
              Text('取り込みました', style: theme.textTheme.titleMedium),
            ],
          ),
          AppSpacing.verticalSm,
          Text(
            '新しい顧客 ${result.createdCustomers}人・'
            '更新 ${result.updatedCustomers}人・車両 ${result.vehicles}台',
            key: const Key('csv_import_result'),
          ),
          AppSpacing.verticalMd,
          FilledButton(
            key: const Key('csv_import_done'),
            onPressed: onDone,
            child: const Text('台帳に戻る'),
          ),
        ],
      ),
    );
  }
}
