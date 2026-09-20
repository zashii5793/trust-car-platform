#!/usr/bin/env node
/**
 * seed_year_of_use.js
 *
 * 「1年近く使い続けたユーザー」の状態を作る。
 *
 * なぜ要るか:
 *   既存のシードは、機能ごとに数件ずつデータを置くもので、**使い込んだ人の
 *   画面**にはならない。ドライブログは直近1か月に6件しかなく、給油記録は
 *   1件も無く、整備記録は 2026-05 で止まっていた。
 *
 *   その状態で画面を見ても分かるのは「機能が動くこと」だけで、**溜まった
 *   ときにどう見えるか**（並び順・件数・合計・スクロール量）は分からない。
 *   ホームに何を出すべきかは、溜まった状態でしか判断できない。
 *
 * 作るもの（断りのないものは user-a = persona.a@example.com に紐づく）:
 *   drive_logs        1年分の走行（通勤・仕事・週末・家族の遠出）
 *   drive_waypoints   直近ぶんだけ経路（地図が描けるのは2点以上から）
 *   fuel_records      1年分の給油（満タン法で燃費が出る並び）
 *   maintenance_records  A: rich_history が止まっている 2026-06 以降を補う
 *                        B: 法人20台の1年ぶん（フリートCSVの整備欄が埋まる）
 *   accessory_showcases  1年のあいだに書いたクチコミ
 *   inquiries         店舗とのやりとり（1年で8スレッド・未読と未対応を含む）
 *   inquiries/messages  その往復メッセージ
 *   vehicles          走行距離の更新日だけを今に寄せる（距離そのものは触らない）
 *
 * 走行距離の作り方:
 *   車両ドキュメントの現在の走行距離を**正**として、そこから1年ぶんを
 *   日割りで逆算する。ドライブログは走った日のうち記録に残した分だけなので、
 *   その合計をオドメーターにすると実際より少なくなる（燃費が倍にずれる）。
 *
 * Usage:
 *   node seed_year_of_use.js --emulator
 *   node seed_year_of_use.js --dry-run
 *   node seed_year_of_use.js --delete --emulator
 *
 * ⚠️ --emulator を付けないと本番 Firestore に書き込みます。
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

const SEED_TAG = 'year_of_use_v1';
const META = { isSeed: true, seedTag: SEED_TAG };
const USER_ID = 'user-a';

const DAY = 24 * 60 * 60 * 1000;
const NOW = Date.now();
const ts = (ms) => admin.firestore.Timestamp.fromDate(new Date(ms));
const daysAgo = (d) => NOW - d * DAY;

// 決定的な乱数。実行のたびに数字が変われば、画面の見え方を比べられない。
let _seed = 20260908;
function rand() {
  _seed = (_seed * 1103515245 + 12345) % 2147483648;
  return _seed / 2147483648;
}
const between = (a, b) => Math.round(a + rand() * (b - a));
const pick = (arr) => arr[Math.floor(rand() * arr.length) % arr.length];

// ---------------------------------------------------------------------------
// 車両。ID は seed_personas.js に合わせる。
//
// 既存の seed_drive_logs_persona_a.js は veh-a-roadster / veh-a-hiace /
// veh-a-note を使っているが、**その ID の車両は存在しない**（正しくは
// veh-a-sports / veh-a-cargo / veh-a-lease）。車両名が出ない状態だった。
// ---------------------------------------------------------------------------

const VEHICLES = [
  {
    id: 'veh-a-lease',
    label: '日産 ノート',
    // 1年でどれだけ走るか。車両ドキュメントの走行距離から逆算する起点。
    kmPerYear: 9600,
    kmPerLiter: 21.5,
    tankLiters: 35,
    use: 'commute',
  },
  {
    id: 'veh-a-cargo',
    label: 'トヨタ ハイエース',
    kmPerYear: 15000,
    kmPerLiter: 9.4,
    tankLiters: 70,
    use: 'work',
  },
  {
    id: 'veh-a-family',
    label: 'トヨタ アルファード',
    kmPerYear: 7200,
    kmPerLiter: 10.8,
    tankLiters: 75,
    use: 'family',
  },
  {
    id: 'veh-a-sports',
    label: 'マツダ ロードスター',
    kmPerYear: 4800,
    kmPerLiter: 14.2,
    tankLiters: 45,
    use: 'weekend',
  },
];

// ---------------------------------------------------------------------------
// ドライブログの素材
// ---------------------------------------------------------------------------

const HOME = [35.6465, 139.6533]; // 東京都世田谷区

/** 用途ごとの行き先。距離は往復のおおよそ。 */
const DESTINATIONS = {
  commute: [
    { title: '', address: '東京都港区', to: [35.6581, 139.7516], km: 12.4, min: 38, roads: ['cityRoad'] },
    { title: '', address: '東京都渋谷区', to: [35.658, 139.7016], km: 9.8, min: 32, roads: ['cityRoad'] },
    { title: '', address: '東京都千代田区', to: [35.6812, 139.7671], km: 15.2, min: 45, roads: ['cityRoad'] },
  ],
  work: [
    { title: '配送（川崎）', address: '神奈川県川崎市', to: [35.5308, 139.7029], km: 34.5, min: 68, roads: ['cityRoad', 'nationalRoad'] },
    { title: '現場まわり（横浜）', address: '神奈川県横浜市', to: [35.4437, 139.638], km: 52.3, min: 95, roads: ['highway', 'cityRoad'] },
    { title: '資材の引き取り（大宮）', address: '埼玉県さいたま市', to: [35.9066, 139.6238], km: 61.8, min: 105, roads: ['highway'] },
    { title: '買い出し（多摩）', address: '東京都多摩市', to: [35.6369, 139.4463], km: 31.8, min: 55, roads: ['cityRoad'] },
    { title: '納品（八王子）', address: '東京都八王子市', to: [35.6664, 139.316], km: 48.2, min: 82, roads: ['nationalRoad'] },
  ],
  family: [
    { title: '軽井沢へ family trip', address: '長野県軽井沢町', to: [36.3418, 138.6357], km: 172.6, min: 195, roads: ['highway'] },
    { title: '実家（宇都宮）へ', address: '栃木県宇都宮市', to: [36.5551, 139.8828], km: 118.4, min: 150, roads: ['highway'] },
    { title: '海ほたる経由で木更津', address: '千葉県木更津市', to: [35.3806, 139.9269], km: 86.5, min: 110, roads: ['highway'] },
    { title: '週末の買い物（二子玉川）', address: '東京都世田谷区', to: [35.6116, 139.6266], km: 8.4, min: 25, roads: ['cityRoad'] },
    { title: '潮干狩り（富津）', address: '千葉県富津市', to: [35.3129, 139.8352], km: 96.2, min: 125, roads: ['highway'] },
  ],
  weekend: [
    { title: '箱根までワインディング', address: '神奈川県箱根町', to: [35.2324, 139.1069], km: 128.4, min: 160, roads: ['highway', 'mountainRoad'] },
    { title: '海沿いを流す', address: '神奈川県逗子市', to: [35.2955, 139.5803], km: 64.2, min: 80, roads: ['coastalRoad', 'nationalRoad'] },
    { title: '奥多摩湖まで', address: '東京都奥多摩町', to: [35.7896, 139.0483], km: 112.8, min: 145, roads: ['mountainRoad'] },
    { title: '宮ヶ瀬湖 早朝', address: '神奈川県清川村', to: [35.5233, 139.2478], km: 92.6, min: 120, roads: ['mountainRoad'] },
    { title: '伊豆スカイライン', address: '静岡県伊豆市', to: [34.9756, 138.9463], km: 186.4, min: 240, roads: ['highway', 'mountainRoad'] },
    { title: '秩父まで下道で', address: '埼玉県秩父市', to: [35.9917, 139.0786], km: 138.2, min: 190, roads: ['nationalRoad', 'mountainRoad'] },
  ],
};

