#!/usr/bin/env node
/**
 * Persona Seed Data — Firestore/Auth 登録スクリプト (Node.js)
 *
 * docs/PERSONA_SCENARIO_GUIDE.md と test/integration/persona_scenarios_test.dart
 * で定義済みのペルソナ A〜I を、実際に「動く」シードデータとして
 * Firebase Emulator に投入する。これまでペルソナはドキュメントとテスト内の
 * インメモリデータにしか存在せず、アプリ/エミュレータで体験できなかった。
 *
 * Usage:
 *   node scripts/seed_personas.js [--dry-run] [--emulator]
 *
 * Options:
 *   --dry-run    Firestore/Auth に書かず、登録予定データを標準出力に表示する
 *   --emulator   Firebase Emulator (Firestore localhost:8080 / Auth localhost:9099)
 *   --with-auth  本番でも Auth ユーザーを作成する（Web版でログインする場合に必要。
 *                パスワードは password123 のため、確認後は必ず削除すること）
 *                に接続する
 *
 * Requirements:
 *   cd scripts && npm install   # firebase-admin
 *
 * Example (エミュレータで体験):
 *   firebase emulators:start --only firestore,auth
 *   node scripts/seed_personas.js --dry-run
 *   node scripts/seed_personas.js --emulator
 *   # → 各ペルソナのメール（下記）＋ 共通パスワード DEMO_PASSWORD でログイン
 *
 * SAFETY:
 *   本スクリプトはエミュレータでの動作確認を主目的とする。--emulator 無しで
 *   実行すると Application Default Credentials で **本番** に書き込む。
 *   CLAUDE.md の禁止事項（Firebase 直接操作は要明示許可）に該当するため、
 *   本番投入は人間の明示的な許可を得てから行うこと。
 *
 * NOTE:
 *   すべて固定ドキュメントID + set(..., { merge: true }) で冪等。再実行しても
 *   重複しない。コレクションは users / vehicles / maintenance_records /
 *   shops / fleet_members / inquiries。トレンド(community_maintenance_trends)・
 *   安全情報(safety_tips) は既存の seed_community_trends.js / seed_safety_tips.js
 *   に委ね、本スクリプトでは投入しない。
 */

const isDryRun = process.argv.includes('--dry-run');
const useEmulator = process.argv.includes('--emulator');

