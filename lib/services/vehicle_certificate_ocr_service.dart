import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../core/result/result.dart';
import '../core/error/app_error.dart';
import '../models/vehicle.dart';

/// 車検証から抽出されたデータ
class VehicleCertificateData {
  final String? registrationNumber;    // 登録番号（ナンバープレート）
  final String? vinNumber;             // 車台番号
  final String? modelCode;             // 型式
  final String? maker;                 // 車名（メーカー）
  final String? model;                 // 車名（モデル）
  final int? year;                     // 初度登録年
  final DateTime? inspectionExpiryDate; // 有効期間の満了する日
  final String? ownerName;             // 所有者の氏名又は名称
  final String? ownerAddress;          // 所有者の住所
  final int? engineDisplacement;       // 総排気量
  final String? fuelType;              // 燃料の種類
  final String? color;                 // 色
  final int? maxCapacity;              // 乗車定員
  final int? vehicleWeight;            // 車両重量
  final int? grossWeight;              // 車両総重量

  VehicleCertificateData({
    this.registrationNumber,
    this.vinNumber,
    this.modelCode,
    this.maker,
    this.model,
    this.year,
    this.inspectionExpiryDate,
    this.ownerName,
    this.ownerAddress,
    this.engineDisplacement,
    this.fuelType,
    this.color,
    this.maxCapacity,
    this.vehicleWeight,
    this.grossWeight,
  });

  /// 車両モデルに変換可能な情報があるか
  bool get hasVehicleInfo =>
      maker != null ||
      model != null ||
      vinNumber != null ||
      modelCode != null ||
      inspectionExpiryDate != null;

  /// 信頼度スコア（抽出できた項目数 / 全項目数）
  double get confidenceScore {
    int total = 15;
    int filled = 0;
    if (registrationNumber != null) filled++;
    if (vinNumber != null) filled++;
    if (modelCode != null) filled++;
    if (maker != null) filled++;
    if (model != null) filled++;
    if (year != null) filled++;
    if (inspectionExpiryDate != null) filled++;
    if (ownerName != null) filled++;
    if (ownerAddress != null) filled++;
    if (engineDisplacement != null) filled++;
    if (fuelType != null) filled++;
    if (color != null) filled++;
    if (maxCapacity != null) filled++;
    if (vehicleWeight != null) filled++;
    if (grossWeight != null) filled++;
    return filled / total;
  }

  @override
  String toString() {
    return '''
VehicleCertificateData(
  registrationNumber: $registrationNumber,
  vinNumber: $vinNumber,
  modelCode: $modelCode,
  maker: $maker,
  model: $model,
  year: $year,
  inspectionExpiryDate: $inspectionExpiryDate,
  engineDisplacement: $engineDisplacement,
  fuelType: $fuelType,
  color: $color,
  confidenceScore: ${(confidenceScore * 100).toStringAsFixed(1)}%
)''';
  }
}

/// 車検証OCRサービス
class VehicleCertificateOcrService {
  final TextRecognizer _textRecognizer;

  VehicleCertificateOcrService()
      : _textRecognizer = TextRecognizer(script: TextRecognitionScript.japanese);

  /// 画像ファイルから車検証情報を抽出
  Future<Result<VehicleCertificateData, AppError>> extractFromImage(
    File imageFile,
  ) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final recognizedText = await _textRecognizer.processImage(inputImage);

      // テキストブロックを解析
      final data = _parseRecognizedText(recognizedText);

