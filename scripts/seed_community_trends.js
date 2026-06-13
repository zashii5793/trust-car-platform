#!/usr/bin/env node
/**
 * Community Maintenance Trends Seed Data — Firestore 登録スクリプト (Node.js)
 *
 * Usage:
 *   node scripts/seed_community_trends.js [--dry-run] [--emulator]
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
 *   node scripts/seed_community_trends.js --dry-run
 *   node scripts/seed_community_trends.js --emulator
 *
 *   # 本番に登録
 *   export GOOGLE_APPLICATION_CREDENTIALS=path/to/serviceAccount.json
 *   node scripts/seed_community_trends.js
 *
 * Data notes:
 *   - Document ID format: {maker}_{model}  (e.g. "トヨタ_プリウス")
 *   - All figures are representative estimates for initial seed.
 *     Replace with real aggregated data once production vehicles accumulate.
 *   - Privacy: only aggregate/median values are stored — no individual user data.
 *   - MaintenanceType keys must match the Flutter enum:
 *       oilChange, oilFilterChange, tireRotation, tireReplacement,
 *       brakeInspection, brakeFluidChange, coolantChange, batteryChange,
 *       airFilterChange, cabinFilterChange, transmissionFluidChange,
 *       legalInspection12, legalInspection24, carInspection, other
 */

const isDryRun    = process.argv.includes('--dry-run');
const useEmulator = process.argv.includes('--emulator');

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

if (!admin.apps.length) {
  if (useEmulator) {
    admin.initializeApp({ projectId: 'trust-car-platform' });
  } else {
    admin.initializeApp({ credential: admin.credential.applicationDefault() });
  }
}

const db = admin.firestore();
const { Timestamp } = admin.firestore;

const now = Timestamp.now();

// ---------------------------------------------------------------------------
// シードデータ定義
// ---------------------------------------------------------------------------

