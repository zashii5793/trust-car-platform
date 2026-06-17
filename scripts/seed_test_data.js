#!/usr/bin/env node
/**
 * Test Data Seed — ローカル画面操作テスト用シード (Node.js)
 *
 * ログイン用テストユーザー + 車両 + 整備記録を Firebase Emulator に投入し、
 * 一覧・詳細・検索・車検リマインダー等の画面を「空っぽでない」状態で
 * 手動テストできるようにする。
 *
 * Usage:
 *   # 1) エミュレーター起動（別ターミナル）
 *   firebase emulators:start --only auth,firestore
 *
 *   # 2) 依存インストール（初回のみ / scripts ディレクトリで）
 *   npm install firebase-admin
 *
 *   # 3) 投入
 *   node scripts/seed_test_data.js              # 投入実行（既定でエミュレーター接続）
 *   node scripts/seed_test_data.js --dry-run    # 書き込まず内容だけ表示
 *   node scripts/seed_test_data.js --reset      # 既存のテストユーザーの車両/整備を削除してから投入
 *
 * Options:
 *   --dry-run   Firestore/Auth に書かず、投入予定の内容を表示する
 *   --reset     既存テストユーザーの vehicles / maintenance_records を削除してから投入
 *   --email     ログインに使うメール（既定: test@example.com）
 *   --password  パスワード（既定: test1234）
 *
 * Notes:
 *   - 既定で Emulator(localhost) に接続する。本番には接続しない安全設計。
 *   - 投入データは架空のサンプル。実在の車両・人物ではない。
 *   - 車検満了日は「期限間近の車両」を1台含め、リマインダー画面の確認に使える。
 */

'use strict';

// ---------------------------------------------------------------------------
// 引数パース
// ---------------------------------------------------------------------------
const argv = process.argv.slice(2);
const isDryRun = argv.includes('--dry-run');
const doReset = argv.includes('--reset');
const getOpt = (name, fallback) => {
  const i = argv.indexOf(name);
  return i >= 0 && argv[i + 1] ? argv[i + 1] : fallback;
};
const EMAIL = getOpt('--email', 'test@example.com');
const PASSWORD = getOpt('--password', 'test1234');

// ---------------------------------------------------------------------------
// Emulator 接続設定（安全のため常にエミュレーターへ接続）
// ---------------------------------------------------------------------------
const AUTH_HOST = process.env.FIREBASE_AUTH_EMULATOR_HOST || 'localhost:9099';
const FS_HOST = process.env.FIRESTORE_EMULATOR_HOST || 'localhost:8080';
process.env.FIREBASE_AUTH_EMULATOR_HOST = AUTH_HOST;
process.env.FIRESTORE_EMULATOR_HOST = FS_HOST;

const PROJECT_ID = 'trust-car-platform';

const admin = (() => {
  try {
    return require('firebase-admin');
  } catch {
    console.error('[ERROR] firebase-admin が見つかりません。');
    console.error('        scripts ディレクトリで `npm install firebase-admin` を実行してください。');
    process.exit(1);
  }
})();

if (!admin.apps.length) {
  admin.initializeApp({ projectId: PROJECT_ID });
}
const db = admin.firestore();
const auth = admin.auth();
const { Timestamp } = admin.firestore;

// ---------------------------------------------------------------------------
// 日付ヘルパー
// ---------------------------------------------------------------------------
const now = new Date();
const daysFromNow = (d) => {
  const t = new Date(now);
  t.setDate(t.getDate() + d);
  return Timestamp.fromDate(t);
};
const TS_NOW = Timestamp.fromDate(now);

