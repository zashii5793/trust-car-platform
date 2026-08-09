#!/usr/bin/env node
/**
 * 大量データ負荷検証用シードスクリプト（B2B / 社用車フリート想定）
 *
 * ページネーション・インデックス・一覧画面・テナント分離のパフォーマンスを
 * 「法人フリート規模の大量データ」で検証するためのダミーデータを投入する。
 * 想定は個人（1〜2台）ではなく **法人10〜100台/テナント** のマルチテナント。
 *
 * 既定の規模（B2B）:
 *   - fleets:               5 法人テナント（shopId==ownerId==uid）
 *   - vehicles:             5 × 40 = 200 台（1フリート40台＝10〜100の中央値）
 *   - maintenance_records:  200 台 × 各 50 件 = 10,000 件
 *   - inquiries:            5 × 100 = 500 件（フリートごとの問い合わせ）
 *   - posts:                1000 件（公開フィード）
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
 *   # 大規模フリート（100台×10法人=1000台, 履歴50件=50,000件）:
 *   node scripts/seed_load_test.js --emulator --fleets 10 --vehicles-per-fleet 100
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

// B2B（社用車管理）前提の既定値。1テナント＝1法人フリート。
//   fleets            : 法人テナント数
//   vehiclesPerFleet  : 1フリートあたりの車両台数（10〜100台想定の中央値）
//   recordsPerVehicle : 1車両あたりの整備履歴（法人は稼働が高く履歴が厚い）
//   inquiriesPerFleet : 1フリートが受け取る問い合わせ件数
const COUNT = {
  posts: numArg('--posts', 1000),
  fleets: numArg('--fleets', 5),
  vehiclesPerFleet: numArg('--vehicles-per-fleet', 40),
  recordsPerVehicle: numArg('--records-per-vehicle', 50),
  inquiriesPerFleet: numArg('--inquiries-per-fleet', 100),
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

const MAKERS = ['toyota', 'honda', 'nissan', 'mazda', 'subaru'];
const STATUSES = ['pending', 'inProgress', 'answered', 'closed'];

// マルチテナント: 1フリート＝1法人。所有者IDとショップIDは同一（shopId==ownerId==uid）で、
// firestore.rules のテナント分離モデルに一致させる。
const fleetOwnerId = (f) => `loadtest_fleet_${f}`;

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

// フリート横断で車両を生成。各車両はどのフリート(法人)に属するかを保持する。
function buildVehicles(fleets, perFleet) {
  const docs = [];
  for (let f = 0; f < fleets; f++) {
    for (let k = 0; k < perFleet; k++) {
      const i = f * perFleet + k;
      docs.push({
        id: `loadtest_vehicle_${i}`,
        _fleet: f, // 内部用（Firestoreには書かない）
        data: {
          userId: fleetOwnerId(f),
          companyId: fleetOwnerId(f), // 社用車：法人に紐づく
          makerId: MAKERS[i % MAKERS.length],
          modelName: `Model-${i % 20}`,
          year: 2015 + (i % 10),
          licensePlate: `品川 ${100 + (i % 900)} あ ${1000 + (i % 8999)}`,
          mileage: 10000 + i * 137,
          createdAt: Timestamp.fromDate(new Date(BASE.getTime() + i * 86400000)),
        },
      });
    }
  }
  return docs;
}

// 各車両にフリート所有者の整備履歴をぶら下げる（車両ごとに perVehicle 件）。
function buildMaintenanceRecords(vehicles, perVehicle) {
  const docs = [];
  let idx = 0;
  for (const v of vehicles) {
    for (let r = 0; r < perVehicle; r++) {
      docs.push({
        id: `loadtest_record_${idx}`,
        data: {
          vehicleId: v.id,
          userId: v.data.userId,
          type: 'oilChange',
          title: `整備 #${r}`,
          cost: 5000 + r * 100,
          date: Timestamp.fromDate(new Date(BASE.getTime() + r * 86400000)),
          createdAt: Timestamp.fromDate(BASE),
        },
      });
      idx++;
    }
  }
  return docs;
}

// 各フリート(法人ショップ)が受け取る問い合わせを生成。shopId でテナント分離を検証できる。
function buildInquiries(fleets, perFleet) {
  const docs = [];
  let idx = 0;
  for (let f = 0; f < fleets; f++) {
    for (let k = 0; k < perFleet; k++) {
      docs.push({
        id: `loadtest_inquiry_${idx}`,
        data: {
          userId: `loadtest_user_${idx % 200}`,
          shopId: fleetOwnerId(f),
          subject: `見積もり依頼 #${idx}`,
          status: STATUSES[idx % STATUSES.length],
          createdAt: Timestamp.fromDate(new Date(BASE.getTime() + idx * 3600000)),
        },
      });
      idx++;
    }
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
  const vehicles = buildVehicles(COUNT.fleets, COUNT.vehiclesPerFleet);
  const plan = {
    posts: buildPosts(COUNT.posts),
    vehicles,
    maintenance_records: buildMaintenanceRecords(
      vehicles,
      COUNT.recordsPerVehicle
    ),
    inquiries: buildInquiries(COUNT.fleets, COUNT.inquiriesPerFleet),
  };

  const total = Object.values(plan).reduce((s, d) => s + d.length, 0);

  console.log('=== Load Test Seed (B2B フリート想定) ===');
  console.log(`dry-run  : ${isDryRun}`);
  console.log(`emulator : ${useEmulator}`);
  console.log(
    `構成      : ${COUNT.fleets} 法人フリート × ${COUNT.vehiclesPerFleet} 台` +
      ` = ${COUNT.fleets * COUNT.vehiclesPerFleet} 車両 / ` +
      `車両あたり整備 ${COUNT.recordsPerVehicle} 件`
  );
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
