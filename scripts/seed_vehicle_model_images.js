#!/usr/bin/env node
/**
 * Vehicle Model Images Seed — 車種マスタの代表画像を設定 (Node.js)
 *
 * VehicleModel.imageUrl（代表画像）を主要車種に設定する。
 * これにより、個人が車両写真をアップロードしていなくても、車種詳細で
 * 車種マスタの代表画像にフォールバック表示される
 * （lib/screens/vehicle_detail_screen.dart の _VehicleImage /
 *   lib/services/vehicle_master_service.dart の getModelImageUrl）。
 *
 * Firestore パス: vehicle_masters/models/items/{modelId}
 *   modelId は makerId + '_' + 車種名(小文字, 空白/ハイフンは_) 例: toyota_rav4
 *
 * Usage:
 *   node scripts/seed_vehicle_model_images.js [--dry-run] [--emulator]
 *
 * 注意: 画像は Unsplash の公開画像（CORS対応・Flutter Web 表示可）。デモ用。
 *       本番は権利処理済みの正式画像へ差し替えること。
 */

const isDryRun = process.argv.includes('--dry-run');
const useEmulator = process.argv.includes('--emulator');
if (useEmulator) process.env.FIRESTORE_EMULATOR_HOST = 'localhost:8080';

const admin = (() => {
  try { return require('firebase-admin'); }
  catch {
    console.error('[ERROR] firebase-admin が必要です。npm install firebase-admin を実行してください。');
    process.exit(1);
  }
})();

if (!admin.apps.length) {
  if (useEmulator) admin.initializeApp({ projectId: 'trust-car-platform' });
  else admin.initializeApp({ credential: admin.credential.applicationDefault() });
}

const db = admin.firestore();

// modelId -> 代表画像URL
const modelImages = {
  toyota_rav4: 'https://images.unsplash.com/photo-1568605117036-5fe5e7bab0b7?auto=format&fit=crop&w=900&q=80',
  toyota_harrier: 'https://images.unsplash.com/photo-1606664515524-ed2f786a0bd6?auto=format&fit=crop&w=900&q=80',
  toyota_prius: 'https://images.unsplash.com/photo-1549317661-bd32c8ce0db2?auto=format&fit=crop&w=900&q=80',
  toyota_alphard: 'https://images.unsplash.com/photo-1632245889029-e406faaa34cd?auto=format&fit=crop&w=900&q=80',
  honda_n_box: 'https://images.unsplash.com/photo-1449965408869-eaa3f722e40d?auto=format&fit=crop&w=900&q=80',
  honda_fit: 'https://images.unsplash.com/photo-1502877338535-766e1452684a?auto=format&fit=crop&w=900&q=80',
  subaru_wrx_s4: 'https://images.unsplash.com/photo-1503376780353-7e6692767b70?auto=format&fit=crop&w=900&q=80',
  nissan_note: 'https://images.unsplash.com/photo-1541899481282-d53bffe3c35d?auto=format&fit=crop&w=900&q=80',
  mazda_cx_5: 'https://images.unsplash.com/photo-1617469767053-d3b523a0b982?auto=format&fit=crop&w=900&q=80',
};

async function main() {
  console.log('='.repeat(70));
  console.log(`Vehicle Model Images Seed — ${isDryRun ? 'DRY RUN' : 'WRITE'}${useEmulator ? ' (emulator)' : ''}`);
  console.log('='.repeat(70));

  const col = db.collection('vehicle_masters').doc('models').collection('items');
  let n = 0;
  for (const [modelId, url] of Object.entries(modelImages)) {
    n++;
    if (isDryRun) {
      console.log(`  items/${modelId}  imageUrl=設定`);
    } else {
      // merge: 既存の車種マスタ行に imageUrl だけ足す（他フィールドは保持）
      await col.doc(modelId).set({ imageUrl: url }, { merge: true });
      console.log(`  ✅ items/${modelId}  imageUrl 更新`);
    }
  }

  console.log('\n' + '-'.repeat(70));
  console.log(`完了: ${n} 車種に代表画像を設定`);
  console.log('※ 個人画像が無い車両の詳細画面で、この画像にフォールバック表示されます。');
  console.log('-'.repeat(70));
}

main()
  .then(() => process.exit(0))
  .catch((e) => { console.error('[FATAL]', e); process.exit(1); });
