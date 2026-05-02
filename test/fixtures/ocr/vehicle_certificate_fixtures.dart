// Vehicle certificate OCR text fixtures.
// Each fixture simulates the raw text output Google MLKit would return
// for a real 車検証 (vehicle inspection certificate) document.
//
// Sources:
// - 車検証フォーマット: https://www.airia.or.jp/info/system/04.html
// - 電子車検証（2023年〜）: https://www.denshishakensho-portal.mlit.go.jp/
// - 新様式A6+記録事項A4について: https://www.kurumaerabi.co.jp/useful-details/5197/

class VehicleCertificateFixture {
  final String name;

  /// Raw text as Google MLKit would return from the scanned image.
  final String rawText;

  final ExpectedVehicleCertificate expected;

  /// Minimum accuracy required for this fixture (matched fields / total expected fields).
  final double minimumAccuracy;

  const VehicleCertificateFixture({
    required this.name,
    required this.rawText,
    required this.expected,
    required this.minimumAccuracy,
  });
}

class ExpectedVehicleCertificate {
  final String? registrationNumber;
  final String? vinNumber;
  final String? modelCode;
  final String? maker;
  final String? model;
  final int? year;
  final DateTime? inspectionExpiryDate;
  final String? ownerName;
  final int? engineDisplacement;
  final String? fuelType;
  final String? color;
  final int? maxCapacity;
  final int? vehicleWeight;
  final int? grossWeight;

  const ExpectedVehicleCertificate({
    this.registrationNumber,
    this.vinNumber,
    this.modelCode,
    this.maker,
    this.model,
    this.year,
    this.inspectionExpiryDate,
    this.ownerName,
    this.engineDisplacement,
    this.fuelType,
    this.color,
    this.maxCapacity,
    this.vehicleWeight,
    this.grossWeight,
  });
}

// ---------------------------------------------------------------------------
// Fixture 1: Toyota 86 — 旧様式A4・全項目・高精度スキャン
// 型式 DBA-ZN6（3文字プレフィックス → VIN正規表現に合致）
// 登録年: 平成25年 → 2013年
// 有効期間: 令和7年5月20日 → 2025-05-20
// ---------------------------------------------------------------------------
const _toyotaGt86RawText = '''
自動車検査証

品川 300 あ 1234

型式 DBA-ZN6
車台番号 ZN6-0123456

車名 トヨタ 86

初度登録年月 平成25年4月

有効期間の満了する日 令和7年5月20日

所有者の氏名 山田 太郎
所有者の住所 東京都品川区大崎1-1-1

総排気量 1998cc
燃料の種類 ガソリン
色 赤

乗車定員 4人

車両重量 1213kg
車両総重量 1323kg
''';

// ---------------------------------------------------------------------------
// Fixture 2: Honda Fit — 旧様式A4・一部フィールド欠損（実際のOCRで起こりやすい）
// 型式 5AA-GD1（GD1は3文字 → OK）
// 登録年: 令和3年 → 2021年
// 所有者氏名・住所・排気量 は記録事項に記載なし（OCR取得不可のシミュレーション）
// ---------------------------------------------------------------------------
const _hondaFitRawText = '''
目動車検査証

横浜 500 さ 5678

型式5AA-GD1
車台番号: GD1-1234567

車名ホンダ フィット

初度登録年月令和3年7月

有効期間の満了する日 令和7年8月31日

燃料の種類ガソリン
色 白

乗車定員 5人

車両重量 1030kg
車両総重量 1305kg
''';

// ---------------------------------------------------------------------------
// Fixture 3: Nissan Leaf (EV) — 電気自動車・排気量なし・令和形式
// 型式 ZE1-XXXXXXX（3文字 → OK）
// 電気自動車のため「総排気量」フィールドなし
// ---------------------------------------------------------------------------
const _nissanLeafRawText = '''
自動車検査証

神奈川 300 す 4321

型式 ZE1-1234567
車台番号 ZE1-0123456

車名 ニッサン リーフ

初度登録年月 令和2年11月

有効期間の満了する日 令和7年12月1日

所有者の氏名 鈴木 花子

燃料の種類 電気
色 青

乗車定員 5人

車両重量 1560kg
車両総重量 1935kg
''';

