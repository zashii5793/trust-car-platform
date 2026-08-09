#!/usr/bin/env node
/**
 * 法人フリート 100台 ＋ 1年分の利用履歴シード
 *
 * Usage:
 *   node scripts/seed_fleet_year.js [--dry-run] [--emulator] [--delete]
 *                                   [--vehicles=100] [--months=12]
 *
 * `seed_personas.js` が作る20台のフリート（Persona B）とは別に、
 * **運用実態に近い規模と履歴**を持つ法人アカウントを1社分作る。
 *
 * なぜ別スクリプトか:
 *   seed_personas.js はペルソナA〜Iの導線確認が目的で、1台あたりの履歴は
 *   持たない。「1年使ったらどう見えるか」は台数ではなく**時間軸の密度**が
 *   要るため、目的が違う。混ぜると片方だけ流したいときに困る。
 *
 * 作るもの（既定 100台 / 12ヶ月）:
 *   users            1件   法人オーナー
 *   users           +8件   担当ドライバー
 *   fleet_members    9件   オーナー + ドライバー
 *   vehicles       100件   貨物62 / 営業38。車検期限・走行距離を分散
 *   maintenance_records 約800件  オイル交換・12ヶ月点検・車検・タイヤ
 *   drive_logs      約240件  営業車の走行記録（直近3ヶ月）
 *
 * Requirements:
 *   cd scripts && npm install
 *
 * ⚠️ 本番に流す場合の注意
 *   --emulator を付けないと本番 Firestore に書き込みます。書き込み件数が
 *   1,000件を超えるため、課金と、後片付け（--delete）を必ず意識してください。
 *   作成したドキュメントには isSeed:true と seedTag を付けており、
 *   --delete はそれを目印に消します。
 */

const admin = require('firebase-admin');

const argv = process.argv.slice(2);
const has = (f) => argv.includes(f);
const num = (name, def) => {
  const hit = argv.find((a) => a.startsWith(`--${name}=`));
  return hit ? parseInt(hit.split('=')[1], 10) : def;
};

const DRY_RUN = has('--dry-run');
const EMULATOR = has('--emulator');
const DELETE = has('--delete');
const VEHICLE_COUNT = num('vehicles', 100);
const MONTHS = num('months', 12);

if (EMULATOR) {
  process.env.FIRESTORE_EMULATOR_HOST = 'localhost:8080';
  process.env.FIREBASE_AUTH_EMULATOR_HOST = 'localhost:9099';
}

const SEED_TAG = 'fleet_year_v1';
const COMPANY_ID = 'fleetyear-owner-uid';
const OWNER_EMAIL = 'fleet.owner@trustcar-test.example';

const DAY = 24 * 60 * 60 * 1000;
const NOW = Date.now();

// 決定的な乱数。実行のたびに中身が変わると「昨日と違う」が起きて
// 動作確認にならないため、シード固定の線形合同法を使う。
let _seed = 20260809;
function rand() {
  _seed = (_seed * 1103515245 + 12345) % 2147483648;
  return _seed / 2147483648;
}
const pick = (arr) => arr[Math.floor(rand() * arr.length)];
const between = (a, b) => a + Math.floor(rand() * (b - a + 1));

const ts = (ms) => admin.firestore.Timestamp.fromMillis(ms);
const daysFromNow = (d) => ts(NOW + d * DAY);

// ---------------------------------------------------------------------------
// 車種構成
// ---------------------------------------------------------------------------
//
// 運送会社を想定。貨物車が多数を占め、営業・管理用の乗用車が混ざる。
// 貨物車（1・4ナンバー）は毎年車検なので、期限管理の負荷が乗用車と違う。
// この差が画面に出るかを確認したいので、比率を実態に寄せる。

const CARGO_MODELS = [
  { maker: 'トヨタ', model: 'ハイエース', grade: 'DX', fuel: 'diesel' },
  { maker: 'トヨタ', model: 'ダイナ', grade: '標準', fuel: 'diesel' },
  { maker: '日産', model: 'キャラバン', grade: 'DX', fuel: 'diesel' },
  { maker: 'いすゞ', model: 'エルフ', grade: '標準', fuel: 'diesel' },
  { maker: 'トヨタ', model: 'プロボックス', grade: 'GX', fuel: 'gasoline' },
];

