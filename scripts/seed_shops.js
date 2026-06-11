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
];

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
