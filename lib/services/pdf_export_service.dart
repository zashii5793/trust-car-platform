import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../core/error/app_error.dart';
import '../core/result/result.dart';
import '../models/vehicle.dart';
import '../models/maintenance_record.dart';

/// PDF出力サービス
class PdfExportService {
  /// 愛車カルテPDFを生成（車両情報＋整備履歴の完全記録）
  Future<Result<Uint8List, AppError>> generateVehicleKarte({
    required Vehicle vehicle,
    required List<MaintenanceRecord> records,
  }) async {
    try {
      final pdf = pw.Document();
      final dateFormat = DateFormat('yyyy/MM/dd');
      final numberFormat = NumberFormat('#,###');

      final sortedRecords = List<MaintenanceRecord>.from(records)
        ..sort((a, b) => b.date.compareTo(a.date));
      final totalCost = sortedRecords.fold<int>(0, (sum, r) => sum + r.cost);

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          maxPages: 9999,
          header: (context) => _buildKarteHeader(vehicle),
          footer: (context) => _buildKarteFooter(context),
          build: (context) => [
            _buildBasicInfoSection(vehicle, numberFormat, dateFormat),
            pw.SizedBox(height: 16),
            _buildLegalSection(vehicle, dateFormat),
            if (vehicle.leaseInfo != null &&
                vehicle.leaseInfo!.hasAnyValue) ...[
              pw.SizedBox(height: 16),
              _buildLeaseSection(vehicle.leaseInfo!, numberFormat, dateFormat),
            ],
            pw.SizedBox(height: 16),
            _buildKarteSummarySection(sortedRecords, totalCost, numberFormat),
            pw.SizedBox(height: 16),
            ..._buildMaintenanceTableWidgets(
                sortedRecords, dateFormat, numberFormat),
            pw.SizedBox(height: 20),
            _buildKarteDisclaimer(),
          ],
        ),
      );

