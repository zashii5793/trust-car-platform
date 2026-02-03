import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../core/result/result.dart';
import '../core/error/app_error.dart';
import '../models/maintenance_record.dart';

/// 請求書から抽出されたデータ
class InvoiceData {
  final DateTime? date;              // 請求日/作業日
  final int? totalAmount;            // 合計金額
  final int? taxAmount;              // 消費税
  final int? subtotalAmount;         // 小計（税抜）
  final String? shopName;            // 店舗名/整備工場名
  final String? shopAddress;         // 店舗住所
  final String? shopPhone;           // 電話番号
  final String? invoiceNumber;       // 請求書番号
  final List<InvoiceItem> items;     // 明細項目
  final String? vehicleInfo;         // 車両情報（ナンバー等）
  final int? mileage;                // 走行距離

  InvoiceData({
    this.date,
    this.totalAmount,
    this.taxAmount,
    this.subtotalAmount,
    this.shopName,
    this.shopAddress,
    this.shopPhone,
    this.invoiceNumber,
    this.items = const [],
    this.vehicleInfo,
    this.mileage,
  });

  /// 整備記録に変換可能な情報があるか
  bool get hasMaintenanceInfo =>
      date != null || totalAmount != null || items.isNotEmpty;

  /// 信頼度スコア
  double get confidenceScore {
    int total = 10;
    int filled = 0;
    if (date != null) filled++;
    if (totalAmount != null) filled++;
    if (taxAmount != null) filled++;
    if (subtotalAmount != null) filled++;
    if (shopName != null) filled++;
    if (shopAddress != null) filled++;
    if (shopPhone != null) filled++;
    if (invoiceNumber != null) filled++;
    if (items.isNotEmpty) filled++;
    if (mileage != null) filled++;
    return filled / total;
  }

  /// メインの整備タイプを推定
  MaintenanceType? get estimatedMaintenanceType {
    if (items.isEmpty) return null;

    // 項目名から整備タイプを推定
    for (final item in items) {
      final name = item.name.toLowerCase();

      if (name.contains('車検') || name.contains('検査')) {
        return MaintenanceType.carInspection;
      }
      if (name.contains('オイル') && name.contains('交換')) {
        return MaintenanceType.oilChange;
      }
      if (name.contains('オイルフィルター') || name.contains('オイルエレメント')) {
        return MaintenanceType.oilFilterChange;
      }
      if (name.contains('タイヤ') && name.contains('交換')) {
        return MaintenanceType.tireChange;
      }
      if (name.contains('タイヤ') && name.contains('ローテーション')) {
        return MaintenanceType.tireRotation;
      }
      if (name.contains('ブレーキパッド')) {
        return MaintenanceType.brakePadChange;
      }
      if (name.contains('バッテリー')) {
        return MaintenanceType.batteryChange;
      }
      if (name.contains('ワイパー')) {
        return MaintenanceType.wiperChange;
      }
      if (name.contains('エアコン') || name.contains('エアクリーナー')) {
        return MaintenanceType.airFilterChange;
      }
      if (name.contains('12ヶ月点検') || name.contains('12か月点検')) {
        return MaintenanceType.legalInspection12;
      }
      if (name.contains('24ヶ月点検') || name.contains('24か月点検')) {
        return MaintenanceType.legalInspection24;
      }
      if (name.contains('点検')) {
        return MaintenanceType.legalInspection12;
      }
      if (name.contains('修理') || name.contains('板金') || name.contains('塗装')) {
        return MaintenanceType.repair;
      }
      if (name.contains('洗車') || name.contains('コーティング')) {
        return MaintenanceType.washing;
      }
    }

    return MaintenanceType.other;
  }

  @override
  String toString() {
    return '''
InvoiceData(
  date: $date,
  totalAmount: $totalAmount,
  shopName: $shopName,
  items: ${items.length}件,
  confidenceScore: ${(confidenceScore * 100).toStringAsFixed(1)}%
)''';
  }
}

/// 請求書の明細項目
class InvoiceItem {
  final String name;           // 項目名
  final int? quantity;         // 数量
  final int? unitPrice;        // 単価
  final int? amount;           // 金額
  final String? partNumber;    // 部品番号

  InvoiceItem({
    required this.name,
    this.quantity,
    this.unitPrice,
    this.amount,
    this.partNumber,
  });

  @override
  String toString() => 'InvoiceItem($name: ¥$amount)';
}

/// 請求書OCRサービス
class InvoiceOcrService {
  final TextRecognizer _textRecognizer;

  InvoiceOcrService()
      : _textRecognizer = TextRecognizer(script: TextRecognitionScript.japanese);

