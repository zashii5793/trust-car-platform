#!/usr/bin/env node
/**
 * Shop Seed Data — Firestore 登録スクリプト (Node.js)
 *
 * Usage:
 *   node scripts/seed_shops.js [--dry-run] [--emulator]
 *
 * Options:
 *   --dry-run    Firestore に書かず、登録予定データを標準出力に表示する
 *   --emulator   Firebase Emulator (localhost:8080) に接続する
 *
 * Requirements:
 *   npm install firebase-admin
 *
 * Example:
 *   # Emulator で動作確認
 *   firebase emulators:start --only firestore
 *   node scripts/seed_shops.js --dry-run
 *   node scripts/seed_shops.js --emulator
 *
 *   # 本番に登録
 *   export GOOGLE_APPLICATION_CREDENTIALS=path/to/serviceAccount.json
 *   node scripts/seed_shops.js
 *
 * Data notes:
 *   - "タカヤモーター株式会社" は実在の提携候補店舗。連絡先/住所/位置の TODO は
 *     人間が正式情報を確認のうえ記入すること（誤情報の公開を避ける）。
 *   - id が "demo_" で始まる店舗は **テスト環境用の架空のサンプルデータ**。
 *     実在の事業者ではない。工場一覧・近い順ソート・店舗比較機能を
 *     テストユーザーが体験できるようにするためのもの。本番投入前に削除するか
 *     実店舗データに差し替えること。電話番号は誤発信防止のため null。
 *     位置情報(GeoPoint)は各都市の公開座標で、距離計算の動作確認用。
 */

const isDryRun  = process.argv.includes('--dry-run');
const useEmulator = process.argv.includes('--emulator');

// Emulator 接続設定（--emulator フラグ時）
if (useEmulator) {
  process.env.FIRESTORE_EMULATOR_HOST = 'localhost:8080';
}

const admin = (() => {
  try { return require('firebase-admin'); }
  catch {
    console.error('[ERROR] firebase-admin が見つかりません。');
    console.error('        npm install firebase-admin を実行してください。');
    process.exit(1);
  }
})();

// ---------------------------------------------------------------------------
// Firebase 初期化
// ---------------------------------------------------------------------------
if (!admin.apps.length) {
  if (useEmulator) {
    admin.initializeApp({ projectId: 'trust-car-platform' });
  } else {
    admin.initializeApp({
      credential: admin.credential.applicationDefault(),
    });
  }
}

const db = admin.firestore();
const { Timestamp, GeoPoint } = admin.firestore;

// ---------------------------------------------------------------------------
// シードデータ定義
// ---------------------------------------------------------------------------
const now = Timestamp.now();

const shopSeeds = [
  {
    // ------------------------------------------------------------------
    // タカヤモーター株式会社
    // 岡山市中区の整備工場。創業1965年、約60年の実績を持つ地域密着の自動車サービス会社。
    // ------------------------------------------------------------------
    id: 'shop_takaya_motor_okayama',
    data: {
      name: 'タカヤモーター株式会社',
      type: 'maintenanceShop',
      description: '創業1965年（昭和40年）。約60年の実績と信頼。車検・点検・整備から新車・中古車販売、カーリースまでトータルカーライフをサポートします。「お客様満足No.1」を目指し、質の高いカーサービスをご提供しています。',
      logoUrl: null,
      imageUrls: [],

      // 連絡先
      phone: null,    // TODO: 正式な電話番号を記入 (例: '086-xxx-xxxx')
      email: null,    // TODO: 正式なメールアドレスを記入
      website: 'https://www.takayagroup.co.jp/',

      // 所在地
      prefecture: '岡山県',
      city: '岡山市中区',
      address: null,  // TODO: 番地まで記入 (例: '中区倉田○○番地')
      location: null, // TODO: new GeoPoint(34.6577, 133.9384) のように設定

      // サービス
      services: [
        'inspection',   // 車検
        'maintenance',  // 整備・点検
        'repair',       // 修理
        'bodyWork',     // 板金・塗装
        'purchase',     // 車両購入（新車・中古車販売）
        'rental',       // レンタカー
        'insurance',    // 保険
      ],
      supportedMakerIds: [], // 空 = 全メーカー対応

      // 営業時間 (0=日, 1=月, ..., 6=土)
      businessHours: {
        '0': { openTime: null,    closeTime: null,    isClosed: true  }, // 日曜
        '1': { openTime: '09:00', closeTime: '18:00', isClosed: false }, // 月曜
        '2': { openTime: '09:00', closeTime: '18:00', isClosed: false }, // 火曜
        '3': { openTime: '09:00', closeTime: '18:00', isClosed: false }, // 水曜
        '4': { openTime: '09:00', closeTime: '18:00', isClosed: false }, // 木曜
        '5': { openTime: '09:00', closeTime: '18:00', isClosed: false }, // 金曜
        '6': { openTime: '09:00', closeTime: '17:00', isClosed: false }, // 土曜
      },
      businessHoursNote: null, // TODO: 定休日・祝日対応を確認して記入

      // 評価（初期値）
      rating: null,
      reviewCount: 0,

      // ステータス
      isVerified: true,   // オーナー確認済み
      isFeatured: true,   // トップ優先表示
      isActive: true,

      createdAt: now,
      updatedAt: now,
    },
  },

  // =========================================================================
  // 以下はテスト環境用の架空サンプル店舗（demo_*）。実在の事業者ではない。
  // 工場一覧・近い順ソート・店舗比較の動作確認用。本番前に削除/差し替え。
  // =========================================================================
  makeDemoShop({
    id: 'demo_kanto_auto_service',
    name: '関東オートサービス（サンプル）',
    description: '車検・一般整備からエンジン診断まで対応する総合整備工場（テスト用サンプルデータ）。',
    prefecture: '東京都',
    city: '世田谷区',
    lat: 35.6464,
    lng: 139.6533,
    services: ['inspection', 'maintenance', 'repair', 'insurance'],
    rating: 4.6,
    reviewCount: 128,
    isFeatured: false,
  }),
  makeDemoShop({
    id: 'demo_minato_motors',
    name: 'みなとモータース（サンプル）',
    description: '輸入車・国産車どちらも対応。鈑金塗装が得意（テスト用サンプルデータ）。',
    prefecture: '神奈川県',
    city: '横浜市西区',
    lat: 35.4437,
    lng: 139.6380,
    services: ['inspection', 'maintenance', 'bodyWork', 'repair'],
    rating: 4.2,
    reviewCount: 64,
    isFeatured: false,
  }),
  makeDemoShop({
    id: 'demo_nagoya_carcare',
    name: '名古屋カーケア（サンプル）',
    description: 'ハイブリッド・EV整備に強い少数精鋭の工場（テスト用サンプルデータ）。',
    prefecture: '愛知県',
    city: '名古屋市中区',
    lat: 35.1815,
    lng: 136.9066,
    services: ['inspection', 'maintenance', 'repair'],
    rating: 4.8,
    reviewCount: 39,
    isFeatured: false,
  }),
  makeDemoShop({
    id: 'demo_naniwa_shaken',
    name: 'なにわ車検センター（サンプル）',
    description: '格安車検と短時間対応が売りの大型店（テスト用サンプルデータ）。',
    prefecture: '大阪府',
    city: '大阪市淀川区',
    lat: 34.6937,
    lng: 135.5023,
    services: ['inspection', 'maintenance', 'repair', 'rental'],
    rating: 3.9,
    reviewCount: 210,
    isFeatured: false,
  }),
  makeDemoShop({
    id: 'demo_sapporo_north_garage',
    name: '札幌ノースガレージ（サンプル）',
    description: '雪国対応・冬タイヤ交換とアンダーコートが得意（テスト用サンプルデータ）。',
    prefecture: '北海道',
    city: '札幌市中央区',
    lat: 43.0618,
    lng: 141.3545,
    services: ['inspection', 'maintenance', 'repair', 'bodyWork'],
    rating: 4.4,
    reviewCount: 52,
    isFeatured: false,
  }),
  makeDemoShop({
    id: 'demo_fukuoka_auto_factory',
    name: '福岡オートファクトリー（サンプル）',
    description: 'カスタム・パーツ取付の相談に強いファクトリー（テスト用サンプルデータ）。',
    prefecture: '福岡県',
    city: '福岡市博多区',
    lat: 33.5904,
    lng: 130.4017,
    services: ['maintenance', 'repair', 'bodyWork'],
    rating: 4.1,
    reviewCount: 87,
    isFeatured: false,
  }),
];