      if (!data.hasVehicleInfo) {
        return Result.failure(
          AppError.validation('車検証の情報を読み取れませんでした。\n画像が鮮明か確認してください。'),
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
  VehicleCertificateData _parseRecognizedText(RecognizedText recognizedText) {
    // 全テキストを取得
    final fullText = recognizedText.text;
    final lines = fullText.split('\n');

    // デバッグ用：認識されたテキストを出力（リリースビルドでは無効）
    assert(() {
      debugPrint('=== OCR Recognized Text ===');
      debugPrint(fullText);
      debugPrint('=========================');
      return true;
    }());

    String? registrationNumber;
    String? vinNumber;
    String? modelCode;
    String? maker;
    String? model;
    int? year;
    DateTime? inspectionExpiryDate;
    String? ownerName;
    String? ownerAddress;
    int? engineDisplacement;
    String? fuelType;
    String? color;
    int? maxCapacity;
    int? vehicleWeight;
    int? grossWeight;

    // 各行を解析
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      final nextLine = i + 1 < lines.length ? lines[i + 1].trim() : '';

      // 登録番号（ナンバープレート）
      registrationNumber ??= _extractRegistrationNumber(line);

      // 車台番号
      if (vinNumber == null && _containsKeyword(line, ['車台番号'])) {
        vinNumber = _extractVinNumber(line, nextLine);
      }

      // 型式
      if (modelCode == null && _containsKeyword(line, ['型式'])) {
        modelCode = _extractModelCode(line, nextLine);
      }

      // 車名（メーカー/モデル）
      if ((maker == null || model == null) && _containsKeyword(line, ['車名'])) {
        final carName = _extractCarName(line, nextLine);
        if (carName != null) {
          final parsed = _parseCarName(carName);
          maker = parsed['maker'];
          model = parsed['model'];
        }
      }

      // 初度登録年月
      if (year == null && _containsKeyword(line, ['初度登録', '初度検査'])) {
        year = _extractYear(line, nextLine);
      }

      // 有効期間の満了する日
      if (inspectionExpiryDate == null &&
          _containsKeyword(line, ['有効期間', '満了'])) {
        inspectionExpiryDate = _extractExpiryDate(line, nextLine);
      }

      // 所有者の氏名
      if (ownerName == null && _containsKeyword(line, ['所有者の氏名', '所有者'])) {
        ownerName = _extractOwnerName(line, nextLine);
      }

      // 所有者の住所
      if (ownerAddress == null && _containsKeyword(line, ['所有者の住所', '住所'])) {
        ownerAddress = _extractOwnerAddress(line, nextLine);
      }

      // 総排気量
      if (engineDisplacement == null && _containsKeyword(line, ['総排気量', '排気量'])) {
        engineDisplacement = _extractEngineDisplacement(line, nextLine);
      }

      // 燃料の種類
      if (fuelType == null && _containsKeyword(line, ['燃料'])) {
        fuelType = _extractFuelType(line, nextLine);
      }

      // 色
      if (color == null && _containsKeyword(line, ['色'])) {
        color = _extractColor(line, nextLine);
      }

      // 乗車定員
      if (maxCapacity == null && _containsKeyword(line, ['乗車定員', '定員'])) {
        maxCapacity = _extractMaxCapacity(line, nextLine);
      }

      // 車両重量
      if (vehicleWeight == null &&
          _containsKeyword(line, ['車両重量']) &&
          !_containsKeyword(line, ['車両総重量'])) {
        vehicleWeight = _extractWeight(line, nextLine);
      }

      // 車両総重量
      if (grossWeight == null && _containsKeyword(line, ['車両総重量'])) {
        grossWeight = _extractWeight(line, nextLine);
      }
    }

    return VehicleCertificateData(
      registrationNumber: registrationNumber,
      vinNumber: vinNumber,
      modelCode: modelCode,
      maker: maker,
      model: model,
      year: year,
      inspectionExpiryDate: inspectionExpiryDate,
      ownerName: ownerName,
      ownerAddress: ownerAddress,
      engineDisplacement: engineDisplacement,
      fuelType: fuelType,
      color: color,
      maxCapacity: maxCapacity,
      vehicleWeight: vehicleWeight,
      grossWeight: grossWeight,
    );
  }

  /// キーワードが含まれているか
  bool _containsKeyword(String text, List<String> keywords) {
    for (final keyword in keywords) {
      if (text.contains(keyword)) return true;
    }
    return false;
  }

  /// 登録番号（ナンバープレート）を抽出
  /// 例: "品川 300 あ 12-34", "横浜500さ1234"
  String? _extractRegistrationNumber(String line) {
    // 地名 + 数字 + ひらがな + 数字のパターン
    final patterns = [
      // 標準的なパターン: "品川 300 あ 12-34"
      RegExp(r'([一-龥ぁ-んァ-ヶ]{2,4})\s*(\d{3})\s*([あ-んア-ン])\s*(\d{1,4}[-−]\d{1,4}|\d{2,4})'),
      // スペースなしパターン
      RegExp(r'([一-龥]{2,4})(\d{3})([あ-ん])(\d{2,4})'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(line);
      if (match != null) {
        final area = match.group(1);
        final classNum = match.group(2);
        final kana = match.group(3);
        final plateNum = match.group(4);
        return '$area $classNum $kana $plateNum';
      }
    }
    return null;
  }

  /// 車台番号を抽出
  /// 例: "ZN6-012345" or "GRB-0123456"
  String? _extractVinNumber(String currentLine, String nextLine) {
    final pattern = RegExp(r'[A-Z0-9]{2,4}[-−]?\d{5,8}');

    var match = pattern.firstMatch(currentLine);
    if (match != null) return match.group(0);

    match = pattern.firstMatch(nextLine);
    if (match != null) return match.group(0);

    // 車台番号の後の値を取得
    final afterKeyword = _extractAfterKeyword(currentLine, '車台番号');
    if (afterKeyword != null && afterKeyword.length >= 6) {
      return afterKeyword;
    }

    return null;
  }

  /// 型式を抽出
  /// 例: "DBA-ZN6", "5BA-GRB"
  String? _extractModelCode(String currentLine, String nextLine) {
    final pattern = RegExp(r'[0-9A-Z]{2,4}[-−][A-Z0-9]{2,6}');

    var match = pattern.firstMatch(currentLine);
    if (match != null) return match.group(0);

    match = pattern.firstMatch(nextLine);
    if (match != null) return match.group(0);

    return _extractAfterKeyword(currentLine, '型式');
  }

  /// 車名を抽出
  String? _extractCarName(String currentLine, String nextLine) {
    final afterKeyword = _extractAfterKeyword(currentLine, '車名');
    if (afterKeyword != null && afterKeyword.isNotEmpty) {
      return afterKeyword;
    }
    if (nextLine.isNotEmpty && !_containsKeyword(nextLine, ['型式', '車台', '番号'])) {
      return nextLine;
    }
    return null;
  }

  /// 車名をメーカーとモデルに分割
  Map<String, String?> _parseCarName(String carName) {
    // 日本の主要メーカー
    final makers = [
      'トヨタ', 'TOYOTA', 'ニッサン', '日産', 'NISSAN',
      'ホンダ', 'HONDA', 'マツダ', 'MAZDA',
      'スバル', 'SUBARU', '富士重工',
      'スズキ', 'SUZUKI', 'ダイハツ', 'DAIHATSU',
      '三菱', 'MITSUBISHI', 'レクサス', 'LEXUS',
      'BMW', 'メルセデス', 'ベンツ', 'MERCEDES',
      'アウディ', 'AUDI', 'フォルクスワーゲン', 'VW', 'VOLKSWAGEN',
      'ポルシェ', 'PORSCHE', 'フェラーリ', 'FERRARI',
      'ボルボ', 'VOLVO', 'ジャガー', 'JAGUAR',
    ];

    for (final maker in makers) {
      if (carName.toUpperCase().contains(maker.toUpperCase())) {
        final model = carName.replaceAll(RegExp(maker, caseSensitive: false), '').trim();
        return {'maker': maker, 'model': model.isNotEmpty ? model : null};
      }
    }

    // メーカーが特定できない場合、全体を車名として扱う
    return {'maker': null, 'model': carName};
  }

  /// 初度登録年を抽出
  int? _extractYear(String currentLine, String nextLine) {
    // 令和/平成/昭和のパターン
    final eraPatterns = [
      RegExp(r'令和\s*(\d{1,2})'),
      RegExp(r'平成\s*(\d{1,2})'),
      RegExp(r'昭和\s*(\d{1,2})'),
      RegExp(r'R\s*(\d{1,2})'),
      RegExp(r'H\s*(\d{1,2})'),
    ];

    for (final pattern in eraPatterns) {
      var match = pattern.firstMatch(currentLine);
      match ??= pattern.firstMatch(nextLine);

      if (match != null) {
        final eraYear = int.tryParse(match.group(1)!);
        if (eraYear != null) {
          // 元号を西暦に変換
          if (currentLine.contains('令和') || currentLine.contains('R')) {
            return 2018 + eraYear;
          } else if (currentLine.contains('平成') || currentLine.contains('H')) {
            return 1988 + eraYear;
          } else if (currentLine.contains('昭和')) {
            return 1925 + eraYear;
          }
        }
      }
    }

    // 西暦パターン
    final yearPattern = RegExp(r'(19|20)\d{2}');
    final match = yearPattern.firstMatch(currentLine) ?? yearPattern.firstMatch(nextLine);
    if (match != null) {
      return int.tryParse(match.group(0)!);
    }

    return null;
  }

  /// 有効期間の満了日を抽出
  DateTime? _extractExpiryDate(String currentLine, String nextLine) {
    // 令和/平成形式: "令和7年5月20日"
    final eraPatterns = [
      RegExp(r'令和\s*(\d{1,2})\s*年\s*(\d{1,2})\s*月\s*(\d{1,2})\s*日'),
      RegExp(r'平成\s*(\d{1,2})\s*年\s*(\d{1,2})\s*月\s*(\d{1,2})\s*日'),
      RegExp(r'R\s*(\d{1,2})[./年]\s*(\d{1,2})[./月]\s*(\d{1,2})'),
    ];

    for (final pattern in eraPatterns) {
      var match = pattern.firstMatch(currentLine);
      match ??= pattern.firstMatch(nextLine);

      if (match != null) {
        final eraYear = int.tryParse(match.group(1)!);
        final month = int.tryParse(match.group(2)!);
        final day = int.tryParse(match.group(3)!);

        if (eraYear != null && month != null && day != null) {
          int year;
          if (currentLine.contains('令和') || currentLine.contains('R')) {
            year = 2018 + eraYear;
          } else {
            year = 1988 + eraYear;
          }
          return DateTime(year, month, day);
        }
      }
    }

    // 西暦形式: "2025/05/20" or "2025年5月20日"
    final datePatterns = [
      RegExp(r'(20\d{2})[./年]\s*(\d{1,2})[./月]\s*(\d{1,2})'),
    ];

    for (final pattern in datePatterns) {
      var match = pattern.firstMatch(currentLine);
      match ??= pattern.firstMatch(nextLine);

      if (match != null) {
        final year = int.tryParse(match.group(1)!);
        final month = int.tryParse(match.group(2)!);
        final day = int.tryParse(match.group(3)!);

        if (year != null && month != null && day != null) {
          return DateTime(year, month, day);
        }
      }
    }

    return null;
  }

  /// 所有者の氏名を抽出
  String? _extractOwnerName(String currentLine, String nextLine) {
    final afterKeyword = _extractAfterKeyword(currentLine, '氏名');
    if (afterKeyword != null && afterKeyword.isNotEmpty) {
      return _cleanPersonalInfo(afterKeyword);
    }
    return null;
  }

  /// 所有者の住所を抽出
  String? _extractOwnerAddress(String currentLine, String nextLine) {
    final afterKeyword = _extractAfterKeyword(currentLine, '住所');
    if (afterKeyword != null && afterKeyword.isNotEmpty) {
      return _cleanPersonalInfo(afterKeyword);
    }
    return null;
  }

  /// 個人情報をクリーンアップ（マスク処理用）
  String _cleanPersonalInfo(String text) {
    // 実際の実装では、ここでマスク処理を行うことも可能
    return text.trim();
  }

  /// 総排気量を抽出
  int? _extractEngineDisplacement(String currentLine, String nextLine) {
    final pattern = RegExp(r'(\d{3,4})\s*(cc|CC|リットル)?');

    var match = pattern.firstMatch(currentLine);
    match ??= pattern.firstMatch(nextLine);

    if (match != null) {
      return int.tryParse(match.group(1)!);
    }
    return null;
  }

  /// 燃料の種類を抽出
  String? _extractFuelType(String currentLine, String nextLine) {
    final fuelTypes = ['ガソリン', '軽油', 'ディーゼル', '電気', 'ハイブリッド', 'LPG', '水素'];

    for (final fuel in fuelTypes) {
      if (currentLine.contains(fuel) || nextLine.contains(fuel)) {
        return fuel;
      }
    }
    return _extractAfterKeyword(currentLine, '燃料');
  }

  /// 色を抽出
  String? _extractColor(String currentLine, String nextLine) {
    final colors = [
      '白', 'ホワイト', '黒', 'ブラック', '銀', 'シルバー', 'グレー', '灰',
      '赤', 'レッド', '青', 'ブルー', '緑', 'グリーン', '黄', 'イエロー',
      '茶', 'ブラウン', 'ベージュ', 'パール', 'ワイン', 'オレンジ',
    ];

    for (final color in colors) {
      if (currentLine.contains(color)) {
        return color;
      }
    }
    return _extractAfterKeyword(currentLine, '色');
  }

  /// 乗車定員を抽出
  int? _extractMaxCapacity(String currentLine, String nextLine) {
    final pattern = RegExp(r'(\d{1,2})\s*(人|名)');

    var match = pattern.firstMatch(currentLine);
    match ??= pattern.firstMatch(nextLine);

    if (match != null) {
      return int.tryParse(match.group(1)!);
    }
    return null;
  }

  /// 重量を抽出
  int? _extractWeight(String currentLine, String nextLine) {
    final pattern = RegExp(r'(\d{3,4})\s*(kg|KG|キロ)?');

    var match = pattern.firstMatch(currentLine);
    match ??= pattern.firstMatch(nextLine);

    if (match != null) {
      return int.tryParse(match.group(1)!);
    }
    return null;
  }

  /// キーワードの後の値を抽出
  String? _extractAfterKeyword(String text, String keyword) {
    final index = text.indexOf(keyword);
    if (index != -1) {
      final afterKeyword = text.substring(index + keyword.length).trim();
      // 最初の空白または改行までを取得
      final endIndex = afterKeyword.indexOf(RegExp(r'\s{2,}'));
      if (endIndex != -1) {
        return afterKeyword.substring(0, endIndex).trim();
      }
      return afterKeyword;
    }
    return null;
  }

  /// リソースを解放
  void dispose() {
    _textRecognizer.close();
  }
}

/// 車検証データから Vehicle に変換するユーティリティ
extension VehicleCertificateDataExtension on VehicleCertificateData {
  /// FuelType enum に変換
  FuelType? get fuelTypeEnum {
    if (fuelType == null) return null;

    switch (fuelType) {
      case 'ガソリン':
        return FuelType.gasoline;
      case '軽油':
      case 'ディーゼル':
        return FuelType.diesel;
      case 'ハイブリッド':
        return FuelType.hybrid;
      case '電気':
        return FuelType.electric;
      case '水素':
        return FuelType.hydrogen;
      default:
        return null;
    }
  }

  /// 車両登録に必要な情報が揃っているか
  bool get isReadyForRegistration =>
      (maker != null || model != null) && inspectionExpiryDate != null;
}
