import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../models/vehicle.dart';
import '../models/maintenance_record.dart';

/// PDF出力サービス
class PdfExportService {
  /// メンテナンス履歴のPDFを生成
  Future<Uint8List> generateMaintenanceReport({
    required Vehicle vehicle,
    required List<MaintenanceRecord> records,
  }) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('yyyy/MM/dd');
    final numberFormat = NumberFormat('#,###');

    // 日付でソート（新しい順）
    final sortedRecords = List<MaintenanceRecord>.from(records)
      ..sort((a, b) => b.date.compareTo(a.date));

    // 総費用計算
    final totalCost = sortedRecords.fold<int>(0, (sum, r) => sum + r.cost);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (context) => _buildHeader(vehicle),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          // 車両情報セクション
          _buildVehicleInfoSection(vehicle, numberFormat),
          pw.SizedBox(height: 20),

          // サマリーセクション
          _buildSummarySection(sortedRecords, totalCost, numberFormat),
          pw.SizedBox(height: 20),

          // メンテナンス履歴テーブル
          _buildMaintenanceTable(sortedRecords, dateFormat, numberFormat),
        ],
      ),
    );

    return pdf.save();
  }

  /// ヘッダー
  pw.Widget _buildHeader(Vehicle vehicle) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(width: 2, color: PdfColors.blue800),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'メンテナンス履歴レポート',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue800,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                '${vehicle.maker} ${vehicle.model}',
                style: const pw.TextStyle(
                  fontSize: 14,
                  color: PdfColors.grey700,
                ),
              ),
            ],
          ),
          pw.Text(
            '出力日: ${DateFormat('yyyy/MM/dd').format(DateTime.now())}',
            style: const pw.TextStyle(
              fontSize: 10,
              color: PdfColors.grey600,
            ),
          ),
        ],
      ),
    );
  }

  /// フッター
  pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(width: 1, color: PdfColors.grey400),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'クルマ統合管理アプリ',
            style: const pw.TextStyle(
              fontSize: 10,
              color: PdfColors.grey600,
            ),
          ),
          pw.Text(
            'ページ ${context.pageNumber} / ${context.pagesCount}',
            style: const pw.TextStyle(
              fontSize: 10,
              color: PdfColors.grey600,
            ),
          ),
        ],
      ),
    );
  }

  /// 車両情報セクション
  pw.Widget _buildVehicleInfoSection(Vehicle vehicle, NumberFormat numberFormat) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            '車両情報',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue800,
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            children: [
              _buildInfoItem('メーカー', vehicle.maker),
              _buildInfoItem('車種', vehicle.model),
              _buildInfoItem('年式', '${vehicle.year}年'),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              _buildInfoItem('グレード', vehicle.grade),
              _buildInfoItem('走行距離', '${numberFormat.format(vehicle.mileage)} km'),
              pw.Expanded(child: pw.SizedBox()),
            ],
          ),
        ],
      ),
    );
  }

  /// 情報アイテム
  pw.Widget _buildInfoItem(String label, String value) {
    return pw.Expanded(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(
              fontSize: 9,
              color: PdfColors.grey600,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// サマリーセクション
  pw.Widget _buildSummarySection(
    List<MaintenanceRecord> records,
    int totalCost,
    NumberFormat numberFormat,
  ) {
    // 種類別の集計
    final typeStats = <String, int>{};
    for (final record in records) {
      final typeName = _getTypeDisplayName(record.type);
      typeStats[typeName] = (typeStats[typeName] ?? 0) + record.cost;
    }

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // 総額
        pw.Expanded(
          child: _buildStatCard(
            '総費用',
            '¥${numberFormat.format(totalCost)}',
            PdfColors.blue800,
          ),
        ),
        pw.SizedBox(width: 10),
        // 履歴数
        pw.Expanded(
          child: _buildStatCard(
            '履歴数',
            '${records.length} 件',
            PdfColors.green800,
          ),
        ),
        pw.SizedBox(width: 10),
        // 平均費用
        pw.Expanded(
          child: _buildStatCard(
            '平均費用',
            records.isNotEmpty
                ? '¥${numberFormat.format((totalCost / records.length).round())}'
                : '-',
            PdfColors.orange800,
          ),
        ),
      ],
    );
  }

  /// 統計カード
  pw.Widget _buildStatCard(String label, String value, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: color, width: 1),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 10,
              color: color,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// メンテナンス履歴テーブル
  pw.Widget _buildMaintenanceTable(
    List<MaintenanceRecord> records,
    DateFormat dateFormat,
    NumberFormat numberFormat,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'メンテナンス履歴',
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blue800,
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(1.2), // 日付
            1: const pw.FlexColumnWidth(1), // 種類
            2: const pw.FlexColumnWidth(2), // タイトル
            3: const pw.FlexColumnWidth(1.2), // 費用
            4: const pw.FlexColumnWidth(1), // 走行距離
          },
          children: [
            // ヘッダー
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.blue800),
              children: [
                _buildTableHeader('日付'),
                _buildTableHeader('種類'),
                _buildTableHeader('内容'),
                _buildTableHeader('費用'),
                _buildTableHeader('走行距離'),
              ],
            ),
            // データ行
            ...records.asMap().entries.map((entry) {
              final index = entry.key;
              final record = entry.value;
              final isEven = index % 2 == 0;

              return pw.TableRow(
                decoration: pw.BoxDecoration(
                  color: isEven ? PdfColors.white : PdfColors.grey100,
                ),
                children: [
                  _buildTableCell(dateFormat.format(record.date)),
                  _buildTableCell(_getTypeDisplayName(record.type)),
                  _buildTableCell(record.title),
                  _buildTableCell(
                    '¥${numberFormat.format(record.cost)}',
                    alignment: pw.TextAlign.right,
                  ),
                  _buildTableCell(
                    record.mileageAtService != null
                        ? '${numberFormat.format(record.mileageAtService)} km'
                        : '-',
                    alignment: pw.TextAlign.right,
                  ),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }

  /// テーブルヘッダーセル
  pw.Widget _buildTableHeader(String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
        ),
      ),
    );
  }

  /// テーブルデータセル
  pw.Widget _buildTableCell(
    String text, {
    pw.TextAlign alignment = pw.TextAlign.left,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Text(
        text,
        style: const pw.TextStyle(fontSize: 9),
        textAlign: alignment,
      ),
    );
  }

  /// メンテナンスタイプの表示名
  String _getTypeDisplayName(MaintenanceType type) {
    return type.displayName;
  }
}