/**
 * Builds a demo (fictional) shop document with standard weekday business hours.
 * Phone/email are intentionally null to prevent test users from contacting a
 * number that might coincide with a real one.
 */
function makeDemoShop({
  id,
  name,
  description,
  prefecture,
  city,
  lat,
  lng,
  services,
  rating,
  reviewCount,
  isFeatured,
}) {
  return {
    id,
    data: {
      name,
      type: 'maintenanceShop',
      description,
      logoUrl: null,
      imageUrls: [],

      phone: null, // demo data — no real contact number
      email: null,
      website: null,

      prefecture,
      city,
      address: null,
      location: new GeoPoint(lat, lng),

      services,
      supportedMakerIds: [], // 空 = 全メーカー対応

      businessHours: {
        '0': { openTime: null, closeTime: null, isClosed: true },
        '1': { openTime: '09:00', closeTime: '18:00', isClosed: false },
        '2': { openTime: '09:00', closeTime: '18:00', isClosed: false },
        '3': { openTime: '09:00', closeTime: '18:00', isClosed: false },
        '4': { openTime: '09:00', closeTime: '18:00', isClosed: false },
        '5': { openTime: '09:00', closeTime: '18:00', isClosed: false },
        '6': { openTime: '09:00', closeTime: '17:00', isClosed: false },
      },
      businessHoursNote: null,

      rating,
      reviewCount,

      isVerified: false, // demo data is not owner-verified
      isFeatured,
      isActive: true,

      createdAt: now,
      updatedAt: now,
    },
  };
}

// ---------------------------------------------------------------------------
// 実行
// ---------------------------------------------------------------------------
async function main() {
  console.log('=== Shop Seed Script ===');
  console.log(`dry-run  : ${isDryRun}`);
  console.log(`emulator : ${useEmulator}`);
  console.log(`登録件数  : ${shopSeeds.length}`);
  console.log('');

  if (isDryRun) {
    console.log('--- [DRY RUN] 登録予定データ ---');
    for (const shop of shopSeeds) {
      console.log(`ID: ${shop.id}`);
      console.log(JSON.stringify(shop.data, null, 2));
      console.log('');
    }
    console.log('--- [DRY RUN] 完了（Firestore への書き込みは行っていません）---');
    return;
  }

  const batch = db.batch();

  for (const shop of shopSeeds) {
    const ref = db.collection('shops').doc(shop.id);
    batch.set(ref, shop.data, { merge: true });
    console.log(`[QUEUED] shops/${shop.id} — ${shop.data.name}`);
  }

  await batch.commit();
  console.log('');
  console.log(`[SUCCESS] ${shopSeeds.length} 件を Firestore に登録しました。`);
}

main().catch((err) => {
  console.error('[ERROR]', err);
  process.exit(1);
});