      return Result.success(await pdf.save());
    } catch (e) {
      return Result.failure(AppError.server('愛車カルテの生成に失敗しました: $e'));
    }
  }

  pw.Widget _buildKarteHeader(Vehicle vehicle) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(width: 2, color: PdfColors.teal800),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                '愛車カルテ',
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.teal800,
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
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildKarteFooter(pw.Context context) {
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
            'Trust Car Platform — 愛車カルテ',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
          ),
          pw.Text(
            'ページ ${context.pageNumber} / ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildBasicInfoSection(
    Vehicle vehicle,
    NumberFormat numberFormat,
    DateFormat dateFormat,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: PdfColors.teal50,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            '基本情報',
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.teal800,
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Row(children: [
            _buildInfoItem('メーカー', vehicle.maker),
            _buildInfoItem('車種', vehicle.model),
            _buildInfoItem('年式', '${vehicle.year}年'),
          ]),
          pw.SizedBox(height: 8),
          pw.Row(children: [
            _buildInfoItem('グレード', vehicle.grade),
            _buildInfoItem('燃料タイプ', vehicle.fuelType?.displayName ?? '未設定'),
            _buildInfoItem('車体色', vehicle.color ?? '未設定'),
          ]),
          pw.SizedBox(height: 8),
          pw.Row(children: [
            _buildInfoItem(
                '走行距離', '${numberFormat.format(vehicle.mileage)} km'),
            _buildInfoItem(
              '購入日',
              vehicle.purchaseDate != null
                  ? dateFormat.format(vehicle.purchaseDate!)
                  : '未設定',
            ),
            pw.Expanded(child: pw.SizedBox()),
          ]),
        ],
      ),
    );
  }

  pw.Widget _buildLegalSection(Vehicle vehicle, DateFormat dateFormat) {
    final now = DateTime.now();
    final inspDays = vehicle.inspectionExpiryDate?.difference(now).inDays;

    String inspectionText;
    PdfColor inspectionColor;
    if (vehicle.inspectionExpiryDate == null) {
      inspectionText = '未設定';
      inspectionColor = PdfColors.grey600;
    } else {
      final dateStr = dateFormat.format(vehicle.inspectionExpiryDate!);
      if (inspDays! < 0) {
        inspectionText = '$dateStr（期限切れ）';
        inspectionColor = PdfColors.red700;
      } else if (inspDays <= 30) {
        inspectionText = '$dateStr（あと$inspDays日）';
        inspectionColor = PdfColors.orange700;
      } else {
        inspectionText = '$dateStr（あと$inspDays日）';
        inspectionColor = PdfColors.green700;
      }
    }

    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            '登録・法定管理',
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue800,
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Row(children: [
            _buildInfoItem('ナンバープレート', vehicle.licensePlate ?? '未設定'),
            _buildInfoItem('車台番号', vehicle.vinNumber ?? '未設定'),
            pw.Expanded(child: pw.SizedBox()),
          ]),
          pw.SizedBox(height: 8),
          pw.Row(children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('車検満了日',
                      style: const pw.TextStyle(
                          fontSize: 9, color: PdfColors.grey600)),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    inspectionText,
                    style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                        color: inspectionColor),
                  ),
                ],
              ),
            ),
            _buildInfoItem(
              '自賠責保険期限',
              vehicle.insuranceExpiryDate != null
                  ? dateFormat.format(vehicle.insuranceExpiryDate!)
                  : '未設定',
            ),
            pw.Expanded(child: pw.SizedBox()),
          ]),
        ],
      ),
    );
  }

  pw.Widget _buildLeaseSection(
    LeaseInfo lease,
    NumberFormat numberFormat,
    DateFormat dateFormat,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: PdfColors.purple50,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'リース情報',
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.purple800,
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Row(children: [
            _buildInfoItem('リース会社', lease.lessorName ?? '未設定'),
            _buildInfoItem(
              '月額料金',
              lease.monthlyFee != null
                  ? '¥${numberFormat.format(lease.monthlyFee!)}'
                  : '未設定',
            ),
            pw.Expanded(child: pw.SizedBox()),
          ]),
          pw.SizedBox(height: 8),
          pw.Row(children: [
            _buildInfoItem(
              '契約開始日',
              lease.contractStartDate != null
                  ? dateFormat.format(lease.contractStartDate!)
                  : '未設定',
            ),
            _buildInfoItem(
              '契約満了日',
              lease.contractEndDate != null
                  ? dateFormat.format(lease.contractEndDate!)
                  : '未設定',
            ),
            pw.Expanded(child: pw.SizedBox()),
          ]),
          if (lease.maintenancePackDetails != null) ...[
            pw.SizedBox(height: 8),
            pw.Text('メンテナンスパック',
                style:
                    const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
            pw.SizedBox(height: 2),
            pw.Text(lease.maintenancePackDetails!,
                style: const pw.TextStyle(fontSize: 10)),
          ],
        ],
      ),
    );
  }

  pw.Widget _buildKarteSummarySection(
    List<MaintenanceRecord> records,
    int totalCost,
    NumberFormat numberFormat,
  ) {
    if (records.isEmpty) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Text(
          '整備履歴なし',
          style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey600),
        ),
      );
    }

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: _buildStatCard(
            '総整備費用',
            '¥${numberFormat.format(totalCost)}',
            PdfColors.teal800,
          ),
        ),
        pw.SizedBox(width: 10),
        pw.Expanded(
          child: _buildStatCard(
            '整備件数',
            '${records.length} 件',
            PdfColors.blue800,
          ),
        ),
        pw.SizedBox(width: 10),
        pw.Expanded(
          child: _buildStatCard(
            '平均費用',
            '¥${numberFormat.format((totalCost / records.length).round())}',
            PdfColors.orange800,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildKarteDisclaimer() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Text(
        '※ このカルテはユーザーが入力した情報に基づきます。'
        '整備記録の正確性については整備工場の公式書類をご確認ください。',
        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
      ),
    );
  }

  /// メンテナンス履歴のPDFを生成
  Future<Result<Uint8List, AppError>> generateMaintenanceReport({
    required Vehicle vehicle,
    required List<MaintenanceRecord> records,
  }) async {
    try {
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
          maxPages: 9999,
          header: (context) => _buildHeader(vehicle),
          footer: (context) => _buildFooter(context),
          build: (context) => [
            // 車両情報セクション
            _buildVehicleInfoSection(vehicle, numberFormat),
            pw.SizedBox(height: 20),

            // サマリーセクション
            _buildSummarySection(sortedRecords, totalCost, numberFormat),
            pw.SizedBox(height: 20),

            // メンテナンス履歴テーブル（スパニング対応のためテーブル直接配置）
            ..._buildMaintenanceTableWidgets(
                sortedRecords, dateFormat, numberFormat),
          ],
        ),
      );

      return Result.success(await pdf.save());
    } catch (e) {
      return Result.failure(AppError.server('PDFの生成に失敗しました: $e'));
    }
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
  pw.Widget _buildVehicleInfoSection(
      Vehicle vehicle, NumberFormat numberFormat) {
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
              _buildInfoItem(
                  '走行距離', '${numberFormat.format(vehicle.mileage)} km'),
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
  // Legacy single-widget version (kept for reference)
  // ignore: unused_element
  pw.Widget _buildMaintenanceTable(
    List<MaintenanceRecord> records,
    DateFormat dateFormat,
    NumberFormat numberFormat,
  ) =>
      pw.Column(
          children:
              _buildMaintenanceTableWidgets(records, dateFormat, numberFormat));

  /// テーブルをリストで返すことで MultiPage のスパニングに対応
  List<pw.Widget> _buildMaintenanceTableWidgets(
    List<MaintenanceRecord> records,
    DateFormat dateFormat,
    NumberFormat numberFormat,
  ) {
    return [
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
    ];
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
