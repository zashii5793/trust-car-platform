#!/usr/bin/env node
/**
 * 大量データ負荷検証用シードスクリプト
 *
 * ページネーション・インデックス・一覧画面のパフォーマンスを「大量データ」で
 * 検証するためのダミーデータを Firestore に投入する。
 *
 * 既定の規模:
 *   - posts:        1000 件（公開フィード）
 *   - vehicles:      100 台（1フリート相当）
 *   - maintenance_records: 100 台 × 各 30 件 = 3000 件
 *   - inquiries:     500 件（1店舗あたりの問い合わせ集中）
 *
 * 安全装置:
 *   - 既定は emulator 専用。--emulator なしで本番に書き込むには明示的に
 *     --i-understand-production を付ける必要がある（誤投入防止）。
 *   - --dry-run で件数だけ確認できる（書き込みなし）。
 *   - 投入データは `loadtest_` プレフィックスのドキュメントIDで作成するため、
 *     後から一括削除しやすい（cleanup は別途）。
 *
 * 使い方:
 *   node scripts/seed_load_test.js --dry-run
 *   firebase emulators:start --only firestore   # 別ターミナル
 *   node scripts/seed_load_test.js --emulator
 *   node scripts/seed_load_test.js --emulator --posts 5000 --vehicles 200
 *
 * ⚠️ 本番投入は原則禁止。検証後は必ずクリーンアップすること。
 *
 * 依存: firebase-admin（namespaced API を使用）。`firebase-admin@14` 以降は
 * `admin.apps` / `admin.firestore` の namespaced API が削除されており、本スクリプト
 * および既存の scripts/seed_*.js は動作しない。`npm install firebase-admin@12` で
 * インストールすること。
 */

'use strict';

const isDryRun = process.argv.includes('--dry-run');
const useEmulator = process.argv.includes('--emulator');
const allowProduction = process.argv.includes('--i-understand-production');

/** 数値オプション（--posts 5000 形式）を読む */
function numArg(name, fallback) {
  const idx = process.argv.indexOf(name);
  if (idx === -1 || idx + 1 >= process.argv.length) return fallback;
  const n = parseInt(process.argv[idx + 1], 10);
  return Number.isFinite(n) && n > 0 ? n : fallback;
}

const COUNT = {
  posts: numArg('--posts', 1000),
  vehicles: numArg('--vehicles', 100),
  recordsPerVehicle: numArg('--records-per-vehicle', 30),
  inquiries: numArg('--inquiries', 500),
};

// --- 安全装置: 本番誤投入を防ぐ ---
if (!isDryRun && !useEmulator && !allowProduction) {
  console.error(
    '[ABORT] 負荷検証データの本番投入は危険です。\n' +
      '  emulator で実行する場合: --emulator を付けてください。\n' +
      '  どうしても本番に投入する場合のみ: --i-understand-production を明示。'
  );
  process.exit(1);
}

if (useEmulator) {
  process.env.FIRESTORE_EMULATOR_HOST =
    process.env.FIRESTORE_EMULATOR_HOST || 'localhost:8080';
}

let admin;
try {
  admin = require('firebase-admin');
} catch (_) {
  console.error('[ERROR] firebase-admin が見つかりません。`npm install firebase-admin` を実行してください。');
  process.exit(1);
}

if (!admin.apps.length) {
  if (useEmulator) {
    admin.initializeApp({ projectId: 'trust-car-platform' });
  } else {
    admin.initializeApp({ credential: admin.credential.applicationDefault() });
  }
}

const db = admin.firestore();
const { Timestamp } = admin.firestore;
const BATCH_LIMIT = 450; // Firestore のバッチ上限 500 に対し安全マージン

const FLEET_OWNER = 'loadtest_owner';
const TARGET_SHOP = 'loadtest_shop_1';
const MAKERS = ['toyota', 'honda', 'nissan', 'mazda', 'subaru'];
const STATUSES = ['pending', 'inProgress', 'answered', 'closed'];

/** date を i 分（または i 日）ずらして単調に並べる基準日 */
const BASE = new Date('2024-01-01T00:00:00Z');