/** 季節の一言。1年ぶんを並べたときに、同じ文が続かないようにする。 */
const NOTES = {
  weekend: [
    '朝いちで出たので空いていた。屋根を開けたまま帰宅。',
    '峠の途中で雨。タイヤを替えたばかりで良かった。',
    '紅葉がきれいだった。写真を撮るために何度も止まった。',
    '寒くて屋根は開けられず。それでも走ると気分が変わる。',
    '路面が乾いていて気持ちよく走れた。',
    '帰りに渋滞。次はもう少し早く帰る。',
    '桜が満開。行きも帰りも下道にした。',
    '暑い。エアコンを入れっぱなしで燃費が落ちた。',
  ],
  family: [
    '渋滞を避けて早朝に出たのが正解だった。',
    '子どもが後ろで寝ていたので、サービスエリアは1回だけ。',
    '荷物が多く、3列目は畳んだまま。',
    '帰りは下道。時間はかかったが混んでいなかった。',
    '',
  ],
  work: ['', '', '', '積み下ろしに時間がかかった。', '高速を使ったぶん早く終わった。'],
  commute: ['', '', '', ''],
};

const WEATHER = ['sunny', 'sunny', 'cloudy', 'cloudy', 'rainy'];

/** 2点を直線で刻んだ経路。地図に線が出れば十分。 */
function route(to, steps, startMs, minutes) {
  const out = [];
  for (let i = 0; i <= steps; i++) {
    const r = i / steps;
    out.push({
      latitude: HOME[0] + (to[0] - HOME[0]) * r,
      longitude: HOME[1] + (to[1] - HOME[1]) * r,
      at: new Date(startMs + minutes * 60000 * r),
    });
  }
  return out;
}

/**
 * 1年ぶんの走行を組み立てる。
 *
 * 用途ごとに「何日おきに乗るか」を決めて、365日を刻む。**通勤を毎日入れると
 * 一覧が通勤で埋まる**ので、記録として残す頻度（週1〜2回）に留める。
 */
