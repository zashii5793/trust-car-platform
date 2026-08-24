/**
 * seed_rich_history.js
 *
 * 整備記録とアクセサリー投稿を、実際に使い込んだ状態まで積み上げる。
 *
 * seed_personas.js が作る整備記録は各車 1〜2 件で、履歴タブを開いても
 * 「タイムラインが伸びている感じ」がしない。こちらは走行距離と経過年数に
 * 沿って、オイル交換・車検・消耗品交換が積み重なった履歴を生成する。
 * アクセサリーのクチコミ（accessory_showcases）も併せて投入する。
 *
 * 書き込み先:
 *   maintenance_records   整備記録（docId: mnt-rh-*）
 *   accessory_showcases   アクセサリーのクチコミ（docId: acc-rh-*）
 *
 * 既存シードとは docId プレフィックスが違うので共存できる。
 *
 * 使い方:
 *   node seed_rich_history.js --emulator
 *   node seed_rich_history.js --dry-run
 *   node seed_rich_history.js --delete --emulator
 */

const admin = require('firebase-admin');

const has = (f) => process.argv.includes(f);
const EMULATOR = has('--emulator');
const DRY_RUN = has('--dry-run');
const DELETE = has('--delete');

if (EMULATOR) {
  process.env.FIRESTORE_EMULATOR_HOST =
    process.env.FIRESTORE_EMULATOR_HOST || 'localhost:8080';
  process.env.FIREBASE_AUTH_EMULATOR_HOST =
    process.env.FIREBASE_AUTH_EMULATOR_HOST || 'localhost:9099';
}

const SEED_TAG = 'rich-history';
const META = { isSeed: true, seedTag: SEED_TAG };

const DAY = 24 * 60 * 60 * 1000;
const NOW = Date.now();

let _seed = 20260818;
function rand() {
  _seed = (_seed * 1103515245 + 12345) % 2147483648;
  return _seed / 2147483648;
}
const between = (a, b) => a + Math.floor(rand() * (b - a + 1));
const ts = (ms) => admin.firestore.Timestamp.fromMillis(ms);
const pick = (arr) => arr[Math.floor(rand() * arr.length)];

// ---------------------------------------------------------------------------
// 対象車両（seed_personas.js の vehicles と ID を揃える）
// ---------------------------------------------------------------------------

const SHOPS = [
  'タカヤモーター株式会社',
  '車検のスピード太郎 世田谷店',
  '横浜テストモータース',
  '川崎テスト自動車工業',
  'オートバックス 環八店',
  'ディーラー系サービス工場',
];

// 各車両の素性。現在の走行距離から遡って履歴を作る。
const VEHICLES = [
  {
    id: 'veh-a-cargo', userId: 'user-a', label: 'Toyota Hiace（貨物・毎年車検）',
    mileage: 96000, yearsOwned: 6, kmPerYear: 16000,
    profile: 'work', // 商用：距離が伸びる、車検は毎年
  },
  {
    id: 'veh-a-minivan', userId: 'user-a', label: 'Toyota Alphard（family）',
    mileage: 58000, yearsOwned: 5, kmPerYear: 11000, profile: 'family',
  },
  {
    id: 'veh-a-sports', userId: 'user-a', label: 'Mazda Roadster（趣味）',
    mileage: 22000, yearsOwned: 5, kmPerYear: 4500, profile: 'hobby',
  },
  {
    id: 'veh-a-lease', userId: 'user-a', label: 'Nissan Note（リース）',
    mileage: 24000, yearsOwned: 2, kmPerYear: 12000, profile: 'commute',
  },
  {
    id: 'veh-d-prius', userId: 'persona-d-user', label: 'Toyota Prius（長期・DIY）',
    mileage: 28000, yearsOwned: 4, kmPerYear: 7000, profile: 'meticulous',
  },
  {
    id: 'veh-e-nbox', userId: 'persona-e-user', label: 'Honda N-BOX（新社会人）',
    mileage: 9000, yearsOwned: 1, kmPerYear: 9000, profile: 'beginner',
  },
  {
    id: 'veh-g-leaf', userId: 'persona-g-user', label: 'Nissan Leaf（EV）',
    mileage: 41000, yearsOwned: 3, kmPerYear: 14000, profile: 'ev',
  },
  {
    id: 'veh-h-beat', userId: 'persona-h-user', label: 'Honda Beat（旧車）',
    mileage: 132000, yearsOwned: 12, kmPerYear: 3000, profile: 'classic',
  },
  {
    id: 'veh-c-fit', userId: 'user-c', label: 'Honda Fit（工場比較）',
    mileage: 34000, yearsOwned: 4, kmPerYear: 8500, profile: 'commute',
  },
];

