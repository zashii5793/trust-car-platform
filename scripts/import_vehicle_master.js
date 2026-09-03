#!/usr/bin/env node
/**
 * Vehicle Master Import — CSV → Firestore (Node.js / firebase-admin)
 *
 * `data/vehicle_masters.csv`（メーカー/車種/グレードのマスタ）を、アプリの
 * `VehicleMasterService` が読むネスト構造へ投入する。
 *
 *   vehicle_masters/makers/items/{id}
 *   vehicle_masters/models/items/{id}
 *
 * 既存の `import_vehicle_master.dart` は Dart コードを生成するだけで Firestore に
 * 書き込めず、しかもトップレベル `vehicle_makers`/`vehicle_models` を想定していて
 * サービスが読むネスト構造と不一致だった。本スクリプトはその不整合を解消する。
 *
 * Usage:
 *   node scripts/import_vehicle_master.js [--dry-run] [--emulator]
 *
 * Options:
 *   --dry-run    Firestore に書かず、投入予定を標準出力に表示する
 *   --emulator   Firebase Emulator (localhost:8080) に接続する
 *
 * Requirements:
 *   cd scripts && npm install   # firebase-admin
 *
 * Example:
 *   firebase emulators:start --only firestore
 *   node scripts/import_vehicle_master.js --dry-run
 *   node scripts/import_vehicle_master.js --emulator
 *
 *   # 本番（要人手承認・vehicle_masters は rules で write=false のため Admin SDK 必須）
 *   export GOOGLE_APPLICATION_CREDENTIALS=path/to/serviceAccount.json
 *   node scripts/import_vehicle_master.js
 *
 * NOTE (grades):
 *   CSV の grade 行は parent_id を持たない「共通グレード」（S/G/X/Z…）で、
 *   `VehicleMasterService.getGradesForModel` は `where('modelId', ...)` で絞り込む
 *   ため、modelId 無しの共通グレードは Firestore からは供給できない。よって grades は
 *   アプリ側の共通グレード・フォールバック（VehicleMasterData.getCommonGrades）に委ね、
 *   本スクリプトでは makers / models のみ投入する（=88車種への拡充。grades は非回帰）。
 *
 * NOTE (本番インデックス):
 *   本番で Firestore データが実際に使われるには、`items` コレクショングループの
 *   複合インデックスが必要（未デプロイ時はクエリが失敗し静的フォールバックに落ちる）。
 *   firestore.indexes.json に追加済み。`firebase deploy --only firestore:indexes` は人手タスク。
 */

const fs = require('fs');
const path = require('path');

const isDryRun = process.argv.includes('--dry-run');
const useEmulator = process.argv.includes('--emulator');

if (useEmulator) {
  process.env.FIRESTORE_EMULATOR_HOST =
    process.env.FIRESTORE_EMULATOR_HOST || 'localhost:8080';
}

