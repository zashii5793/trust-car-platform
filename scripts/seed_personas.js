#!/usr/bin/env node
/**
 * Persona Seed Data — Web テスト用ペルソナ投入スクリプト (Node.js)
 *
 * 企画書「信頼を設計する」のターゲットユーザーに沿った 4 ペルソナを
 * Firebase Auth + Firestore に投入する。Web 画面の動作確認（ログイン →
 * マイカー → 履歴 → AI 提案 → 工場/パーツ）を実データで体験できるようにする。
 *
 * 投入されるペルソナ:
 *   1. 佐藤 健太   — 30-50代ファミリー・共働き（メインターゲット / Premium）
 *                    トヨタ RAV4。点検・整備履歴あり。車検が近い。
 *   2. 鈴木 大輔   — クルマ好き層（サブターゲット / Free）
 *                    スバル WRX S4。カスタム志向。
 *   3. 田中 美咲   — 若年層・初めての車購入（サブターゲット / Free）
 *                    ホンダ N-BOX（軽）。履歴これから。
 *   4. 山田 物流   — 法人・フリート（business アカウント / Premium）
 *                    トヨタ ハイエース ×2。社用車管理。
 *
 * Usage:
 *   node scripts/seed_personas.js [--dry-run] [--emulator] [--clean]
 *
 * Options:
 *   --dry-run   Firestore/Auth に書かず、投入予定データを表示する
 *   --emulator  Firebase Emulator (Auth:9099 / Firestore:8080) に接続する
 *   --clean     既存のペルソナ（uid が 'persona_' で始まる）を削除してから投入
 *
 * Requirements:
 *   npm install firebase-admin   (scripts/ ディレクトリで実行)
 *
 * 例（Emulator で確認）:
 *   firebase emulators:start --only auth,firestore
 *   node scripts/seed_personas.js --emulator
 *
 * 例（本番）:  ※要確認・本番反映
 *   export GOOGLE_APPLICATION_CREDENTIALS=path/to/serviceAccount.json
 *   node scripts/seed_personas.js --clean
 *
 * ログイン情報（全ペルソナ共通パスワード）:
 *   Email    : 各ペルソナの email を参照
 *   Password : TrustCar!2026
 *
 * 注意:
 *   - これらは **テスト専用の架空ユーザー** であり実在しない。本番公開前に
 *     --clean で削除すること。
 *   - 車両画像は Unsplash の公開画像（CORS 対応のため Flutter Web の
 *     Image.network で表示可能）。デモ用途であり、実車そのものではない。
 */

const isDryRun = process.argv.includes('--dry-run');
const useEmulator = process.argv.includes('--emulator');
const doClean = process.argv.includes('--clean');

const COMMON_PASSWORD = 'TrustCar!2026';

if (useEmulator) {
  process.env.FIRESTORE_EMULATOR_HOST = 'localhost:8080';
  process.env.FIREBASE_AUTH_EMULATOR_HOST = 'localhost:9099';
}