function buildPosts(n) {
  const docs = [];
  for (let i = 0; i < n; i++) {
    docs.push({
      id: `loadtest_post_${i}`,
      data: {
        userId: `loadtest_user_${i % 50}`,
        visibility: 'public',
        content: `負荷検証投稿 #${i} #loadtest`,
        category: 'general',
        hashtags: ['loadtest'],
        mentionedUserIds: [],
        likeCount: i % 100,
        commentCount: i % 10,
        shareCount: 0,
        viewCount: i,
        isEdited: false,
        media: [],
        createdAt: Timestamp.fromDate(new Date(BASE.getTime() + i * 60000)),
        updatedAt: Timestamp.fromDate(BASE),
      },
    });
  }
  return docs;
}

function buildVehicles(n) {
  const docs = [];
  for (let i = 0; i < n; i++) {
    docs.push({
      id: `loadtest_vehicle_${i}`,
      data: {
        userId: FLEET_OWNER,
        makerId: MAKERS[i % MAKERS.length],
        modelName: `Model-${i % 20}`,
        year: 2015 + (i % 10),
        licensePlate: `品川 ${100 + i} あ ${1000 + i}`,
        mileage: 10000 + i * 137,
        createdAt: Timestamp.fromDate(new Date(BASE.getTime() + i * 86400000)),
      },
    });
  }
  return docs;
}

function buildMaintenanceRecords(vehicleCount, perVehicle) {
  const docs = [];
  for (let v = 0; v < vehicleCount; v++) {
    for (let r = 0; r < perVehicle; r++) {
      const idx = v * perVehicle + r;
      docs.push({
        id: `loadtest_record_${idx}`,
        data: {
          vehicleId: `loadtest_vehicle_${v}`,
          userId: FLEET_OWNER,
          type: 'oilChange',
          title: `整備 #${r}`,
          cost: 5000 + r * 100,
          date: Timestamp.fromDate(new Date(BASE.getTime() + r * 86400000)),
          createdAt: Timestamp.fromDate(BASE),
        },
      });
    }
  }
  return docs;
}

function buildInquiries(n) {
  const docs = [];
  for (let i = 0; i < n; i++) {
    docs.push({
      id: `loadtest_inquiry_${i}`,
      data: {
        userId: `loadtest_user_${i % 50}`,
        shopId: TARGET_SHOP,
        subject: `見積もり依頼 #${i}`,
        status: STATUSES[i % STATUSES.length],
        createdAt: Timestamp.fromDate(new Date(BASE.getTime() + i * 3600000)),
      },
    });
  }
  return docs;
}

/** ドキュメント配列を BATCH_LIMIT ごとに分割コミット */
async function writeChunked(collection, docs) {
  let written = 0;
  for (let i = 0; i < docs.length; i += BATCH_LIMIT) {
    const slice = docs.slice(i, i + BATCH_LIMIT);
    const batch = db.batch();
    for (const doc of slice) {
      batch.set(db.collection(collection).doc(doc.id), doc.data, { merge: true });
    }
    await batch.commit();
    written += slice.length;
    console.log(`[QUEUED] ${collection}: ${written}/${docs.length}`);
  }
  return written;
}

async function main() {
  const plan = {
    posts: buildPosts(COUNT.posts),
    vehicles: buildVehicles(COUNT.vehicles),
    maintenance_records: buildMaintenanceRecords(
      COUNT.vehicles,
      COUNT.recordsPerVehicle
    ),
    inquiries: buildInquiries(COUNT.inquiries),
  };

  const total = Object.values(plan).reduce((s, d) => s + d.length, 0);

  console.log('=== Load Test Seed ===');
  console.log(`dry-run  : ${isDryRun}`);
  console.log(`emulator : ${useEmulator}`);
  console.log('--- 投入予定件数 ---');
  for (const [col, docs] of Object.entries(plan)) {
    console.log(`  ${col}: ${docs.length}`);
  }
  console.log(`  合計: ${total} ドキュメント`);
  console.log('');

  if (isDryRun) {
    console.log('--- [DRY RUN] 書き込みは行いません ---');
    console.log('サンプル posts[0]:', JSON.stringify(plan.posts[0], null, 2));
    return;
  }

  for (const [col, docs] of Object.entries(plan)) {
    await writeChunked(col, docs);
  }

  console.log('');
  console.log(`[SUCCESS] 合計 ${total} ドキュメントを投入しました（IDプレフィックス: loadtest_）。`);
  console.log('検証後は loadtest_ プレフィックスのドキュメントを削除してください。');
}

main().catch((err) => {
  console.error('[ERROR]', err);
  process.exit(1);
});