function buildDrives() {
  const cadence = { commute: 4, work: 6, family: 24, weekend: 11 };
  const drives = [];

  VEHICLES.forEach((v) => {
    const every = cadence[v.use];
    for (let d = 358; d >= 1; d -= every) {
      const day = d - between(0, Math.max(1, Math.floor(every / 2)));
      if (day < 1) continue;
      const dest = pick(DESTINATIONS[v.use]);
      // 同じ行き先でも距離は毎回きっちり同じにはならない。
      const km = Number((dest.km * (0.92 + rand() * 0.16)).toFixed(1));
      const min = Math.round(dest.min * (0.9 + rand() * 0.2));
      const hour = v.use === 'commute' ? 8 : v.use === 'work' ? 9 : between(6, 10);
      const start = daysAgo(day) - (24 - hour) * 60 * 60 * 1000;
      drives.push({
        vehicle: v,
        day,
        start,
        minutes: min,
        km,
        dest,
        weather: pick(WEATHER),
        note: pick(NOTES[v.use]),
        // 公開するのは週末と家族の遠出だけ。通勤と仕事は自分の記録。
        isPublic: v.use === 'weekend' || v.use === 'family',
      });
    }
  });

  drives.sort((a, b) => a.start - b.start);
  return drives;
}

/**
 * 給油。
 *
 * オドメーターは**ドライブログの合計ではなく、車両の走行距離を1年で割った
 * ペース**で進める。ドライブログに残すのは走った日のうちの一部で、記録した
 * 分だけを足すと、実際の給油量と合わなくなる（燃費が2倍3倍にずれる）。
 */
function buildFuel(startOdo, currentOdo) {
  const records = [];

  VEHICLES.forEach((v) => {
    // タンクの7割ほど使ったら入れる、という頻度。
    const kmPerRefill = v.kmPerLiter * v.tankLiters * 0.7;
    const kmPerDay = v.kmPerYear / 365;
    const daysPerRefill = Math.max(4, Math.round(kmPerRefill / kmPerDay));
    let n = 0;

    for (let d = 358; d >= 2; d -= daysPerRefill) {
      const day = Math.max(1, d - between(0, 2));
      // その日のオドメーター。1年前の値から日割りで進める。
      const odo = Math.round(
        startOdo[v.id] +
          (currentOdo[v.id] - startOdo[v.id]) * ((365 - day) / 365),
      );
      // 前回からの走行分を入れる。満タン法なので、入れた量＝使った量。
      const km = kmPerRefill * (0.85 + rand() * 0.3);
      const liters = Number((km / v.kmPerLiter).toFixed(2));
      // 2025年秋〜2026年秋のレギュラー価格の幅（円/L）。
      const pricePerLiter = between(165, 182);
      n++;
      records.push({
        id: `fuel-yu-${v.id}-${String(n).padStart(2, '0')}`,
        vehicleId: v.id,
        date: daysAgo(day) - 6 * 60 * 60 * 1000,
        liters,
        cost: Math.round(liters * pricePerLiter),
        odometer: odo,
        isFullTank: true,
      });
    }
  });

  return records;
}

// ---------------------------------------------------------------------------
// 整備記録。rich_history が 2026-05 で止まっているので、そこから今日までを補う。
// ---------------------------------------------------------------------------

const MAINTENANCE = [
  { vehicleId: 'veh-a-cargo', type: 'oilChange', title: 'エンジンオイル交換', cost: [5200, 6800], daysAgo: 118, shop: 'テストオート品川整備センター', note: '10,000km ごとに交換。次は12月ごろ。' },
  { vehicleId: 'veh-a-cargo', type: 'tireChange', title: 'タイヤ交換（前後4本）', cost: [62000, 78000], daysAgo: 96, shop: 'テストオート品川整備センター', note: '溝が残り2分山だったので4本まとめて。空車と積載で減り方が違う。' },
  { vehicleId: 'veh-a-cargo', type: 'legalInspection24', title: '車検（継続検査）', cost: [128000, 148000], daysAgo: 71, shop: 'テストオート品川整備センター', note: 'ブレーキパッドも一緒に交換。next の見積もりは出してもらった。' },
  { vehicleId: 'veh-a-cargo', type: 'oilChange', title: 'エンジンオイル交換', cost: [5200, 6800], daysAgo: 24, shop: 'テストオート品川整備センター', note: '' },
  { vehicleId: 'veh-a-family', type: 'oilChange', title: 'エンジンオイル交換', cost: [6200, 7600], daysAgo: 104, shop: '世田谷テストサービス工場', note: '' },
  { vehicleId: 'veh-a-family', type: 'batteryChange', title: 'バッテリー交換', cost: [24000, 32000], daysAgo: 63, shop: '世田谷テストサービス工場', note: 'エンジンのかかりが重かった。5年もった。' },
  { vehicleId: 'veh-a-family', type: 'other', title: 'エアコンフィルター交換', cost: [3200, 4800], daysAgo: 38, shop: '世田谷テストサービス工場', note: '花粉の時期の前に。自分でも替えられるが、点検のついでに頼んだ。' },
  { vehicleId: 'veh-a-lease', type: 'inspection', title: '12ヶ月点検', cost: [14000, 18000], daysAgo: 88, shop: '日産テスト販売 世田谷店', note: 'リース契約に含まれる点検。' },
  { vehicleId: 'veh-a-lease', type: 'oilChange', title: 'エンジンオイル交換', cost: [4200, 5400], daysAgo: 33, shop: '日産テスト販売 世田谷店', note: '' },
  { vehicleId: 'veh-a-sports', type: 'tireChange', title: 'タイヤ交換（前後4本）', cost: [78000, 96000], daysAgo: 132, shop: '横浜テストモータース', note: '4年目。ひび割れが出てきたので早めに。' },
  { vehicleId: 'veh-a-sports', type: 'oilChange', title: 'エンジンオイル交換', cost: [7800, 9600], daysAgo: 57, shop: '横浜テストモータース', note: '峠を走ったあとなので早めに交換。' },
  { vehicleId: 'veh-a-sports', type: 'other', title: 'ワイパーゴム交換', cost: [1200, 2200], daysAgo: 12, shop: '', note: '自分で交換。1,200円ほど。' },
];