const PASSENGER_MODELS = [
  { maker: 'トヨタ', model: 'プリウス', grade: 'S', fuel: 'hybrid' },
  { maker: 'トヨタ', model: 'カローラ', grade: 'G', fuel: 'gasoline' },
  { maker: 'ホンダ', model: 'フリード', grade: 'G', fuel: 'hybrid' },
  { maker: '日産', model: 'セレナ', grade: 'X', fuel: 'gasoline' },
];

const PLATE_AREAS = ['足立', '練馬', '品川', '八王子', '横浜', '川口'];

const DRIVERS = [
  '佐藤 健一', '鈴木 大輔', '高橋 誠', '田中 浩二',
  '伊藤 隆', '渡辺 明', '山本 和也', '中村 直樹',
];

// ---------------------------------------------------------------------------
// 生成
// ---------------------------------------------------------------------------

function buildVehicles() {
  const vehicles = [];
  for (let i = 0; i < VEHICLE_COUNT; i++) {
    // 6割強を貨物にする。
    const isCargo = i % 5 !== 4 && i % 7 !== 6;
    const spec = isCargo ? pick(CARGO_MODELS) : pick(PASSENGER_MODELS);

    // 車検期限の分布。期限切れ・間近を必ず含めないと、警告表示の確認が
    // できない。かといって全部が赤いと実態から離れる。
    let inspectionDays;
    if (i < 3) inspectionDays = between(-40, -2); // 期限切れ
    else if (i < 9) inspectionDays = between(1, 30); // 30日以内
    else if (i < 20) inspectionDays = between(31, 90); // 90日以内
    else inspectionDays = between(91, isCargo ? 360 : 700);

    const yearsOwned = between(1, 6);
    const annualKm = isCargo ? between(25000, 40000) : between(9000, 18000);
    const mileage = annualKm * yearsOwned + between(0, 5000);

    const driver = i % 3 === 0 ? DRIVERS[i % DRIVERS.length] : null;

    vehicles.push({
      id: `fy-veh-${String(i).padStart(3, '0')}`,
      isCargo,
      annualKm,
      data: {
        userId: COMPANY_ID,
        companyId: COMPANY_ID,
        maker: spec.maker,
        model: spec.model,
        grade: spec.grade,
        year: new Date().getFullYear() - yearsOwned,
        mileage,
        mileageUpdatedAt: daysFromNow(-between(0, 20)),
        licensePlate: `${pick(PLATE_AREAS)} ${isCargo ? '400' : '300'} あ ${String(
          i + 1,
        ).padStart(2, '0')}-${String(between(10, 99))}`,
        inspectionExpiryDate: daysFromNow(inspectionDays),
        insuranceExpiryDate: daysFromNow(between(-10, 350)),
        useCategory: isCargo ? 'cargo' : 'privatePassenger',
        fuelType: spec.fuel,
        status: 'active',
        isDataRetained: true,
        ...(driver
          ? { assigneeId: `fy-driver-${i % DRIVERS.length}`, assigneeName: driver }
          : {}),
        createdAt: daysFromNow(-yearsOwned * 365),
        updatedAt: daysFromNow(-between(0, 20)),
        isSeed: true,
        seedTag: SEED_TAG,
      },
    });
  }
  return vehicles;
}

