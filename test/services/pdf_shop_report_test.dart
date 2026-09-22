// 店舗の月次レポートを PDF にする。
//
// なぜ要るか:
//   工場は数字を紙で会議にかける。画面で見るだけでは、月次の振り返りに
//   使えない。`printing` パッケージは依存に入っていたが、使われていたのは
//   **愛車カルテ（個人向け）の1ファイルだけ**で、店舗の月次レポートは
//   対象外だった（2026-09-22 実測）。
//
// ここでは「生成できること」と「落ちないこと」を見る。見た目は PDF を
// 開いて人が見るもの。

import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/models/inquiry.dart';
import 'package:trust_car_platform/models/shop_monthly_report.dart';
import 'package:trust_car_platform/services/pdf_export_service.dart';

ShopMonthlyReport _report({
  int total = 12,
  int previousTotal = 9,
  Map<InquiryStatus, int>? byStatus,
}) =>
    ShopMonthlyReport(
      month: DateTime(2026, 9),
      total: total,
      previousTotal: previousTotal,
      byStatus: byStatus ??
          {
            InquiryStatus.pending: 2,
            InquiryStatus.replied: 7,
            InquiryStatus.closed: 3,
          },
    );

void main() {
  const service = PdfExportService();

  group('generateShopMonthlyReport', () {
    test('PDF を生成できる', () async {
      final result = await service.generateShopMonthlyReport(
        shopName: 'タカヤモーター株式会社',
        report: _report(),
      );

      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull, isNotNull);
      expect(result.valueOrNull!.isNotEmpty, isTrue);
    });

    test('PDF のヘッダーが付いている（中身が PDF になっている）', () async {
      final result = await service.generateShopMonthlyReport(
        shopName: 'テスト工場',
        report: _report(),
      );

      final bytes = result.valueOrNull!;
      // %PDF-
      expect(bytes.sublist(0, 5), [0x25, 0x50, 0x44, 0x46, 0x2D]);
    });

    group('Edge Cases', () {
      test('問い合わせ0件でも生成できる', () async {
        final result = await service.generateShopMonthlyReport(
          shopName: 'テスト工場',
          report: _report(total: 0, previousTotal: 0, byStatus: const {}),
        );

        expect(result.isSuccess, isTrue);
      });

      test('前月より減っていても生成できる（マイナスの前月比）', () async {
        final result = await service.generateShopMonthlyReport(
          shopName: 'テスト工場',
          report: _report(total: 3, previousTotal: 10),
        );

        expect(result.isSuccess, isTrue);
      });

      test('店名が空でも落ちない', () async {
        final result = await service.generateShopMonthlyReport(
          shopName: '',
          report: _report(),
        );

        expect(result.isSuccess, isTrue);
      });
    });
  });
}