// ---------------------------------------------------------------------------
// 車両シード（userId は実行時に解決した UID を差し込む）
// ---------------------------------------------------------------------------
function buildVehicleSeeds(userId) {
  return [
    {
      _key: 'corolla',
      userId,
      maker: 'トヨタ',
      model: 'カローラ',
      year: 2020,
      grade: 'G',
      mileage: 45000,
      mileageUpdatedAt: TS_NOW,
      licensePlate: '品川 300 あ 12-34',
      modelCode: '6AA-ZWE211',
      inspectionExpiryDate: daysFromNow(120), // 余裕あり
      insuranceExpiryDate: daysFromNow(120),
      color: 'ホワイトパール',
      engineDisplacement: 1800,
      fuelType: 'hybrid',
      purchaseDate: daysFromNow(-1500),
      firstRegistrationDate: daysFromNow(-1500),
      driveType: 'ff',
      transmissionType: 'cvt',
      vehicleWeight: 1370,
      seatingCapacity: 5,
      useCategory: 'privatePassenger',
      status: 'active',
      isDataRetained: true,
      createdAt: TS_NOW,
      updatedAt: TS_NOW,
    },
    {
      _key: 'nbox',
      userId,
      maker: 'ホンダ',
      model: 'N-BOX',
      year: 2022,
      grade: 'カスタムL',
      mileage: 18000,
      mileageUpdatedAt: TS_NOW,
      licensePlate: '練馬 580 さ 56-78',
      modelCode: '6BA-JF3',
      inspectionExpiryDate: daysFromNow(25), // ★期限間近：リマインダー確認用
      insuranceExpiryDate: daysFromNow(25),
      color: 'ブラック',
      engineDisplacement: 660,
      fuelType: 'gasoline',
      purchaseDate: daysFromNow(-700),
      firstRegistrationDate: daysFromNow(-700),
      driveType: 'ff',
      transmissionType: 'cvt',
      vehicleWeight: 920,
      seatingCapacity: 4,
      useCategory: 'privatePassenger',
      status: 'active',
      isDataRetained: true,
      createdAt: TS_NOW,
      updatedAt: TS_NOW,
    },
    {
      _key: 'hiace',
      userId,
      maker: 'トヨタ',
      model: 'ハイエースバン',
      year: 2019,
      grade: 'スーパーGL',
      mileage: 98000,
      mileageUpdatedAt: TS_NOW,
      licensePlate: '足立 400 か 90-12',
      modelCode: 'CBF-TRH200V',
      inspectionExpiryDate: daysFromNow(300),
      insuranceExpiryDate: daysFromNow(300),
      color: 'シルバー',
      engineDisplacement: 2000,
      fuelType: 'gasoline',
      purchaseDate: daysFromNow(-2200),
      firstRegistrationDate: daysFromNow(-2200),
      driveType: 'fr',
      transmissionType: 'at',
      vehicleWeight: 1900,
      seatingCapacity: 3,
      useCategory: 'cargo', // 貨物車 → 毎年車検
      status: 'active',
      isDataRetained: true,
      createdAt: TS_NOW,
      updatedAt: TS_NOW,
    },
  ];
}

// ---------------------------------------------------------------------------
// 整備記録シード（vehicleId は投入後の doc.id を差し込む）
// ---------------------------------------------------------------------------
function buildMaintenanceSeeds(vehicleId, userId, vehicleKey) {
  const base = {
    vehicleId,
    userId,
    imageUrls: [],
    workItems: [],
    parts: [],
    certificateUpdated: false,
    createdAt: TS_NOW,
  };
  const common = [
    {
      ...base,
      type: 'oilChange',
      title: 'エンジンオイル交換',
      description: '0W-20 化学合成油、オイルフィルター同時交換',
      cost: 6800,
      shopName: 'オートバックス 環七店',
      date: daysFromNow(-90),
      mileageAtService: 40000,
      nextReplacementMileage: 45000,
    },
    {
      ...base,
      type: 'tireRotation',
      title: 'タイヤローテーション',
      cost: 2200,
      shopName: 'タイヤ館',
      date: daysFromNow(-60),
      mileageAtService: 42000,
      tireSize: '195/65R15',
      tirePosition: '全輪',
      tireTreadDepth: 6,
    },
    {
      ...base,
      type: 'carInspection',
      title: '車検（24ヶ月点検）',
      description: '法定24ヶ月点検＋継続検査',
      cost: 98000,
      shopName: 'トヨタカローラ店',
      date: daysFromNow(-30),
      mileageAtService: 44000,
      inspectionResult: 'passed',
      certificateUpdated: true,
      partsCost: 18000,
      laborCost: 35000,
      miscCost: 45000,
    },
  ];
  // 車両ごとに少し変化を付ける
  if (vehicleKey === 'hiace') {
    common.push({
      ...base,
      type: 'brakePadChange',
      title: 'ブレーキパッド交換（フロント）',
      cost: 14500,
      shopName: '整備工場タカヤ',
      date: daysFromNow(-15),
      mileageAtService: 97000,
    });
  }
  return common;
}