// ---------------------------------------------------------------------------
// 履歴の組み立て
// ---------------------------------------------------------------------------
//
// 「何ヶ月ごと」「何kmごと」で発生する整備を、所有年数ぶん遡って並べる。
// EV はオイル交換が発生しない、旧車は修理が多い、といった差を profile で出す。

function itemsFor(profile) {
  // { type, title, everyMonths, cost: [min,max], shopUsed }
  const base = [
    { type: 'oilChange', title: 'エンジンオイル交換', everyMonths: 6, cost: [4500, 8000] },
    { type: 'oilFilterChange', title: 'オイルフィルター交換', everyMonths: 12, cost: [1800, 3200] },
    { type: 'tireRotation', title: 'タイヤローテーション', everyMonths: 12, cost: [2000, 4000] },
    { type: 'airFilterChange', title: 'エアフィルター交換', everyMonths: 24, cost: [2500, 4500] },
    { type: 'cabinFilterChange', title: 'エアコンフィルター交換', everyMonths: 12, cost: [2800, 5000] },
    { type: 'wiperChange', title: 'ワイパーゴム交換', everyMonths: 12, cost: [1200, 2600] },
    { type: 'brakeFluidChange', title: 'ブレーキフルード交換', everyMonths: 24, cost: [5000, 9000] },
    { type: 'coolantChange', title: '冷却水交換', everyMonths: 36, cost: [6000, 11000] },
    { type: 'batteryChange', title: 'バッテリー交換', everyMonths: 40, cost: [14000, 26000] },
    { type: 'tireChange', title: 'タイヤ交換（4本）', everyMonths: 40, cost: [48000, 92000] },
    { type: 'brakePadChange', title: 'ブレーキパッド交換', everyMonths: 42, cost: [16000, 32000] },
    { type: 'legalInspection12', title: '12ヶ月法定点検', everyMonths: 24, cost: [12000, 20000] },
    { type: 'carInspection', title: '車検（24ヶ月）', everyMonths: 24, cost: [78000, 138000] },
  ];

  switch (profile) {
    case 'ev':
      // EV：オイル系なし。代わりにタイヤと冷却系、12ヶ月点検が中心
      return base.filter(
        (i) => !['oilChange', 'oilFilterChange', 'airFilterChange'].includes(i.type),
      );
    case 'work':
      // 商用：車検は毎年、消耗が早い
      return base
        .map((i) => (i.type === 'carInspection'
          ? { ...i, everyMonths: 12, title: '車検（貨物・毎年）' }
          : i))
        .concat([
          { type: 'repair', title: 'スライドドアレール修理', everyMonths: 30, cost: [18000, 38000] },
          { type: 'lightBulbChange', title: 'ヘッドライトバルブ交換', everyMonths: 18, cost: [3000, 8000] },
        ]);
    case 'meticulous':
      // DIY派：オイルは短周期
      return base.map((i) => (i.type === 'oilChange' ? { ...i, everyMonths: 4 } : i));
    case 'classic':
      // 旧車：修理・調整が多い
      return base.concat([
        { type: 'repair', title: 'キャブレター調整', everyMonths: 12, cost: [12000, 28000] },
        { type: 'repair', title: 'タイミングベルト交換', everyMonths: 60, cost: [42000, 78000] },
        { type: 'bodyRepair', title: '錆止め・下回り塗装', everyMonths: 36, cost: [25000, 55000] },
      ]);
    case 'hobby':
      return base.concat([
        { type: 'glassCoating', title: 'ガラスコーティング施工', everyMonths: 36, cost: [60000, 95000] },
        { type: 'wheelAlignment', title: 'ホイールアライメント調整', everyMonths: 24, cost: [12000, 22000] },
      ]);
    case 'beginner':
      // 新車1年：点検とごく軽い消耗品のみ
      return base.filter((i) => [
        'oilChange', 'wiperChange', 'legalInspection12', 'cabinFilterChange',
      ].includes(i.type));
    default:
      return base;
  }
}

