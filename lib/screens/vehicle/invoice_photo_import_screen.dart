import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/spacing.dart';
import '../../core/error/app_error.dart';
import '../../core/result/result.dart';
import '../../models/maintenance_record.dart';
import '../../models/vehicle.dart';
import '../../services/invoice_ocr_service.dart';
import '../../services/maintenance_history_import.dart';
import '../../services/maintenance_history_import_service.dart';

/// 請求書の写真を選ぶ関数（パスの一覧）。テストで差し替える。
typedef InvoicePhotoPicker = Future<List<String>> Function();

/// 1枚を読む関数。テストで差し替える。
typedef InvoiceReader = Future<Result<InvoiceData, AppError>> Function(
    String path);

Future<List<String>> _pickPhotos() async {
  final picked = await ImagePicker().pickMultiImage();
  return picked.map((x) => x.path).toList();
}

Future<Result<InvoiceData, AppError>> _readWithOcr(String path) =>
    InvoiceOcrService().extractFromImage(File(path));

/// 読み取った請求書1枚ぶんの下書き。画面で直してから取り込む。
class InvoiceDraft {
  final String name;
  DateTime? date;
  int? total;
  final String? shopName;
  final MaintenanceType type;
  final String title;
  final int? mileage;
  final String? invoiceNumber;
  bool include;

  InvoiceDraft({
    required this.name,
    required this.date,
    required this.total,
    required this.shopName,
    required this.type,
    required this.title,
    required this.mileage,
    required this.invoiceNumber,
    this.include = true,
  });

  /// 読み取り結果から下書きを作る。
  ///
  /// 内容は、明細の1行目 → 推定した種類 → 「整備」の順。**読めなかった日付と
  /// 金額は空のまま**にして、画面で入れてもらう（推測で埋めない）。
  factory InvoiceDraft.fromInvoice(String name, InvoiceData d) {
    final type = d.estimatedMaintenanceType ??
        guessMaintenanceType(d.items.isEmpty ? null : d.items.first.name);
    final first = d.items.isEmpty ? null : d.items.first.name.trim();
    var title = (first != null && first.isNotEmpty)
        ? first
        : (type == MaintenanceType.other ? '整備' : type.displayName);
    if (title.length > 100) title = title.substring(0, 100);
    return InvoiceDraft(
      name: name,
      date: d.date,
      total: d.totalAmount,
      shopName: d.shopName,
      type: type,
      title: title,
      mileage: d.mileage,
      invoiceNumber: d.invoiceNumber,
    );
  }

  /// 取り込める状態か（日付と金額がそろっていて、未来の日付でない）。
  bool isReady(DateTime today) =>
      date != null && total != null && total! >= 0 && !date!.isAfter(today);

  HistoryImportRow toRow(int line) => HistoryImportRow(
        line: line,
        date: date!,
        type: type,
        title: title,
        cost: total!,
        mileage: mileage,
        shopName: shopName,
        memo: invoiceNumber == null
            ? '請求書の写真から'
            : '請求書の写真から（請求書番号 $invoiceNumber）',
      );
}

String _date(DateTime d) => '${d.year}/${d.month}/${d.day}';

String _yen(int v) => v.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (m) => '${m[1]},',
    );

/// 請求書の写真から、過去の整備記録をまとめて移す（スマートフォンのみ）。
///
/// 読み取りは端末の中で行う（写真は外に送らない）。読めなかった日付と金額は
/// その場で入れてもらう。取り込みは記入用フォーマットと同じ処理なので、
/// 同じ請求書を2回読み込んでも二重にならない。
class InvoicePhotoImportScreen extends StatefulWidget {
  final Vehicle vehicle;
  final String userId;
  final MaintenanceHistoryImportService service;
  final InvoicePhotoPicker pickPhotos;
  final InvoiceReader readInvoice;
  final DateTime? today;

  const InvoicePhotoImportScreen({
    super.key,
    required this.vehicle,
    required this.userId,
    required this.service,
    this.pickPhotos = _pickPhotos,
    this.readInvoice = _readWithOcr,
    this.today,
  });

  @override
  State<InvoicePhotoImportScreen> createState() =>
      _InvoicePhotoImportScreenState();
}

class _InvoicePhotoImportScreenState extends State<InvoicePhotoImportScreen> {
  final List<InvoiceDraft> _drafts = [];
  final List<String> _unreadable = [];
  int _reading = 0;
  int _readTotal = 0;
  bool _importing = false;
  String? _error;
  HistoryImportResult? _result;

  DateTime get _today => widget.today ?? DateTime.now();

  Future<void> _pick() async {
    final paths = await widget.pickPhotos();
    if (paths.isEmpty || !mounted) return;
    setState(() {
      _readTotal = paths.length;
      _reading = 0;
      _error = null;
    });
    for (final path in paths) {
      final name = path.split('/').last;
      final r = await widget.readInvoice(path);
      if (!mounted) return;
      setState(() {
        _reading++;
        final data = r.valueOrNull;
        if (data == null) {
          _unreadable.add(name);
        } else {
          _drafts.add(InvoiceDraft.fromInvoice(name, data));
        }
      });
    }
    setState(() => _readTotal = 0);
  }