// ---------------------------------------------------------------------------
// メイン
// ---------------------------------------------------------------------------
async function ensureUser() {
  let user;
  try {
    user = await auth.getUserByEmail(EMAIL);
    console.log(`[auth] 既存ユーザーを使用: ${EMAIL} (uid=${user.uid})`);
  } catch {
    if (isDryRun) {
      console.log(`[auth][dry-run] ユーザー作成予定: ${EMAIL} / ${PASSWORD}`);
      return { uid: 'DRYRUN_UID' };
    }
    user = await auth.createUser({ email: EMAIL, password: PASSWORD, emailVerified: true });
    console.log(`[auth] ユーザー作成: ${EMAIL} (uid=${user.uid})`);
  }
  return user;
}

async function resetUserData(userId) {
  const cols = ['vehicles', 'maintenance_records'];
  for (const col of cols) {
    const snap = await db.collection(col).where('userId', '==', userId).get();
    if (snap.empty) continue;
    const batch = db.batch();
    snap.docs.forEach((d) => batch.delete(d.ref));
    await batch.commit();
    console.log(`[reset] ${col}: ${snap.size} 件削除`);
  }
}

async function main() {
  console.log('==============================================');
  console.log(' Test Data Seed');
  console.log(`   Auth Emulator     : ${AUTH_HOST}`);
  console.log(`   Firestore Emulator: ${FS_HOST}`);
  console.log(`   Login             : ${EMAIL} / ${PASSWORD}`);
  console.log(`   Mode              : ${isDryRun ? 'DRY-RUN' : 'WRITE'}${doReset ? ' +RESET' : ''}`);
  console.log('==============================================');

  const user = await ensureUser();
  const userId = user.uid;

  if (doReset && !isDryRun) {
    await resetUserData(userId);
  }

  const vehicles = buildVehicleSeeds(userId);
  let vehicleCount = 0;
  let maintenanceCount = 0;

  for (const v of vehicles) {
    const { _key, ...vehicleData } = v;
    if (isDryRun) {
      console.log(`\n[dry-run] vehicle: ${v.maker} ${v.model} (${v.licensePlate})`);
    } else {
      const ref = await db.collection('vehicles').add(vehicleData);
      // id フィールドにも doc.id を保持（アプリの fromFirestore 互換のため任意）
      await ref.update({ id: ref.id });
      vehicleCount++;
      const records = buildMaintenanceSeeds(ref.id, userId, _key);
      for (const r of records) {
        const mref = await db.collection('maintenance_records').add(r);
        await mref.update({ id: mref.id });
        maintenanceCount++;
      }
      console.log(`[write] vehicle: ${v.maker} ${v.model}  +整備${records.length}件`);
    }
  }

  console.log('\n----------------------------------------------');
  if (isDryRun) {
    console.log(`[dry-run] 投入予定: 車両 ${vehicles.length} 台 / 整備記録 複数`);
  } else {
    console.log(`完了: 車両 ${vehicleCount} 台 / 整備記録 ${maintenanceCount} 件を投入`);
    console.log(`ログイン: ${EMAIL} / ${PASSWORD}`);
  }
  console.log('----------------------------------------------');
}

main()
  .then(() => process.exit(0))
  .catch((e) => {
    console.error('[ERROR]', e);
    process.exit(1);
  });