const NOTE_BY_TYPE = {
  oilChange: [
    '0W-20 化学合成油。前回から順調。',
    '純正指定オイルで交換。フィルターは次回。',
    '距離が伸びていたので早めに実施。',
  ],
  carInspection: [
    '検査ラインは一発合格。ブレーキパッド残量に指摘あり。',
    '見積もり比較のうえ依頼。追加整備は最小限に。',
    '法定費用のほか、下回り洗浄と防錆を追加。',
  ],
  tireChange: [
    '4本とも同時交換。銘柄は前回と同じ。',
    '溝が1.6mmを下回ったため交換。',
    '夏タイヤへ入れ替え。バランス調整込み。',
  ],
  batteryChange: [
    'エンジンのかかりが悪くなったため予防交換。',
    '寒くなる前に交換。前回から3年半。',
  ],
  brakePadChange: [
    'フロントのみ交換。リアは残量あり。',
    '異音が出始めたため交換。ローターは研磨で対応。',
  ],
  repair: [
    '走行に支障はないが早めに対処。',
    '部品の入荷待ちで作業まで1週間かかった。',
  ],
  legalInspection12: [
    '指摘事項なし。次回は距離の進み具合を見て判断。',
    '下回りに軽い錆。次回車検時に再確認。',
  ],
};

function noteFor(type) {
  const list = NOTE_BY_TYPE[type];
  return list ? pick(list) : '';
}

// 車両ドキュメントの現在走行距離を引く。
//
// 履歴はここから過去へ遡って作るため、VEHICLES にハードコードした距離が
// seed_personas.js 側の車両と食い違うと、整備記録が車両の現在値を追い越す。
// （実機で 45,000km の Hiace に 89,522km の整備記録が並び、通知文も
//   「前回から0km走行」という不自然な表示になった）
async function fetchCurrentMileages(db) {
  const out = {};
  for (const v of VEHICLES) {
    const snap = await db.collection('vehicles').doc(v.id).get();
    if (!snap.exists) continue;
    const m = snap.data().mileage;
    if (typeof m === 'number' && m > 0) out[v.id] = m;
  }
  return out;
}

// actualMileages: { vehicleId: 現在の走行距離 }。--dry-run では空。
function buildMaintenance(actualMileages = {}) {
  const entries = [];
  let count = 0;
  const perVehicle = {};

  VEHICLES.forEach((v) => {
    const items = itemsFor(v.profile);
    const monthsOwned = v.yearsOwned * 12;
    // 車両ドキュメントの距離を正とする。年間走行距離もそこから引き直す
    // （テーブル値のままだと逆算が下限に張り付き、履歴が同じ距離で並ぶ）。
    const actual = actualMileages[v.id];
    const currentMileage = actual ?? v.mileage;
    const kmPerYear = actual
      ? Math.max(1000, Math.round(currentMileage / Math.max(1, v.yearsOwned)))
      : v.kmPerYear;
    let n = 0;

    items.forEach((item, ii) => {
      // 所有期間を everyMonths で割った回数だけ、過去に遡って記録を作る
      const times = Math.floor(monthsOwned / item.everyMonths);
      for (let k = 1; k <= times; k++) {
        const monthsAgo = k * item.everyMonths - between(0, 2);
        if (monthsAgo <= 0 || monthsAgo > monthsOwned) continue;

        const daysAgo = Math.round(monthsAgo * 30.4);
        const date = NOW - daysAgo * DAY;
        // その時点の走行距離を線形に逆算。現在の走行距離は超えない。
        const mileage = Math.min(
          currentMileage,
          Math.max(
            500,
            Math.round(
              currentMileage - (kmPerYear * monthsAgo) / 12 + between(-400, 400),
            ),
          ),
        );

        const id = `mnt-rh-${v.id}-${item.type}-${k}`;
        entries.push({
          col: 'maintenance_records',
          id,
          data: {
            vehicleId: v.id,
            userId: v.userId,
            type: item.type,
            title: item.title,
            description: noteFor(item.type),
            cost: between(item.cost[0], item.cost[1]),
            shopName: pick(SHOPS),
            date: ts(date),
            mileageAtService: mileage,
            imageUrls: [],
            createdAt: ts(date + between(1, 6) * 60 * 60 * 1000),
            updatedAt: ts(date + between(1, 6) * 60 * 60 * 1000),
            ...META,
          },
        });
        count++;
        n++;
      }
      // ii は未使用だが、将来の分岐用に残す
      void ii;
    });

    perVehicle[v.label] = n;
  });

  return { entries, count, perVehicle };
}