const admin = (() => {
  try { return require('firebase-admin'); }
  catch {
    console.error('[ERROR] firebase-admin が見つかりません。');
    console.error('        scripts/ で npm install firebase-admin を実行してください。');
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
const auth = admin.auth();
const { Timestamp } = admin.firestore;

// ---------------------------------------------------------------------------
// 日付ヘルパー（基準日からの相対指定で履歴を作る）
// ---------------------------------------------------------------------------
const now = new Date();
function daysFromNow(d) { return new Date(now.getTime() + d * 24 * 60 * 60 * 1000); }
function ts(date) { return Timestamp.fromDate(date); }

// 車両画像（Unsplash・CORS対応・Flutter Web で表示可能なデモ画像）
const CAR_IMG = {
  suvWhite: 'https://images.unsplash.com/photo-1568605117036-5fe5e7bab0b7?auto=format&fit=crop&w=900&q=80',
  sportSedan: 'https://images.unsplash.com/photo-1503376780353-7e6692767b70?auto=format&fit=crop&w=900&q=80',
  compact: 'https://images.unsplash.com/photo-1449965408869-eaa3f722e40d?auto=format&fit=crop&w=900&q=80',
  van: 'https://images.unsplash.com/photo-1559416523-140ddc3d238c?auto=format&fit=crop&w=900&q=80',
};

// ---------------------------------------------------------------------------
// 共通ファクトリ
// ---------------------------------------------------------------------------
function userDoc({ email, displayName, planType, accountType, companyName, photoUrl }) {
  const doc = {
    email,
    displayName,
    photoUrl: photoUrl ?? null,
    notificationSettings: {
      pushEnabled: true,
      inspectionReminder: true,
      maintenanceReminder: true,
      oilChangeReminder: true,
      tireChangeReminder: true,
      carInspectionReminder: true,
    },
    planType,                    // 'free' | 'premium'
    accountType,                 // 'personal' | 'business'
    createdAt: ts(daysFromNow(-400)),
    updatedAt: ts(now),
  };
  if (companyName) doc.companyName = companyName;
  return doc;
}

function vehicleDoc(uid, v) {
  return {
    userId: uid,
    maker: v.maker,
    model: v.model,
    year: v.year,
    grade: v.grade ?? '',
    mileage: v.mileage,
    mileageUpdatedAt: ts(daysFromNow(-7)),
    imageUrl: v.imageUrl ?? null,
    createdAt: ts(daysFromNow(-365)),
    updatedAt: ts(now),
    licensePlate: v.licensePlate ?? null,
    vinNumber: null,
    modelCode: v.modelCode ?? null,
    inspectionExpiryDate: v.inspectionExpiryDate ? ts(v.inspectionExpiryDate) : null,
    insuranceExpiryDate: v.insuranceExpiryDate ? ts(v.insuranceExpiryDate) : null,
    color: v.color ?? null,
    engineDisplacement: v.engineDisplacement ?? null,
    fuelType: v.fuelType ?? null,        // 'gasoline' | 'hybrid' | ...
    purchaseDate: v.purchaseDate ? ts(v.purchaseDate) : null,
    firstRegistrationDate: v.firstRegistrationDate ? ts(v.firstRegistrationDate) : null,
    driveType: v.driveType ?? null,
    transmissionType: v.transmissionType ?? null,
    vehicleWeight: v.vehicleWeight ?? null,
    seatingCapacity: v.seatingCapacity ?? null,
    voluntaryInsurance: null,
    leaseInfo: null,
    companyId: v.companyId ?? null,
    assigneeId: null,
    assigneeName: v.assigneeName ?? null,
    useCategory: v.useCategory ?? 'privatePassenger',
    status: 'active',
    retiredAt: null,
    retirementNote: null,
    isDataRetained: true,
  };
}

function maintenanceDoc(uid, vehicleId, m) {
  return {
    vehicleId,
    userId: uid,
    type: m.type,                // MaintenanceType.name（例: 'oilChange'）
    title: m.title,
    description: m.description ?? '',
    cost: m.cost ?? 0,
    shopName: m.shopName ?? null,
    date: ts(m.date),
    mileageAtService: m.mileageAtService ?? null,
    imageUrls: [],
    createdAt: ts(m.date),
    partNumber: null,
    partManufacturer: null,
    nextReplacementMileage: m.nextReplacementMileage ?? null,
    nextReplacementDate: m.nextReplacementDate ? ts(m.nextReplacementDate) : null,
    staffId: null,
    staffName: null,
    inspectionResult: m.inspectionResult ?? null,
    certificateUpdated: false,
    safetyStandardsCertificate: null,
    workItems: [],
    parts: [],
    partsCost: null,
    laborCost: null,
    miscCost: null,
    taxAmount: null,
    discountAmount: null,
  };
}

// ---------------------------------------------------------------------------
// ペルソナ定義
// ---------------------------------------------------------------------------
const personas = [
  {
    uid: 'persona_family_sato',
    user: userDoc({
      email: 'family.sato@trustcar.demo',
      displayName: '佐藤 健太',
      planType: 'premium',
      accountType: 'personal',
    }),
    vehicles: [
      {
        id: 'persona_family_sato_rav4',
        spec: {
          maker: 'トヨタ', model: 'RAV4', year: 2021, grade: 'Adventure',
          mileage: 38500, color: 'アーバンカーキ', engineDisplacement: 2000,
          fuelType: 'gasoline', driveType: 'fourWd', transmissionType: 'cvt',
          seatingCapacity: 5, modelCode: '6BA-MXAA54', licensePlate: '岡山 300 あ 12-34',
          imageUrl: CAR_IMG.suvWhite,
          purchaseDate: daysFromNow(-1100),
          firstRegistrationDate: daysFromNow(-1100),
          inspectionExpiryDate: daysFromNow(38),   // 車検まもなく → AI 提案が出る
          insuranceExpiryDate: daysFromNow(120),
        },
        maintenance: [
          { type: 'carInspection', title: '12ヶ月法定点検', shopName: 'タカヤモーター株式会社',
            cost: 25000, date: daysFromNow(-210), mileageAtService: 31000,
            inspectionResult: 'passed', description: '異常なし。ブレーキパッド残量は次回要確認。' },
          { type: 'oilChange', title: 'エンジンオイル・エレメント交換', shopName: 'タカヤモーター株式会社',
            cost: 6600, date: daysFromNow(-95), mileageAtService: 35200,
            nextReplacementMileage: 40200, nextReplacementDate: daysFromNow(85),
            description: '0W-20 化学合成油。次回は約5,000km後が目安。' },
          { type: 'tireRotation', title: 'タイヤローテーション', shopName: 'タカヤモーター株式会社',
            cost: 3300, date: daysFromNow(-95), mileageAtService: 35200 },
        ],
      },
    ],
  },
  {
    uid: 'persona_enthusiast_suzuki',
    user: userDoc({
      email: 'enthusiast.suzuki@trustcar.demo',
      displayName: '鈴木 大輔',
      planType: 'free',
      accountType: 'personal',
    }),
    vehicles: [
      {
        id: 'persona_enthusiast_suzuki_wrx',
        spec: {
          maker: 'スバル', model: 'WRX S4', year: 2022, grade: 'STI Sport R EX',
          mileage: 21000, color: 'WRブルー・パール', engineDisplacement: 2400,
          fuelType: 'gasoline', driveType: 'fourWd', transmissionType: 'at',
          seatingCapacity: 5, modelCode: '4BA-VBH', licensePlate: '岡山 330 す 5-67',
          imageUrl: CAR_IMG.sportSedan,
          purchaseDate: daysFromNow(-700),
          firstRegistrationDate: daysFromNow(-700),
          inspectionExpiryDate: daysFromNow(400),
          insuranceExpiryDate: daysFromNow(210),
        },
        maintenance: [
          { type: 'oilChange', title: 'エンジンオイル交換（サーキット後）', shopName: '自宅DIY',
            cost: 9000, date: daysFromNow(-30), mileageAtService: 20500,
            description: '5W-40。走行会後のため早めに交換。' },
          { type: 'brakePadChange', title: 'ブレーキパッド前後交換', shopName: 'プロショップ青空',
            cost: 48000, date: daysFromNow(-150), mileageAtService: 17000,
            description: 'ストリート＋ライトサーキット用パッドに変更。' },
        ],
      },
    ],
  },
  {
    uid: 'persona_firsttime_tanaka',
    user: userDoc({
      email: 'firsttime.tanaka@trustcar.demo',
      displayName: '田中 美咲',
      planType: 'free',
      accountType: 'personal',
    }),
    vehicles: [
      {
        id: 'persona_firsttime_tanaka_nbox',
        spec: {
          maker: 'ホンダ', model: 'N-BOX', year: 2023, grade: 'Custom L',
          mileage: 6800, color: 'プレミアムサンライトホワイト・パール', engineDisplacement: 660,
          fuelType: 'gasoline', driveType: 'ff', transmissionType: 'cvt',
          seatingCapacity: 4, modelCode: '6BA-JF5', licensePlate: '岡山 580 み 8-90',
          imageUrl: CAR_IMG.compact,
          purchaseDate: daysFromNow(-200),
          firstRegistrationDate: daysFromNow(-200),
          inspectionExpiryDate: daysFromNow(900),  // 新車初回車検まで3年
          insuranceExpiryDate: daysFromNow(165),
        },
        maintenance: [
          { type: 'oilChange', title: '初回エンジンオイル交換', shopName: 'ホンダカーズ岡山',
            cost: 4400, date: daysFromNow(-20), mileageAtService: 6000,
            nextReplacementMileage: 12000, nextReplacementDate: daysFromNow(160),
            description: '新車1ヶ月点検時に交換。次回は半年または6,000kmが目安。' },
        ],
      },
    ],
  },
  {
    uid: 'persona_fleet_yamada',
    user: userDoc({
      email: 'fleet.yamada@trustcar.demo',
      displayName: '山田 太郎（山田物流）',
      planType: 'premium',
      accountType: 'business',
      companyName: '山田物流株式会社',
    }),
    vehicles: [
      {
        id: 'persona_fleet_yamada_hiace1',
        spec: {
          maker: 'トヨタ', model: 'ハイエースバン', year: 2020, grade: 'スーパーGL',
          mileage: 98000, color: 'ホワイト', engineDisplacement: 2800,
          fuelType: 'diesel', driveType: 'fr', transmissionType: 'at',
          seatingCapacity: 5, modelCode: '3DF-GDH201V', licensePlate: '岡山 100 か 1-01',
          imageUrl: CAR_IMG.van,
          companyId: 'persona_fleet_yamada', assigneeName: '配送1号車',
          useCategory: 'cargo',                       // 貨物＝毎年車検
          purchaseDate: daysFromNow(-1400),
          firstRegistrationDate: daysFromNow(-1400),
          inspectionExpiryDate: daysFromNow(25),       // 直近で車検 → 法人ダッシュボードで警告
          insuranceExpiryDate: daysFromNow(80),
        },
        maintenance: [
          { type: 'carInspection', title: '継続車検（貨物・毎年）', shopName: 'タカヤモーター株式会社',
            cost: 92000, date: daysFromNow(-340), mileageAtService: 84000,
            inspectionResult: 'passed', description: '貨物車のため毎年車検。下回り防錆施工済み。' },
          { type: 'oilChange', title: 'ディーゼルオイル・フィルター交換', shopName: 'タカヤモーター株式会社',
            cost: 12000, date: daysFromNow(-40), mileageAtService: 95000,
            nextReplacementMileage: 105000 },
        ],
      },
      {
        id: 'persona_fleet_yamada_hiace2',
        spec: {
          maker: 'トヨタ', model: 'ハイエースバン', year: 2022, grade: 'DX',
          mileage: 42000, color: 'シルバー', engineDisplacement: 2800,
          fuelType: 'diesel', driveType: 'fr', transmissionType: 'at',
          seatingCapacity: 3, modelCode: '3DF-GDH201V', licensePlate: '岡山 100 か 1-02',
          imageUrl: CAR_IMG.van,
          companyId: 'persona_fleet_yamada', assigneeName: '配送2号車',
          useCategory: 'cargo',
          purchaseDate: daysFromNow(-650),
          firstRegistrationDate: daysFromNow(-650),
          inspectionExpiryDate: daysFromNow(310),
          insuranceExpiryDate: daysFromNow(200),
        },
        maintenance: [
          { type: 'tireChange', title: 'スタッドレスタイヤ交換', shopName: '自社整備',
            cost: 0, date: daysFromNow(-60), mileageAtService: 40000 },
        ],
      },
    ],
  },
];

// ---------------------------------------------------------------------------
// 投入処理
// ---------------------------------------------------------------------------
async function ensureAuthUser(p) {
  const props = {
    uid: p.uid,
    email: p.user.email,
    emailVerified: true,
    password: COMMON_PASSWORD,
    displayName: p.user.displayName,
  };
  try {
    await auth.getUser(p.uid);
    await auth.updateUser(p.uid, {
      email: props.email, password: COMMON_PASSWORD, displayName: props.displayName,
    });
    return 'updated';
  } catch (e) {
    if (e.code === 'auth/user-not-found') {
      await auth.createUser(props);
      return 'created';
    }
    throw e;
  }
}

async function cleanPersonas() {
  for (const p of personas) {
    // Auth
    try { await auth.deleteUser(p.uid); } catch (_) { /* ignore */ }
    // vehicles + maintenance
    for (const v of p.vehicles) {
      const mSnap = await db.collection('maintenance_records').where('vehicleId', '==', v.id).get();
      for (const d of mSnap.docs) await d.ref.delete();
      await db.collection('vehicles').doc(v.id).delete().catch(() => {});
    }
    await db.collection('users').doc(p.uid).delete().catch(() => {});
    console.log(`  🧹 cleaned ${p.uid}`);
  }
}

async function main() {
  console.log('='.repeat(70));
  console.log(`Persona Seed — ${isDryRun ? 'DRY RUN' : 'WRITE'}${useEmulator ? ' (emulator)' : ''}`);
  console.log('='.repeat(70));

  if (doClean && !isDryRun) {
    console.log('\n[clean] 既存ペルソナを削除します...');
    await cleanPersonas();
  }

  let mCount = 0, vCount = 0;
  for (const p of personas) {
    console.log(`\n👤 ${p.user.displayName}  <${p.user.email}>  [${p.user.planType}/${p.user.accountType}]`);

    if (isDryRun) {
      console.log(`   users/${p.uid}`);
    } else {
      const authResult = await ensureAuthUser(p);
      await db.collection('users').doc(p.uid).set(p.user, { merge: true });
      console.log(`   ✅ auth ${authResult} / users/${p.uid} 保存`);
    }

    for (const v of p.vehicles) {
      const doc = vehicleDoc(p.uid, v.spec);
      vCount++;
      if (isDryRun) {
        console.log(`   🚗 vehicles/${v.id}  ${v.spec.maker} ${v.spec.model} (${v.spec.year})  img:${v.spec.imageUrl ? 'あり' : 'なし'}`);
      } else {
        await db.collection('vehicles').doc(v.id).set(doc, { merge: true });
        console.log(`   🚗 vehicles/${v.id}  ${v.spec.maker} ${v.spec.model} 保存`);
      }
      (v.maintenance || []).forEach((m, i) => {
        const mid = `${v.id}_m${i + 1}`;
        const mdoc = maintenanceDoc(p.uid, v.id, m);
        mCount++;
        if (isDryRun) {
          console.log(`      🔧 maintenance_records/${mid}  ${m.title}`);
        } else {
          db.collection('maintenance_records').doc(mid).set(mdoc, { merge: true });
        }
      });
    }
  }

  console.log('\n' + '-'.repeat(70));
  console.log(`完了: ${personas.length} ペルソナ / ${vCount} 車両 / ${mCount} 整備記録`);
  if (!isDryRun) {
    console.log(`\nログイン用パスワード（全員共通）: ${COMMON_PASSWORD}`);
    console.log('Email 例: family.sato@trustcar.demo / enthusiast.suzuki@trustcar.demo');
    console.log('          firsttime.tanaka@trustcar.demo / fleet.yamada@trustcar.demo');
  }
  console.log('-'.repeat(70));
}

main()
  .then(() => process.exit(0))
  .catch((e) => { console.error('[FATAL]', e); process.exit(1); });