// ---------------------------------------------------------------------------
// アクセサリーのクチコミ。1年のあいだに書いたもの。
// ---------------------------------------------------------------------------

const SHOWCASES = [
  {
    id: 'acc-yu-tirepressure', vehicleId: 'veh-a-cargo', category: 'electronics',
    itemName: 'タイヤ空気圧センサー（4輪モニター）', brand: 'ミナモ', priceApprox: 12800, rating: 4,
    daysAgo: 210, helpful: 7,
    review: '荷物を積む日と空車の日で空気圧が変わるのが分かるようになりました。'
      + '警告が鳴るほどではない差でも数字で見えるので、給油のついでに調整しています。',
  },
  {
    id: 'acc-yu-ledroom', vehicleId: 'veh-a-family', category: 'interior',
    itemName: 'LEDルームランプセット', brand: 'トキワ', priceApprox: 4200, rating: 5,
    daysAgo: 165, helpful: 4,
    review: '後席が明るくなって、子どもが本を読めるようになりました。'
      + '取り付けは工具なしで15分ほど。',
  },
  {
    id: 'acc-yu-etc2', vehicleId: 'veh-a-sports', category: 'electronics',
    itemName: 'ETC2.0 車載器', brand: 'ヤマセミ', priceApprox: 18500, rating: 4,
    daysAgo: 98, helpful: 11,
    review: '渋滞の迂回情報が出るのが便利です。取り付けは工場に頼みました（工賃 5,500円）。'
      + '高速をよく使うなら元は取れると思います。',
  },
  {
    id: 'acc-yu-cooler', vehicleId: 'veh-a-family', category: 'other',
    itemName: '車載用ポータブル冷蔵庫 15L', brand: 'コトブキ', priceApprox: 21800, rating: 3,
    daysAgo: 44, helpful: 6,
    review: '夏の遠出には便利でしたが、思ったより音がします。'
      + '走行中は気になりませんが、車中泊では気になる人がいるかもしれません。',
  },
];

// ---------------------------------------------------------------------------
// 店舗とお客様のチャット（inquiries + inquiries/{id}/messages）
//
// なぜ1年ぶんが要るか:
//   既存の seed_full_experience.js は問い合わせ4件・返信5通の「スナップショット」
//   で、**続いている付き合い**にはならない。1年使った人の画面では、問い合わせは
//   溜まって並び、古いものは閉じ、直近のものだけが未読で上に来る。その見え方は
//   件数がそろって初めて確かめられる。
//
// 相手はタカヤモーター（shop_takaya_motor_okayama）を主にする:
//   店の文書ID = 店主の uid なので、**店側でもログインして同じ会話を開ける**。
//   fx-shop-* には Auth ユーザーが無く、お客様側からしか見えない。
//
// 会話の中身は MAINTENANCE の整備記録と噛み合わせてある（見積もり → 入庫 →
// 完了 → 次回の案内）。整備履歴とチャットが別々の作り話だと、突き合わせた
// ときに辻褄が合わない。
// ---------------------------------------------------------------------------

const SHOP_TAKAYA = { id: 'shop_takaya_motor_okayama', name: 'タカヤモーター株式会社' };
const SHOP_SHINAGAWA = { id: 'fx-shop-shinagawa', name: 'テストオート品川整備センター' };

/**
 * m: メッセージ。fromShop=true なら店舗発。
 * daysAgo は「何日前のやりとりか」。スレッド内は必ず新しい順に下る。
 */