// ---------------------------------------------------------------------------
// アクセサリーのクチコミ
// ---------------------------------------------------------------------------

const P = {
  a: 'user-a',
  b: 'president-uid',
  c: 'user-c',
  d: 'persona-d-user',
  e: 'persona-e-user',
  f: 'persona-f-user',
  g: 'persona-g-user',
  h: 'persona-h-user',
  i: 'persona-i-user',
};

const ACCESSORIES = [
  {
    id: 'dashcam-2ch', user: P.a, vehicleId: 'veh-a-cargo', category: 'electronics',
    itemName: '前後2カメラ ドライブレコーダー', brand: 'コムテック', priceApprox: 32000, rating: 5,
    daysAgo: 40, helpful: 12,
    review: '仕事で毎日乗るので前後は必須でした。夜間でもナンバーが読めます。'
      + '駐車監視は別売の電源ケーブルが要りますが、付けておいてよかったです。',
  },
  {
    id: 'dashcam-cheap', user: P.e, vehicleId: 'veh-e-nbox', category: 'electronics',
    itemName: '前後2カメラ ドライブレコーダー（エントリー）', brand: 'ユピテル', priceApprox: 14800, rating: 4,
    daysAgo: 22, helpful: 9,
    review: '初めてのドラレコ。昼間は十分きれいですが、夜の対向車のナンバーは読めません。'
      + '価格を考えれば納得です。取り付けは自分でできました。',
  },
  {
    id: 'floor-mat', user: P.a, vehicleId: 'veh-a-minivan', category: 'interior',
    itemName: 'ラバーフロアマット', brand: '純正オプション', priceApprox: 18000, rating: 5,
    daysAgo: 65, helpful: 7,
    review: '子どもがお菓子をこぼしても水拭きで済みます。'
      + '布マットに戻れなくなりました。雪の日も安心です。',
  },
  {
    id: 'seat-cover', user: P.b, vehicleId: null, category: 'interior',
    itemName: '防水シートカバー（社用車用）', brand: 'Clazzio', priceApprox: 24000, rating: 4,
    daysAgo: 55, helpful: 11,
    review: '20台に導入しました。作業着のまま乗る社員が多いので、'
      + '汚れたら外して洗える点が決め手です。取り付けは1台30分ほど。',
  },
  {
    id: 'tire-gauge', user: P.d, vehicleId: 'veh-d-prius', category: 'maintenance',
    itemName: 'デジタルタイヤゲージ', brand: 'エーモン', priceApprox: 3200, rating: 5,
    daysAgo: 30, helpful: 15,
    review: '月1で空気圧を見る習慣がつきました。'
      + '燃費が落ちたと思ったら空気圧不足だったこともあり、元は取れています。',
  },
  {
    id: 'coating-kit', user: P.c, vehicleId: 'veh-c-fit', category: 'maintenance',
    itemName: '簡易コーティング剤', brand: 'シュアラスター', priceApprox: 2800, rating: 4,
    daysAgo: 18, helpful: 6,
    review: 'プロ施工の間のメンテとして使っています。'
      + '洗車後に吹くだけで水弾きが戻ります。持ちは1ヶ月程度。',
  },
  {
    id: 'ev-charger-cable', user: P.g, vehicleId: 'veh-g-leaf', category: 'electronics',
    itemName: '200V 普通充電ケーブル（7.5m）', brand: 'パナソニック', priceApprox: 42000, rating: 5,
    daysAgo: 90, helpful: 14,
    review: '自宅充電はEV生活の前提です。7.5mあれば駐車位置を選びません。'
      + '純正付属より取り回しが楽でした。',
  },
  {
    id: 'roof-box', user: P.a, vehicleId: 'veh-a-minivan', category: 'exterior',
    itemName: 'ルーフボックス 400L', brand: 'THULE', priceApprox: 89000, rating: 4,
    daysAgo: 120, helpful: 8,
    review: '家族4人分の荷物が余裕で入ります。'
      + '高速では風切り音と燃費悪化がありますが、積載力には代えがたいです。',
  },
  {
    id: 'led-bulb', user: P.h, vehicleId: 'veh-h-beat', category: 'exterior',
    itemName: 'LEDヘッドライトバルブ', brand: 'IPF', priceApprox: 16800, rating: 3,
    daysAgo: 75, helpful: 5,
    review: '旧車のハロゲンから交換。明るくはなりましたが、'
      + '車検の光軸調整が必要でした。旧車に入れるなら光軸調整込みで考えてください。',
  },
  {
    id: 'child-seat', user: P.b, vehicleId: null, category: 'safety',
    itemName: 'ISOFIX対応チャイルドシート', brand: 'コンビ', priceApprox: 45000, rating: 5,
    daysAgo: 35, helpful: 10,
    review: 'ISOFIXなら取り付けミスが起きにくいです。'
      + '社用車に付ける場合は対応の有無を先に確認してください。',
  },
  {
    id: 'jump-starter', user: P.h, vehicleId: 'veh-h-beat', category: 'safety',
    itemName: 'モバイルジャンプスターター', brand: 'メルテック', priceApprox: 9800, rating: 5,
    daysAgo: 50, helpful: 13,
    review: 'バッテリー上がりで2回助かりました。旧車乗りは持っておくべきです。'
      + 'スマホの充電にも使えます。',
  },
  {
    id: 'snow-brush', user: P.e, vehicleId: 'veh-e-nbox', category: 'maintenance',
    itemName: 'スノーブラシ（伸縮式）', brand: 'アイリスオーヤマ', priceApprox: 1980, rating: 4,
    daysAgo: 15, helpful: 4,
    review: '初めての冬に購入。軽自動車なら伸縮なしでも届きますが、'
      + '伸ばせるとルーフの雪も落とせて楽です。',
  },
  {
    id: 'phone-holder', user: P.i, vehicleId: null, category: 'interior',
    itemName: 'マグネット式スマホホルダー', brand: 'Anker', priceApprox: 3480, rating: 4,
    daysAgo: 28, helpful: 6,
    review: '試乗車巡りでナビ代わりに使っています。'
      + 'エアコン吹き出し口タイプは夏に熱くなるので、ダッシュボード固定型がおすすめ。',
  },
  {
    id: 'trunk-tray', user: P.f, vehicleId: null, category: 'interior',
    itemName: 'ラゲッジトレイ', brand: '汎用品', priceApprox: 6800, rating: 5,
    daysAgo: 100, helpful: 7,
    review: '売却時に荷室が綺麗なままだったのは、これのおかげです。'
      + '査定でも内装の状態は見られるので、早めに入れておく価値があります。',
  },
  {
    id: 'wheel-lock', user: P.a, vehicleId: 'veh-a-sports', category: 'safety',
    itemName: 'ロックナット', brand: 'マックガード', priceApprox: 8500, rating: 5,
    daysAgo: 60, helpful: 9,
    review: '趣味車には必須だと思っています。'
      + 'タイヤ交換のたびに専用キーが要るのは手間ですが、盗難対策として納得しています。',
  },
];