// ---------------------------------------------------------------------------
// Fixture 4: 重いOCRノイズ — キーワード欠け・文字化け・スペース乱れ
// 精度低め（最低60%で合格）
// 実際のOCR誤認識例を参考にシミュレーション
// ---------------------------------------------------------------------------
const _noisyOcrRawText = '''
白動車検査証

大阪 330 ら 1122

型式  5BA-GRB
車台垂号 GRB-0345678

車タマ スバル WRX STI

初度登録年
平成26年4月

有効期間の満了する日
令和8年3月5日

燃料 ガソリン
色 銀

定員 5

車両重量 1480
総重量 1725
''';

// ---------------------------------------------------------------------------
// Fixtures list
// ---------------------------------------------------------------------------

final vehicleCertificateFixtures = <VehicleCertificateFixture>[
  VehicleCertificateFixture(
    name: 'トヨタ 86（旧様式・全項目・高精度）',
    rawText: _toyotaGt86RawText,
    expected: ExpectedVehicleCertificate(
      registrationNumber: '品川 300 あ 1234',
      vinNumber: 'ZN6-0123456',
      modelCode: 'DBA-ZN6',
      maker: 'トヨタ',
      model: '86',
      year: 2013,
      inspectionExpiryDate: DateTime(2025, 5, 20),
      ownerName: '山田 太郎',
      engineDisplacement: 1998,
      fuelType: 'ガソリン',
      color: '赤',
      maxCapacity: 4,
      vehicleWeight: 1213,
      grossWeight: 1323,
    ),
    minimumAccuracy: 0.90,
  ),

  VehicleCertificateFixture(
    name: 'ホンダ フィット（一部フィールド欠損・OCRノイズ軽め）',
    rawText: _hondaFitRawText,
    expected: ExpectedVehicleCertificate(
      registrationNumber: '横浜 500 さ 5678',
      vinNumber: 'GD1-1234567',
      modelCode: '5AA-GD1',
      maker: 'ホンダ',
      model: 'フィット',
      year: 2021,
      inspectionExpiryDate: DateTime(2025, 8, 31),
      // ownerName intentionally omitted — test that null result is acceptable
      fuelType: 'ガソリン',
      color: '白',
      maxCapacity: 5,
      vehicleWeight: 1030,
      grossWeight: 1305,
    ),
    minimumAccuracy: 0.85,
  ),

  VehicleCertificateFixture(
    name: '日産 リーフ（電気自動車・排気量フィールドなし）',
    rawText: _nissanLeafRawText,
    expected: ExpectedVehicleCertificate(
      registrationNumber: '神奈川 300 す 4321',
      vinNumber: 'ZE1-0123456',
      modelCode: 'ZE1-1234567',
      maker: 'ニッサン',
      model: 'リーフ',
      year: 2020,
      inspectionExpiryDate: DateTime(2025, 12, 1),
      ownerName: '鈴木 花子',
      // engineDisplacement: null — EV has no displacement
      fuelType: '電気',
      color: '青',
      maxCapacity: 5,
      vehicleWeight: 1560,
      grossWeight: 1935,
    ),
    minimumAccuracy: 0.85,
  ),

  VehicleCertificateFixture(
    name: '重いOCRノイズ（文字化け・キーワード欠け）',
    rawText: _noisyOcrRawText,
    expected: ExpectedVehicleCertificate(
      registrationNumber: '大阪 330 ら 1122',
      // vinNumber may fail due to keyword corruption ('車台垂号' not '車台番号')
      fuelType: 'ガソリン',
      color: '銀',
      vehicleWeight: 1480,
      grossWeight: 1725,
      // year, inspectionExpiryDate, maker, model — tested as best-effort
    ),
    minimumAccuracy: 0.60,
  ),
];