const CHAT_THREADS = [
  {
    id: 'inq-yu-01-oil-first',
    shop: SHOP_TAKAYA,
    vehicleId: 'veh-a-cargo',
    type: 'appointment',
    status: 'closed',
    subject: 'ハイエースのオイル交換をお願いしたいです',
    daysAgo: 312,
    initial: 'はじめまして。ハイエース（品川400か22-22）のオイル交換をお願いしたいのですが、'
      + '今週の土曜日は空いていますか。走行は8万kmを超えたところです。',
    messages: [
      { fromShop: true, daysAgo: 311, text: 'お問い合わせありがとうございます。土曜は14時以降でしたらお取りできます。'
        + '8万km超でしたらオイルエレメントも一緒の交換をおすすめします。合わせて6,500円前後です。' },
      { fromShop: false, daysAgo: 311, text: '14時でお願いします。エレメントも一緒でお願いします。' },
      { fromShop: true, daysAgo: 310, text: '承知しました。土曜14時でお待ちしております。所要は40分ほどです。' },
      { fromShop: true, daysAgo: 309, text: '本日はありがとうございました。次回の交換の目安は9万kmか、半年後の頃合いです。' },
    ],
  },
  {
    id: 'inq-yu-02-roadster-tire',
    shop: SHOP_TAKAYA,
    vehicleId: 'veh-a-sports',
    type: 'estimate',
    status: 'closed',
    subject: 'ロードスターのタイヤ交換の見積もりをお願いします',
    daysAgo: 141,
    initial: 'ロードスターのタイヤにひび割れが出てきました。4年目です。'
      + '前後4本の交換で、銘柄のおすすめも含めて見積もりをいただけますか。',
    messages: [
      { fromShop: true, daysAgo: 140, text: 'ひび割れは側面でしょうか。写真を送っていただけると判断しやすいです。'
        + '純正サイズ195/50R16でしたら、静かさ重視と走り重視で2案お出しできます。' },
      { fromShop: false, daysAgo: 140, text: '側面です。峠も走るので、どちらかというと走り重視でお願いします。' },
      { fromShop: true, daysAgo: 139, text: '走り重視の銘柄で工賃・廃タイヤ処分込み 88,000円前後でいかがでしょうか。'
        + '在庫は取り寄せで3日ほどいただきます。' },
      { fromShop: false, daysAgo: 138, text: 'それでお願いします。来週の土曜に持ち込みます。' },
      { fromShop: true, daysAgo: 132, text: '交換完了しました。慣らしの100kmは急のつく操作を控えてください。'
        + '1か月後に増し締めの点検をおすすめします（無料です）。' },
    ],
  },
  {
    id: 'inq-yu-03-hiace-shaken',
    shop: SHOP_TAKAYA,
    vehicleId: 'veh-a-cargo',
    type: 'estimate',
    status: 'closed',
    subject: 'ハイエースの車検見積もりをお願いします',
    daysAgo: 84,
    initial: 'ハイエースの車検が来月末で切れます。貨物なので毎年で、今年もお願いしたいです。'
      + '概算をいただけますか。ブレーキの効きが少し甘い気がします。',
    messages: [
      { fromShop: true, daysAgo: 83, text: '承知しました。貨物の継続検査は法定費用込みで 128,000〜148,000円が目安です。'
        + 'ブレーキは入庫時に点検します。パッドが残り2mmを切っていれば交換をご提案します。' },
      { fromShop: false, daysAgo: 83, text: 'ありがとうございます。パッド交換込みだといくらぐらいになりますか。' },
      { fromShop: true, daysAgo: 82, text: '前後パッド交換で +22,000円ほどです。見てからのご相談でも間に合います。' },
      { fromShop: false, daysAgo: 78, text: '来週の火曜に入庫でお願いします。代車はお借りできますか。' },
      { fromShop: true, daysAgo: 77, text: '火曜9時で承りました。代車をご用意します。車検証と自賠責をお持ちください。' },
      { fromShop: true, daysAgo: 71, text: '車検が完了しました。ブレーキパッドは前後とも交換しています。'
        + '明細をこのスレッドに添付しました。次回は来年の同じ時期です。' },
    ],
  },
  {
    id: 'inq-yu-04-alphard-battery',
    shop: SHOP_TAKAYA,
    vehicleId: 'veh-a-family',
    type: 'serviceInquiry',
    status: 'closed',
    subject: 'アルファードのエンジンのかかりが重いです',
    daysAgo: 66,
    initial: '朝いちばんのエンジンのかかりが重くなってきました。5年ほど替えていません。'
      + 'バッテリーでしょうか。週末に家族で出かける予定があるので、その前に見てほしいです。',
    messages: [
      { fromShop: true, daysAgo: 65, text: '5年でしたら寿命の範囲です。無料で点検できますので、'
        + '明日でもお持ちください。交換の場合は 24,000〜32,000円が目安です。' },
      { fromShop: false, daysAgo: 64, text: '明日の午前に伺います。' },
      { fromShop: true, daysAgo: 63, text: '点検の結果、充電の戻りが弱く交換をおすすめする状態でした。'
        + '本日交換まで済んでいます。これで週末は安心してお出かけいただけます。' },
    ],
  },
  {
    id: 'inq-yu-05-note-lease-end',
    shop: SHOP_SHINAGAWA,
    vehicleId: 'veh-a-lease',
    type: 'general',
    status: 'closed',
    subject: 'リース満了前の点検について',
    daysAgo: 47,
    initial: 'ノートのリース満了が近づいています。返却前に見ておいた方がよい点はありますか。',
    messages: [
      { fromShop: true, daysAgo: 46, text: '返却時の査定で見られるのは、外装の傷・内装の汚れ・タイヤの残り溝です。'
        + '小傷はそのままの方が安く済むことが多いので、まずは現状のままお持ちください。' },
      { fromShop: false, daysAgo: 45, text: '分かりました。タイヤは見ておきます。ありがとうございます。' },
    ],
  },
  {
    id: 'inq-yu-06-aircon-filter',
    shop: SHOP_TAKAYA,
    vehicleId: 'veh-a-family',
    type: 'appointment',
    status: 'closed',
    subject: 'エアコンフィルターの交換をお願いします',
    daysAgo: 41,
    initial: '花粉の時期の前にエアコンフィルターを替えたいです。点検のついでにお願いできますか。',
    messages: [
      { fromShop: true, daysAgo: 40, text: 'もちろん可能です。部品代込みで 3,200〜4,800円、作業は15分ほどです。' },
      { fromShop: false, daysAgo: 39, text: 'ではお願いします。' },
      { fromShop: true, daysAgo: 38, text: '交換しました。前のフィルターはかなり詰まっていました。'
        + '1年ごとの交換をおすすめします。' },
    ],
  },
  {
    id: 'inq-yu-07-hiace-oil-recent',
    shop: SHOP_TAKAYA,
    vehicleId: 'veh-a-cargo',
    type: 'appointment',
    status: 'replied',
    subject: 'ハイエースのオイル交換の時期でしょうか',
    daysAgo: 27,
    initial: '前回の交換から1万km近く走りました。そろそろでしょうか。来週あたりで空いている日はありますか。',
    messages: [
      { fromShop: false, daysAgo: 26, text: '今の走行は 96,400km ほどです。' },
      { fromShop: true, daysAgo: 25, text: 'ちょうど良い時期です。来週でしたら水曜・木曜の午前が空いています。' },
      // 最後の1通は**お客様が未読**。一覧でバッジが付いて見える状態を作る。
      { fromShop: true, daysAgo: 24, text: '本日交換分の明細をお送りします。次回は10万kmの頃合いでご案内します。', unread: true },
    ],
  },
  {
    id: 'inq-yu-08-roadster-noise',
    shop: SHOP_TAKAYA,
    vehicleId: 'veh-a-sports',
    type: 'serviceInquiry',
    status: 'pending',
    subject: 'ロードスターから異音がします（相談）',
    daysAgo: 3,
    // 店舗側が**まだ返していない**スレッド。店側の一覧で「未対応」として見える。
    initial: '低速で曲がるときに、右前あたりから「コトコト」という音がするようになりました。'
      + '走行に支障は無さそうですが、一度見ていただけますか。今週末は空いていますか。',
    messages: [],
  },
];

