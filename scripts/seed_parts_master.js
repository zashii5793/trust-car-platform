#!/usr/bin/env node
/**
 * Parts Master Seed — AI パーツレコメンド用マスタ投入スクリプト (Node.js)
 *
 * 企画書のコンセプト:
 *   「AIが提携EC（Amazon等）の膨大なパーツから、ユーザーの車と目的に最適な
 *     ものを論理的に絞り込み、"理由（メリット/デメリット/注意点）と共に" 提示する」
 *
 * このスクリプトは Firestore の `part_listings` コレクションにマスタを投入する。
 * 各パーツは compatibleVehicles（適合車種）と prosAndCons（メリット/デメリット）を
 * 持ち、AI レコメンド画面（車両詳細 →「パーツ提案」）に表示される。
 *
 * 適合判定:
 *   PartRecommendationService が vehicle.maker/model から makerId/modelId を
 *   生成（例: トヨタ RAV4 → toyota / toyota_rav4）し、compatibleVehicles と
 *   照合する。本スクリプトの modelId はこの規則に合わせている。
 *
 * Usage:
 *   node scripts/seed_parts_master.js [--dry-run] [--emulator] [--clean]
 *
 * Requirements:
 *   npm install firebase-admin   (scripts/ で実行)
 *
 * 注意:
 *   - これは **デモ用のサンプルマスタ**。価格・品番・適合は実在のものでは
 *     ない場合があるため、本番公開前に正式な提携EC/メーカーのデータへ
 *     差し替えること（docs/PARTS_MASTER_GUIDE.md 参照）。
 *   - 画像は Unsplash の公開画像（CORS 対応・Flutter Web 表示可）。
 *   - affiliateUrl は将来の提携EC送客用フィールド。現状 PartListing モデルは
 *     未対応のため、モデル拡張後に有効化される（GUIDE 参照）。
 */

const isDryRun = process.argv.includes('--dry-run');
const useEmulator = process.argv.includes('--emulator');
const doClean = process.argv.includes('--clean');

if (useEmulator) process.env.FIRESTORE_EMULATOR_HOST = 'localhost:8080';

const admin = (() => {
  try { return require('firebase-admin'); }
  catch {
    console.error('[ERROR] firebase-admin が見つかりません。npm install firebase-admin を実行してください。');
    process.exit(1);
  }
})();

if (!admin.apps.length) {
  if (useEmulator) admin.initializeApp({ projectId: 'trust-car-platform' });
  else admin.initializeApp({ credential: admin.credential.applicationDefault() });
}

const db = admin.firestore();
const { Timestamp } = admin.firestore;
const now = Timestamp.now();

// 提携EC（デモ）。本番では実在の提携先 shopId に差し替える。
const EC_SHOP_ID = 'partner_ec_demo';

const PART_IMG = {
  wheel: 'https://images.unsplash.com/photo-1626668893632-6f3a4466d22f?auto=format&fit=crop&w=600&q=80',
  tire: 'https://images.unsplash.com/photo-1568772585407-9361f9bf3a87?auto=format&fit=crop&w=600&q=80',
  roof: 'https://images.unsplash.com/photo-1533473359331-0135ef1b58bf?auto=format&fit=crop&w=600&q=80',
  brake: 'https://images.unsplash.com/photo-1486262715619-67b85e0b08d3?auto=format&fit=crop&w=600&q=80',
  dashcam: 'https://images.unsplash.com/photo-1449965408869-eaa3f722e40d?auto=format&fit=crop&w=600&q=80',
  mat: 'https://images.unsplash.com/photo-1449130015084-2d1d2da3c4f0?auto=format&fit=crop&w=600&q=80',
};

function pro(text) { return { text, isPro: true }; }
function con(text) { return { text, isPro: false }; }

/** compatibleVehicles のヘルパ */
function fit(makerId, modelId, { yearFrom = null, yearTo = null, gradePattern = null, bodyType = null } = {}) {
  return { makerId, modelId, yearFrom, yearTo, gradePattern, bodyType };
}