function buildAccessories() {
  const entries = [];
  ACCESSORIES.forEach((a) => {
    const created = NOW - a.daysAgo * DAY;
    entries.push({
      col: 'accessory_showcases',
      id: `acc-rh-${a.id}`,
      data: {
        userId: a.user,
        ...(a.vehicleId ? { vehicleId: a.vehicleId } : {}),
        category: a.category,
        itemName: a.itemName,
        brand: a.brand,
        priceApprox: a.priceApprox,
        rating: a.rating,
        imageUrls: [],
        review: a.review,
        helpfulCount: a.helpful,
        createdAt: ts(created),
        updatedAt: ts(created),
        ...META,
      },
    });
  });
  return entries;
}


// ---------------------------------------------------------------------------
// 任意保険（vehicles.voluntaryInsurance サブマップを更新）
// ---------------------------------------------------------------------------
//
// VoluntaryInsurance は車両に1件だけぶら下がる構造で、保険料の履歴は持てない。
// ここでは「現在加入中の内容」を車両の素性に合わせて入れる。
// 等級・年齢条件・車両保険の有無で保険料が変わる実態を反映している。

const INSURANCE = [
  {
    vehicleId: 'veh-a-cargo', // 商用ハイエース：対物無制限・車両保険あり
    companyName: '東京海上日動', policyNumber: 'TKM-2026-884213',
    expiresInDays: 138, contractStartedDaysAgo: 227,
    annualPremium: 98400, nonFleetGrade: 18, driverAgeCondition: '年齢問わず補償',
    driverScope: '本人・配偶者', hasVehicleInsurance: true,
    vehicleInsuranceType: '一般', vehicleInsuranceAmount: 1800000,
    vehicleInsuranceDeductible: '5万円 / 10万円', usagePurpose: '業務使用',
  },
  {
    vehicleId: 'veh-a-minivan', // 家族用アルファード
    companyName: '東京海上日動', policyNumber: 'TKM-2026-884214',
    expiresInDays: 138, contractStartedDaysAgo: 227,
    annualPremium: 74600, nonFleetGrade: 20, driverAgeCondition: '35歳以上補償',
    driverScope: '家族限定', hasVehicleInsurance: true,
    vehicleInsuranceType: '一般', vehicleInsuranceAmount: 2400000,
    vehicleInsuranceDeductible: '5万円 / 10万円', usagePurpose: '日常・レジャー',
  },
  {
    vehicleId: 'veh-a-sports', // 趣味のロードスター：走行少なめ・車両保険厚め
    companyName: 'ソニー損保', policyNumber: 'SNY-26-551907',
    expiresInDays: 41, contractStartedDaysAgo: 324,
    annualPremium: 52300, nonFleetGrade: 20, driverAgeCondition: '35歳以上補償',
    driverScope: '本人限定', hasVehicleInsurance: true,
    vehicleInsuranceType: '一般', vehicleInsuranceAmount: 1600000,
    vehicleInsuranceDeductible: '10万円 / 10万円', usagePurpose: '日常・レジャー',
  },
  {
    vehicleId: 'veh-d-prius',
    companyName: '損保ジャパン', policyNumber: 'SJP-2026-330118',
    expiresInDays: 96, contractStartedDaysAgo: 269,
    annualPremium: 46800, nonFleetGrade: 19, driverAgeCondition: '30歳以上補償',
    driverScope: '本人・配偶者', hasVehicleInsurance: true,
    vehicleInsuranceType: 'エコノミー', vehicleInsuranceAmount: 1500000,
    vehicleInsuranceDeductible: '5万円 / 10万円', usagePurpose: '通勤・通学',
  },
  {
    vehicleId: 'veh-e-nbox', // 新社会人：等級が低く保険料は高め
    companyName: 'アクサダイレクト', policyNumber: 'AXA-26-772044',
    expiresInDays: 212, contractStartedDaysAgo: 153,
    annualPremium: 88200, nonFleetGrade: 7, driverAgeCondition: '21歳以上補償',
    driverScope: '本人限定', hasVehicleInsurance: true,
    vehicleInsuranceType: 'エコノミー', vehicleInsuranceAmount: 1300000,
    vehicleInsuranceDeductible: '5万円 / 10万円', usagePurpose: '通勤・通学',
  },
  {
    vehicleId: 'veh-g-leaf',
    companyName: 'イーデザイン損保', policyNumber: 'EDS-26-119032',
    expiresInDays: 24, contractStartedDaysAgo: 341,
    annualPremium: 41500, nonFleetGrade: 17, driverAgeCondition: '30歳以上補償',
    driverScope: '本人・配偶者', hasVehicleInsurance: true,
    vehicleInsuranceType: '一般', vehicleInsuranceAmount: 2100000,
    vehicleInsuranceDeductible: '5万円 / 10万円', usagePurpose: '通勤・通学',
  },
  {
    vehicleId: 'veh-h-beat', // 旧車：車両保険を付けられず対人対物のみ
    companyName: '三井住友海上', policyNumber: 'MSI-2026-660471',
    expiresInDays: 173, contractStartedDaysAgo: 192,
    annualPremium: 33800, nonFleetGrade: 20, driverAgeCondition: '26歳以上補償',
    driverScope: '本人限定', hasVehicleInsurance: false,
    vehicleInsuranceType: null, vehicleInsuranceAmount: null,
    vehicleInsuranceDeductible: null, usagePurpose: '日常・レジャー',
  },
  {
    vehicleId: 'veh-c-fit',
    companyName: 'チューリッヒ', policyNumber: 'ZUR-26-908115',
    expiresInDays: 61, contractStartedDaysAgo: 304,
    annualPremium: 39200, nonFleetGrade: 16, driverAgeCondition: '30歳以上補償',
    driverScope: '本人・配偶者', hasVehicleInsurance: true,
    vehicleInsuranceType: 'エコノミー', vehicleInsuranceAmount: 1200000,
    vehicleInsuranceDeductible: '5万円 / 10万円', usagePurpose: '日常・レジャー',
  },
];

