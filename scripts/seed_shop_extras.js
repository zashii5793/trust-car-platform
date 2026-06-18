#!/usr/bin/env node
/**
 * Shop Extras Seed — 工場詳細を充実させる追加データ (Node.js)
 *
 * 既存の shops（seed_shops.js で投入）に対し、工場詳細画面で表示される
 * 「工場の特徴(appealPoints)」と「料金メニュー(service_menus)」を追加する。
 * これにより shop_detail_screen の新セクションが実データで確認できる。
 *
 * Usage:
 *   node scripts/seed_shop_extras.js [--dry-run] [--emulator] [--clean]
 *
 * 前提: 先に seed_shops.js を実行して shops が存在すること。
 *
 * 注意:
 *   - デモ用サンプル。料金・特徴は架空。本番では実店舗の正式データに差し替える。
 *   - service_menus は (isActive, shopId, sortOrder) でクエリされるため、
 *     Firestore 複合インデックスが必要な場合がある（firestore.indexes.json 参照）。
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

// 各店舗の appealPoints（工場の特徴）
const appealPointsByShop = {
  shop_takaya_motor_okayama: ['創業約60年の実績', '車検・整備・販売まで一括', '国家資格整備士在籍'],
  demo_kanto_auto_service: ['年中無休', '代車無料', 'EV・ハイブリッド対応'],
  demo_minato_motors: ['輸入車サービス', '女性スタッフ在籍', 'ガラスコーティング認定店'],
  demo_nagoya_carcare: ['板金・塗装が得意', '保険対応OK', '見積無料'],
  demo_naniwa_shaken: ['車検最短60分', '土日も営業', '立会い車検可能'],
  demo_sapporo_north_garage: ['積雪地対応', 'スタッドレス保管', '4WD整備に強い'],
  demo_fukuoka_auto_factory: ['カスタム相談歓迎', 'ドラレコ取付実績多数', 'LINE予約対応'],
};

// service_menus（一部の店舗にデモ料金を投入）。category は ServiceCategory.name。
function menu(shopId, sortOrder, m) {
  return {
    id: `${shopId}_menu${sortOrder}`,
    data: {
      shopId,
      category: m.category,
      name: m.name,
      description: m.description ?? null,
      details: null,
      pricingType: m.pricingType ?? 'fixed',     // fixed | fromPrice | perHour | estimate
      basePrice: m.basePrice ?? null,
      maxPrice: m.maxPrice ?? null,
      laborCostPerHour: null,
      estimatedHours: m.estimatedHours ?? null,
      minHours: null,
      maxHours: null,
      applicableVehicleTypes: [],
      isUniversal: true,
      isActive: true,
      isPopular: m.isPopular ?? false,
      isRecommended: false,
      sortOrder,
      imageUrl: null,
      galleryUrls: [],
      metadata: null,
      createdAt: now,
      updatedAt: now,
    },
  };
}

const serviceMenus = [
  // タカヤモーター
  menu('shop_takaya_motor_okayama', 1, { category: 'inspection', name: '軽自動車 車検（基本）', description: '法定費用別・代車無料', pricingType: 'fromPrice', basePrice: 28000, estimatedHours: 2, isPopular: true }),
  menu('shop_takaya_motor_okayama', 2, { category: 'inspection', name: '普通車 車検（基本）', description: '法定費用別', pricingType: 'fromPrice', basePrice: 38000, estimatedHours: 2 }),
  menu('shop_takaya_motor_okayama', 3, { category: 'oilChange', name: 'オイル交換（化学合成油）', description: 'エレメント別', pricingType: 'fromPrice', basePrice: 4400, estimatedHours: 0.5, isPopular: true }),
  menu('shop_takaya_motor_okayama', 4, { category: 'tire', name: 'タイヤ交換（4本・脱着）', pricingType: 'fromPrice', basePrice: 4400, estimatedHours: 1 }),
  // 関東オートサービス（demo）
  menu('demo_kanto_auto_service', 1, { category: 'inspection', name: '普通車 車検 スピードコース', description: '最短当日', pricingType: 'fromPrice', basePrice: 42000, estimatedHours: 1.5, isPopular: true }),
  menu('demo_kanto_auto_service', 2, { category: 'maintenance', name: 'バッテリー交換', description: '工賃込', pricingType: 'fromPrice', basePrice: 8800, estimatedHours: 0.5 }),
  menu('demo_kanto_auto_service', 3, { category: 'oilChange', name: 'オイル交換', pricingType: 'fromPrice', basePrice: 3300, estimatedHours: 0.5 }),
  // なにわ車検（demo）
  menu('demo_naniwa_shaken', 1, { category: 'inspection', name: '立会い車検（普通車）', description: '最短60分・その場で説明', pricingType: 'fromPrice', basePrice: 35000, estimatedHours: 1, isPopular: true }),
  menu('demo_naniwa_shaken', 2, { category: 'inspection', name: '軽自動車 車検', pricingType: 'fromPrice', basePrice: 27000, estimatedHours: 1 }),
];

async function main() {
  console.log('='.repeat(70));
  console.log(`Shop Extras Seed — ${isDryRun ? 'DRY RUN' : 'WRITE'}${useEmulator ? ' (emulator)' : ''}`);
  console.log('='.repeat(70));

  if (doClean && !isDryRun) {
    for (const m of serviceMenus) {
      await db.collection('service_menus').doc(m.id).delete().catch(() => {});
    }
    console.log('[clean] 既存のデモ料金メニューを削除しました');
  }

  // appealPoints を merge 更新
  console.log('\n[appealPoints]');
  for (const [shopId, points] of Object.entries(appealPointsByShop)) {
    if (isDryRun) {
      console.log(`  shops/${shopId}  +appealPoints ${JSON.stringify(points)}`);
    } else {
      await db.collection('shops').doc(shopId).set(
        { appealPoints: points, updatedAt: now }, { merge: true },
      );
      console.log(`  ✅ shops/${shopId}  appealPoints 更新`);
    }
  }

  // service_menus を投入
  console.log('\n[service_menus]');
  for (const m of serviceMenus) {
    if (isDryRun) {
      console.log(`  service_menus/${m.id}  ${m.data.name}`);
    } else {
      await db.collection('service_menus').doc(m.id).set(m.data, { merge: true });
      console.log(`  ✅ service_menus/${m.id}  ${m.data.name}`);
    }
  }

  console.log('\n' + '-'.repeat(70));
  console.log(`完了: appealPoints ${Object.keys(appealPointsByShop).length}店 / service_menus ${serviceMenus.length}件`);
  console.log('-'.repeat(70));
}

main()
  .then(() => process.exit(0))
  .catch((e) => { console.error('[FATAL]', e); process.exit(1); });
