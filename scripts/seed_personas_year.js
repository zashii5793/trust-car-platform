#!/usr/bin/env node
/**
 * seed_personas_year.js
 *
 * ペルソナ C / D / E / F の「1年使った状態」の足りない分を補う。
 *
 * なぜ要るか（2026-10-08 実測）:
 *   1年分のシード（seed_year_of_use.js）は persona.a だけが対象で、
 *   ほかのペルソナは seed_personas.js と seed_rich_history.js が置く
 *   整備記録しか持っていなかった。
 *
 *     ペルソナ   整備（直近1年）  給油（直近1年）  自賠責の期限
 *     C (Fit)        6 件            0 件            なし
 *     D (Prius)      7 件            0 件            なし
 *     E (N-BOX)      4 件            0 件            なし
 *     F (売却)       0 件            0 件            （売却済み）
 *
 *   使用感テストのシナリオ（docs/USABILITY_TEST_PROMPT.md）では、
 *   E に「自賠責・任意保険の期限がどこで分かるか」、D に「去年いくら使ったか」、
 *   F に「記録を残したまま手放す」を見てもらう。給油が0件・自賠責が空・
 *   売却車に記録が0件のままでは、画面を見ても「空の画面」しか分からない。
 *
 * 作るもの:
 *   fuel_records         C / D / E / F の1年分の給油（満タン法で燃費が出る並び）
 *   maintenance_records  F: 売却までの1年分（オイル・点検・バッテリー）
 *   vehicles             C / D / E: 自賠責の期限（insuranceExpiryDate）・購入日
 *                        （走行距離そのものは触らない。seed_personas.js の値が正）
 *
 * 走行距離の作り方は seed_year_of_use.js と同じ: 車両ドキュメントの現在の
 * 走行距離を正として、そこから日割りで逆算する。
 *
 * Usage:
 *   node seed_personas_year.js --emulator
 *   node seed_personas_year.js --dry-run
 *   node seed_personas_year.js --delete --emulator
 *
 * 前提: 先に seed_personas.js を流しておくこと。
 * --emulator を付けないと書き込まない（--dry-run 以外は止める）。
 */

const admin = require('firebase-admin');

const has = (f) => process.argv.includes(f);
const EMULATOR = has('--emulator');
const DRY_RUN = has('--dry-run');
const DELETE = has('--delete');

if (!EMULATOR && !DRY_RUN) {
  console.error('[ERROR] 本番保護のため、--emulator か --dry-run を付けてください。');
  process.exit(1);
}
if (EMULATOR) {
  process.env.FIRESTORE_EMULATOR_HOST =
    process.env.FIRESTORE_EMULATOR_HOST || 'localhost:8080';
  process.env.FIREBASE_AUTH_EMULATOR_HOST =
    process.env.FIREBASE_AUTH_EMULATOR_HOST || 'localhost:9099';
}

const SEED_TAG = 'personas_year_v1';
const META = { isSeed: true, seedTag: SEED_TAG };

const DAY = 24 * 60 * 60 * 1000;
// 「今日」の0時を基準にする。同じ日に流し直せば、同じデータになる。
const TODAY = (() => {
  const d = new Date();
  d.setHours(0, 0, 0, 0);
  return d.getTime();
})();
const ts = (ms) => admin.firestore.Timestamp.fromMillis(ms);
const daysAgo = (d) => TODAY - d * DAY;

let _seed = 20261008;
function rand() {
  _seed = (_seed * 1103515245 + 12345) % 2147483648;
  return _seed / 2147483648;
}
const between = (a, b) => a + Math.floor(rand() * (b - a + 1));

