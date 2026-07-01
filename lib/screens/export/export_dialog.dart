import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../models/vehicle.dart';
import '../../models/maintenance_record.dart';
import '../../services/pdf_export_service.dart';
import '../../core/di/service_locator.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/spacing.dart';
import '../../widgets/common/loading_indicator.dart';

/// エクスポートするレポートの種類
enum ExportReportType {
  /// 従来のメンテナンス履歴レポート
  maintenance,

  /// 「愛車カルテ」形式（Issue #64）
  carte,
}

/// メンテナンス履歴レポートの出力ダイアログを表示
Future<void> showExportDialog({
  required BuildContext context,
  required Vehicle vehicle,
  required List<MaintenanceRecord> records,
}) async {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => _ExportDialog(
      vehicle: vehicle,
      records: records,
      reportType: ExportReportType.maintenance,
    ),
  );
}

/// 「愛車カルテ」PDF出力ダイアログを表示（Issue #64）
Future<void> showCarteDialog({
  required BuildContext context,
  required Vehicle vehicle,
  required List<MaintenanceRecord> records,
}) async {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => _ExportDialog(
      vehicle: vehicle,
      records: records,
      reportType: ExportReportType.carte,
    ),
  );
}

class _ExportDialog extends StatefulWidget {
  final Vehicle vehicle;
  final List<MaintenanceRecord> records;
  final ExportReportType reportType;

  const _ExportDialog({
    required this.vehicle,
    required this.records,
    required this.reportType,
  });

  @override
  State<_ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<_ExportDialog> {
  PdfExportService get _pdfService => sl.get<PdfExportService>();
  bool _isLoading = false;
  Uint8List? _pdfData;

  bool get _isCarte => widget.reportType == ExportReportType.carte;

  @override
  void initState() {
    super.initState();
    _generatePdf();
  }

  Future<void> _generatePdf() async {
    setState(() => _isLoading = true);

    final result = _isCarte
        ? await _pdfService.generateCarteReport(
            vehicle: widget.vehicle,
            records: widget.records,
          )
        : await _pdfService.generateMaintenanceReport(
            vehicle: widget.vehicle,
            records: widget.records,
          );

    if (!mounted) return;
    result.when(
      success: (data) => _pdfData = data,
      failure: (error) => showAppErrorSnackBar(context, error),
    );
    setState(() => _isLoading = false);
  }

  Future<void> _previewPdf() async {
    if (_pdfData == null) return;
    Navigator.pop(context);
    await Printing.layoutPdf(
      onLayout: (_) async => _pdfData!,
      name: _getFileName(),
    );
  }

  Future<void> _sharePdf() async {
    if (_pdfData == null) return;

    try {
      setState(() => _isLoading = true);
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/${_getFileName()}');
      await file.writeAsBytes(_pdfData!);

      if (!mounted) return;
      Navigator.pop(context);

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: _shareSubject(),
      );
    } catch (e) {
      if (mounted) showErrorSnackBar(context, '共有に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _printPdf() async {
    if (_pdfData == null) return;
    Navigator.pop(context);
    await Printing.directPrintPdf(
      printer: await Printing.pickPrinter(context: context) ??
          const Printer(url: ''),
      onLayout: (_) async => _pdfData!,
      name: _getFileName(),
    );
  }

  String _getFileName() {
    final date = DateTime.now();
    final dateStr =
        '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
    final prefix = _isCarte ? 'carte' : 'maintenance_report';
    return '${prefix}_${widget.vehicle.maker}_${widget.vehicle.model}_$dateStr.pdf';
  }

  String _shareSubject() {
    final name = '${widget.vehicle.maker} ${widget.vehicle.model}';
    return _isCarte ? '$name 愛車カルテ' : '$name メンテナンス履歴';
  }

  String get _dialogTitle => _isCarte ? '愛車カルテを出力' : 'メンテナンス履歴をエクスポート';

  String get _loadingMessage => _isCarte ? '愛車カルテを生成中...' : 'PDFを生成中...';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: AppSpacing.paddingScreen,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ハンドル
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // タイトル
            Text(
              _dialogTitle,
              style: theme.textTheme.headlineLarge,
              textAlign: TextAlign.center,
            ),
            AppSpacing.verticalXs,
            Text(
              '${widget.vehicle.maker} ${widget.vehicle.model} / ${widget.records.length}件の履歴',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            AppSpacing.verticalLg,

            if (_isLoading) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                child: AppLoadingCenter(message: _loadingMessage),
              ),
            ] else ...[
              _ExportOption(
                icon: Icons.print,
                title: 'プレビュー / 印刷',
                description: 'PDFをプレビューして印刷します',
                onTap: _previewPdf,
              ),
              AppSpacing.verticalSm,
              _ExportOption(
                icon: Icons.share,
                title: '共有',
                description: '他のアプリにPDFを共有します',
                onTap: _sharePdf,
              ),
              AppSpacing.verticalSm,
              _ExportOption(
                icon: Icons.local_printshop,
                title: 'ダイレクト印刷',
                description: 'プリンターを選択して直接印刷します',
                onTap: _printPdf,
              ),
            ],

            AppSpacing.verticalLg,
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル'),
            ),
            AppSpacing.verticalSm,
          ],
        ),
      ),
    );
  }
}

class _ExportOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _ExportOption({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: isDark ? AppColors.darkCard : AppColors.backgroundLight,
      borderRadius: AppSpacing.borderRadiusMd,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppSpacing.borderRadiusMd,
        child: Padding(
          padding: AppSpacing.paddingCard,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: AppSpacing.borderRadiusSm,
                ),
                child: Icon(icon, color: AppColors.primary),
              ),
              AppSpacing.horizontalMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(description, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: isDark
                    ? AppColors.darkTextTertiary
                    : AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