// Emulator 接続設定（--emulator フラグ時）。admin require より前に設定する。
if (useEmulator) {
  process.env.FIRESTORE_EMULATOR_HOST =
    process.env.FIRESTORE_EMULATOR_HOST || 'localhost:8080';
  process.env.FIREBASE_AUTH_EMULATOR_HOST =
    process.env.FIREBASE_AUTH_EMULATOR_HOST || 'localhost:9099';
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

// ---------------------------------------------------------------------------
// Firebase 初期化
// ---------------------------------------------------------------------------
if (!admin.apps.length) {
  if (useEmulator) {
    admin.initializeApp({ projectId: 'trust-car-platform' });
  } else {
    admin.initializeApp({
      credential: admin.credential.applicationDefault(),
    });
  }
}

const db = admin.firestore();
// ネストで一部フィールドを省略するため、undefined を無視して null 扱いにしない。
db.settings({ ignoreUndefinedProperties: true });
const { Timestamp, GeoPoint } = admin.firestore;

// ---------------------------------------------------------------------------
// 共通ヘルパ
// ---------------------------------------------------------------------------
const DAY = 24 * 60 * 60 * 1000;
const now = Timestamp.now();
const nowMs = Date.now();

/** 現在から days 日後(負なら過去)の Timestamp */
const tsFromNow = (days) => Timestamp.fromDate(new Date(nowMs + days * DAY));
/** ISO文字列の Timestamp */
const tsDate = (iso) => Timestamp.fromDate(new Date(iso));
/** base(ISO)から days 日後の Timestamp */
const tsPlus = (iso, days) =>
  Timestamp.fromDate(new Date(new Date(iso).getTime() + days * DAY));

const DEMO_PASSWORD = 'password123';

/** AppUser.notificationSettings 既定（全 true） */
const NOTIF = {
  pushEnabled: true,
  inspectionReminder: true,
  maintenanceReminder: true,
  oilChangeReminder: true,
  tireChangeReminder: true,
  carInspectionReminder: true,
};

// ---------------------------------------------------------------------------
// 1) Auth ユーザー & users コレクション（A〜I）
// ---------------------------------------------------------------------------
// { uid, email, displayName, accountType, companyName?, planType }
const personaUsers = [
  {
    uid: 'user-a',
    email: 'persona.a@example.com',
    displayName: '個人 太郎（A: 4台混在）',
    accountType: 'personal',
    planType: 'free',
  },
  {
    uid: 'president-uid',
    email: 'persona.b@example.com',
    displayName: '田中 花子（B: 法人20台）',
    accountType: 'business',
    companyName: 'サンプル運輸株式会社',
    planType: 'premium',
  },
  {
    uid: 'user-c',
    email: 'persona.c@example.com',
    displayName: '比較 花子（C: 工場比較）',
    accountType: 'personal',
    planType: 'free',
  },
  {
    uid: 'persona-d-user',
    email: 'persona.d@example.com',
    displayName: 'プリウス 大郎（D: 長期整備）',
    accountType: 'personal',
    planType: 'premium',
  },
  {
    uid: 'persona-e-user',
    email: 'persona.e@example.com',
    displayName: '新人 みどり（E: 新社会人）',
    accountType: 'personal',
    planType: 'free',
  },
  {
    uid: 'persona-f-user',
    email: 'persona.f@example.com',
    displayName: '売却 三郎（F: 売却/廃車）',
    accountType: 'personal',
    planType: 'free',
  },
  {
    uid: 'persona-g-user',
    email: 'persona.g@example.com',
    displayName: 'EV 四郎（G: 日産リーフ）',
    accountType: 'personal',
    planType: 'free',
  },
  {
    uid: 'persona-h-user',
    email: 'persona.h@example.com',
    displayName: '旧車 五郎（H: Beat 1994）',
    accountType: 'personal',
    planType: 'free',
  },
  {
    uid: 'persona-i-user',
    email: 'persona.i@example.com',
    displayName: '購入 六郎（I: 中古SUV検討）',
    accountType: 'personal',
    planType: 'free',
  },
];

/** users/{uid} ドキュメント data を組み立てる */
function userDoc(u) {
  const data = {
    email: u.email,
    displayName: u.displayName,
    notificationSettings: NOTIF,
    planType: u.planType,
    accountType: u.accountType,
    createdAt: now,
    updatedAt: now,
  };
  if (u.companyName) data.companyName = u.companyName;
  return data;
}

// ---------------------------------------------------------------------------
// 2) vehicles（トップレベル・userId/companyId で紐付け）
// ---------------------------------------------------------------------------
const vehicleSeeds = [];

// ---- Persona A: 個人4台混在（品川） -------------------------------------
vehicleSeeds.push(
  {
    id: 'veh-a-family',
    data: {
      userId: 'user-a',
      maker: 'Toyota', model: 'Alphard', grade: 'Z', year: 2021,
      mileage: 30000,
      licensePlate: '品川 300 あ 11-11',
      inspectionExpiryDate: tsFromNow(200),
      useCategory: 'privatePassenger',
      fuelType: 'hybrid',
      status: 'active', isDataRetained: true,
      createdAt: now, updatedAt: now,
    },
  },
  {
    id: 'veh-a-cargo',
    data: {
      userId: 'user-a',
      maker: 'Toyota', model: 'Hiace', grade: 'DX', year: 2022,
      mileage: 45000,
      licensePlate: '品川 400 か 22-22',
      inspectionExpiryDate: tsFromNow(20), // 貨物=毎年車検・期限間近
      useCategory: 'cargo',
      fuelType: 'diesel',
      status: 'active', isDataRetained: true,
      createdAt: now, updatedAt: now,
    },
  },
  {
    id: 'veh-a-lease',
    data: {
      userId: 'user-a',
      maker: 'Nissan', model: 'Note', grade: 'X', year: 2023,
      mileage: 15000,
      licensePlate: '品川 500 さ 33-33',
      inspectionExpiryDate: tsFromNow(400),
      fuelType: 'hybrid',
      useCategory: 'privatePassenger',
      leaseInfo: {
        lessorName: 'オリックスカーリース',
        monthlyFee: 35000,
        contractStartDate: tsFromNow(-500),
        contractEndDate: tsFromNow(45), // リース満了間近
        maintenancePackDetails: 'メンテナンスパック込み',
      },
      status: 'active', isDataRetained: true,
      createdAt: now, updatedAt: now,
    },
  },
  {
    id: 'veh-a-sports',
    data: {
      userId: 'user-a',
      maker: 'Mazda', model: 'Roadster', grade: 'S', year: 2019,
      mileage: 22000,
      licensePlate: '品川 330 す 44-44',
      // 車検日未登録（長期保管）→ inspectionExpiryDate 省略
      useCategory: 'privatePassenger',
      fuelType: 'gasoline',
      status: 'active', isDataRetained: true,
      createdAt: now, updatedAt: now,
    },
  },
);

// ---- Persona B: 法人20台フリート（companyId=president-uid） ---------------
// 車検期限で critical=3 / warning=3 / normal=14 になるよう配置。
for (let i = 0; i < 20; i++) {
  let inspectionDays;
  if (i < 2) inspectionDays = -5;        // 期限切れ（critical）
  else if (i === 2) inspectionDays = 5;  // 7日以内（critical）
  else if (i < 6) inspectionDays = 20;   // 8〜30日（warning）
  else inspectionDays = 300;             // normal
  const isCargo = i < 10;
  const assigned = i % 2 === 0; // 偶数号車に担当ドライバー
  const ii = String(i).padStart(2, '0');
  const data = {
    userId: 'president-uid',
    companyId: 'president-uid', // フリートコード = オーナーuid
    maker: isCargo ? 'Toyota' : 'Nissan',
    model: isCargo ? 'Hiace' : 'Serena',
    grade: isCargo ? 'DX' : 'X',
    year: 2020 + (i % 4),
    mileage: 20000 + i * 3500,
    licensePlate: `足立 100 あ ${ii}-00`,
    inspectionExpiryDate: tsFromNow(inspectionDays),
    useCategory: isCargo ? 'cargo' : 'privatePassenger',
    fuelType: isCargo ? 'diesel' : 'gasoline',
    status: 'active', isDataRetained: true,
    createdAt: now, updatedAt: now,
  };
  if (assigned) {
    data.assigneeId = `driver-${i}`;
    data.assigneeName = `ドライバー${i}`;
  }
  vehicleSeeds.push({ id: `veh-b-fleet-${ii}`, data });
}

// ---- Persona C: 工場比較ユーザー（Honda Fit 1台） ------------------------
vehicleSeeds.push({
  id: 'veh-c-fit',
  data: {
    userId: 'user-c',
    maker: 'Honda', model: 'Fit', grade: 'G', year: 2020,
    mileage: 40000,
    licensePlate: '世田谷 500 な 55-55',
    inspectionExpiryDate: tsFromNow(90),
    useCategory: 'privatePassenger',
    fuelType: 'gasoline',
    status: 'active', isDataRetained: true,
    createdAt: now, updatedAt: now,
  },
});

// ---- Persona D: プリウス長期オーナー ------------------------------------
vehicleSeeds.push({
  id: 'veh-d-prius',
  data: {
    userId: 'persona-d-user',
    maker: 'Toyota', model: 'Prius', grade: 'A', year: 2020,
    mileage: 28000,
    licensePlate: '練馬 300 た 66-66',
    inspectionExpiryDate: tsFromNow(150),
    useCategory: 'privatePassenger',
    fuelType: 'hybrid',
    status: 'active', isDataRetained: true,
    createdAt: now, updatedAt: now,
  },
});

// ---- Persona E: 新社会人 N-BOX ------------------------------------------
vehicleSeeds.push({
  id: 'veh-e-nbox',
  data: {
    userId: 'persona-e-user',
    maker: 'Honda', model: 'N-BOX', grade: 'G', year: 2023,
    mileage: 5000,
    licensePlate: '横浜 580 な 77-77',
    inspectionExpiryDate: tsFromNow(800),
    useCategory: 'privatePassenger',
    fuelType: 'gasoline',
    status: 'active', isDataRetained: true,
    createdAt: now, updatedAt: now,
  },
});

// ---- Persona F: 売却済みプリウス（退役・データ保持） --------------------
vehicleSeeds.push({
  id: 'veh-f-prius',
  data: {
    userId: 'persona-f-user',
    maker: 'Toyota', model: 'Prius', grade: 'S', year: 2015,
    mileage: 120000,
    licensePlate: '足立 300 は 88-88',
    useCategory: 'privatePassenger',
    fuelType: 'hybrid',
    status: 'sold',
    retiredAt: tsFromNow(-10),
    retirementNote: 'ガリバー買取 35万円',
    isDataRetained: true,
    createdAt: now, updatedAt: now,
  },
});

// ---- Persona G: EV（日産リーフ） ----------------------------------------
vehicleSeeds.push({
  id: 'veh-g-leaf',
  data: {
    userId: 'persona-g-user',
    maker: 'Nissan', model: 'Leaf', grade: 'G', year: 2022,
    mileage: 25000,
    licensePlate: '川崎 300 ま 99-99',
    inspectionExpiryDate: tsFromNow(365),
    useCategory: 'privatePassenger',
    fuelType: 'electric',
    status: 'active', isDataRetained: true,
    createdAt: now, updatedAt: now,
  },
});

// ---- Persona H: 旧車 Honda Beat 1994 ------------------------------------
vehicleSeeds.push({
  id: 'veh-h-beat',
  data: {
    userId: 'persona-h-user',
    maker: 'Honda', model: 'Beat', grade: 'PP1', year: 1994,
    mileage: 85000,
    licensePlate: '品川 500 ん 12-34',
    inspectionExpiryDate: tsFromNow(100),
    useCategory: 'privatePassenger',
    fuelType: 'gasoline',
    status: 'active', isDataRetained: true,
    createdAt: now, updatedAt: now,
  },
});

// Persona I（中古車購入検討者）は車両未保有。問い合わせのみ。

// ---------------------------------------------------------------------------
// 3) maintenance_records（トップレベル・vehicleId/userId で紐付け）
// ---------------------------------------------------------------------------
const maintenanceSeeds = [];

/** 整備記録 data を組み立てる（必須フィールドを補完） */
function maint({ id, vehicleId, userId, type, title, cost, date, mileage }) {
  return {
    id,
    data: {
      vehicleId,
      userId,
      type,
      title,
      cost,
      date,
      mileageAtService: mileage,
      imageUrls: [],
      certificateUpdated: false,
      verificationSource: 'selfReported',
      createdAt: now,
    },
  };
}

// Persona D: プリウス4年分（base 2020-06-01）
{
  const base = '2020-06-01';
  maintenanceSeeds.push(
    maint({ id: 'mnt-d-oil-1', vehicleId: 'veh-d-prius', userId: 'persona-d-user', type: 'oilChange', title: 'オイル交換', cost: 4200, date: tsPlus(base, 0), mileage: 10000 }),
    maint({ id: 'mnt-d-oil-2', vehicleId: 'veh-d-prius', userId: 'persona-d-user', type: 'oilChange', title: 'オイル交換', cost: 4400, date: tsPlus(base, 180), mileage: 15000 }),
    maint({ id: 'mnt-d-oil-3', vehicleId: 'veh-d-prius', userId: 'persona-d-user', type: 'oilChange', title: 'オイル交換', cost: 4100, date: tsPlus(base, 360), mileage: 20000 }),
    maint({ id: 'mnt-d-oil-4', vehicleId: 'veh-d-prius', userId: 'persona-d-user', type: 'oilChange', title: 'オイル交換', cost: 4300, date: tsPlus(base, 540), mileage: 25000 }),
    maint({ id: 'mnt-d-tire-1', vehicleId: 'veh-d-prius', userId: 'persona-d-user', type: 'tireChange', title: 'タイヤ交換', cost: 32000, date: tsPlus(base, 365), mileage: 18000 }),
    maint({ id: 'mnt-d-tire-2', vehicleId: 'veh-d-prius', userId: 'persona-d-user', type: 'tireChange', title: 'タイヤ交換', cost: 34000, date: tsPlus(base, 730), mileage: 28000 }),
    maint({ id: 'mnt-d-batt-1', vehicleId: 'veh-d-prius', userId: 'persona-d-user', type: 'batteryChange', title: 'バッテリー交換', cost: 15000, date: tsPlus(base, 1200), mileage: 40000 }),
  );
}

// Persona G: EV整備（オイル交換なし・base 2022-04-01）
{
  const base = '2022-04-01';
  maintenanceSeeds.push(
    maint({ id: 'mnt-g-tire-1', vehicleId: 'veh-g-leaf', userId: 'persona-g-user', type: 'tireChange', title: 'タイヤ交換', cost: 28000, date: tsPlus(base, 365), mileage: 12000 }),
    maint({ id: 'mnt-g-tire-2', vehicleId: 'veh-g-leaf', userId: 'persona-g-user', type: 'tireChange', title: 'タイヤ交換', cost: 30000, date: tsPlus(base, 730), mileage: 24000 }),
    maint({ id: 'mnt-g-brake-1', vehicleId: 'veh-g-leaf', userId: 'persona-g-user', type: 'brakeFluidChange', title: 'ブレーキフルード交換', cost: 5500, date: tsPlus(base, 720), mileage: 23000 }),
    maint({ id: 'mnt-g-wiper-1', vehicleId: 'veh-g-leaf', userId: 'persona-g-user', type: 'wiperChange', title: 'ワイパー交換', cost: 2000, date: tsPlus(base, 365), mileage: 12000 }),
    maint({ id: 'mnt-g-wiper-2', vehicleId: 'veh-g-leaf', userId: 'persona-g-user', type: 'wiperChange', title: 'ワイパー交換', cost: 2000, date: tsPlus(base, 730), mileage: 24000 }),
  );
}

// Persona H: 旧車Beat（紙記録のデジタル化）
maintenanceSeeds.push(
  maint({ id: 'mnt-h-oil-1', vehicleId: 'veh-h-beat', userId: 'persona-h-user', type: 'oilChange', title: 'オイル交換', cost: 3000, date: tsDate('2023-01-01'), mileage: 80000 }),
  maint({ id: 'mnt-h-oil-2', vehicleId: 'veh-h-beat', userId: 'persona-h-user', type: 'oilChange', title: 'オイル交換', cost: 3000, date: tsDate('2023-07-01'), mileage: 83000 }),
);

// ---------------------------------------------------------------------------
// 4) shops（Persona C の3工場・世田谷） ※実店舗ではなくペルソナ検証用
// ---------------------------------------------------------------------------
const WEEKDAY_HOURS = {
  '0': { openTime: null, closeTime: null, isClosed: true },
  '1': { openTime: '09:00', closeTime: '18:00', isClosed: false },
  '2': { openTime: '09:00', closeTime: '18:00', isClosed: false },
  '3': { openTime: '09:00', closeTime: '18:00', isClosed: false },
  '4': { openTime: '09:00', closeTime: '18:00', isClosed: false },
  '5': { openTime: '09:00', closeTime: '18:00', isClosed: false },
  '6': { openTime: '09:00', closeTime: '17:00', isClosed: false },
};

const shopSeeds = [
  {
    id: 'persona_shop_inspection_pro',
    data: {
      name: '車検のスピード太郎 世田谷店（ペルソナ検証用）',
      type: 'maintenanceShop',
      description: '車検・整備が得意。ペルソナCの工場比較シナリオ検証用データ。',
      logoUrl: null, imageUrls: [],
      phone: null, email: null, website: null,
      prefecture: '東京都', city: '世田谷区', address: null,
      location: new GeoPoint(35.655, 139.653),
      services: ['inspection', 'maintenance'],
      supportedMakerIds: [],
      businessHours: WEEKDAY_HOURS,
      businessHoursNote: null,
      rating: 4.8, reviewCount: 120,
      isVerified: true, isFeatured: false, isActive: true,
      createdAt: now, updatedAt: now,
    },
  },
  {
    id: 'persona_shop_custom_garage',
    data: {
      name: 'ガレージ ワークス（ペルソナ検証用）',
      type: 'customShop',
      description: 'カスタム・板金が得意。ペルソナCの工場比較シナリオ検証用データ。',
      logoUrl: null, imageUrls: [],
      phone: null, email: null, website: null,
      prefecture: '東京都', city: '世田谷区', address: null,
      location: new GeoPoint(35.672, 139.660),
      services: ['customization', 'bodyWork', 'partsInstall'],
      supportedMakerIds: [],
      businessHours: WEEKDAY_HOURS,
      businessHoursNote: null,
      rating: 4.2, reviewCount: 45,
      isVerified: true, isFeatured: false, isActive: true,
      createdAt: now, updatedAt: now,
    },
  },
  {
    id: 'persona_shop_dealer_service',
    data: {
      name: 'トヨタモビリティ サービス（ペルソナ検証用）',
      type: 'dealer',
      description: '車検・タイヤが得意。ペルソナCの工場比較シナリオ検証用データ。',
      logoUrl: null, imageUrls: [],
      phone: null, email: null, website: null,
      prefecture: '東京都', city: '世田谷区', address: null,
      location: new GeoPoint(35.690, 139.670),
      services: ['inspection', 'tire', 'coating'],
      supportedMakerIds: [],
      businessHours: WEEKDAY_HOURS,
      businessHoursNote: null,
      rating: 4.0, reviewCount: 8,
      isVerified: true, isFeatured: false, isActive: true,
      createdAt: now, updatedAt: now,
    },
  },
];

// ---------------------------------------------------------------------------
// 5) fleet_members（docId = `${companyId}_${userId}`, joinedAt は ISO文字列）
// ---------------------------------------------------------------------------
const fleetMemberSeeds = [
  {
    id: 'president-uid_president-uid',
    data: {
      companyId: 'president-uid',
      userId: 'president-uid',
      role: 'owner',
      displayName: '田中 花子',
      joinedAt: new Date(nowMs - 300 * DAY).toISOString(),
    },
  },
];
// 担当ドライバー10名（staff）
for (let i = 0; i < 10; i++) {
  fleetMemberSeeds.push({
    id: `president-uid_driver-${i}`,
    data: {
      companyId: 'president-uid',
      userId: `driver-${i}`,
      role: 'staff',
      displayName: `ドライバー${i}`,
      joinedAt: new Date(nowMs - (200 - i) * DAY).toISOString(),
    },
  });
}

// ---------------------------------------------------------------------------
// 6) inquiries（問い合わせ）
// ---------------------------------------------------------------------------
const inquirySeeds = [
  {
    id: 'inq-a-inspection',
    data: {
      userId: 'user-a',
      shopId: 'persona_shop_inspection_pro',
      vehicleId: 'veh-a-cargo',
      type: 'serviceInquiry',
      status: 'pending',
      subject: '車検のご相談（ハイエース）',
      initialMessage:
        '品川 400 か 22-22（貨物車/毎年車検）が車検期限を迎えます。ご連絡お願いします。',
      attachmentUrls: [],
      shopName: '車検のスピード太郎 世田谷店（ペルソナ検証用）',
      vehicleMaker: 'Toyota', vehicleModel: 'Hiace', vehicleYear: 2022,
      createdAt: now, updatedAt: now,
      messageCount: 1, unreadCountUser: 0, unreadCountShop: 1,
    },
  },
  {
    id: 'inq-i-purchase',
    data: {
      userId: 'persona-i-user',
      shopId: 'persona_shop_dealer_service',
      type: 'vehiclePurchase',
      status: 'pending',
      subject: '中古SUVを探しています',
      initialMessage:
        '2020年以降のSUVを探しています。家族4人で使います。予算400万円以内・走行5万km以内が希望です。',
      attachmentUrls: [],
      shopName: 'トヨタモビリティ サービス（ペルソナ検証用）',
      createdAt: now, updatedAt: now,
      messageCount: 1, unreadCountUser: 0, unreadCountShop: 1,
    },
  },
];

// ---------------------------------------------------------------------------
// 実行
// ---------------------------------------------------------------------------
function logGroup(title, entries, labelFn) {
  console.log(`--- ${title}（${entries.length}件）---`);
  for (const e of entries) {
    console.log(`  ${labelFn(e)}`);
  }
  console.log('');
}

async function seedAuthUsers() {
  // 本番 Auth への作成は既定でスキップする。ただし Web 版（本番接続）で
  // ログインして動作確認するには本番側に Auth ユーザーが必要なので、
  // 明示フラグ --with-auth を付けた場合のみ本番にも作成する。
  const withAuth = process.argv.includes('--with-auth');
  if (!useEmulator && !withAuth) {
    console.log(
      '[SKIP] Auth ユーザー作成は --emulator 時のみ実行します（本番 Auth を汚さないため）。',
    );
    console.log(
      '       Web版でログインする場合は --with-auth を付けてください。');
    return;
  }
  if (!useEmulator && withAuth) {
    console.log(
      '[WARN] 本番 Auth にテストユーザー9名を作成します（パスワードは ' +
        'password123）。公開されている Web からログイン可能になるため、' +
        '確認が終わったら必ず削除してください。');
  }
  const auth = admin.auth();
  let created = 0;
  for (const u of personaUsers) {
    const props = {
      uid: u.uid,
      email: u.email,
      emailVerified: true,
      password: DEMO_PASSWORD,
      displayName: u.displayName,
    };
    try {
      await auth.createUser(props);
      created++;
      console.log(`[AUTH] created ${u.email} (uid=${u.uid})`);
    } catch (err) {
      if (err && err.code === 'auth/uid-already-exists') {
        try {
          await auth.updateUser(u.uid, {
            email: u.email,
            password: DEMO_PASSWORD,
            displayName: u.displayName,
          });
          console.log(`[AUTH] updated ${u.email} (uid=${u.uid})`);
        } catch (e2) {
          console.warn(`[AUTH][WARN] update 失敗 ${u.uid}: ${e2.message}`);
        }
      } else {
        console.warn(
          `[AUTH][WARN] ${u.uid} の作成に失敗（Auth エミュレータ未起動?）: ${
            err ? err.message : err
          }`,
        );
      }
    }
  }
  console.log(`[AUTH] 新規 ${created} 件 / 全 ${personaUsers.length} 件`);
  console.log('');
}

/// 作成した Auth ユーザー9名を削除する（--delete-auth）。
///
/// パスワードが password123 の共通値なので、本番で確認が終わったら
/// アカウントを残さないこと。Firestore 側のシードデータは公開情報のみで
/// あり、残っても不正ログインの足がかりにはならないが、Auth は別。
async function deleteAuthUsers() {
  const auth = admin.auth();
  let deleted = 0;
  for (const u of personaUsers) {
    try {
      await auth.deleteUser(u.uid);
      deleted++;
      console.log(`[AUTH] deleted ${u.email} (uid=${u.uid})`);
    } catch (err) {
      if (err && err.code === 'auth/user-not-found') {
        console.log(`[AUTH] skip（存在しない）: ${u.uid}`);
      } else {
        console.warn(`[AUTH][WARN] 削除失敗 ${u.uid}: ${err.message}`);
      }
    }
  }
  console.log(`[AUTH] 削除 ${deleted} 件 / 全 ${personaUsers.length} 件`);
}

async function main() {
  // 初期化はモジュール先頭で済んでいる（emulator/本番の分岐込み）。
  if (process.argv.includes('--delete-auth')) {
    await deleteAuthUsers();
    return;
  }
  console.log('=== Persona Seed Script ===');
  console.log(`dry-run  : ${isDryRun}`);
  console.log(`emulator : ${useEmulator}`);
  console.log('');

  const userEntries = personaUsers.map((u) => ({
    collection: 'users',
    id: u.uid,
    data: userDoc(u),
  }));
  const vehicleEntries = vehicleSeeds.map((v) => ({
    collection: 'vehicles',
    id: v.id,
    data: v.data,
  }));
  const maintEntries = maintenanceSeeds.map((m) => ({
    collection: 'maintenance_records',
    id: m.id,
    data: m.data,
  }));
  const shopEntries = shopSeeds.map((s) => ({
    collection: 'shops',
    id: s.id,
    data: s.data,
  }));
  const fleetEntries = fleetMemberSeeds.map((f) => ({
    collection: 'fleet_members',
    id: f.id,
    data: f.data,
  }));
  const inquiryEntries = inquirySeeds.map((q) => ({
    collection: 'inquiries',
    id: q.id,
    data: q.data,
  }));

  const all = [
    ...userEntries,
    ...vehicleEntries,
    ...maintEntries,
    ...shopEntries,
    ...fleetEntries,
    ...inquiryEntries,
  ];

  console.log('登録サマリー:');
  console.log(`  users              : ${userEntries.length}`);
  console.log(`  vehicles           : ${vehicleEntries.length}`);
  console.log(`  maintenance_records: ${maintEntries.length}`);
  console.log(`  shops              : ${shopEntries.length}`);
  console.log(`  fleet_members      : ${fleetEntries.length}`);
  console.log(`  inquiries          : ${inquiryEntries.length}`);
  console.log(`  合計ドキュメント    : ${all.length}`);
  console.log(`  auth users         : ${personaUsers.length}（--emulator 時）`);
  console.log('');

  if (isDryRun) {
    console.log('--- [DRY RUN] 登録予定データ ---');
    logGroup('users', userEntries, (e) => `${e.id} — ${e.data.displayName}`);
    logGroup('vehicles', vehicleEntries, (e) =>
      `${e.id} — ${e.data.maker} ${e.data.model} (userId=${e.data.userId}${
        e.data.companyId ? `, companyId=${e.data.companyId}` : ''
      })`,
    );
    logGroup('maintenance_records', maintEntries, (e) =>
      `${e.id} — ${e.data.type} ¥${e.data.cost} (vehicleId=${e.data.vehicleId})`,
    );
    logGroup('shops', shopEntries, (e) =>
      `${e.id} — ${e.data.name} ★${e.data.rating}/${e.data.reviewCount}件`,
    );
    logGroup('fleet_members', fleetEntries, (e) =>
      `${e.id} — ${e.data.role} ${e.data.displayName}`,
    );
    logGroup('inquiries', inquiryEntries, (e) =>
      `${e.id} — ${e.data.type} 「${e.data.subject}」`,
    );
    console.log('--- [DRY RUN] 完了（Firestore/Auth への書き込みは行っていません）---');
    console.log(
      `\nログイン用: 各ペルソナのメール（persona.a@example.com 〜 persona.i@example.com）+ パスワード「${DEMO_PASSWORD}」`,
    );
    return;
  }

  // Auth ユーザー（--emulator 時のみ）
  await seedAuthUsers();

  // Firestore（batch。500 ops 未満なので単一バッチで十分）
  const batch = db.batch();
  for (const e of all) {
    const ref = db.collection(e.collection).doc(e.id);
    batch.set(ref, e.data, { merge: true });
  }
  await batch.commit();

  console.log(`[SUCCESS] Firestore に ${all.length} 件のドキュメントを登録しました。`);
  console.log('');
  console.log('ログイン（Auth エミュレータ）:');
  console.log(`  メール : persona.a@example.com 〜 persona.i@example.com`);
  console.log(`  パスワード : ${DEMO_PASSWORD}`);
  console.log('  例) 法人フリート20台を見る → persona.b@example.com（田中 花子）');
}

main().catch((err) => {
  console.error('[ERROR]', err);
  process.exit(1);
});