// ---------------------------------------------------------------------------

admin.initializeApp({ projectId: 'trust-car-platform' });
const db = admin.firestore();

async function wipe() {
  const cols = [
    'drive_logs',
    'drive_waypoints',
    'fuel_records',
    'maintenance_records',
    'accessory_showcases',
  ];
  for (const c of cols) {
    const snap = await db.collection(c).where('seedTag', '==', SEED_TAG).get();
    // batch は500件まで。1年ぶんは超える。
    for (let i = 0; i < snap.docs.length; i += 400) {
      const batch = db.batch();
      snap.docs.slice(i, i + 400).forEach((d) => batch.delete(d.ref));
      await batch.commit();
    }
    console.log(`[DELETE] ${c}: ${snap.size} 件`);
  }

  // 問い合わせは messages サブコレクションを持つ。親だけ消すと**メッセージが
  // 孤児として残り**、同じ ID で流し直したときに古い会話が混ざる。
  const inq = await db
    .collection('inquiries')
    .where('seedTag', '==', SEED_TAG)
    .get();
  let msgCount = 0;
  for (const d of inq.docs) {
    const msgs = await d.ref.collection('messages').get();
    msgCount += msgs.size;
    for (let i = 0; i < msgs.docs.length; i += 400) {
      const batch = db.batch();
      msgs.docs.slice(i, i + 400).forEach((m) => batch.delete(m.ref));
      await batch.commit();
    }
    await d.ref.delete();
  }
  console.log(`[DELETE] inquiries: ${inq.size} 件（messages ${msgCount} 件）`);
}

