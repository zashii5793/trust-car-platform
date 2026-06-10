// Invoice OCR text fixtures.
// Each fixture simulates the raw text output Google MLKit would return
// for a real 整備請求書 (auto maintenance invoice).
//
// Sources:
// - 整備請求書フォーマット標準項目:
//   https://biz.moneyforward.com/invoice/basic/55085/
// - 自動車整備関連の請求書テンプレート:
//   https://www.misoca.jp/blog/freelance_mechanic_invoice
// - 整備費用の一般的な相場（工賃・部品代）:
//   https://www.goo-net.com/pit/shop/0174724/blog/1111953

class InvoiceFixture {
  final String name;

  /// Raw text as Google MLKit would return from the scanned invoice image.
  final String rawText;

  final ExpectedInvoice expected;

  /// Minimum accuracy required (matched fields / total non-null expected fields).
  final double minimumAccuracy;

  const InvoiceFixture({
    required this.name,
    required this.rawText,
    required this.expected,
    required this.minimumAccuracy,
  });
}

class ExpectedInvoice {
  final DateTime? date;
  final int? totalAmount;
  final int? taxAmount;
  final int? subtotalAmount;
  final String? shopName;
  final String? shopPhone;
  final int? mileage;
  final int? itemCount;

  const ExpectedInvoice({
    this.date,
    this.totalAmount,
    this.taxAmount,
    this.subtotalAmount,
    this.shopName,
    this.shopPhone,
    this.mileage,
    this.itemCount,
  });
}

// ---------------------------------------------------------------------------
// Fixture 1: エンジンオイル交換 — 一般整備工場・標準フォーマット
// 令和6年3月15日 → DateTime(2024, 3, 15)
// 消費税10%: ¥7,000 × 10% = ¥700
// 出典参考: マネーフォワード整備請求書テンプレート
// ---------------------------------------------------------------------------
const _oilChangeRawText = '''
株式会社カーサービス山田
東京都品川区大崎2-1-1
TEL 03-1234-5678

請求書
請求書番号 INV-20240315-001

令和6年3月15日

品川 300 あ 1234
走行距離 45231km

オイル交換 ¥3800
オイルフィルター交換 ¥1200
工賃 ¥2000

小計 ¥7000
消費税 ¥700
合計 ¥7700
''';

// ---------------------------------------------------------------------------
// Fixture 2: 車検 — ディーラー発行・複数明細・高額請求書
// 法定費用 + 整備費用の複合
// 令和6年9月1日 → DateTime(2024, 9, 1)
// ---------------------------------------------------------------------------
const _vehicleInspectionRawText = '''
トヨタカローラ東京 品川店
東京都品川区西品川3-2-1
TEL 03-9876-5432

整備請求書

令和6年9月1日

ご請求金額 ¥120000

明細
車検代行手数料 ¥15000
24ヶ月点検 ¥25000
エンジンオイル交換 ¥3800
タイヤローテーション ¥3200
ブレーキフルード交換 ¥4500
自動車重量税 ¥24600
自賠責保険料 ¥17540

小計 ¥93640
消費税 ¥5764
合計 ¥99404
''';

// ---------------------------------------------------------------------------
// Fixture 3: タイヤ交換 — タイヤ専門店・4本交換
// 令和6年11月20日 → DateTime(2024, 11, 20)
// 出典参考: グーネットピット工賃表
// ---------------------------------------------------------------------------
const _tireChangeRawText = '''
タイヤ館 横浜港北店
神奈川県横浜市港北区新横浜2-5-10
TEL 045-123-4567

作業明細書

2024年11月20日

横浜 500 さ 5678
走行距離 32100km

タイヤ交換 195/65R15 ×4本 ¥56000
タイヤ廃棄処分 ¥2000
バルブ交換 ×4本 ¥1600
タイヤ組み換え工賃 ¥8000
タイヤバランス調整 ¥4000
窒素充填 ¥2000

小計 ¥73600
消費税 ¥7360
合計 ¥80960
''';

// ---------------------------------------------------------------------------
// Fixture 4: 印字薄め・手書き補足ありのノイズ入り請求書
// 一部フィールドが欠損または誤認識される想定
// ---------------------------------------------------------------------------
const _noisyInvoiceRawText = '''
有限会社オートサービス整備工場

R 6年 6月 5日

エアコンフィルター交換 ¥2500
バッテリー交換 ¥18000
工賃 ¥5000

合計請求金額 ¥25500
''';

// ---------------------------------------------------------------------------
// Fixtures list
// ---------------------------------------------------------------------------

final invoiceFixtures = <InvoiceFixture>[
  InvoiceFixture(
    name: 'エンジンオイル交換（標準フォーマット・高精度）',
    rawText: _oilChangeRawText,
    expected: ExpectedInvoice(
      date: DateTime(2024, 3, 15),
      totalAmount: 7700,
      taxAmount: 700,
      subtotalAmount: 7000,
      shopName: '株式会社カーサービス山田',
      shopPhone: '03-1234-5678',
      mileage: 45231,
      itemCount: 3,
    ),
    minimumAccuracy: 0.80,
  ),
  InvoiceFixture(
    name: '車検費用（ディーラー発行・複数明細）',
    rawText: _vehicleInspectionRawText,
    expected: ExpectedInvoice(
      date: DateTime(2024, 9, 1),
      totalAmount: 99404,
      taxAmount: 5764,
      subtotalAmount: 93640,
      shopPhone: '03-9876-5432',
      itemCount: 7,
    ),
    minimumAccuracy: 0.70,
  ),
  InvoiceFixture(
    name: 'タイヤ交換4本（タイヤ専門店・西暦表記）',
    rawText: _tireChangeRawText,
    expected: ExpectedInvoice(
      date: DateTime(2024, 11, 20),
      totalAmount: 80960,
      taxAmount: 7360,
      subtotalAmount: 73600,
      shopPhone: '045-123-4567',
      mileage: 32100,
      itemCount: 6,
    ),
    minimumAccuracy: 0.75,
  ),
  InvoiceFixture(
    name: 'ノイズ入り請求書（印字薄・手書き補足）',
    rawText: _noisyInvoiceRawText,
    expected: ExpectedInvoice(
      totalAmount: 25500,
      itemCount: 3,
    ),
    minimumAccuracy: 0.50,
  ),
];