// ---------------------------------------------------------------------------
// パーツマスタ定義
// ---------------------------------------------------------------------------
const parts = [
  {
    id: 'part_rav4_roofbox',
    data: {
      shopId: EC_SHOP_ID,
      name: 'ルーフボックス 400L（SUV・アウトドア向け）',
      nameEn: 'Roof Box 400L',
      description: 'ファミリーのキャンプ・スキーに。RAV4 のルーフレールに適合する大容量ルーフボックス。',
      category: 'exterior',
      imageUrls: [PART_IMG.roof],
      priceFrom: 38000, priceTo: 52000, isPriceNegotiable: false,
      compatibleVehicles: [fit('toyota', 'toyota_rav4', { yearFrom: 2019, bodyType: 'suv' })],
      defaultCompatibility: 'compatible',
      prosAndCons: [
        pro('荷室を圧迫せず、5人乗車でも大荷物を積める'),
        pro('純正ルーフレールにボルトオン、加工不要'),
        con('全高が上がり立体駐車場（多くは2.1m制限）に入れない場合がある'),
        con('高速走行時に風切り音と燃費悪化（数%）が出る'),
      ],
      brand: 'OutdoorRack', partNumber: 'ORB-400-SUV',
      tags: ['アウトドア', 'ファミリー', '積載'],
      affiliateUrl: 'https://example.com/ec/roofbox-400',  // ※モデル拡張後に有効化
      rating: 4.5, reviewCount: 128, isActive: true, isFeatured: true,
    },
  },
  {
    id: 'part_rav4_allweather_mat',
    data: {
      shopId: EC_SHOP_ID,
      name: '3D オールウェザー フロアマット（RAV4専用）',
      nameEn: '3D All-Weather Floor Mat',
      description: '泥・砂・雪に強い立体ラバーマット。お子様の乗り降りが多いファミリーに。',
      category: 'interior',
      imageUrls: [PART_IMG.mat],
      priceFrom: 12800, priceTo: 16800, isPriceNegotiable: false,
      compatibleVehicles: [fit('toyota', 'toyota_rav4', { yearFrom: 2019 })],
      defaultCompatibility: 'perfect',
      prosAndCons: [
        pro('車種専用設計でズレにくく、丸洗いできる'),
        pro('純正マットの上に重ねず単体使用で安全'),
        con('夏場は素材の匂いが出ることがある（数日で軽減）'),
      ],
      brand: 'FitGuard', partNumber: 'FG-RAV4-3D',
      tags: ['ファミリー', '実用', 'メンテナンス性'],
      affiliateUrl: 'https://example.com/ec/mat-rav4',
      rating: 4.7, reviewCount: 342, isActive: true, isFeatured: false,
    },
  },
  {
    id: 'part_wrx_brakepad_sport',
    data: {
      shopId: EC_SHOP_ID,
      name: 'スポーツブレーキパッド（ストリート〜軽サーキット）',
      nameEn: 'Sport Brake Pad',
      description: '初期制動と耐フェード性を両立。ワインディング/走行会を楽しむWRX向け。',
      category: 'brake',
      imageUrls: [PART_IMG.brake],
      priceFrom: 28000, priceTo: 42000, isPriceNegotiable: false,
      compatibleVehicles: [fit('subaru', 'subaru_wrx_s4', { yearFrom: 2021 })],
      defaultCompatibility: 'compatible',
      prosAndCons: [
        pro('高温域でのコントロール性が向上し、安心して攻められる'),
        pro('純正キャリパーに適合、ボルトオン交換'),
        con('純正よりブレーキダスト（ホイール汚れ）が増える'),
        con('完全に冷えている朝一は鳴きが出る個体がある'),
      ],
      brand: 'ApexBrake', partNumber: 'AB-WRX-ST',
      tags: ['スポーツ', '走行会', '制動'],
      affiliateUrl: 'https://example.com/ec/brakepad-wrx',
      rating: 4.4, reviewCount: 76, isActive: true, isFeatured: true,
    },
  },
  {
    id: 'part_wrx_lightweight_wheel',
    data: {
      shopId: EC_SHOP_ID,
      name: '軽量鍛造ホイール 18インチ（5H/114.3）',
      nameEn: 'Lightweight Forged Wheel 18"',
      description: 'バネ下軽量化でハンドリングと加減速の応答が向上。',
      category: 'wheel',
      imageUrls: [PART_IMG.wheel],
      priceFrom: 132000, priceTo: 198000, isPriceNegotiable: true,
      compatibleVehicles: [fit('subaru', 'subaru_wrx_s4', { yearFrom: 2021 })],
      defaultCompatibility: 'conditional',
      prosAndCons: [
        pro('1本あたり純正比 約2kg軽量、ハンドリングが軽快に'),
        pro('鍛造で剛性が高く、見た目の質感も向上'),
        con('車検時はサイズ・はみ出し（保安基準）に注意が必要'),
        con('インチアップで乗り心地はやや硬くなる'),
        con('対応タイヤの新規購入費が別途かかる'),
      ],
      brand: 'ForgeOne', partNumber: 'F1-1885-1143',
      tags: ['軽量化', 'ハンドリング', 'ドレスアップ'],
      affiliateUrl: 'https://example.com/ec/wheel-forged-18',
      rating: 4.6, reviewCount: 54, isActive: true, isFeatured: false,
    },
  },
  {
    id: 'part_universal_dashcam',
    data: {
      shopId: EC_SHOP_ID,
      name: '前後2カメラ ドライブレコーダー（駐車監視付き）',
      nameEn: 'Front+Rear Dashcam',
      description: 'はじめての1台の安心装備。あおり運転・当て逃げ対策に。全車種取付可。',
      category: 'safety',
      imageUrls: [PART_IMG.dashcam],
      priceFrom: 14800, priceTo: 24800, isPriceNegotiable: false,
      // 全車種対応（modelId 指定なし → 幅広く適合）
      compatibleVehicles: [fit('honda', 'honda_n_box'), fit('toyota', 'toyota_rav4')],
      defaultCompatibility: 'compatible',
      prosAndCons: [
        pro('前後同時録画で万一の際の証拠能力が高い'),
        pro('駐車監視で停車中のいたずら・当て逃げも記録'),
        pro('初心者でも運転の振り返りに使える'),
        con('駐車監視を多用するとバッテリー上がりのリスク（別売の電圧カットや外部バッテリー推奨）'),
        con('配線をきれいに隠すには取付工賃（約1〜2万円）がかかる'),
      ],
      brand: 'SafeDrive', partNumber: 'SD-2CAM-PRO',
      tags: ['初心者おすすめ', '安全', '必須級'],
      affiliateUrl: 'https://example.com/ec/dashcam-2cam',
      rating: 4.5, reviewCount: 511, isActive: true, isFeatured: true,
    },
  },
  {
    id: 'part_nbox_seatcover',
    data: {
      shopId: EC_SHOP_ID,
      name: '撥水シートカバー（N-BOX専用・お手入れ簡単）',
      nameEn: 'Water-Repellent Seat Cover',
      description: '飲みこぼし・汚れに強い。小さなお子様や初めての愛車を綺麗に保ちたい方に。',
      category: 'interior',
      imageUrls: [PART_IMG.mat],
      priceFrom: 13800, priceTo: 19800, isPriceNegotiable: false,
      compatibleVehicles: [fit('honda', 'honda_n_box', { yearFrom: 2017 })],
      defaultCompatibility: 'perfect',
      prosAndCons: [
        pro('車種専用で純正シート形状にフィット、サイドエアバッグ対応'),
        pro('撥水素材でサッと拭けて清潔を保てる'),
        con('取付に30分〜1時間ほどかかる（説明書あり）'),
      ],
      brand: 'CleanFit', partNumber: 'CF-NBOX-WR',
      tags: ['初心者おすすめ', '清潔', 'ファミリー'],
      affiliateUrl: 'https://example.com/ec/seatcover-nbox',
      rating: 4.6, reviewCount: 198, isActive: true, isFeatured: false,
    },
  },
];