/// 1台につき MONTHS ヶ月ぶんの整備履歴を作る。
///
/// 実際の運用に合わせ、オイル交換は走行距離ベース、法定点検は時間ベースで
/// 発生させる。全車両を同じ日に整備したことにすると、画面上の分布が
/// 不自然になり「1年使った感じ」にならない。
function buildMaintenanceRecords(vehicle) {
  const records = [];
  const { id: vehicleId, isCargo, annualKm } = vehicle;
  // 5,000kmごとにオイル交換 → 年間の回数
  const oilChangesPerYear = Math.max(1, Math.round(annualKm / 5000));
  const monthsPerOil = 12 / oilChangesPerYear;

  let seq = 0;
  const push = (daysAgo, type, title, cost, extra = {}) => {
    records.push({
      id: `fy-mr-${vehicleId}-${seq++}`,
      data: {
        vehicleId,
        userId: COMPANY_ID,
        type,
        title,
        cost,
        date: daysFromNow(-daysAgo),
        createdAt: daysFromNow(-daysAgo),
        mileageAtService:
          vehicle.data.mileage - Math.round((annualKm * daysAgo) / 365),
        shopName: pick(['タカヤモーター株式会社', '西日暮里自動車工業', 'オートサービス竹内']),
        imageUrls: [],
        isSeed: true,
        seedTag: SEED_TAG,
        ...extra,
      },
    });
  };

  for (let m = 0; m < MONTHS; m++) {
    const daysAgo = Math.round(m * 30.4) + between(0, 6);

    if (m % Math.max(1, Math.round(monthsPerOil)) === 0) {
      push(daysAgo, 'oilChange', 'エンジンオイル交換', between(4500, 8000), {
        parts: [
          {
            partNumber: '90915-10003',
            name: 'オイルフィルター',
            manufacturer: '純正',
            unitPrice: 1200,
            quantity: 1,
          },
        ],
        partsCost: 1200,
        laborCost: between(3000, 5000),
        taxAmount: between(400, 800),
        nextReplacementMileage:
          vehicle.data.mileage - Math.round((annualKm * daysAgo) / 365) + 5000,
      });
    }

    // 法定12ヶ月点検（1年に1回）
    if (m === 6) {
      push(daysAgo, 'legalInspection12', '法定12ヶ月点検', between(15000, 28000), {
        inspectionResult: 'passed',
        laborCost: between(12000, 20000),
        taxAmount: between(1200, 2500),
        staffName: pick(['整備 一郎', '点検 次郎']),
      });
    }

    // 車検（貨物は毎年、乗用は2年に1回。ここでは一部の車両に付ける）
    if (m === 11 && (isCargo || vehicleId.endsWith('0'))) {
      push(daysAgo, 'carInspection', '車検（継続検査）', between(85000, 160000), {
        inspectionResult: 'passed',
        certificateUpdated: true,
        safetyStandardsCertificate: `A-${between(10000, 99999)}`,
        partsCost: between(8000, 25000),
        laborCost: between(30000, 55000),
        miscCost: between(35000, 50000), // 重量税・自賠責・印紙
        taxAmount: between(3000, 7000),
      });
    }

    // タイヤ交換（貨物は摩耗が早い）
    if (isCargo && m === 3) {
      push(daysAgo, 'tireChange', 'タイヤ交換（前後）', between(60000, 110000), {
        tireSize: '195/80R15',
        tirePosition: '全輪',
        tireTreadDepth: 8,
        partsCost: between(48000, 90000),
        laborCost: between(8000, 14000),
      });
    }
  }
  return records;
}

/// 営業車のドライブログ（直近3ヶ月）。
function buildDriveLogs(vehicle, index) {
  if (vehicle.isCargo) return [];
  const logs = [];
  for (let d = 0; d < 6; d++) {
    const daysAgo = d * 14 + between(0, 4);
    const distance = between(15, 120);
    const durationSec = distance * between(90, 150);
    logs.push({
      id: `fy-dl-${vehicle.id}-${d}`,
      data: {
        userId: COMPANY_ID,
        vehicleId: vehicle.id,
        status: 'completed',
        title: pick(['得意先訪問', '現場確認', '配送立会い', '営業所間移動']),
        startTime: daysFromNow(-daysAgo),
        endTime: ts(NOW - daysAgo * DAY + durationSec * 1000),
        startAddress: pick(['東京都足立区', '東京都練馬区', '埼玉県川口市']),
        endAddress: pick(['神奈川県横浜市', '千葉県船橋市', '東京都八王子市']),
        statistics: {
          totalDistance: distance,
          totalDuration: durationSec,
          averageSpeed: Math.round((distance / (durationSec / 3600)) * 10) / 10,
          maxSpeed: between(60, 95),
          stopCount: between(2, 12),
          totalStopDuration: between(300, 2400),
        },
        // 業務利用の記録なので既定は非公開。公開の確認は個人ペルソナ側で行う。
        isPublic: false,
        likeCount: 0,
        commentCount: 0,
        tags: ['業務'],
        photoUrls: [],
        createdAt: daysFromNow(-daysAgo),
        updatedAt: daysFromNow(-daysAgo),
        isSeed: true,
        seedTag: SEED_TAG,
      },
    });
  }
  return logs;
}

// ---------------------------------------------------------------------------
// 書き込み
// ---------------------------------------------------------------------------

/// Firestore の一括書き込みは1バッチ500件が上限。超えると丸ごと失敗する。
async function commitInChunks(db, entries, label) {
  const CHUNK = 400;
  for (let i = 0; i < entries.length; i += CHUNK) {
    const batch = db.batch();
    for (const e of entries.slice(i, i + CHUNK)) {
      batch.set(db.collection(e.col).doc(e.id), e.data, { merge: true });
    }
    await batch.commit();
    console.log(`  ${label}: ${Math.min(i + CHUNK, entries.length)}/${entries.length}`);
  }
}