const admin = (() => {
  try {
    return require('firebase-admin');
  } catch {
    console.error('[ERROR] firebase-admin が見つかりません。');
    console.error('        cd scripts && npm install を実行してください。');
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
db.settings({ ignoreUndefinedProperties: true });

// ---------------------------------------------------------------------------
// CSV パース
// ---------------------------------------------------------------------------
const CSV_PATH = path.join(__dirname, '..', 'data', 'vehicle_masters.csv');

/** 数値化（空文字/未定義は undefined＝書き込まない） */
function num(v) {
  if (v === undefined || v === null || v.trim() === '') return undefined;
  const n = parseInt(v.trim(), 10);
  return Number.isNaN(n) ? undefined : n;
}

/** 空文字は undefined（書き込まない）に正規化 */
function str(v) {
  if (v === undefined || v === null) return undefined;
  const s = v.trim();
  return s === '' ? undefined : s;
}

function parseCsv() {
  const raw = fs.readFileSync(CSV_PATH, 'utf8');
  const lines = raw.split(/\r?\n/);
  const makers = [];
  const models = [];
  let gradeCount = 0;

  // 列: type,id,parent_id,name,name_en,body_type,
  //     production_start_year,production_end_year,display_order,country
  for (const line of lines) {
    const trimmed = line.trim();
    if (trimmed === '' || trimmed.startsWith('#')) continue;
    const cols = line.split(',');
    const type = (cols[0] || '').trim();
    if (type === 'type') continue; // ヘッダ行

    const id = str(cols[1]);
    const parentId = str(cols[2]);
    const name = str(cols[3]);
    const nameEn = str(cols[4]);
    const bodyType = str(cols[5]);
    const startYear = num(cols[6]);
    const endYear = num(cols[7]);
    const displayOrder = num(cols[8]) ?? 0;
    const country = str(cols[9]);

    if (type === 'maker') {
      if (!id || !name) continue;
      makers.push({
        id,
        data: {
          name,
          nameEn: nameEn ?? name,
          country: country ?? 'JP',
          displayOrder,
          isActive: true,
        },
      });
    } else if (type === 'model') {
      if (!id || !parentId || !name) continue;
      models.push({
        id,
        data: {
          makerId: parentId,
          name,
          nameEn, // 任意（未設定なら undefined→書き込まない）
          bodyType, // BodyType.fromString がパース。未設定なら undefined
          productionStartYear: startYear,
          productionEndYear: endYear,
          displayOrder,
          isActive: true,
        },
      });
    } else if (type === 'grade') {
      // 共通グレード（modelId 無し）はアプリのフォールバックに委ねる（NOTE参照）。
      gradeCount++;
    }
  }

  return { makers, models, gradeCount };
}

// ---------------------------------------------------------------------------
// 実行
// ---------------------------------------------------------------------------
async function main() {
  console.log('=== Vehicle Master Import ===');
  console.log(`dry-run  : ${isDryRun}`);
  console.log(`emulator : ${useEmulator}`);
  console.log(`csv      : ${CSV_PATH}`);
  console.log('');

  const { makers, models, gradeCount } = parseCsv();

  console.log('投入サマリー:');
  console.log(`  vehicle_masters/makers/items : ${makers.length}`);
  console.log(`  vehicle_masters/models/items : ${models.length}`);
  console.log(
    `  grades（共通・フォールバックに委ね未投入）: ${gradeCount}`,
  );
  console.log('');

  if (isDryRun) {
    console.log('--- [DRY RUN] makers ---');
    for (const m of makers) {
      console.log(`  ${m.id} — ${m.data.name} (${m.data.nameEn})`);
    }
    console.log('--- [DRY RUN] models（先頭20件） ---');
    for (const m of models.slice(0, 20)) {
      console.log(
        `  ${m.id} — ${m.data.name} [maker=${m.data.makerId}, body=${
          m.data.bodyType ?? '-'
        }]`,
      );
    }
    if (models.length > 20) console.log(`  ...（他 ${models.length - 20} 件）`);
    console.log('\n--- [DRY RUN] 完了（Firestore への書き込みは行っていません）---');
    return;
  }

  const makersCol = db
    .collection('vehicle_masters')
    .doc('makers')
    .collection('items');
  const modelsCol = db
    .collection('vehicle_masters')
    .doc('models')
    .collection('items');

  const batch = db.batch();
  for (const m of makers) {
    batch.set(makersCol.doc(m.id), m.data, { merge: true });
  }
  for (const m of models) {
    batch.set(modelsCol.doc(m.id), m.data, { merge: true });
  }
  await batch.commit();

  console.log(
    `[SUCCESS] makers ${makers.length} 件 / models ${models.length} 件を Firestore に投入しました。`,
  );
  console.log(
    'grades は共通グレードのため未投入（アプリの VehicleMasterData.getCommonGrades にフォールバック）。',
  );
}

main().catch((err) => {
  console.error('[ERROR]', err);
  process.exit(1);
});