// ---------------------------------------------------------------------------
async function main() {
  console.log('='.repeat(70));
  console.log(`Parts Master Seed — ${isDryRun ? 'DRY RUN' : 'WRITE'}${useEmulator ? ' (emulator)' : ''}`);
  console.log('='.repeat(70));

  if (doClean && !isDryRun) {
    for (const p of parts) {
      await db.collection('part_listings').doc(p.id).delete().catch(() => {});
    }
    console.log('[clean] 既存のデモパーツを削除しました');
  }

  for (const p of parts) {
    const data = { ...p.data, createdAt: now, updatedAt: now };
    if (isDryRun) {
      console.log(`  📦 part_listings/${p.id}  ${p.data.name}  [${p.data.category}]  適合:${p.data.compatibleVehicles.map(v => v.modelId || v.makerId).join(',')}`);
    } else {
      await db.collection('part_listings').doc(p.id).set(data, { merge: true });
      console.log(`  ✅ part_listings/${p.id}  ${p.data.name}`);
    }
  }

  console.log('\n' + '-'.repeat(70));
  console.log(`完了: ${parts.length} 件のパーツマスタ`);
  console.log('-'.repeat(70));
}

main()
  .then(() => process.exit(0))
  .catch((e) => { console.error('[FATAL]', e); process.exit(1); });