async function main() {
  admin.initializeApp({ projectId: 'trust-car-platform' });
  const db = admin.firestore();

  if (DELETE) {
    await deleteSeed(db);
    return;
  }

  const vehicles = buildVehicles();
  const entries = [];

  entries.push({
    col: 'users',
    id: COMPANY_ID,
    data: {
      email: OWNER_EMAIL,
      displayName: '山田 太郎（フリート管理者）',
      accountType: 'business',
      companyName: '株式会社トラストロジスティクス',
      planType: 'premium',
      prefecture: '東京都',
      city: '足立区',
      createdAt: daysFromNow(-400),
      updatedAt: daysFromNow(0),
      isSeed: true,
      seedTag: SEED_TAG,
    },
  });

  DRIVERS.forEach((name, i) => {
    entries.push({
      col: 'users',
      id: `fy-driver-${i}`,
      data: {
        email: `fleet.driver${i}@trustcar-test.example`,
        displayName: name,
        accountType: 'personal',
        planType: 'free',
        createdAt: daysFromNow(-380),
        updatedAt: daysFromNow(0),
        isSeed: true,
        seedTag: SEED_TAG,
      },
    });
    entries.push({
      col: 'fleet_members',
      id: `${COMPANY_ID}_fy-driver-${i}`,
      data: {
        companyId: COMPANY_ID,
        userId: `fy-driver-${i}`,
        displayName: name,
        role: 'viewer',
        joinedAt: new Date(NOW - 380 * DAY).toISOString(),
        isSeed: true,
        seedTag: SEED_TAG,
      },
    });
  });

  entries.push({
    col: 'fleet_members',
    id: `${COMPANY_ID}_${COMPANY_ID}`,
    data: {
      companyId: COMPANY_ID,
      userId: COMPANY_ID,
      displayName: '山田 太郎',
      role: 'owner',
      joinedAt: new Date(NOW - 400 * DAY).toISOString(),
      isSeed: true,
      seedTag: SEED_TAG,
    },
  });

  let recordCount = 0;
  let logCount = 0;
  vehicles.forEach((v, i) => {
    entries.push({ col: 'vehicles', id: v.id, data: v.data });
    for (const r of buildMaintenanceRecords(v)) {
      entries.push({ col: 'maintenance_records', id: r.id, data: r.data });
      recordCount++;
    }
    for (const l of buildDriveLogs(v, i)) {
      entries.push({ col: 'drive_logs', id: l.id, data: l.data });
      logCount++;
    }
  });

  const cargo = vehicles.filter((v) => v.isCargo).length;
  console.log('--- 作成予定 ---');
  console.log(`  会社           : 株式会社トラストロジスティクス`);
  console.log(`  車両           : ${vehicles.length}台（貨物 ${cargo} / 乗用 ${vehicles.length - cargo}）`);
  console.log(`  整備記録       : ${recordCount}件（${MONTHS}ヶ月分）`);
  console.log(`  ドライブログ   : ${logCount}件`);
  console.log(`  ユーザー       : ${1 + DRIVERS.length}件`);
  console.log(`  合計ドキュメント: ${entries.length}件`);

  if (DRY_RUN) {
    console.log('\n--dry-run のため書き込んでいません。');
    return;
  }

  await commitInChunks(db, entries, '書き込み');
  console.log('\n完了しました。');
  console.log(`法人アカウント: ${OWNER_EMAIL}`);
  console.log('※ Auth ユーザーは作成していません。ログインが必要な場合は');
  console.log('  Firebase コンソールで上記メールのユーザーを作成し、uid を');
  console.log(`  "${COMPANY_ID}" に合わせるか、seed_personas.js をご利用ください。`);
  console.log('\n後片付け: node scripts/seed_fleet_year.js --delete');
}

async function deleteSeed(db) {
  const cols = ['vehicles', 'maintenance_records', 'drive_logs', 'fleet_members', 'users'];
  for (const col of cols) {
    let total = 0;
    // seedTag で引く。全件走査は台数が増えると重いので、必ず where で絞る。
    for (;;) {
      const snap = await db
        .collection(col)
        .where('seedTag', '==', SEED_TAG)
        .limit(400)
        .get();
      if (snap.empty) break;
      if (!DRY_RUN) {
        const batch = db.batch();
        snap.docs.forEach((d) => batch.delete(d.ref));
        await batch.commit();
      }
      total += snap.size;
      if (DRY_RUN) break;
    }
    console.log(`削除 ${col}: ${total}件`);
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