// ---------------------------------------------------------------------------
// 車両ごとの素性（ID は seed_personas.js と揃える）
// ---------------------------------------------------------------------------
//
// tank: 満タンで入る量（L）、kmPerL: 実燃費、kmPerYear: 年間走行。
// soldDaysAgo: 売却した日（F のみ）。その日より後の記録は作らない。
const VEHICLES = [
  {
    id: 'veh-c-fit', userId: 'user-c', label: 'C: Honda Fit',
    tank: 40, kmPerL: 17.5, kmPerYear: 8500, fuel: 'regular',
    insuranceAfterInspectionDays: 31, purchasedDaysAgo: 365 * 6,
  },
  {
    id: 'veh-d-prius', userId: 'persona-d-user', label: 'D: Toyota Prius',
    tank: 43, kmPerL: 24.0, kmPerYear: 7000, fuel: 'regular',
    insuranceAfterInspectionDays: 30, purchasedDaysAgo: 365 * 4 + 120,
  },
  {
    id: 'veh-e-nbox', userId: 'persona-e-user', label: 'E: Honda N-BOX',
    tank: 27, kmPerL: 18.0, kmPerYear: 3000, fuel: 'regular',
    insuranceAfterInspectionDays: 33, purchasedDaysAgo: 400,
  },
  {
    id: 'veh-f-prius', userId: 'persona-f-user', label: 'F: Toyota Prius（売却済み）',
    tank: 45, kmPerL: 21.0, kmPerYear: 8000, fuel: 'regular',
    soldDaysAgo: 10,
  },
];

// レギュラーの単価。2025-12-31 に暫定税率が廃止され、年明けから下がった。
function pricePerLiter(ms) {
  const d = new Date(ms);
  const base = d < new Date(2026, 0, 1) ? 174 : 158;
  return base + between(-3, 3);
}

function buildFuel(v, currentOdo) {
  const out = [];
  const endDay = v.soldDaysAgo ?? 0;
  // 1回の給油で走る距離（満タン→次の給油まで。8割ほど使ったら入れる）
  const kmPerFill = v.tank * v.kmPerL * 0.8;
  const daysPerFill = Math.max(10, Math.round((kmPerFill / v.kmPerYear) * 365));
  let n = 0;
  for (let d = 365 - between(0, 6); d >= endDay; d -= daysPerFill + between(-4, 4)) {
    const date = daysAgo(d) + between(8, 19) * 60 * 60 * 1000;
    const odo = Math.round(currentOdo - (v.kmPerYear * (d - endDay)) / 365);
    // 10回に1回は満タンにしない（急いでいた・安い店で少しだけ）
    const isFullTank = rand() > 0.1;
    const liters = Math.round(
      (isFullTank ? v.tank * between(70, 88) / 100 : between(10, 18)) * 100,
    ) / 100;
    out.push({
      id: `fuel-py-${v.id}-${String(n).padStart(3, '0')}`,
      vehicleId: v.id,
      userId: v.userId,
      date,
      liters,
      cost: Math.round(liters * pricePerLiter(date)),
      odometer: odo,
      isFullTank,
    });
    n++;
  }
  return out;
}

// F: 売却まで1年分の整備（自分でつけた記録。工場を通していない）
function buildSoldCarMaintenance(v, saleOdo) {
  const items = [
    { d: 340, type: 'oilChange', title: 'エンジンオイル交換', cost: 4980, shop: 'オートバックス 環七店' },
    { d: 300, type: 'legalInspection12', title: '12ヶ月点検', cost: 16500, shop: 'ディーラー系サービス工場' },
    { d: 215, type: 'batteryChange', title: '補機バッテリー交換', cost: 27800, shop: 'ディーラー系サービス工場' },
    { d: 160, type: 'oilChange', title: 'エンジンオイル交換', cost: 5280, shop: 'オートバックス 環七店' },
    { d: 95, type: 'wiperChange', title: 'ワイパーゴム交換', cost: 2100, shop: null },
    { d: 40, type: 'washing', title: '売却前の車内クリーニング', cost: 8800, shop: 'カーケアショップ足立' },
  ];
  return items.map((m, i) => {
    const date = daysAgo(m.d);
    const mileage = Math.round(saleOdo - (v.kmPerYear * (m.d - v.soldDaysAgo)) / 365);
    return {
      id: `mnt-py-f-${String(i).padStart(2, '0')}`,
      data: {
        vehicleId: v.id,
        userId: v.userId,
        type: m.type,
        title: m.title,
        cost: m.cost,
        shopName: m.shop,
        date: ts(date),
        mileageAtService: mileage,
        imageUrls: [],
        certificateUpdated: false,
        workItems: [],
        parts: [],
        verificationSource: 'selfReported',
        createdAt: ts(date + 3 * 60 * 60 * 1000),
        ...META,
      },
    };
  });
}