async function main() {
  if (DELETE) {
    await wipe();
    console.log('\n削除しました。');
    return;
  }

  // 車両の現在の走行距離を読み、1年前の値を逆算する。
  const startOdo = {};
  const currentOdo = {};
  // 問い合わせは車名をそのまま持つ（`Inquiry.vehicleDisplay` が使う）。
  // 一覧で「トヨタ ハイエース」と出るのはこの写しで、車両を引き直さない。
  const vehicleInfo = {};
  for (const v of VEHICLES) {
    const doc = await db.collection('vehicles').doc(v.id).get();
    const mileage = doc.exists ? doc.data().mileage : v.kmPerYear * 3;
    currentOdo[v.id] = mileage;
    startOdo[v.id] = Math.max(0, mileage - v.kmPerYear);
    const d = doc.exists ? doc.data() : {};
    vehicleInfo[v.id] = {
      maker: d.maker || null,
      model: d.model || null,
      year: d.year || null,
    };
  }

  const drives = buildDrives();
  const fuel = buildFuel(startOdo, currentOdo);

  const entries = [];

  // ---- ドライブログ ----
  drives.forEach((d, i) => {
    const id = `dl-yu-${String(i).padStart(3, '0')}`;
    const endAt = d.start + d.minutes * 60000;
    entries.push({
      col: 'drive_logs',
      id,
      data: {
        userId: USER_ID,
        vehicleId: d.vehicle.id,
        status: 'completed',
        title: d.dest.title,
        description: d.note,
        startLocation: { latitude: HOME[0], longitude: HOME[1] },
        endLocation: { latitude: d.dest.to[0], longitude: d.dest.to[1] },
        startAddress: '東京都世田谷区',
        endAddress: d.dest.address,
        startTime: ts(d.start),
        endTime: ts(endAt),
        statistics: {
          totalDistance: d.km,
          totalDuration: d.minutes * 60,
          averageSpeed: Number((d.km / (d.minutes / 60)).toFixed(1)),
          maxSpeed: Number((d.km / (d.minutes / 60) * 1.6).toFixed(1)),
          stopCount: between(1, 5),
          totalStopDuration: between(120, 1200),
        },
        weather: d.weather,
        roadTypes: d.dest.roads,
        photoUrls: [],
        isPublic: d.isPublic,
        likeCount: d.isPublic ? between(0, 12) : 0,
        commentCount: 0,
        tags: [],
        createdAt: ts(endAt),
        updatedAt: ts(endAt),
        ...META,
      },
    });

    // 経路は直近12件だけ。全部に付けると2000件を超えるが、地図を見るのは
    // たいてい最近の記録なので、その分だけあればよい。
    if (drives.length - i <= 12) {
      route(d.dest.to, 20, d.start, d.minutes).forEach((p, k) => {
        entries.push({
          col: 'drive_waypoints',
          id: `${id}-wp-${String(k).padStart(3, '0')}`,
          data: {
            driveLogId: id,
            userId: USER_ID, // ルールが要求する。アプリの addWaypoint は書いていない
            location: { latitude: p.latitude, longitude: p.longitude },
            timestamp: admin.firestore.Timestamp.fromDate(p.at),
            speed: Number((d.km / (d.minutes / 60)).toFixed(1)),
            ...META,
          },
        });
      });
    }
  });

  // ---- 給油 ----
  fuel.forEach((f) => {
    entries.push({
      col: 'fuel_records',
      id: f.id,
      data: {
        vehicleId: f.vehicleId,
        userId: USER_ID,
        date: ts(f.date),
        liters: f.liters,
        cost: f.cost,
        odometer: f.odometer,
        isFullTank: f.isFullTank,
        createdAt: ts(f.date),
        ...META,
      },
    });
  });

  // ---- 整備記録 ----
  MAINTENANCE.forEach((m, i) => {
    const date = daysAgo(m.daysAgo);
    // その日のオドメーターは、現在の距離から日割りで戻す。
    const v = VEHICLES.find((x) => x.id === m.vehicleId);
    const mileage = Math.round(
      currentOdo[m.vehicleId] - (v.kmPerYear * m.daysAgo) / 365,
    );
    entries.push({
      col: 'maintenance_records',
      id: `mnt-yu-${String(i).padStart(2, '0')}`,
      data: {
        vehicleId: m.vehicleId,
        userId: USER_ID,
        type: m.type,
        title: m.title,
        description: m.note,
        cost: between(m.cost[0], m.cost[1]),
        shopName: m.shop,
        date: ts(date),
        mileageAtService: Math.max(0, mileage),
        imageUrls: [],
        createdAt: ts(date + 3 * 60 * 60 * 1000),
        updatedAt: ts(date + 3 * 60 * 60 * 1000),
        ...META,
      },
    });
  });

  // ---- アクセサリーのクチコミ ----
  SHOWCASES.forEach((s) => {
    const date = daysAgo(s.daysAgo);
    entries.push({
      col: 'accessory_showcases',
      id: s.id,
      data: {
        userId: USER_ID,
        vehicleId: s.vehicleId,
        category: s.category,
        itemName: s.itemName,
        brand: s.brand,
        priceApprox: s.priceApprox,
        rating: s.rating,
        review: s.review,
        imageUrls: [],
        helpfulCount: s.helpful,
        isPublic: true,
        createdAt: ts(date),
        updatedAt: ts(date),
        ...META,
      },
    });
  });

  // ---- 法人フリート（ペルソナB）の1年ぶんの整備 ----
  //
  // B の20台には整備記録が1件も無かった。フリート画面の CSV 出力は
  // `FleetService.getMaintenanceSummaries` で整備欄を埋めるので、記録が無いと
  // **出力は通るのに整備欄だけ空**になり、直っているのか壊れているのか
  // 区別が付かない。1台あたり2〜3件を1年に散らす。
  const FLEET_MENU = [
    { type: 'oilChange', title: 'エンジンオイル交換', cost: [5400, 7200] },
    { type: 'inspection', title: '12ヶ月点検', cost: [14000, 19000] },
    { type: 'tireChange', title: 'タイヤ交換（前後4本）', cost: [58000, 74000] },
    { type: 'legalInspection24', title: '車検（継続検査）', cost: [118000, 142000] },
    { type: 'other', title: 'ブレーキパッド交換', cost: [18000, 26000] },
  ];
  for (let v = 0; v < 20; v += 1) {
    const vehicleId = `veh-b-fleet-${String(v).padStart(2, '0')}`;
    const howMany = 2 + (v % 2); // 2 件か 3 件
    for (let k = 0; k < howMany; k += 1) {
      const menu = pick(FLEET_MENU);
      // 1年を台数ぶんずらして散らす。同じ日に20台まとめて入庫はしない。
      const ago = between(20, 350);
      entries.push({
        col: 'maintenance_records',
        id: `mnt-yu-fleet-${String(v).padStart(2, '0')}-${k}`,
        data: {
          vehicleId,
          userId: 'president-uid',
          type: menu.type,
          title: menu.title,
          description: '',
          cost: between(menu.cost[0], menu.cost[1]),
          shopName: 'タカヤモーター株式会社',
          date: ts(daysAgo(ago)),
          mileageAtService: 20000 + v * 3500 - Math.round((ago / 365) * 18000),
          imageUrls: [],
          createdAt: ts(daysAgo(ago)),
          updatedAt: ts(daysAgo(ago)),
          ...META,
        },
      });
    }
  }

  // ---- 店舗とお客様のチャット ----
  //
  // 初回の相談は inquiry.initialMessage に入り、messages サブコレクションには
  // 入らない（lib/models/inquiry.dart の作り）。messageCount は 1 + 返信数。
  CHAT_THREADS.forEach((t) => {
    const opened = daysAgo(t.daysAgo);
    const replies = t.messages;
    const last = replies.length > 0 ? replies[replies.length - 1] : null;
    const lastAt = last ? daysAgo(last.daysAgo) : opened;

    // 未読数は「相手が送って、まだ読んでいない通数」。
    const unreadUser = replies.filter((m) => m.fromShop && m.unread).length;
    const unreadShop = replies.filter((m) => !m.fromShop && m.unread).length
      + (replies.length === 0 ? 1 : 0); // 返信0件＝店舗がまだ初回を読んでいない

    const firstShopReply = replies.find((m) => m.fromShop);

    entries.push({
      col: 'inquiries',
      id: t.id,
      data: {
        userId: USER_ID,
        shopId: t.shop.id,
        shopName: t.shop.name,
        vehicleId: t.vehicleId,
        vehicleMaker: vehicleInfo[t.vehicleId]?.maker ?? null,
        vehicleModel: vehicleInfo[t.vehicleId]?.model ?? null,
        vehicleYear: vehicleInfo[t.vehicleId]?.year ?? null,
        partListingId: null,
        type: t.type,
        status: t.status,
        subject: t.subject,
        initialMessage: t.initial,
        attachmentUrls: [],
        messageCount: 1 + replies.length,
        unreadCountUser: unreadUser,
        unreadCountShop: unreadShop,
        createdAt: ts(opened),
        updatedAt: ts(lastAt),
        repliedAt: firstShopReply ? ts(daysAgo(firstShopReply.daysAgo)) : null,
        closedAt: t.status === 'closed' ? ts(lastAt) : null,
        ...META,
      },
    });

    replies.forEach((m, i) => {
      const at = daysAgo(m.daysAgo);
      entries.push({
        // サブコレクション。col ではなくパスで指定する。
        path: `inquiries/${t.id}/messages/msg-yu-${String(i).padStart(2, '0')}`,
        col: 'inquiries/messages',
        data: {
          senderId: m.fromShop ? t.shop.id : USER_ID,
          isFromShop: m.fromShop,
          content: m.text,
          attachmentUrls: [],
          sentAt: ts(at),
          isRead: !m.unread,
          ...META,
        },
      });
    });
  });

  // ---- 「最近ちゃんと入力している人」に見えるよう、更新日だけ今に寄せる ----
  //
  // **走行距離そのものは書き換えない。** この スクリプトは車両の走行距離を
  // 起点に1年ぶんを逆算するので、計算結果を書き戻すと、流すたびに距離が
  // 下がっていく（2回流したら 15,000km の車が 5,912km になった）。
  VEHICLES.forEach((v) => {
    entries.push({
      col: 'vehicles',
      id: v.id,
      data: {
        mileageUpdatedAt: ts(daysAgo(between(2, 9))),
      },
    });
  });

  // ---- 集計と書き込み ----
  const byCol = {};
  entries.forEach((e) => {
    byCol[e.col] = (byCol[e.col] || 0) + 1;
  });

  console.log('■ 1年ぶんの利用データ（主に user-a / persona.a@example.com）');
  console.log('  ※ maintenance_records には法人B（president-uid）の20台ぶんを含む');
  Object.entries(byCol).forEach(([c, n]) => console.log(`  ${c.padEnd(22)} ${n} 件`));
  const totalKm = drives.reduce((s, d) => s + d.km, 0);
  const totalFuelCost = fuel.reduce((s, f) => s + f.cost, 0);
  console.log(`  走行 ${Math.round(totalKm).toLocaleString()} km / 給油代 ${totalFuelCost.toLocaleString()} 円`);

  if (DRY_RUN) {
    console.log('\n--dry-run のため書き込みませんでした。');
    return;
  }

  for (let i = 0; i < entries.length; i += 400) {
    const batch = db.batch();
    entries.slice(i, i + 400).forEach((e) => {
      const ref = e.path ? db.doc(e.path) : db.collection(e.col).doc(e.id);
      batch.set(ref, e.data, { merge: true });
    });
    await batch.commit();
  }

  console.log(`\n[SUCCESS] ${entries.length} 件を登録しました。`);
  console.log('確認: persona.a@example.com / password123 でログイン');
  console.log(`後片付け: node seed_year_of_use.js --delete${EMULATOR ? ' --emulator' : ''}`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