const communityTrends = [
  // ------------------------------------------------------------------
  // トヨタ プリウス (60系・50系混在の代表値)
  // ------------------------------------------------------------------
  {
    id: 'トヨタ_プリウス',
    data: {
      maker: 'トヨタ',
      model: 'プリウス',
      sampleVehicleCount: 42,
      lastUpdated: now,
      insights: [
        {
          type: 'oilChange',
          medianIntervalKm: 8000,
          medianIntervalDays: 180,
          medianCost: 4500,
          sampleCount: 38,
          popularityPercent: 91,
        },
        {
          type: 'tireRotation',
          medianIntervalKm: 10000,
          medianIntervalDays: 365,
          medianCost: 3300,
          sampleCount: 30,
          popularityPercent: 71,
        },
        {
          type: 'tireReplacement',
          medianIntervalKm: 40000,
          medianIntervalDays: 1460,
          medianCost: 55000,
          sampleCount: 18,
          popularityPercent: 43,
        },
        {
          type: 'brakeInspection',
          medianIntervalKm: 20000,
          medianIntervalDays: 730,
          medianCost: 8000,
          sampleCount: 22,
          popularityPercent: 52,
        },
        {
          type: 'cabinFilterChange',
          medianIntervalKm: 15000,
          medianIntervalDays: 365,
          medianCost: 2800,
          sampleCount: 28,
          popularityPercent: 67,
        },
        {
          type: 'batteryChange',
          medianIntervalKm: 60000,
          medianIntervalDays: 1825,
          medianCost: 12000,
          sampleCount: 12,
          popularityPercent: 29,
        },
      ],
    },
  },

  // ------------------------------------------------------------------
  // ホンダ N-BOX (JF3/JF4)
  // ------------------------------------------------------------------
  {
    id: 'ホンダ_N-BOX',
    data: {
      maker: 'ホンダ',
      model: 'N-BOX',
      sampleVehicleCount: 38,
      lastUpdated: now,
      insights: [
        {
          type: 'oilChange',
          medianIntervalKm: 5000,
          medianIntervalDays: 150,
          medianCost: 3800,
          sampleCount: 35,
          popularityPercent: 92,
        },
        {
          type: 'oilFilterChange',
          medianIntervalKm: 10000,
          medianIntervalDays: 300,
          medianCost: 1500,
          sampleCount: 28,
          popularityPercent: 74,
        },
        {
          type: 'tireRotation',
          medianIntervalKm: 8000,
          medianIntervalDays: 300,
          medianCost: 3300,
          sampleCount: 25,
          popularityPercent: 66,
        },
        {
          type: 'tireReplacement',
          medianIntervalKm: 30000,
          medianIntervalDays: 1095,
          medianCost: 35000,
          sampleCount: 16,
          popularityPercent: 42,
        },
        {
          type: 'airFilterChange',
          medianIntervalKm: 20000,
          medianIntervalDays: 730,
          medianCost: 3000,
          sampleCount: 20,
          popularityPercent: 53,
        },
        {
          type: 'brakeInspection',
          medianIntervalKm: 20000,
          medianIntervalDays: 730,
          medianCost: 5500,
          sampleCount: 18,
          popularityPercent: 47,
        },
      ],
    },
  },

  // ------------------------------------------------------------------
  // 日産 リーフ (ZE1)
  // ------------------------------------------------------------------
  {
    id: '日産_リーフ',
    data: {
      maker: '日産',
      model: 'リーフ',
      sampleVehicleCount: 15,
      lastUpdated: now,
      insights: [
        {
          type: 'tireRotation',
          medianIntervalKm: 10000,
          medianIntervalDays: 365,
          medianCost: 3300,
          sampleCount: 12,
          popularityPercent: 80,
        },
        {
          type: 'tireReplacement',
          medianIntervalKm: 35000,
          medianIntervalDays: 1460,
          medianCost: 50000,
          sampleCount: 8,
          popularityPercent: 53,
        },
        {
          type: 'brakeInspection',
          medianIntervalKm: 30000,
          medianIntervalDays: 1095,
          medianCost: 6000,
          sampleCount: 10,
          popularityPercent: 67,
        },
        {
          type: 'cabinFilterChange',
          medianIntervalKm: 15000,
          medianIntervalDays: 365,
          medianCost: 3500,
          sampleCount: 11,
          popularityPercent: 73,
        },
        {
          // EV固有: 冷却水（バッテリー冷却系）交換
          type: 'coolantChange',
          medianIntervalKm: 60000,
          medianIntervalDays: 1825,
          medianCost: 9000,
          sampleCount: 5,
          popularityPercent: 33,
        },
      ],
    },
  },

  // ------------------------------------------------------------------
  // ホンダ フィット (GR系)
  // ------------------------------------------------------------------
  {
    id: 'ホンダ_フィット',
    data: {
      maker: 'ホンダ',
      model: 'フィット',
      sampleVehicleCount: 28,
      lastUpdated: now,
      insights: [
        {
          type: 'oilChange',
          medianIntervalKm: 6000,
          medianIntervalDays: 180,
          medianCost: 4000,
          sampleCount: 26,
          popularityPercent: 93,
        },
        {
          type: 'oilFilterChange',
          medianIntervalKm: 12000,
          medianIntervalDays: 365,
          medianCost: 1500,
          sampleCount: 20,
          popularityPercent: 71,
        },
        {
          type: 'tireRotation',
          medianIntervalKm: 10000,
          medianIntervalDays: 365,
          medianCost: 3300,
          sampleCount: 18,
          popularityPercent: 64,
        },
        {
          type: 'tireReplacement',
          medianIntervalKm: 40000,
          medianIntervalDays: 1460,
          medianCost: 40000,
          sampleCount: 12,
          popularityPercent: 43,
        },
        {
          type: 'brakeFluidChange',
          medianIntervalKm: 40000,
          medianIntervalDays: 1460,
          medianCost: 8000,
          sampleCount: 10,
          popularityPercent: 36,
        },
      ],
    },
  },

  // ------------------------------------------------------------------
  // トヨタ ヴォクシー (90系)
  // ------------------------------------------------------------------
  {
    id: 'トヨタ_ヴォクシー',
    data: {
      maker: 'トヨタ',
      model: 'ヴォクシー',
      sampleVehicleCount: 33,
      lastUpdated: now,
      insights: [
        {
          type: 'oilChange',
          medianIntervalKm: 7000,
          medianIntervalDays: 180,
          medianCost: 5000,
          sampleCount: 30,
          popularityPercent: 91,
        },
        {
          type: 'tireRotation',
          medianIntervalKm: 10000,
          medianIntervalDays: 365,
          medianCost: 3300,
          sampleCount: 22,
          popularityPercent: 67,
        },
        {
          type: 'tireReplacement',
          medianIntervalKm: 40000,
          medianIntervalDays: 1460,
          medianCost: 60000,
          sampleCount: 14,
          popularityPercent: 42,
        },
        {
          type: 'brakeInspection',
          medianIntervalKm: 20000,
          medianIntervalDays: 730,
          medianCost: 9000,
          sampleCount: 18,
          popularityPercent: 55,
        },
        {
          type: 'airFilterChange',
          medianIntervalKm: 25000,
          medianIntervalDays: 730,
          medianCost: 3500,
          sampleCount: 15,
          popularityPercent: 45,
        },
        {
          type: 'transmissionFluidChange',
          medianIntervalKm: 60000,
          medianIntervalDays: 2190,
          medianCost: 15000,
          sampleCount: 8,
          popularityPercent: 24,
        },
      ],
    },
  },
];

// ---------------------------------------------------------------------------
// 実行
// ---------------------------------------------------------------------------
async function main() {
  console.log('=== Community Maintenance Trends Seed Script ===');
  console.log(`dry-run  : ${isDryRun}`);
  console.log(`emulator : ${useEmulator}`);
  console.log(`登録件数  : ${communityTrends.length} 車種`);
  console.log('');

  if (isDryRun) {
    console.log('--- [DRY RUN] 登録予定データ ---');
    for (const trend of communityTrends) {
      console.log(`ID: ${trend.id}`);
      console.log(`  maker  : ${trend.data.maker}`);
      console.log(`  model  : ${trend.data.model}`);
      console.log(`  samples: ${trend.data.sampleVehicleCount} 台`);
      console.log(`  insights: ${trend.data.insights.length} 件`);
      console.log('');
    }
    console.log('--- [DRY RUN] 完了（Firestore への書き込みは行っていません）---');
    return;
  }

  const batch = db.batch();

  for (const trend of communityTrends) {
    const ref = db.collection('community_maintenance_trends').doc(trend.id);
    batch.set(ref, trend.data, { merge: true });
    console.log(
      `[QUEUED] community_maintenance_trends/${trend.id} — ${trend.data.maker} ${trend.data.model} (${trend.data.sampleVehicleCount}台)`,
    );
  }

  await batch.commit();
  console.log('');
  console.log(`[SUCCESS] ${communityTrends.length} 車種のトレンドデータを Firestore に登録しました。`);
}

main().catch((err) => {
  console.error('[ERROR]', err);
  process.exit(1);
});