function buildInsurance() {
  return INSURANCE.map((ins) => ({
    col: 'vehicles',
    id: ins.vehicleId,
    data: {
      voluntaryInsurance: {
        companyName: ins.companyName,
        policyNumber: ins.policyNumber,
        expiryDate: ts(NOW + ins.expiresInDays * DAY),
        coverageType: ins.hasVehicleInsurance ? '対人対物無制限・車両保険あり' : '対人対物無制限',
        agentName: null,
        agentPhone: null,
        contractStartDate: ts(NOW - ins.contractStartedDaysAgo * DAY),
        annualPremium: ins.annualPremium,
        paymentMethod: '年払い',
        contractType: 'nonFleet',
        usagePurpose: ins.usagePurpose,
        namedInsured: null,
        nonFleetGrade: ins.nonFleetGrade,
        accidentCoefficientPeriod: 0,
        fleetDiscountRate: null,
        bodilyInjuryLimit: '無制限',
        propertyDamageLimit: '無制限',
        // String? なので数値ではなく表記をそのまま入れる（モデル定義に合わせる）
        personalInjuryAmount: '3000万円',
        passengerInjuryAmount: null,
        hasVehicleInsurance: ins.hasVehicleInsurance,
        vehicleInsuranceType: ins.vehicleInsuranceType,
        vehicleInsuranceAmount: ins.vehicleInsuranceAmount,
        vehicleInsuranceDeductible: ins.vehicleInsuranceDeductible,
        driverScope: ins.driverScope,
        driverAgeCondition: ins.driverAgeCondition,
        specialClauses: ['弁護士費用特約', 'ロードサービス'],
      },
    },
  }));
}