  /// 画像ファイルから請求書情報を抽出
  Future<Result<InvoiceData, AppError>> extractFromImage(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final recognizedText = await _textRecognizer.processImage(inputImage);

      final data = _parseRecognizedText(recognizedText);

      if (!data.hasMaintenanceInfo) {
        return Result.failure(
          AppError.validation('請求書の情報を読み取れませんでした。\n画像が鮮明か確認してください。'),
        );
      }

      return Result.success(data);
    } catch (e) {
      return Result.failure(
        AppError.unknown('OCR処理中にエラーが発生しました: $e'),
      );
    }
  }

  /// 認識されたテキストを解析
  InvoiceData _parseRecognizedText(RecognizedText recognizedText) {
    final fullText = recognizedText.text;
    final lines = fullText.split('\n');

    // デバッグ出力
    assert(() {
      debugPrint('=== Invoice OCR Text ===');
      debugPrint(fullText);
      debugPrint('========================');
      return true;
    }());

    DateTime? date;
    int? totalAmount;
    int? taxAmount;
    int? subtotalAmount;
    String? shopName;
    String? shopAddress;
    String? shopPhone;
    String? invoiceNumber;
    String? vehicleInfo;
    int? mileage;
    List<InvoiceItem> items = [];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      // 日付を抽出
      date ??= _extractDate(line);

      // 金額を抽出
      if (totalAmount == null && _containsKeyword(line, ['合計', '請求金額', 'ご請求', '総額'])) {
        totalAmount = _extractAmount(line);
      }
      if (taxAmount == null && _containsKeyword(line, ['消費税', '税額', '税'])) {
        taxAmount = _extractAmount(line);
      }
      if (subtotalAmount == null && _containsKeyword(line, ['小計', '税抜', '本体'])) {
        subtotalAmount = _extractAmount(line);
      }

      // 店舗情報を抽出
      if (shopName == null && _isLikelyShopName(line)) {
        shopName = _cleanShopName(line);
      }
      shopPhone ??= _extractPhoneNumber(line);

      // 請求書番号
      if (invoiceNumber == null && _containsKeyword(line, ['請求書番号', '伝票番号', 'No.', 'NO.'])) {
        invoiceNumber = _extractInvoiceNumber(line);
      }

      // 車両情報
      vehicleInfo ??= _extractVehicleInfo(line);

      // 走行距離
      if (mileage == null && _containsKeyword(line, ['走行', 'km', 'KM', 'ODO'])) {
        mileage = _extractMileage(line);
      }

      // 明細項目を抽出
      final item = _extractInvoiceItem(line);
      if (item != null) {
        items.add(item);
      }
    }

    // 合計金額が取れなかった場合、最大金額を合計とする
    if (totalAmount == null && items.isNotEmpty) {
      final amounts = items.where((i) => i.amount != null).map((i) => i.amount!);
      if (amounts.isNotEmpty) {
        totalAmount = amounts.reduce((a, b) => a > b ? a : b);
      }
    }

    return InvoiceData(
      date: date,
      totalAmount: totalAmount,
      taxAmount: taxAmount,
      subtotalAmount: subtotalAmount,
      shopName: shopName,
      shopAddress: shopAddress,
      shopPhone: shopPhone,
      invoiceNumber: invoiceNumber,
      items: items,
      vehicleInfo: vehicleInfo,
      mileage: mileage,
    );
  }

  bool _containsKeyword(String text, List<String> keywords) {
    for (final keyword in keywords) {
      if (text.contains(keyword)) return true;
    }
    return false;
  }

  /// 日付を抽出
  DateTime? _extractDate(String line) {
    // 和暦パターン: 令和6年1月15日
    final eraPatterns = [
      RegExp(r'令和\s*(\d{1,2})\s*年\s*(\d{1,2})\s*月\s*(\d{1,2})\s*日'),
      RegExp(r'R\s*(\d{1,2})[./年]\s*(\d{1,2})[./月]\s*(\d{1,2})'),
    ];

    for (final pattern in eraPatterns) {
      final match = pattern.firstMatch(line);
      if (match != null) {
        final year = 2018 + int.parse(match.group(1)!);
        final month = int.parse(match.group(2)!);
        final day = int.parse(match.group(3)!);
        return DateTime(year, month, day);
      }
    }

    // 西暦パターン: 2024/01/15, 2024-01-15, 2024年1月15日
    final datePatterns = [
      RegExp(r'(20\d{2})[/\-年]\s*(\d{1,2})[/\-月]\s*(\d{1,2})'),
    ];

    for (final pattern in datePatterns) {
      final match = pattern.firstMatch(line);
      if (match != null) {
        final year = int.parse(match.group(1)!);
        final month = int.parse(match.group(2)!);
        final day = int.parse(match.group(3)!);
        return DateTime(year, month, day);
      }
    }

    return null;
  }

  /// 金額を抽出
  int? _extractAmount(String line) {
    // ¥マーク付き、カンマ区切り対応
    final patterns = [
      RegExp(r'[¥￥]\s*([\d,]+)'),
      RegExp(r'([\d,]+)\s*円'),
      RegExp(r'([\d,]{4,})'),  // 4桁以上の数字
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(line);
      if (match != null) {
        final amountStr = match.group(1)!.replaceAll(',', '');
        final amount = int.tryParse(amountStr);
        if (amount != null && amount >= 100) {  // 100円以上を金額とみなす
          return amount;
        }
      }
    }
    return null;
  }

  /// 店舗名らしいかどうか判定
  bool _isLikelyShopName(String line) {
    final shopKeywords = [
      '株式会社', '有限会社', '合同会社',
      'オートバックス', 'イエローハット', 'タイヤ館',
      '整備', '工場', 'サービス', 'モータース',
      'カーショップ', 'ガレージ', 'ディーラー',
    ];

    for (final keyword in shopKeywords) {
      if (line.contains(keyword)) return true;
    }
    return false;
  }

  /// 店舗名をクリーンアップ
  String _cleanShopName(String line) {
    // 電話番号や住所を除去
    var name = line;
    name = name.replaceAll(RegExp(r'[\d\-]{10,}'), '');
    name = name.replaceAll(RegExp(r'〒[\d\-]+'), '');
    return name.trim();
  }

  /// 電話番号を抽出
  String? _extractPhoneNumber(String line) {
    final pattern = RegExp(r'(\d{2,4}[-\s]?\d{2,4}[-\s]?\d{3,4})');
    final match = pattern.firstMatch(line);
    if (match != null) {
      final phone = match.group(1)!;
      if (phone.replaceAll(RegExp(r'[\-\s]'), '').length >= 10) {
        return phone;
      }
    }
    return null;
  }

  /// 請求書番号を抽出
  String? _extractInvoiceNumber(String line) {
    final pattern = RegExp(r'[A-Z0-9\-]{5,}');
    final match = pattern.firstMatch(line);
    return match?.group(0);
  }

  /// 車両情報（ナンバー）を抽出
  String? _extractVehicleInfo(String line) {
    final pattern = RegExp(r'([一-龥ぁ-んァ-ヶ]{2,4})\s*(\d{3})\s*([あ-んア-ン])\s*(\d{1,4}[-−]?\d{1,4}|\d{2,4})');
    final match = pattern.firstMatch(line);
    if (match != null) {
      return '${match.group(1)} ${match.group(2)} ${match.group(3)} ${match.group(4)}';
    }
    return null;
  }

  /// 走行距離を抽出
  int? _extractMileage(String line) {
    final pattern = RegExp(r'([\d,]+)\s*(km|KM|キロ)');
    final match = pattern.firstMatch(line);
    if (match != null) {
      final mileageStr = match.group(1)!.replaceAll(',', '');
      return int.tryParse(mileageStr);
    }
    return null;
  }

  /// 明細項目を抽出
  InvoiceItem? _extractInvoiceItem(String line) {
    // 整備関連のキーワードがある行を明細とみなす
    final maintenanceKeywords = [
      'オイル', 'タイヤ', 'ブレーキ', 'バッテリー', 'フィルター',
      'ワイパー', 'エアコン', '点検', '車検', '整備', '修理',
      '交換', '工賃', '部品', 'パーツ', '洗車', 'コーティング',
    ];

    bool isMaintenanceItem = false;
    for (final keyword in maintenanceKeywords) {
      if (line.contains(keyword)) {
        isMaintenanceItem = true;
        break;
      }
    }

    if (!isMaintenanceItem) return null;

    // 金額を抽出
    final amount = _extractAmount(line);
    if (amount == null) return null;

    // 項目名を抽出（金額部分を除去）
    var name = line;
    name = name.replaceAll(RegExp(r'[¥￥]\s*[\d,]+'), '');
    name = name.replaceAll(RegExp(r'[\d,]+\s*円'), '');
    name = name.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (name.isEmpty) return null;

    // 数量を抽出
    int? quantity;
    final qtyPattern = RegExp(r'(\d+)\s*(個|本|セット|枚|L|リットル)');
    final qtyMatch = qtyPattern.firstMatch(line);
    if (qtyMatch != null) {
      quantity = int.tryParse(qtyMatch.group(1)!);
    }

    return InvoiceItem(
      name: name,
      quantity: quantity,
      amount: amount,
    );
  }

  void dispose() {
    _textRecognizer.close();
  }
}