async function wipe(db) {
  for (const col of ['fuel_records', 'maintenance_records']) {
    const snap = await db.collection(col).where('seedTag', '==', SEED_TAG).get();
    const w = db.bulkWriter();
    snap.docs.forEach((d) => w.delete(d.ref));
    await w.close();
    console.log(`[DELETE] ${col}: ${snap.size} 件`);
  }
  // 車両に足した項目だけを外す（車両そのものは seed_personas.js のもの）
  for (const v of VEHICLES) {
    const ref = db.collection('vehicles').doc(v.id);
    const doc = await ref.get();
    if (!doc.exists || doc.data().personasYearSeedTag !== SEED_TAG) continue;
    await ref.update({
      insuranceExpiryDate: admin.firestore.FieldValue.delete(),
      purchaseDate: admin.firestore.FieldValue.delete(),
      personasYearSeedTag: admin.firestore.FieldValue.delete(),
    });
  }
  console.log('[DELETE] vehicles: 自賠責の期限・購入日を外しました');
}

async function main() {
  if (!admin.apps.length) admin.initializeApp({ projectId: 'trust-car-platform' });
  const db = admin.firestore();

  if (DELETE) {
    if (DRY_RUN) {
      console.log('[DRY-RUN] 削除は行いません');
      return;
    }
    await wipe(db);
    console.log('\n削除しました。');
    return;
  }

  const entries = [];
  const vehicleUpdates = [];
  for (const v of VEHICLES) {
    let doc = null;
    if (!DRY_RUN) {
      doc = await db.collection('vehicles').doc(v.id).get();
      if (!doc.exists) {
        console.error(`[ERROR] vehicles/${v.id} がありません。先に seed_personas.js を流してください。`);
        process.exitCode = 1;
        return;
      }
    }
    const data = doc ? doc.data() : {};
    const currentOdo = data.mileage ?? v.kmPerYear * 4;

    for (const f of buildFuel(v, currentOdo)) {
      entries.push({
        col: 'fuel_records',
        id: f.id,
        data: {
          vehicleId: f.vehicleId,
          userId: f.userId,
          date: ts(f.date),
          liters: f.liters,
          cost: f.cost,
          odometer: f.odometer,
          isFullTank: f.isFullTank,
          createdAt: ts(f.date),
          ...META,
        },
      });
    }

    if (v.soldDaysAgo != null) {
      for (const m of buildSoldCarMaintenance(v, currentOdo)) {
        entries.push({ col: 'maintenance_records', id: m.id, data: m.data });
      }
    } else {
      // 自賠責は、車検と一緒に更新して満了日が車検より1か月ほど後になるのが普通
      const insp = data.inspectionExpiryDate?.toMillis?.() ?? TODAY + 180 * DAY;
      vehicleUpdates.push({
        id: v.id,
        data: {
          insuranceExpiryDate: ts(insp + v.insuranceAfterInspectionDays * DAY),
          purchaseDate: ts(daysAgo(v.purchasedDaysAgo)),
          personasYearSeedTag: SEED_TAG,
        },
      });
    }
  }

  const byCol = {};
  for (const e of entries) byCol[e.col] = (byCol[e.col] || 0) + 1;
  console.log('■ ペルソナ C/D/E/F の1年分（足りない分）');
  for (const [c, n] of Object.entries(byCol)) console.log(`  ${c.padEnd(22)} ${n} 件`);
  console.log(`  ${'vehicles（項目追加）'.padEnd(20)} ${vehicleUpdates.length} 台`);
  for (const v of VEHICLES) {
    const n = entries.filter((e) => e.data.vehicleId === v.id && e.col === 'fuel_records').length;
    console.log(`    ${v.label}: 給油 ${n} 件`);
  }

  if (DRY_RUN) {
    console.log('\n[DRY-RUN] 書き込みは行いません');
    return;
  }

  // 前回の分を消してから書く（日付が変わって ID の数が変わっても残らない）
  await wipe(db);
  const w = db.bulkWriter();
  for (const e of entries) w.set(db.collection(e.col).doc(e.id), e.data);
  for (const u of vehicleUpdates) w.set(db.collection('vehicles').doc(u.id), u.data, { merge: true });
  await w.close();

  console.log(`\n[SUCCESS] ${entries.length} 件を書き込みました。`);
  console.log('後片付け: node seed_personas_year.js --delete --emulator');
}

main().catch((e) => {
  console.error('[FATAL]', e);
  process.exit(1);
});