// ---------------------------------------------------------------------------
// 実行
// ---------------------------------------------------------------------------

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

async function deleteInChunks(db, entries) {
  const CHUNK = 400;
  for (let i = 0; i < entries.length; i += CHUNK) {
    const batch = db.batch();
    for (const e of entries.slice(i, i + CHUNK)) {
      batch.delete(db.collection(e.col).doc(e.id));
    }
    await batch.commit();
    console.log(`  削除: ${Math.min(i + CHUNK, entries.length)}/${entries.length}`);
  }
}

async function main() {
  // 履歴の走行距離は車両ドキュメントの実値から遡るので、先に Firestore を開く。
  let db = null;
  if (!DRY_RUN) {
    admin.initializeApp({ projectId: 'trust-car-platform' });
    db = admin.firestore();
  }
  const currentMileages = db ? await fetchCurrentMileages(db) : {};

  const mnt = buildMaintenance(currentMileages);
  const acc = buildAccessories();
  const ins = buildInsurance();
  const entries = [...mnt.entries, ...acc, ...ins];

  console.log('');
  console.log('整備記録・アクセサリーシード');
  console.log('----------------------------------------');
  console.log(`  整備記録        : ${mnt.count}`);
  console.log(`  アクセサリー    : ${acc.length}`);
  console.log(`  任意保険        : ${ins.length}`);
  console.log(`  合計ドキュメント: ${entries.length}`);
  console.log('');
  console.log('  車両ごとの整備記録:');
  Object.entries(mnt.perVehicle)
    .sort((x, y) => y[1] - x[1])
    .forEach(([label, n]) => console.log(`    ${String(n).padStart(3)} 件  ${label}`));
  console.log('');

  if (DRY_RUN) {
    console.log('[DRY-RUN] 書き込みは行いませんでした。');
    return;
  }

  if (DELETE) {
    await deleteInChunks(db, entries);
    console.log('');
    console.log(`[DONE] ${entries.length} 件を削除しました。`);
    return;
  }

  await commitInChunks(db, entries, '投入');
  console.log('');
  console.log(`[SUCCESS] ${entries.length} 件を Firestore に登録しました。`);
  console.log('');
  console.log('確認: 車両詳細の「整備記録」タブ / プロフィール →「みんなのアクセサリー」');
  console.log('後片付け: node seed_rich_history.js --delete' + (EMULATOR ? ' --emulator' : ''));
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