  Future<void> _editDate(InvoiceDraft d) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: d.date ?? _today,
      firstDate: DateTime(1990),
      lastDate: _today,
    );
    if (picked != null) setState(() => d.date = picked);
  }

  Future<void> _editTotal(InvoiceDraft d) async {
    final value = await showDialog<int>(
      context: context,
      builder: (_) => _AmountDialog(initial: d.total),
    );
    if (value != null && value >= 0) setState(() => d.total = value);
  }

  List<InvoiceDraft> get _ready =>
      _drafts.where((d) => d.include && d.isReady(_today)).toList();

  Future<void> _import() async {
    final rows = [
      for (var i = 0; i < _ready.length; i++) _ready[i].toRow(i + 1),
    ];
    setState(() {
      _importing = true;
      _error = null;
    });
    final r = await widget.service.importRows(
      userId: widget.userId,
      vehicleId: widget.vehicle.id,
      rows: rows,
    );
    if (!mounted) return;
    r.when(
      success: (res) => setState(() {
        _result = res;
        _importing = false;
      }),
      failure: (e) => setState(() {
        _error = e.userMessage;
        _importing = false;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = _result;
    final needsInput =
        _drafts.where((d) => d.include && !d.isReady(_today)).length;

    return Scaffold(
      appBar: AppBar(title: const Text('請求書の写真から移す')),
      body: ListView(
        padding: AppSpacing.paddingScreen,
        children: [
          if (result != null) ...[
            Text(
              '${result.added}件を追加しました'
              '${result.skipped > 0 ? '（${result.skipped}件は取り込み済み）' : ''}',
              key: const Key('invoice_import_result'),
              style: theme.textTheme.titleMedium,
            ),
            AppSpacing.verticalMd,
            FilledButton(
              key: const Key('invoice_import_done'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('戻る'),
            ),
          ] else ...[
            const Text('請求書の写真を選ぶと、日付・金額・お店を読み取ります。'
                '写真は端末の中で読み取り、外には送りません。'
                '読めなかったところは、この画面で入れてください。'),
            AppSpacing.verticalMd,
            OutlinedButton.icon(
              key: const Key('invoice_pick'),
              onPressed: (_readTotal > 0 || _importing) ? null : _pick,
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(_drafts.isEmpty ? '請求書の写真を選ぶ' : '写真を追加する'),
            ),
            if (_readTotal > 0) ...[
              AppSpacing.verticalSm,
              LinearProgressIndicator(value: _reading / _readTotal),
              Text('読み取っています… $_reading / $_readTotal'),
            ],
            if (_unreadable.isNotEmpty) ...[
              AppSpacing.verticalSm,
              Text(
                '読み取れなかった写真: ${_unreadable.join('、')}',
                key: const Key('invoice_unreadable'),
                style: const TextStyle(color: AppColors.warning),
              ),
            ],
            for (final d in _drafts)
              Card(
                margin: const EdgeInsets.only(top: AppSpacing.sm),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Checkbox(
                            value: d.include,
                            onChanged: (v) =>
                                setState(() => d.include = v ?? false),
                          ),
                          Expanded(
                            child: Text(
                              '${d.title}（${d.type.displayName}）',
                              style: theme.textTheme.titleSmall,
                            ),
                          ),
                        ],
                      ),
                      Wrap(
                        spacing: AppSpacing.xs,
                        children: [
                          ActionChip(
                            avatar: const Icon(Icons.event, size: 16),
                            label: Text(
                                d.date == null ? '日付を入れる' : _date(d.date!)),
                            backgroundColor: d.date == null
                                ? AppColors.warning.withValues(alpha: 0.15)
                                : null,
                            onPressed: () => _editDate(d),
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.currency_yen, size: 16),
                            label: Text(d.total == null
                                ? '金額を入れる'
                                : '${_yen(d.total!)}円'),
                            backgroundColor: d.total == null
                                ? AppColors.warning.withValues(alpha: 0.15)
                                : null,
                            onPressed: () => _editTotal(d),
                          ),
                          if (d.shopName != null)
                            Chip(label: Text(d.shopName!)),
                        ],
                      ),
                      Text(d.name, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ),
            if (_drafts.isNotEmpty) ...[
              AppSpacing.verticalMd,
              if (needsInput > 0)
                Text(
                  '日付か金額が入っていないものが $needsInput 件あります'
                  '（入れるか、チェックを外してください）',
                  key: const Key('invoice_needs_input'),
                  style: const TextStyle(color: AppColors.warning),
                ),
              FilledButton.icon(
                key: const Key('invoice_import_run'),
                onPressed: (_importing || _ready.isEmpty) ? null : _import,
                icon: const Icon(Icons.download_done),
                label: Text('${_ready.length}件を移す'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(AppSpacing.tapTargetMin),
                ),
              ),
            ],
          ],
          if (_error != null)
            Text(_error!, style: const TextStyle(color: AppColors.error)),
          AppSpacing.verticalXl,
        ],
      ),
    );
  }
}

/// 金額を入れるダイアログ。入力欄の後片付けは、閉じ終わってからこの部品が
/// 自分で行う（呼び出し側で先に破棄すると、閉じる途中の入力欄が落ちる）。
class _AmountDialog extends StatefulWidget {
  final int? initial;

  const _AmountDialog({this.initial});

  @override
  State<_AmountDialog> createState() => _AmountDialogState();
}

class _AmountDialogState extends State<_AmountDialog> {
  late final _controller =
      TextEditingController(text: widget.initial?.toString() ?? '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('金額（税込）'),
      content: TextField(
        key: const Key('invoice_total_field'),
        controller: _controller,
        keyboardType: TextInputType.number,
        autofocus: true,
        decoration: const InputDecoration(suffixText: '円'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('やめる'),
        ),
        TextButton(
          key: const Key('invoice_total_ok'),
          onPressed: () => Navigator.pop(
            context,
            int.tryParse(_controller.text.replaceAll(',', '').trim()),
          ),
          child: const Text('決める'),
        ),
      ],
    );
  }
}
