#!/usr/bin/env node
/**
 * backfill_fleet_summaries.js — 法人向けの整備集計を、いまある記録から作る（Issue #192）
 *
 * fleet_maintenance_summaries は Cloud Functions（onMaintenanceRecordWritten /
 * onVehicleWrittenForFleetSummary）が記録・車の書き込みのたびに作り直す。
 * **関数をデプロイした時点で既に法人に入っている車**は、次に記録が書かれる
 * まで集計が無いので、デプロイ後に1回だけこれを流す。
 *
 * 対象は companyId が入っている車だけ（法人の管理者しか集計を使わない）。
 * 集計の作り方は functions/src/fleetMaintenanceSummary.ts をそのまま使う。
 *
 * Usage:
 *   (cd functions && npm ci && npm run build)   # lib/ を作る
 *   (cd scripts && npm ci)
 *   node scripts/backfill_fleet_summaries.js --dry-run     # 件数だけ見る
 *   node scripts/backfill_fleet_summaries.js --emulator    # エミュレータ（localhost:8080）
 *   GOOGLE_APPLICATION_CREDENTIALS=... node scripts/backfill_fleet_summaries.js   # 本番
 *
 * 何度流しても同じ結果になる（毎回、記録から作り直すだけ）。
 */

const args = new Set(process.argv.slice(2));
const DRY_RUN = args.has('--dry-run');
if (args.has('--emulator')) {
  process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || 'localhost:8080';
}

const admin = require('firebase-admin');
const {
  SUMMARY_COLLECTION,
  recomputeSummary,
  summarize,
} = require('../functions/lib/fleetMaintenanceSummary');

admin.initializeApp({ projectId: process.env.GCLOUD_PROJECT || 'trust-car-platform' });
const db = admin.firestore();

async function loadRecords(vehicleId) {
  const snap = await db.collection('maintenance_records').where('vehicleId', '==', vehicleId).get();
  return snap.docs.map((d) => d.data());
}

async function main() {
  const vehicles = await db.collection('vehicles').where('companyId', '!=', null).get();
  let written = 0;
  let deleted = 0;
  for (const v of vehicles.docs) {
    if (DRY_RUN) {
      const s = summarize(v.id, String(v.data().userId || ''), await loadRecords(v.id));
      console.log(`[dry-run] ${v.id}: ${s ? `${s.recordCount}件 / ${s.totalCost}円` : '記録なし'}`);
      s ? written++ : deleted++;
      continue;
    }
    const result = await recomputeSummary(v.id, {
      loadVehicle: async () => v.data(),
      loadRecords,
      writeSummary: async (id, s) => {
        await db.collection(SUMMARY_COLLECTION).doc(id).set({
          vehicleId: s.vehicleId,
          ownerId: s.ownerId,
          lastMaintenanceDate: s.lastMaintenanceDateMs === null
            ? null
            : admin.firestore.Timestamp.fromMillis(s.lastMaintenanceDateMs),
          totalCost: s.totalCost,
          recordCount: s.recordCount,
          updatedAt: admin.firestore.Timestamp.now(),
        });
      },
      deleteSummary: async (id) => {
        await db.collection(SUMMARY_COLLECTION).doc(id).delete();
      },
    });
    result === 'written' ? written++ : deleted++;
  }
  console.log(`法人の車 ${vehicles.size}台: 集計あり ${written} / 記録なし ${deleted}${DRY_RUN ? '（dry-run）' : ''}`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
