#!/usr/bin/env node
/**
 * seed_shop_ledger_year.js
 *
 * タカヤモーターの顧客台帳を「1年運用した状態」にする。
 *
 * なぜ要るか:
 *   店側の画面（顧客台帳・車検の近い順・しばらく来ていない・取りこぼし・
 *   送っていない明細・操作の記録）は、**4,000人規模でどう見えるか**が
 *   使用感の芯になる（docs/USABILITY_TEST_PROMPT.md プロンプト2）。
 *   ところが台帳を作るシードが1本も無く、店主でログインしても台帳は空だった。
 *
 * 作るもの（shops/shop_takaya_motor_okayama の下）:
 *   customers          個人 4,000（ペルソナ A・C を含む）・法人 100（ペルソナ J を含む）
 *   customer_vehicles  顧客の車。法人は 2〜20 台
 *   service_records    整備履歴（伝票）。直近1年分＋しばらく来ていない客の最後の来店
 *   audit_logs         1年分の操作の記録（店主とスタッフ）
 *   members            店主（owner）とスタッフ4人（staff）
 *
 * ほかに:
 *   shop_staff / shop_staff_invites   スタッフの札と、使った招待コード
 *   users + Auth                      スタッフ4人（--emulator のときだけ）
 *   shop_invites                      ペルソナ A/C/J に出した顧客専用コード（使用済み）
 *   shop_customers                    A/C/J の札に、台帳の顧客ID（customerId・inviteCode）を足す
 *   inquiries / messages              店から開いたスレッドと、送った整備明細
 *   maintenance_records               A/C/J が「記録に追加」した明細（出所: shopImported）
 *
 * 形はアプリと同じにしてある（ここがずれると、アプリの検索が当たらない）:
 *   - searchKey / plateKey / plateNumber は lib/models/shop_ledger.dart の
 *     LedgerSearch と同じ計算（このファイルの nameKey / plateKey / plateNumber）
 *   - 取込由来の ID は ShopLedgerService.idForExternal と同じ（c_ / v_ / r_ + 番号）
 *   - 顧客の vehicleCount / nextInspectionAt / lastVisitAt は
 *     LedgerCustomerSummary.of と同じ規則（切れた車検は「次の車検」に数えない）
 *   - 明細の送付は DetailDeliveryService と同じ形（店から開いたスレッドに
 *     maintenancePayload 付きのメッセージ。伝票に detailSentAt / detailInquiryId）
 *   - 取り込んだ明細は buildMaintenanceRecordFromPayload と同じ形（inquiryId 付き。
 *     verificationSource は 'shopImported'）
 *
 * 日付は「今日の0時」から数える。同じ日に流し直せば同じデータになる
 * （乱数は固定シード）。流し直すと、前回の分のうち今回作らなかったものは消す。
 *
 * Usage:
 *   node seed_shop_ledger_year.js --emulator
 *   node seed_shop_ledger_year.js --dry-run
 *   node seed_shop_ledger_year.js --delete --emulator
 *   node seed_shop_ledger_year.js --emulator --today=2026-10-08   # 基準日を固定
 *
 * **--emulator を付けないと何も書かない**（--dry-run を除き、起動時に止める）。
 * 接続先が localhost / 127.0.0.1 でなければ、--emulator でも止める。
 *
 * 前提: seed_shops.js → seed_personas.js → seed_shop_owner.js を先に流すこと。
 */

const has = (f) => process.argv.includes(f);
const argValue = (name) => {
  const a = process.argv.find((x) => x.startsWith(`--${name}=`));
  return a ? a.slice(name.length + 3) : null;
};
const EMULATOR = has('--emulator');
const DRY_RUN = has('--dry-run');
const DELETE = has('--delete');

// 本番保護。require されたとき（verify_shop_ledger.js が検索キーの関数を
// 借りるとき）は何もしない。
function guardTarget() {
  if (!EMULATOR && !DRY_RUN) {
    console.error('[ERROR] 本番保護のため、--emulator か --dry-run を付けてください。');
    process.exit(1);
  }
  if (EMULATOR) {
    process.env.FIRESTORE_EMULATOR_HOST =
      process.env.FIRESTORE_EMULATOR_HOST || 'localhost:8080';
    process.env.FIREBASE_AUTH_EMULATOR_HOST =
      process.env.FIREBASE_AUTH_EMULATOR_HOST || 'localhost:9099';
    for (const k of ['FIRESTORE_EMULATOR_HOST', 'FIREBASE_AUTH_EMULATOR_HOST']) {
      const host = process.env[k].split(':')[0];
      if (!['localhost', '127.0.0.1', '::1', '[::1]'].includes(host)) {
        console.error(`[ERROR] ${k}=${process.env[k]} はローカルではありません。止めます。`);
        process.exit(1);
      }
    }
  }
}

const SEED_TAG = 'shop_ledger_year_v1';
const META = { isSeed: true, seedTag: SEED_TAG };

const SHOP_ID = 'shop_takaya_motor_okayama';
const SHOP_NAME = 'タカヤモーター株式会社';
// seed_shop_owner.js と同じ。店主の uid は店の文書IDと同じにしてある。
const OWNER_UID = SHOP_ID;
const OWNER_NAME = 'タカヤ 店長（店舗ペルソナ）';
const DEMO_PASSWORD = 'password123';

// lib/services/inquiry_maintenance_importer.dart の maintenanceDetailMessage と同じ文
const DETAIL_MESSAGE = '整備明細をお送りします。「記録に追加」から保存できます。';

const DAY = 24 * 60 * 60 * 1000;
const HOUR = 60 * 60 * 1000;

// 基準日（今日の0時・端末の時刻帯）
const TODAY = (() => {
  const s = argValue('today');
  if (s) {
    const [y, m, d] = s.split('-').map(Number);
    return new Date(y, m - 1, d).getTime();
  }
  const d = new Date();
  d.setHours(0, 0, 0, 0);
  return d.getTime();
})();
const YEAR_START = TODAY - 365 * DAY;
const dayMs = (offsetDays) => {
  // 夏時間の無い日本では DAY を足すだけでよいが、念のため暦で数える
  const d = new Date(TODAY);
  d.setDate(d.getDate() + offsetDays);
  return d.getTime();
};
const startOfDay = (ms) => {
  const d = new Date(ms);
  d.setHours(0, 0, 0, 0);
  return d.getTime();
};

// 整備履歴の取込は毎週月曜の朝。最後の取込は、今日以前で直近の月曜 8:30。
const LAST_IMPORT = (() => {
  const d = new Date(TODAY);
  while (d.getDay() !== 1) d.setDate(d.getDate() - 1);
  d.setHours(8, 30, 0, 0);
  return d.getTime();
})();
// 伝票の日付から、それを取り込んだ時刻（その日より後の最初の月曜 8:30）
function importTimeFor(dateMs) {
  const d = new Date(startOfDay(dateMs));
  d.setDate(d.getDate() + 1);
  while (d.getDay() !== 1) d.setDate(d.getDate() + 1);
  d.setHours(8, 30, 0, 0);
  return Math.min(d.getTime(), LAST_IMPORT);
}
// 伝票を作ってよい最後の日（最後の取込の前日まで。取込前の入庫は台帳にまだ無い）
const LAST_RECORD_DAY = startOfDay(LAST_IMPORT) - DAY;

// ---------------------------------------------------------------------------
// 乱数（固定シード）
// ---------------------------------------------------------------------------
function mulberry32(a) {
  return function () {
    a |= 0;
    a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
let rand = mulberry32(20261008);
const between = (a, b) => a + Math.floor(rand() * (b - a + 1));
const pick = (arr) => arr[Math.floor(rand() * arr.length)];
const chance = (p) => rand() < p;
function weighted(pairs) {
  const total = pairs.reduce((s, [, w]) => s + w, 0);
  let r = rand() * total;
  for (const [v, w] of pairs) {
    if ((r -= w) < 0) return v;
  }
  return pairs[pairs.length - 1][0];
}
const AUTO_ID_CHARS =
  'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
// Firestore の自動IDと同じ形（20文字）。手で登録した顧客・車はこの形になる。
const autoId = () =>
  Array.from({ length: 20 }, () => AUTO_ID_CHARS[Math.floor(rand() * 62)]).join('');

// ---------------------------------------------------------------------------
// 検索用の正規化（lib/models/shop_ledger.dart の LedgerSearch と同じ）
// ---------------------------------------------------------------------------
const HALF_KANA = {
  'ｦ': 'ヲ', 'ｧ': 'ァ', 'ｨ': 'ィ', 'ｩ': 'ゥ', 'ｪ': 'ェ', 'ｫ': 'ォ', 'ｬ': 'ャ',
  'ｭ': 'ュ', 'ｮ': 'ョ', 'ｯ': 'ッ', 'ｰ': 'ー', 'ｱ': 'ア', 'ｲ': 'イ', 'ｳ': 'ウ',
  'ｴ': 'エ', 'ｵ': 'オ', 'ｶ': 'カ', 'ｷ': 'キ', 'ｸ': 'ク', 'ｹ': 'ケ', 'ｺ': 'コ',
  'ｻ': 'サ', 'ｼ': 'シ', 'ｽ': 'ス', 'ｾ': 'セ', 'ｿ': 'ソ', 'ﾀ': 'タ', 'ﾁ': 'チ',
  'ﾂ': 'ツ', 'ﾃ': 'テ', 'ﾄ': 'ト', 'ﾅ': 'ナ', 'ﾆ': 'ニ', 'ﾇ': 'ヌ', 'ﾈ': 'ネ',
  'ﾉ': 'ノ', 'ﾊ': 'ハ', 'ﾋ': 'ヒ', 'ﾌ': 'フ', 'ﾍ': 'ヘ', 'ﾎ': 'ホ', 'ﾏ': 'マ',
  'ﾐ': 'ミ', 'ﾑ': 'ム', 'ﾒ': 'メ', 'ﾓ': 'モ', 'ﾔ': 'ヤ', 'ﾕ': 'ユ', 'ﾖ': 'ヨ',
  'ﾗ': 'ラ', 'ﾘ': 'リ', 'ﾙ': 'ル', 'ﾚ': 'レ', 'ﾛ': 'ロ', 'ﾜ': 'ワ', 'ﾝ': 'ン',
};
const DAKUTEN = {
  'カ': 'ガ', 'キ': 'ギ', 'ク': 'グ', 'ケ': 'ゲ', 'コ': 'ゴ', 'サ': 'ザ', 'シ': 'ジ',
  'ス': 'ズ', 'セ': 'ゼ', 'ソ': 'ゾ', 'タ': 'ダ', 'チ': 'ヂ', 'ツ': 'ヅ', 'テ': 'デ',
  'ト': 'ド', 'ハ': 'バ', 'ヒ': 'ビ', 'フ': 'ブ', 'ヘ': 'ベ', 'ホ': 'ボ', 'ウ': 'ヴ',
};
const HANDAKUTEN = { 'ハ': 'パ', 'ヒ': 'ピ', 'フ': 'プ', 'ヘ': 'ペ', 'ホ': 'ポ' };

function halfwidthKanaToFullwidth(input) {
  // Dart の input.split('') と同じく UTF-16 の単位で見る（半角カナは BMP 内）
  const chars = input.split('');
  let out = '';
  for (let i = 0; i < chars.length; i++) {
    const c = chars[i];
    const full = HALF_KANA[c];
    if (full === undefined) {
      out += c;
      continue;
    }
    const next = i + 1 < chars.length ? chars[i + 1] : null;
    if (next === 'ﾞ' && DAKUTEN[full]) {
      out += DAKUTEN[full];
      i++;
    } else if (next === 'ﾟ' && HANDAKUTEN[full]) {
      out += HANDAKUTEN[full];
      i++;
    } else {
      out += full;
    }
  }
  return out;
}

function nameKey(input) {
  let out = '';
  for (const ch of halfwidthKanaToFullwidth(input)) {
    let r = ch.codePointAt(0);
    if (r >= 0xff01 && r <= 0xff5e) r -= 0xfee0;
    if (r >= 0x30a1 && r <= 0x30f6) r -= 0x60;
    if (r === 0x20 || r === 0x3000) continue;
    out += String.fromCodePoint(r);
  }
  return out.toLowerCase();
}

const PLATE_DASHES = new Set([0x2d, 0x2010, 0x2011, 0x2012, 0x2013, 0x2014, 0x2015, 0x2212]);
function plateKey(input) {
  let out = '';
  for (const ch of input) {
    let r = ch.codePointAt(0);
    if (r >= 0xff01 && r <= 0xff5e) r -= 0xfee0;
    if (r === 0x20 || r === 0x3000) continue;
    if (PLATE_DASHES.has(r)) continue;
    if (r === 0x30fc && out.length > 0 && /[0-9]$/.test(out)) continue;
    out += String.fromCodePoint(r);
  }
  return out.toLowerCase();
}

function plateNumber(input) {
  const m = /(\d{1,4})$/.exec(plateKey(input));
  return m ? m[1] : null;
}

// ShopLedgerService.isInspectionWork と同じ（車検の入庫とみなす作業）
function isInspectionWork(type) {
  const t = nameKey(type || '');
  return t.includes('車検') || t.includes('継続検査') || t.includes('carinspection');
}

// ShopLedgerService.inspectionDueFor と同じ。車検をした日から、それがどの
// 満了日の分かを決める（名簿の満了日が既に1〜2年進んでいても戻す）。
function inspectionDueFor(expiryMs, inspectedMs) {
  if (expiryMs == null) return null;
  const earliest = inspectedMs - 31 * DAY;
  const latest = inspectedMs + 92 * DAY;
  const e = new Date(expiryMs);
  for (let years = 0; years <= 3; years++) {
    const due = new Date(e.getFullYear() - years, e.getMonth(), e.getDate()).getTime();
    if (due >= earliest && due <= latest) return due;
  }
  return null;
}

// 整備履歴の取込（ShopLedgerService.importHistory）が車に写す、最後の車検日と
// それがどの満了日の分か。取りこぼしの集計は伝票を読まずにこれを使う。
function applyInspections() {
  const last = new Map();
  for (const r of out.records) {
    if (!isInspectionWork(r.text)) continue;
    const prev = last.get(r.vehicle);
    if (prev == null || r.date > prev) last.set(r.vehicle, r.date);
  }
  for (const v of out.vehicles) {
    const at = last.get(v) ?? null;
    v.lastInspectionAt = at;
    v.lastInspectionDueAt = at == null ? null : inspectionDueFor(v.expiry, at);
  }
}

// ShopLedgerService.idForExternal と同じ
const idForExternal = (prefix, ext) => `${prefix}_${ext.trim().replace(/[/\s]/g, '_')}`;

// maintenance_history_import.dart の guessMaintenanceType と同じ判定
// （明細の typeKey を、店が送るときと同じに決めるため）
const TYPE_DISPLAY = {
  repair: '修理', legalInspection12: '12ヶ月点検', legalInspection24: '24ヶ月点検',
  carInspection: '車検', oilChange: 'オイル交換', oilFilterChange: 'オイルフィルター交換',
  tireChange: 'タイヤ交換', tireRotation: 'タイヤローテーション',
  wheelAlignment: 'ホイールアライメント', batteryChange: 'バッテリー交換',
  brakePadChange: 'ブレーキパッド交換', brakeFluidChange: 'ブレーキフルード交換',
  coolantChange: '冷却水交換', airConditionerService: 'エアコン整備',
  airFilterChange: 'エアフィルター交換', cabinFilterChange: 'エアコンフィルター交換',
  wiperChange: 'ワイパー交換', lightBulbChange: 'ライト交換',
  transmissionFluidChange: 'ATF/CVTフルード交換', bodyRepair: '板金・塗装',
  paintCorrection: '磨き・補修', glassCoating: 'ガラスコーティング',
  bodyCoating: 'ボディコーティング', carFilm: 'カーフィルム',
  protectionFilm: 'プロテクションフィルム', customization: 'カスタム・ドレスアップ',
  audioInstall: 'オーディオ取付', accessoryInstall: 'アクセサリー取付',
  partsReplacement: '部品交換', washing: '洗車', other: 'その他',
};
function guessMaintenanceType(raw) {
  const s = nameKey(raw || '');
  if (!s) return 'other';
  for (const [k, label] of Object.entries(TYPE_DISPLAY)) {
    if (nameKey(label) === s) return k;
  }
  const hasW = (w) => s.includes(nameKey(w));
  if (hasW('車検')) return 'carInspection';
  if (hasW('24') && hasW('点検')) return 'legalInspection24';
  if (hasW('点検')) return 'legalInspection12';
  if (hasW('オイル') && hasW('フィルター')) return 'oilFilterChange';
  if (hasW('エレメント')) return 'oilFilterChange';
  if (hasW('オイル')) return 'oilChange';
  if (hasW('ローテーション')) return 'tireRotation';
  if (hasW('タイヤ')) return 'tireChange';
  if (hasW('アライメント')) return 'wheelAlignment';
  if (hasW('バッテリー')) return 'batteryChange';
  if (hasW('ブレーキ') && (hasW('フルード') || hasW('液'))) return 'brakeFluidChange';
  if (hasW('ブレーキ')) return 'brakePadChange';
  if (hasW('冷却') || hasW('クーラント') || hasW('LLC')) return 'coolantChange';
  if (hasW('エアコン') && hasW('フィルター')) return 'cabinFilterChange';
  if (hasW('エアコン')) return 'airConditionerService';
  if (hasW('エアフィルター') || hasW('エアクリ')) return 'airFilterChange';
  if (hasW('ワイパー')) return 'wiperChange';
  if (hasW('ATF') || hasW('CVT')) return 'transmissionFluidChange';
  if (hasW('板金') || hasW('塗装')) return 'bodyRepair';
  if (hasW('コーティング')) return 'bodyCoating';
  if (hasW('洗車')) return 'washing';
  if (hasW('修理')) return 'repair';
  if (hasW('交換')) return 'partsReplacement';
  return 'other';
}

// Dart の DateTime.toIso8601String()（ローカル時刻・時差なし）と同じ形
function dartIsoLocal(ms) {
  const d = new Date(ms);
  const p = (n, w = 2) => String(n).padStart(w, '0');
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}T${p(d.getHours())}:${p(d.getMinutes())}:${p(d.getSeconds())}.${p(d.getMilliseconds(), 3)}`;
}

// ---------------------------------------------------------------------------
// 名前・住所・連絡先（すべて架空）
// ---------------------------------------------------------------------------
// 姓: 漢字:カナ:ローマ字。岡山に多い姓を多めに入れてある。
const SURNAMES = `
山本:ヤマモト:yamamoto 藤原:フジワラ:fujiwara 佐藤:サトウ:sato 田中:タナカ:tanaka
小野:オノ:ono 岡田:オカダ:okada 三宅:ミヤケ:miyake 高橋:タカハシ:takahashi
伊藤:イトウ:ito 中村:ナカムラ:nakamura 小林:コバヤシ:kobayashi 渡辺:ワタナベ:watanabe
井上:イノウエ:inoue 松本:マツモト:matsumoto 木村:キムラ:kimura 林:ハヤシ:hayashi
山田:ヤマダ:yamada 森:モリ:mori 池田:イケダ:ikeda 橋本:ハシモト:hashimoto
石井:イシイ:ishii 難波:ナンバ:namba 守屋:モリヤ:moriya 片山:カタヤマ:katayama
浅野:アサノ:asano 原田:ハラダ:harada 平松:ヒラマツ:hiramatsu 河原:カワハラ:kawahara
大森:オオモリ:omori 秋山:アキヤマ:akiyama 赤木:アカギ:akagi 坂本:サカモト:sakamoto
西村:ニシムラ:nishimura 吉田:ヨシダ:yoshida 清水:シミズ:shimizu 山崎:ヤマサキ:yamasaki
近藤:コンドウ:kondo 石田:イシダ:ishida 藤井:フジイ:fujii 後藤:ゴトウ:goto
長谷川:ハセガワ:hasegawa 村上:ムラカミ:murakami 遠藤:エンドウ:endo 青木:アオキ:aoki
坂田:サカタ:sakata 内田:ウチダ:uchida 太田:オオタ:ota 光岡:ミツオカ:mitsuoka
妹尾:セノオ:senoo 小橋:コバシ:kobashi 横山:ヨコヤマ:yokoyama 植田:ウエダ:ueda
三浦:ミウラ:miura 安藤:アンドウ:ando 杉本:スギモト:sugimoto 宮本:ミヤモト:miyamoto
黒田:クロダ:kuroda 土井:ドイ:doi 服部:ハットリ:hattori 中山:ナカヤマ:nakayama
大塚:オオツカ:otsuka 野崎:ノザキ:nozaki 渡邊:ワタナベ:watanabe 齋藤:サイトウ:saito
小川:オガワ:ogawa 武田:タケダ:takeda 前田:マエダ:maeda 竹内:タケウチ:takeuchi
松田:マツダ:matsuda 福田:フクダ:fukuda 中島:ナカシマ:nakashima 上田:ウエダ:ueda
森本:モリモト:morimoto 野村:ノムラ:nomura 谷口:タニグチ:taniguchi 丸山:マルヤマ:maruyama
今井:イマイ:imai 高田:タカタ:takata 藤田:フジタ:fujita 岡本:オカモト:okamoto
松井:マツイ:matsui 和田:ワダ:wada 中田:ナカタ:nakata 石川:イシカワ:ishikawa
小山:コヤマ:koyama 久保:クボ:kubo 大野:オオノ:ono 若林:ワカバヤシ:wakabayashi
有本:アリモト:arimoto 国定:クニサダ:kunisada 虫明:ムシアケ:mushiake 三木:ミキ:miki
平田:ヒラタ:hirata 川上:カワカミ:kawakami 増田:マスダ:masuda 小西:コニシ:konishi
岸本:キシモト:kishimoto 浜田:ハマダ:hamada 須藤:スドウ:sudo 水野:ミズノ:mizuno
北村:キタムラ:kitamura 菊池:キクチ:kikuchi 金子:カネコ:kaneko 新田:ニッタ:nitta
`.trim().split(/\s+/).map((s) => s.split(':'));

const GIVEN_M = `
太郎:タロウ:taro 健一:ケンイチ:kenichi 誠:マコト:makoto 浩二:コウジ:koji
大輔:ダイスケ:daisuke 翔太:ショウタ:shota 拓也:タクヤ:takuya 剛:ツヨシ:tsuyoshi
隆:タカシ:takashi 修:オサム:osamu 和夫:カズオ:kazuo 秀樹:ヒデキ:hideki
健太:ケンタ:kenta 亮:リョウ:ryo 悠斗:ユウト:yuto 蓮:レン:ren
一郎:イチロウ:ichiro 茂:シゲル:shigeru 勝:マサル:masaru 直樹:ナオキ:naoki
雄介:ユウスケ:yusuke 智也:トモヤ:tomoya 康弘:ヤスヒロ:yasuhiro 博:ヒロシ:hiroshi
正人:マサト:masato 光男:ミツオ:mitsuo 俊介:シュンスケ:shunsuke 陽介:ヨウスケ:yosuke
大和:ヤマト:yamato 湊:ミナト:minato 颯太:ソウタ:sota 晴:ハル:haru
義男:ヨシオ:yoshio 昭:アキラ:akira 進:ススム:susumu 稔:ミノル:minoru
達也:タツヤ:tatsuya 和也:カズヤ:kazuya 圭介:ケイスケ:keisuke 純一:ジュンイチ:junichi
哲也:テツヤ:tetsuya 賢治:ケンジ:kenji 克己:カツミ:katsumi 信二:シンジ:shinji
`.trim().split(/\s+/).map((s) => s.split(':'));

const GIVEN_F = `
花子:ハナコ:hanako 恵子:ケイコ:keiko 由美:ユミ:yumi 陽子:ヨウコ:yoko
美香:ミカ:mika さくら:サクラ:sakura 彩:アヤ:aya 千尋:チヒロ:chihiro
真由美:マユミ:mayumi 智子:トモコ:tomoko 裕子:ユウコ:yuko 明美:アケミ:akemi
愛:アイ:ai 葵:アオイ:aoi 結衣:ユイ:yui 美咲:ミサキ:misaki
早苗:サナエ:sanae 久美子:クミコ:kumiko 直美:ナオミ:naomi 静香:シズカ:shizuka
麻衣:マイ:mai 晴美:ハルミ:harumi 典子:ノリコ:noriko 和子:カズコ:kazuko
陽菜:ヒナ:hina 凛:リン:rin 芽依:メイ:mei 美穂:ミホ:miho
幸子:サチコ:sachiko 洋子:ヨウコ:yoko 節子:セツコ:setsuko 文子:フミコ:fumiko
加奈子:カナコ:kanako 理恵:リエ:rie 沙織:サオリ:saori 奈々:ナナ:nana
香織:カオリ:kaori 舞:マイ:mai 由紀:ユキ:yuki 恵美:エミ:emi
`.trim().split(/\s+/).map((s) => s.split(':'));

// 岡山県内の住所。郵便番号の上3桁は地域に合わせ、下4桁は乱数（架空）。
const AREAS = [
  ['岡山市北区', '700', ['奉還町', '野田', '今', '大元', '津島南', '伊福町', '学南町', '西古松', '庭瀬', '白石'], 22],
  ['岡山市中区', '703', ['平井', '原尾島', '赤田', '倉田', '浜', '国富'], 10],
  ['岡山市南区', '702', ['妹尾', '豊成', '福田', '藤田', '当新田', '浦安南町'], 14],
  ['岡山市東区', '704', ['西大寺中', '瀬戸町瀬戸', '上道北方'], 7],
  ['倉敷市', '710', ['中庄', '老松町', '笹沖', '水島東栄町', '玉島', '児島小川町', '連島'], 22],
  ['総社市', '719', ['中央', '井手', '駅前'], 7],
  ['玉野市', '706', ['宇野', '築港', '田井'], 5],
  ['赤磐市', '709', ['桜が丘東', '山陽', '下市'], 5],
  ['都窪郡早島町', '701', ['早島', '前潟'], 3],
  ['浅口市', '719', ['鴨方町鴨方', '金光町占見新田'], 3],
];
const BUILDINGS = ['コーポ平和', 'ハイツ緑', 'メゾン清輝', 'グランドール野田', 'サンシャイン倉敷', 'レジデンス桜'];

function makeAddress() {
  const [city, zip3, towns] = weighted(AREAS.map((a) => [a, a[3]]));
  const town = pick(towns);
  const postalCode = `${zip3}-${String(between(0, 9999)).padStart(4, '0')}`;
  let address = `岡山県${city}${town}`;
  address += chance(0.75) ? `${between(1, 5)}丁目${between(1, 30)}-${between(1, 25)}` : `${between(100, 2999)}-${between(1, 12)}`;
  if (chance(0.12)) address += ` ${pick(BUILDINGS)} ${between(1, 5)}0${between(1, 8)}`;
  return { postalCode, address, city };
}

// 電話番号は、局番の先頭を「0」にして実在しない形にしてある
// （市内局番・携帯の加入者番号は 0 から始まらない）。
const mobilePhone = () => `${pick(['090', '080', '070'])}-0${between(100, 999)}-${String(between(0, 9999)).padStart(4, '0')}`;
const landPhone = () => `086-0${between(10, 99)}-${String(between(0, 9999)).padStart(4, '0')}`;

// 半角カナに直す（古い整備管理ソフトから来た名簿は半角のことがある）
const FULL_TO_HALF = (() => {
  const m = {};
  for (const [h, f] of Object.entries(HALF_KANA)) m[f] = h;
  for (const [f, d] of Object.entries(DAKUTEN)) m[d] = m[f] + 'ﾞ';
  for (const [f, p] of Object.entries(HANDAKUTEN)) m[p] = m[f] + 'ﾟ';
  return m;
})();
const toHalfKana = (s) => s.split('').map((c) => (c === ' ' ? ' ' : FULL_TO_HALF[c] ?? c)).join('');

// ---------------------------------------------------------------------------
// 車種
// ---------------------------------------------------------------------------
// cls: kei（軽乗用）/ keiCargo（軽貨物）/ small（5ナンバー）/ normal（3ナンバー）
//      / cargo（4ナンバー貨物・毎年車検）/ truck（1ナンバー・毎年車検・3ヶ月点検）
const MODELS = [
  ['ホンダ', 'N-BOX', 'JF3', 'kei', [2017, 2025], 14],
  ['スズキ', 'スペーシア', 'MK53S', 'kei', [2017, 2025], 8],
  ['ダイハツ', 'タント', 'LA650S', 'kei', [2019, 2025], 8],
  ['スズキ', 'ワゴンR', 'MH55S', 'kei', [2014, 2024], 6],
  ['ダイハツ', 'ムーヴ', 'LA150S', 'kei', [2014, 2024], 5],
  ['日産', 'デイズ', 'B44W', 'kei', [2019, 2025], 5],
  ['スズキ', 'ハスラー', 'MR92S', 'kei', [2020, 2025], 4],
  ['スズキ', 'ジムニー', 'JB64W', 'kei', [2018, 2025], 3],
  ['ダイハツ', 'ミライース', 'LA350S', 'kei', [2017, 2025], 4],
  ['トヨタ', 'アクア', 'MXPK11', 'small', [2012, 2025], 8],
  ['トヨタ', 'プリウス', 'ZVW50', 'normal', [2015, 2025], 7],
  ['トヨタ', 'ヤリス', 'MXPH10', 'small', [2020, 2025], 5],
  ['トヨタ', 'シエンタ', 'MXPL10G', 'small', [2015, 2025], 5],
  ['トヨタ', 'ヴォクシー', 'ZWR90W', 'small', [2014, 2025], 5],
  ['トヨタ', 'ノア', 'ZWR90W', 'small', [2014, 2025], 4],
  ['トヨタ', 'アルファード', 'AGH30W', 'normal', [2015, 2025], 3],
  ['トヨタ', 'ハリアー', 'AXUH80', 'normal', [2014, 2025], 3],
  ['トヨタ', 'ライズ', 'A200A', 'small', [2019, 2025], 4],
  ['トヨタ', 'カローラフィールダー', 'NKE165G', 'small', [2013, 2022], 3],
  ['ホンダ', 'フィット', 'GR3', 'small', [2013, 2025], 6],
  ['ホンダ', 'フリード', 'GB7', 'small', [2016, 2025], 5],
  ['ホンダ', 'ヴェゼル', 'RV5', 'normal', [2014, 2025], 4],
  ['ホンダ', 'ステップワゴン', 'RP8', 'small', [2015, 2025], 3],
  ['日産', 'ノート', 'E13', 'small', [2016, 2025], 6],
  ['日産', 'セレナ', 'GFC27', 'small', [2016, 2025], 5],
  ['日産', 'エクストレイル', 'T33', 'normal', [2014, 2025], 2],
  ['マツダ', 'CX-5', 'KF2P', 'normal', [2017, 2025], 3],
  ['マツダ', 'MAZDA2', 'DJLFS', 'small', [2015, 2024], 2],
  ['スバル', 'フォレスター', 'SK5', 'normal', [2018, 2025], 2],
  ['スズキ', 'スイフト', 'ZC83S', 'small', [2017, 2025], 3],
  ['三菱', 'デリカD:5', 'CV1W', 'normal', [2013, 2025], 2],
  // 貨物（個人で持つ人もいる）
  ['ダイハツ', 'ハイゼットトラック', 'S510P', 'keiCargo', [2012, 2025], 4],
  ['スズキ', 'キャリイ', 'DA16T', 'keiCargo', [2013, 2025], 3],
  ['スズキ', 'エブリイ', 'DA17V', 'keiCargo', [2015, 2025], 2],
  ['トヨタ', 'ハイエースバン', 'GDH201V', 'cargo', [2012, 2025], 2],
  ['トヨタ', 'プロボックス', 'NCP160V', 'cargo', [2014, 2025], 1],
];
// 法人の業種ごとの車の持ち方
const FLEET_MODELS = {
  運輸: [['いすゞ', 'エルフ', 'TRG-NJR88', 'truck', [2014, 2024], 5], ['日野', 'デュトロ', 'TKG-XZU605M', 'truck', [2014, 2024], 4], ['三菱ふそう', 'キャンター', 'TPG-FEA50', 'truck', [2015, 2024], 3], ['トヨタ', 'ハイエースバン', 'GDH201V', 'cargo', [2012, 2025], 4]],
  建設: [['トヨタ', 'ハイエースバン', 'GDH201V', 'cargo', [2012, 2025], 5], ['トヨタ', 'プロボックス', 'NCP160V', 'cargo', [2014, 2025], 4], ['ダイハツ', 'ハイゼットトラック', 'S510P', 'keiCargo', [2012, 2025], 4], ['いすゞ', 'エルフ', 'TRG-NJR88', 'truck', [2014, 2024], 2], ['トヨタ', 'タウンエースバン', 'S403M', 'cargo', [2020, 2025], 2]],
  営業: [['トヨタ', 'プロボックス', 'NCP160V', 'cargo', [2014, 2025], 5], ['トヨタ', 'アクア', 'MXPK11', 'small', [2012, 2025], 4], ['トヨタ', 'プリウス', 'ZVW50', 'normal', [2015, 2025], 3], ['ホンダ', 'N-BOX', 'JF3', 'kei', [2017, 2025], 2]],
  福祉: [['トヨタ', 'ヴォクシー（ウェルキャブ）', 'ZWR90W', 'small', [2016, 2025], 4], ['ホンダ', 'N-BOX スロープ', 'JF3', 'kei', [2017, 2025], 4], ['トヨタ', 'シエンタ', 'MXPL10G', 'small', [2015, 2025], 3], ['スズキ', 'エブリイ', 'DA17V', 'keiCargo', [2015, 2025], 1]],
  農業: [['ダイハツ', 'ハイゼットトラック', 'S510P', 'keiCargo', [2010, 2025], 6], ['スズキ', 'キャリイ', 'DA16T', 'keiCargo', [2012, 2025], 5], ['トヨタ', 'ハイエースバン', 'GDH201V', 'cargo', [2012, 2025], 2]],
  配達: [['スズキ', 'エブリイ', 'DA17V', 'keiCargo', [2015, 2025], 5], ['ダイハツ', 'ハイゼットカーゴ', 'S700V', 'keiCargo', [2021, 2025], 4], ['日産', 'NV200バネット', 'VM20', 'cargo', [2014, 2022], 2]],
};

const CLASS_INFO = {
  kei: { cycleYears: 2, km: [3000, 9000], plateClass: ['580', '581', '585', '50'], kana: 'private' },
  keiCargo: { cycleYears: 2, km: [3000, 10000], plateClass: ['480', '483', '40'], kana: 'private' },
  small: { cycleYears: 2, km: [5000, 12000], plateClass: ['500', '501', '502', '530', '50'], kana: 'private' },
  normal: { cycleYears: 2, km: [6000, 14000], plateClass: ['300', '330', '331', '338', '30'], kana: 'private' },
  cargo: { cycleYears: 1, km: [10000, 30000], plateClass: ['400', '480', '401', '40'], kana: 'private' },
  truck: { cycleYears: 1, km: [20000, 50000], plateClass: ['100', '130', '400', '10'], kana: 'business' },
};
const KANA_PRIVATE = 'さすせそたちつてとなにぬねのはひふほまみむめもやゆよらりるれろ'.split('');
const KANA_BUSINESS = 'あいうえかきくけこを'.split('');

const usedPlates = new Set();
function makePlate(cls, region) {
  const info = CLASS_INFO[cls];
  for (;;) {
    const kana = pick(info.kana === 'business' ? KANA_BUSINESS : KANA_PRIVATE);
    const num = chance(0.9) ? between(1000, 9999) : between(1, 999);
    const cl = pick(info.plateClass);
    const numText = num >= 1000
      ? `${String(num).slice(0, 2)}-${String(num).slice(2)}`
      : num >= 100 ? `・${num}` : num >= 10 ? `・・${num}` : `・・・${num}`;
    const base = `${region} ${cl} ${kana} ${numText}`;
    const key = plateKey(base);
    if (usedPlates.has(key)) continue;
    usedPlates.add(key);
    // 入力の揺れ（全角数字・空白なし）。検索キーで同じ形に揃うことを確かめるため
    const r = rand();
    if (r < 0.03) {
      return base.replace(/[0-9-]/g, (c) => (c === '-' ? '－' : String.fromCharCode(c.charCodeAt(0) + 0xfee0)));
    }
    if (r < 0.06) return base.replace(/[\s-]/g, '');
    return base;
  }
}

// ---------------------------------------------------------------------------
// 整備の種類（伝票の「作業内容」。整備管理ソフトの言い方）
// ---------------------------------------------------------------------------
const WORK = {
  inspection: { text: '車検（継続検査）', cost: { kei: [52000, 78000], keiCargo: [48000, 72000], small: [78000, 125000], normal: [92000, 160000], cargo: [70000, 130000], truck: [110000, 220000] } },
  check12: { text: '12ヶ月点検', cost: [11000, 22000] },
  check3: { text: '3ヶ月点検', cost: [8800, 16500] },
  oil: { text: 'オイル交換', cost: [3300, 6600] },
  oilElement: { text: 'オイル・エレメント交換', cost: [4950, 9350] },
  tire: { text: 'タイヤ交換（4本）', cost: [38000, 118000] },
  studless: { text: 'スタッドレスタイヤ組替', cost: [4400, 8800] },
  summerTire: { text: '夏タイヤ組替', cost: [4400, 8800] },
  battery: { text: 'バッテリー交換', cost: [12100, 38500] },
  brake: { text: 'ブレーキパッド交換', cost: [15400, 38500] },
  wiper: { text: 'ワイパーゴム交換', cost: [1980, 4400] },
  aircon: { text: 'エアコン修理（ガス補充）', cost: [8800, 33000] },
  cvt: { text: 'CVTフルード交換', cost: [9900, 19800] },
  llc: { text: '冷却水（LLC）交換', cost: [6600, 13200] },
  repair: { text: '一般修理', cost: [8800, 132000] },
  body: { text: '板金塗装', cost: [33000, 275000] },
};
const REPAIR_DETAIL = ['（オルタネーター）', '（ドライブシャフトブーツ）', '（ウォーターポンプ）', '（スライドドア）', '（パワーウィンドウ）', '（マフラー）', ''];
const BODY_DETAIL = ['（リアバンパー）', '（フロントバンパー）', '（左スライドドア）', '（右フェンダー）', ''];
const costOf = (range) => Math.round(between(range[0], range[1]) / 10) * 10;

// ---------------------------------------------------------------------------
// スタッフ
// ---------------------------------------------------------------------------
const STAFF = [
  { uid: 'takaya-staff-01', email: 'staff1.takaya@example.com', name: '山本 健二（工場長）', code: 'K7M3QX', addedDays: 352 },
  { uid: 'takaya-staff-02', email: 'staff2.takaya@example.com', name: '中川 誠（整備士）', code: 'P4RW8N', addedDays: 352 },
  { uid: 'takaya-staff-03', email: 'staff3.takaya@example.com', name: '藤井 由美（フロント）', code: 'H2TB9E', addedDays: 300 },
  { uid: 'takaya-staff-04', email: 'staff4.takaya@example.com', name: '岡田 早苗（事務）', code: 'W6ZD5S', addedDays: 120 },
];
const ACTORS = [{ uid: OWNER_UID, name: OWNER_NAME }, ...STAFF.map((s) => ({ uid: s.uid, name: s.name }))];

// ---------------------------------------------------------------------------
// ペルソナ（アプリの利用者）。seed_shop_owner.js がタカヤモーターにつないだ3人
// ---------------------------------------------------------------------------
// 店から送った明細（records）の d は「何日前の入庫か」、state は:
//   imported  送った → お客さんが「記録に追加」した（アプリに出所の印つきで入る）
//   sent      送った → まだ取り込んでいない（スレッドに「記録に追加」が出る）
//   unsent    まだ送っていない（店の「送っていない明細」に出る）
//   old       明細送付を始める前の入庫（台帳の履歴だけ）
const PERSONAS = [
  {
    uid: 'user-a', kind: 'individual', name: '個人 太郎', kana: 'コジン タロウ',
    phone: '090-0418-1111', email: 'persona.a@example.com',
    postalCode: '140-0000', address: '東京都品川区（ペルソナA・架空）',
    ext: 'K00418', invite: 'A9KQ2M', sourceName: 'csv', linkedDaysAgo: 75,
    vehicles: [
      { appId: 'veh-a-cargo', ext: 'S004181' },
      { appId: 'veh-a-family', ext: 'S004182' },
      { appId: 'veh-a-lease', ext: 'S004183' },
      { appId: 'veh-a-sports', ext: 'S004184' },
    ],
    records: [
      { appId: 'veh-a-cargo', d: 365, text: '車検（継続検査）', cost: 90584, state: 'old' },
      { appId: 'veh-a-lease', d: 335, text: 'エアコンフィルター交換', cost: 3975, state: 'old' },
      { appId: 'veh-a-family', d: 49, text: '12ヶ月点検', cost: 16500, state: 'imported' },
      { appId: 'veh-a-sports', d: 20, text: 'ブレーキフルード交換', cost: 7700, state: 'sent' },
      { appId: 'veh-a-cargo', d: 7, text: 'ワイパーゴム交換', cost: 2640, state: 'unsent' },
    ],
  },
  {
    uid: 'user-c', kind: 'individual', name: '比較 花子', kana: 'ヒカク ハナコ',
    phone: '080-0555-5555', email: 'persona.c@example.com',
    postalCode: '154-0000', address: '東京都世田谷区（ペルソナC・架空）',
    ext: null, invite: 'C8WH4R', sourceName: 'manual', linkedDaysAgo: 70,
    vehicles: [{ appId: 'veh-c-fit', ext: null }],
    records: [
      { appId: 'veh-c-fit', d: 60, text: 'オイル交換', cost: 4950, state: 'imported' },
    ],
  },
  {
    uid: 'persona-j-user', kind: 'corporate', name: '七郎運送', kana: 'シチロウウンソウ',
    contactPerson: '配送 七郎', phone: '03-0777-7171', email: 'persona.j@example.com',
    postalCode: '120-0000', address: '東京都足立区（ペルソナJ・架空）',
    ext: 'K00977', invite: 'J3PX7T', sourceName: 'csv', linkedDaysAgo: 65,
    vehicles: [
      { appId: 'veh-j-elf', ext: 'S009771' },
      { appId: 'veh-j-dutro', ext: 'S009772' },
      { appId: 'veh-j-keitruck', ext: 'S009773' },
    ],
    records: [
      { appId: 'veh-j-elf', d: 340, text: '車検（継続検査）', cost: 148500, state: 'old' },
      { appId: 'veh-j-dutro', d: 300, text: '3ヶ月点検', cost: 12100, state: 'old' },
      { appId: 'veh-j-dutro', d: 210, text: '3ヶ月点検', cost: 12100, state: 'old' },
      { appId: 'veh-j-dutro', d: 120, text: '3ヶ月点検', cost: 13200, state: 'old' },
      { appId: 'veh-j-dutro', d: 30, text: '3ヶ月点検', cost: 12100, state: 'imported' },
      { appId: 'veh-j-keitruck', d: 12, text: 'オイル交換', cost: 3850, state: 'sent' },
      { appId: 'veh-j-elf', d: 8, text: 'オイル・エレメント交換', cost: 11000, state: 'unsent' },
    ],
  },
];

// ---------------------------------------------------------------------------
// 生成
// ---------------------------------------------------------------------------
const N_INDIVIDUAL = 4000 - PERSONAS.filter((p) => p.kind === 'individual').length;
const N_CORPORATE = 100 - PERSONAS.filter((p) => p.kind === 'corporate').length;

// 名簿を最初に取り込んだ日（運用開始）
const ROSTER_IMPORT_AT = dayMs(-359) + 10 * HOUR + 30 * 60 * 1000;

const out = {
  customers: [],
  vehicles: [],
  records: [],
  audit: [],
};
let slipSeq = 0;
const nextSlip = () => `D${String(++slipSeq).padStart(6, '0')}`;
let extCustomerSeq = 10000;
let extVehicleSeq = 100000;

/** 顧客のプロフィール（来店の傾向）を決める */
function customerProfile() {
  return weighted([
    ['core', 52], // オイルも点検もここでやる
    ['light', 27], // 車検・点検だけ
    ['lapsed', 14], // 1年以上来ていない
    ['never', 4], // 名簿にいるだけで来店の記録が無い
    ['new', 3], // この1年で新しく来た（手で登録）
  ]);
}

function buildVehicle(customer, model, profile, opts = {}) {
  const [maker, modelName, code, cls, [y0, y1]] = model;
  const info = CLASS_INFO[cls];
  const year = between(y0, y1);
  const region = customer.city && customer.city.startsWith('倉敷') && chance(0.85) ? '倉敷' : '岡山';
  const plate = chance(0.97) ? makePlate(cls, region) : null; // ナンバー未入力も少し
  const kmPerYear = between(info.km[0], info.km[1]);
  const ageYears = Math.max(0.5, new Date(TODAY).getFullYear() - year + 0.5);
  const odometerNow = Math.round(kmPerYear * ageYears + between(0, 3000));
  const cycleDays = info.cycleYears === 1 ? 365 : 730;

  const csv = customer.source === 'csv';
  const ext = csv ? `S${++extVehicleSeq}` : null;
  const id = ext ? idForExternal('v', ext) : autoId();

  // 運用を始める前（名簿の時点）の満了日 E0 を、1周期ぶんの幅で散らす
  let expiry;
  if (profile === 'lapsed') expiry = dayMs(between(-1000, 300));
  else if (profile === 'never') expiry = dayMs(between(-180, 700));
  else if (profile === 'new') expiry = dayMs(between(30, cycleDays));
  else expiry = dayMs(between(-365, cycleDays - 365));
  const noExpiry = chance(0.03); // 名簿で満了日が空

  const v = {
    id, ext, customerId: customer.id, customerName: customer.name, plate,
    maker, model: modelName, year, modelCode: chance(0.75) ? code : null,
    vin: chance(0.6) ? `${code.split('-').pop()}-${between(1000000, 9999999)}` : null,
    cls, cycleDays, kmPerYear, odometerNow,
    expiry0: noExpiry ? null : expiry, expiry: noExpiry ? null : expiry,
    lastVisitAt: null, lastMileage: null,
    noticeAt: null, noticeExpiry: null,
    createdAt: opts.createdAt ?? customer.createdAt,
    updatedAt: opts.createdAt ?? customer.createdAt,
    profile,
  };
  return v;
}

function addRecord(v, dateMs, work, extraText = '') {
  const day = startOfDay(dateMs);
  if (day < YEAR_START - 4 * 365 * DAY || day > LAST_RECORD_DAY) return null;
  const text = work.text + extraText;
  let cost;
  if (work === WORK.inspection) cost = costOf(work.cost[v.cls]);
  else cost = costOf(work.cost);
  const mileage = Math.max(10, Math.round(v.odometerNow - (v.kmPerYear * (TODAY - day)) / (365 * DAY)));
  const slip = nextSlip();
  const r = {
    id: idForExternal('r', slip), slip, vehicle: v, date: day, text, cost, mileage,
  };
  out.records.push(r);
  if (v.lastVisitAt == null || day > v.lastVisitAt) {
    v.lastVisitAt = day;
    v.lastMileage = mileage;
  }
  return r;
}

// 毎月1日（前後の平日）に、満了日が2か月以内の車へはがきを出す
const NOTICE_EXPORTS = (() => {
  const list = [];
  for (let i = 12; i >= 0; i--) {
    const d = new Date(TODAY);
    d.setDate(1);
    d.setMonth(d.getMonth() - i);
    while (d.getDay() === 0 || d.getDay() === 6) d.setDate(d.getDate() + 1);
    d.setHours(16, 0, 0, 0);
    if (d.getTime() <= TODAY + 17 * HOUR && d.getTime() >= YEAR_START) list.push(d.getTime());
  }
  return list;
})();

function simulateVehicleYear(v, profile, customer) {
  if (profile === 'lapsed') {
    // 最後の来店は 13〜40 か月前。そのとき名簿に入っていた伝票が1〜2件
    const last = dayMs(-between(395, 1200));
    if (chance(0.4)) addRecord(v, last - between(120, 400) * DAY, pick([WORK.oil, WORK.check12, WORK.battery]));
    addRecord(v, last, pick([WORK.oil, WORK.oilElement, WORK.inspection, WORK.check12, WORK.tire]));
    return;
  }
  if (profile === 'never') return;

  const core = profile === 'core' || profile === 'new';
  const firstDay = profile === 'new' ? Math.max(YEAR_START, customer.createdAt) : YEAR_START;

  // 前回の車検（運用を始める前。名簿と一緒に取り込んだ過去の伝票）。
  // 2年車検の車は、車検の年でなければ1年以上来ないこともある。
  if (profile !== 'new' && v.expiry0 != null && chance(0.8)) {
    addRecord(v, v.expiry0 - v.cycleDays * DAY - between(0, 30) * DAY, WORK.inspection);
  }

  // 車検: 満了日がこの1年のうちに来た車
  if (v.expiry0 != null && v.expiry0 >= firstDay && v.expiry0 < TODAY + 30 * DAY) {
    const lost = v.expiry0 < TODAY && chance(profile === 'light' ? 0.22 : 0.12);
    if (!lost) {
      const date = Math.max(firstDay, v.expiry0 - between(0, 40) * DAY);
      if (date <= LAST_RECORD_DAY) {
        addRecord(v, date, WORK.inspection);
        v.expiry = v.expiry0 + v.cycleDays * DAY;
        if (core && chance(0.5)) addRecord(v, date, chance(0.5) ? WORK.oil : WORK.oilElement);
      }
    }
  }
  // 12ヶ月点検: 2年車検の車で、前の車検から1年目が今年に来た車
  if (v.cycleDays === 730 && v.expiry0 != null) {
    const check = v.expiry0 - 365 * DAY;
    if (check >= firstDay && check <= LAST_RECORD_DAY && chance(core ? 0.4 : 0.18)) {
      addRecord(v, check - between(0, 25) * DAY, WORK.check12);
    }
  }
  // 3ヶ月点検: トラック
  if (v.cls === 'truck') {
    for (let q = 1; q <= 4; q++) {
      const d = firstDay + q * 90 * DAY - between(0, 10) * DAY;
      if (chance(0.8)) addRecord(v, d, WORK.check3);
    }
  }
  // オイル: 走る距離に応じて年1〜6回（車検の伝票に入っていない分）
  if (core) {
    const n = Math.max(1, Math.min(6, Math.round(v.kmPerYear / 5000)));
    const span = (LAST_RECORD_DAY - firstDay) / DAY;
    for (let i = 0; i < n; i++) {
      if (!chance(0.85)) continue;
      const d = firstDay + Math.round(((i + rand()) * span) / n) * DAY;
      addRecord(v, d, i % 2 === 0 ? WORK.oil : WORK.oilElement);
    }
  }
  // そのほかの作業
  const extras = [
    [WORK.tire, 0.09], [WORK.battery, 0.06], [WORK.brake, 0.04], [WORK.wiper, 0.06],
    [WORK.cvt, 0.03], [WORK.llc, 0.02], [WORK.repair, 0.07], [WORK.body, 0.03],
  ];
  for (const [w, p] of extras) {
    if (!chance(core ? p : p / 2)) continue;
    const d = firstDay + between(0, Math.max(0, (LAST_RECORD_DAY - firstDay) / DAY)) * DAY;
    addRecord(v, d, w, w === WORK.repair ? pick(REPAIR_DETAIL) : w === WORK.body ? pick(BODY_DETAIL) : '');
  }
  // エアコン修理は夏（6〜8月）
  if (chance(core ? 0.03 : 0.01)) {
    const d = new Date(TODAY);
    d.setMonth(6, between(1, 28));
    if (d.getTime() > LAST_RECORD_DAY) d.setFullYear(d.getFullYear() - 1);
    if (d.getTime() >= firstDay) addRecord(v, d.getTime(), WORK.aircon);
  }
  // スタッドレス（岡山の北のほうへ行く人だけ）
  if (core && ['kei', 'small', 'normal'].includes(v.cls) && chance(0.04)) {
    for (const [month, w] of [[11, WORK.studless], [2, WORK.summerTire]]) {
      const d = new Date(TODAY);
      d.setMonth(month, between(5, 25));
      if (d.getTime() > LAST_RECORD_DAY) d.setFullYear(d.getFullYear() - 1);
      if (d.getTime() >= firstDay) addRecord(v, d.getTime(), w);
    }
  }
}

/** 車検の案内（はがき）の印。毎月の書き出しで、そのとき2か月以内に満了する車 */
function applyNotices(v, customer) {
  if (!customer.address || customer.linkedUserId) return;
  for (const at of NOTICE_EXPORTS) {
    const from = startOfDay(at);
    const to = new Date(from);
    to.setMonth(to.getMonth() + 2);
    // そのときの満了日（更新前なら E0、更新後なら新しい満了日）
    const renewedAt = v.renewedAt ?? Infinity;
    const expiryThen = at < renewedAt ? v.expiry0 : v.expiry;
    if (expiryThen == null) continue;
    if (expiryThen < from || expiryThen >= to.getTime()) continue;
    if (v.noticeExpiry === expiryThen) continue; // 同じ満了日には二度出さない
    if (!chance(0.85)) continue; // 店が手で外した分
    v.noticeAt = at;
    v.noticeExpiry = expiryThen;
    v.noticeCount = (v.noticeCount || 0) + 1;
  }
}

function buildCustomers() {
  const usedNames = new Set();
  // 個人
  for (let i = 0; i < N_INDIVIDUAL; i++) {
    const profile = customerProfile();
    const female = chance(0.42);
    let sk, skana, sroma, gk, gkana, groma, name;
    // 同姓同名は少しだけ残す（1.5%）。窓口で「同じ名前が2人」も起こるので
    for (let t = 0; t < 20; t++) {
      [sk, skana, sroma] = pick(SURNAMES);
      [gk, gkana, groma] = pick(female ? GIVEN_F : GIVEN_M);
      name = `${sk} ${gk}`;
      if (!usedNames.has(name) || chance(0.015)) break;
    }
    let kana = `${skana} ${gkana}`;
    const kanaStyle = rand();
    let nameKana = kana;
    if (kanaStyle < 0.03) nameKana = null; // 名簿でフリガナが空
    else if (kanaStyle < 0.08) nameKana = toHalfKana(kana); // 半角カナの名簿
    else if (kanaStyle < 0.12) nameKana = kana.replace(' ', ''); // 空白なし
    const source = profile === 'new' ? 'manual' : chance(0.94) ? 'csv' : 'manual';
    const ext = source === 'csv' ? `K${++extCustomerSeq}` : null;
    const createdAt = source === 'csv'
      ? ROSTER_IMPORT_AT
      : profile === 'new'
        ? dayMs(-between(10, 340)) + between(9, 18) * HOUR
        : dayMs(-between(200, 358)) + between(9, 18) * HOUR;
    const { postalCode, address, city } = makeAddress();
    const hasAddress = chance(0.95);
    const phone = chance(0.97) ? (chance(0.8) ? mobilePhone() : landPhone()) : null;
    const email = chance(0.45) ? `${sroma}.${groma}${between(1, 999)}@${pick(['example.com', 'example.jp'])}` : null;
    usedNames.add(name);
    out.customers.push({
      id: ext ? idForExternal('c', ext) : autoId(),
      kind: 'individual', name, nameKana, contactPerson: null, phone, email,
      postalCode: hasAddress ? postalCode : null, address: hasAddress ? address : null, city,
      note: chance(0.04) ? pick(['代車希望', '平日夕方のみ連絡可', '奥様の車も同じ担当', '支払いは振込', '車検は毎回見積もりを先に']) : null,
      externalId: ext, source, linkedUserId: null, createdAt, profile,
      vehicleCountTarget: weighted([[1, 72], [2, 22], [3, 5], [4, 1]]),
    });
  }

  // 法人
  const BASES = `
岡南:コウナン 吉備:キビ 旭川:アサヒカワ 備前:ビゼン 倉敷中央:クラシキチュウオウ 児島:コジマ
水島:ミズシマ 総社:ソウジャ 玉野:タマノ 瀬戸内:セトウチ 後楽:コウラク 操山:ミサオヤマ
笹ヶ瀬:ササガセ 足守:アシモリ 西大寺:サイダイジ 妹尾:セノオ 庭瀬:ニワセ 藤田:フジタ
山陽:サンヨウ 中国:チュウゴク 晴れの国:ハレノクニ 桃太郎:モモタロウ 白桃:ハクトウ
清輝:セイキ 大供:ダイク 鴨方:カモガタ 早島:ハヤシマ 赤磐:アカイワ 牛窓:ウシマド
`.trim().split(/\s+/).map((s) => s.split(':'));
  const KINDS = [
    ['運輸', 'ウンユ', '運輸', 18], ['物流', 'ブツリュウ', '運輸', 6], ['建設', 'ケンセツ', '建設', 14],
    ['工務店', 'コウムテン', '建設', 8], ['設備', 'セツビ', '建設', 8], ['電設', 'デンセツ', '建設', 5],
    ['商事', 'ショウジ', '営業', 8], ['不動産', 'フドウサン', '営業', 6], ['保険サービス', 'ホケンサービス', '営業', 3],
    ['福祉会', 'フクシカイ', '福祉', 5], ['ケアサービス', 'ケアサービス', '福祉', 5],
    ['農園', 'ノウエン', '農業', 5], ['ファーム', 'ファーム', '農業', 3],
    ['食品', 'ショクヒン', '配達', 5], ['クリーニング', 'クリーニング', '配達', 3], ['酒店', 'サケテン', '配達', 2],
  ];
  const FORMS = [['株式会社', 'pre', 45], ['株式会社', 'post', 25], ['有限会社', 'pre', 20], ['合同会社', 'post', 5], ['社会福祉法人', 'pre', 0]];
  for (let i = 0; i < N_CORPORATE; i++) {
    let name, kana, sector;
    for (;;) {
      const [bk, bkana] = pick(BASES);
      const [kk, kkana, sec] = weighted(KINDS.map((k) => [k, k[3]]));
      sector = sec;
      let form = weighted(FORMS.map((f) => [f, f[2]]));
      if (kk === '福祉会') form = ['社会福祉法人', 'pre'];
      const core = `${bk}${kk}`;
      name = form[1] === 'pre' ? `${form[0]}${core}` : `${core}${form[0]}`;
      // フリガナは法人格を除いて持つ（「かぶしきがいしゃ」で前方一致しても役に立たない）
      kana = `${bkana}${kkana}`;
      if (!usedNames.has(name)) break;
    }
    usedNames.add(name);
    const profile = weighted([['core', 70], ['light', 20], ['lapsed', 6], ['never', 2], ['new', 2]]);
    const source = profile === 'new' ? 'manual' : 'csv';
    const ext = source === 'csv' ? `K${++extCustomerSeq}` : null;
    const [sk] = pick(SURNAMES);
    const [gk] = pick(chance(0.3) ? GIVEN_F : GIVEN_M);
    const { postalCode, address, city } = makeAddress();
    const vehicleCountTarget = weighted([
      [between(2, 3), 35], [between(4, 6), 30], [between(7, 10), 20], [between(11, 15), 10], [between(16, 20), 5],
    ]);
    out.customers.push({
      id: ext ? idForExternal('c', ext) : autoId(),
      kind: 'corporate', name, nameKana: chance(0.97) ? kana : null,
      contactPerson: `${pick(['', '総務部 ', '車両管理 ', '業務課 '])}${sk} ${gk}`,
      phone: landPhone(), email: chance(0.7) ? `fleet${between(10, 99)}@${pick(['example.com', 'example.jp'])}` : null,
      postalCode, address, city,
      note: chance(0.3) ? pick(['請求は月末締め翌月払い', '車検は2台ずつ', '代車2台まで', '担当者が4月に交代予定', '引取納車あり']) : null,
      externalId: ext, source, linkedUserId: null,
      createdAt: source === 'csv' ? ROSTER_IMPORT_AT : dayMs(-between(30, 300)) + 11 * HOUR,
      profile, sector, vehicleCountTarget,
    });
  }
}

function buildVehiclesAndHistory() {
  for (const c of out.customers) {
    if (c.persona) continue;
    for (let k = 0; k < c.vehicleCountTarget; k++) {
      const model = c.kind === 'corporate'
        ? weighted(FLEET_MODELS[c.sector].map((m) => [m, m[5]]))
        : weighted(MODELS.map((m) => [m, m[5]]));
      // 法人や2台目以降は、運用中に足した車もある
      const added = k > 0 && c.source === 'csv' && chance(0.06)
        ? dayMs(-between(20, 330)) + 14 * HOUR : null;
      const v = buildVehicle(c, model, c.profile, { createdAt: added ?? c.createdAt });
      if (added) v.addedInYear = true;
      out.vehicles.push(v);
      const before = v.expiry;
      simulateVehicleYear(v, c.profile, c);
      if (v.expiry !== before) {
        // 車検を通した日（案内の判定に使う）
        const insp = out.records.filter((r) => r.vehicle === v && r.text === WORK.inspection.text);
        v.renewedAt = insp.length ? insp[insp.length - 1].date : null;
      }
      applyNotices(v, c);
    }
  }
}

// ---------------------------------------------------------------------------
// ペルソナ（アプリの車・つながり・明細）
// ---------------------------------------------------------------------------
async function buildPersonas(db) {
  const extras = { invites: [], links: [], inquiries: [], messages: [], appRecords: [] };
  for (const p of PERSONAS) {
    const customerId = p.ext ? idForExternal('c', p.ext) : `cust_persona_${p.uid.replace(/[^a-z0-9]/gi, '')}`;
    const linkedAt = dayMs(-p.linkedDaysAgo) + 15 * HOUR;
    const c = {
      id: customerId, kind: p.kind, name: p.name, nameKana: p.kana,
      contactPerson: p.contactPerson ?? null, phone: p.phone, email: p.email,
      postalCode: p.postalCode, address: p.address, city: '',
      note: 'アプリ利用中（使用感テストのペルソナ）', externalId: p.ext, source: p.sourceName,
      linkedUserId: p.uid, createdAt: p.sourceName === 'csv' ? ROSTER_IMPORT_AT : dayMs(-200) + 10 * HOUR,
      updatedAt: linkedAt, profile: 'persona', persona: p,
    };
    out.customers.push(c);

    // アプリの車を読み、台帳の車として写す（店が車検証から登録した体）
    const appVehicles = {};
    for (const pv of p.vehicles) {
      let data = null;
      if (db) {
        const doc = await db.collection('vehicles').doc(pv.appId).get();
        if (!doc.exists) {
          throw new Error(`vehicles/${pv.appId} がありません。先に seed_personas.js を流してください。`);
        }
        data = doc.data();
      } else {
        data = { maker: '(dry-run)', model: pv.appId, year: 2020, mileage: 30000, licensePlate: null };
      }
      appVehicles[pv.appId] = data;
      const cls = /cargo|elf|dutro|keitruck/.test(pv.appId) ? (/keitruck/.test(pv.appId) ? 'keiCargo' : /cargo/.test(pv.appId) ? 'cargo' : 'truck') : 'small';
      const exp = data.inspectionExpiryDate ? startOfDay(data.inspectionExpiryDate.toMillis()) : null;
      const v = {
        id: pv.ext ? idForExternal('v', pv.ext) : `veh_persona_${pv.appId.replace(/[^a-z0-9]/gi, '')}`,
        ext: pv.ext, customerId, customerName: p.name,
        plate: data.licensePlate ?? null, maker: data.maker, model: data.model, year: data.year ?? null,
        modelCode: null, vin: null, cls, cycleDays: cls === 'small' || cls === 'keiCargo' ? 730 : 365,
        kmPerYear: 10000, odometerNow: data.mileage ?? 30000,
        expiry0: exp, expiry: exp, lastVisitAt: null, lastMileage: null,
        noticeAt: null, noticeExpiry: null, createdAt: c.createdAt, updatedAt: linkedAt,
        appId: pv.appId, profile: 'persona',
      };
      out.vehicles.push(v);
      pv.ledger = v;
    }

    // 顧客専用コード（使用済み）と、札に台帳の顧客IDを足す
    extras.invites.push({
      code: p.invite,
      data: {
        shopId: SHOP_ID, shopName: SHOP_NAME, shopOwnerId: OWNER_UID,
        createdAt: ts(linkedAt - 2 * DAY), expiresAt: ts(linkedAt - 2 * DAY + 30 * DAY),
        isActive: true, usedCount: 1, maxUses: 1, customerId, ...META,
      },
    });
    extras.links.push({ uid: p.uid, customerId, inviteCode: p.invite, linkedAt });
    out.audit.push({ at: linkedAt - 2 * DAY + 2 * HOUR, actor: ACTORS[3], action: 'issueCustomerInvite', targetId: customerId, targetLabel: p.name });

    // 伝票（店の整備履歴）と、送った明細
    const inquiryId = `inq-ledger-takaya-${p.uid}`;
    const sentList = [];
    for (const rec of p.records) {
      const pv = p.vehicles.find((x) => x.appId === rec.appId);
      const v = pv.ledger;
      const app = appVehicles[rec.appId];
      const date = dayMs(-rec.d);
      const mileage = Math.max(10, Math.round((app.mileage ?? 30000) - (10000 * rec.d) / 365));
      const slip = nextSlip();
      const r = { id: idForExternal('r', slip), slip, vehicle: v, date, text: rec.text, cost: rec.cost, mileage };
      out.records.push(r);
      if (v.lastVisitAt == null || date > v.lastVisitAt) {
        v.lastVisitAt = date;
        v.lastMileage = mileage;
      }
      if (rec.state === 'imported' || rec.state === 'sent') {
        const sentAt = importTimeFor(date) + between(1, 5) * HOUR;
        r.detailSentAt = sentAt;
        r.detailInquiryId = inquiryId;
        sentList.push({ r, rec, sentAt, app });
      }
    }

    if (sentList.length) {
      sentList.sort((a, b) => a.sentAt - b.sentAt);
      const sender = ACTORS[3]; // フロントが送る
      let unread = 0;
      sentList.forEach((s, i) => {
        const payload = {
          typeKey: guessMaintenanceType(s.r.text),
          title: s.r.text,
          date: dartIsoLocal(s.r.date),
          cost: s.r.cost,
          mileageAtService: s.r.mileage,
          shopName: SHOP_NAME,
          description: `伝票番号 ${s.r.slip}`,
          workItems: [],
          parts: [],
        };
        const read = s.rec.state === 'imported';
        if (!read) unread++;
        extras.messages.push({
          inquiryId,
          id: `msg-ledger-${s.r.slip}`,
          data: {
            senderId: sender.uid, isFromShop: true, content: DETAIL_MESSAGE,
            attachmentUrls: [], sentAt: ts(s.sentAt), isRead: read,
            ...(read ? { readAt: ts(s.sentAt + 6 * HOUR) } : {}),
            maintenancePayload: payload, ...META,
          },
        });
        out.audit.push({ at: s.sentAt, actor: sender, action: 'sendDetail', targetId: customerId, targetLabel: p.name, detail: i === 0 ? 'スレッドを開いた' : '送っていない明細からまとめて送った・1件' });
        if (read) {
          // buildMaintenanceRecordFromPayload と同じ形（userId はお客さん本人）
          extras.appRecords.push({
            id: `mnt-ledger-${s.r.slip}`,
            data: {
              vehicleId: s.rec.appId, userId: p.uid,
              type: payload.typeKey, title: payload.title, description: payload.description,
              cost: payload.cost, shopName: SHOP_NAME, date: ts(s.r.date),
              mileageAtService: payload.mileageAtService, imageUrls: [],
              createdAt: ts(s.sentAt + 6 * HOUR),
              partNumber: null, partManufacturer: null, nextReplacementMileage: null, nextReplacementDate: null,
              staffId: null, staffName: null, inspectionResult: null, certificateUpdated: false,
              safetyStandardsCertificate: null, workItems: [], parts: [],
              partsCost: null, laborCost: null, miscCost: null, taxAmount: null, discountAmount: null,
              inquiryId, verificationSource: 'shopImported', ...META,
            },
          });
        }
      });
      const first = sentList[0].sentAt - 60 * 1000;
      const last = sentList[sentList.length - 1].sentAt;
      extras.inquiries.push({
        id: inquiryId,
        data: {
          userId: p.uid, shopId: SHOP_ID, vehicleId: null, partListingId: null,
          type: 'general', status: 'replied', subject: '整備明細のお届け',
          initialMessage: `${SHOP_NAME} から整備明細をお送りします。届いた明細は「記録に追加」から保存できます。`,
          attachmentUrls: [], shopName: SHOP_NAME,
          vehicleMaker: null, vehicleModel: null, vehicleYear: null,
          createdAt: ts(first), updatedAt: ts(last), repliedAt: ts(sentList[0].sentAt), closedAt: null,
          messageCount: sentList.length, unreadCountUser: unread, unreadCountShop: 0,
          openedByShop: true, ...META,
        },
      });
    }
  }
  return extras;
}

// ---------------------------------------------------------------------------
// 集計値（LedgerCustomerSummary.of と同じ規則）と、書き込む形
// ---------------------------------------------------------------------------
function summarize() {
  const byCustomer = new Map();
  for (const v of out.vehicles) {
    if (!byCustomer.has(v.customerId)) byCustomer.set(v.customerId, []);
    byCustomer.get(v.customerId).push(v);
  }
  for (const c of out.customers) {
    const vs = byCustomer.get(c.id) || [];
    let next = null;
    let last = null;
    for (const v of vs) {
      if (v.expiry != null && v.expiry >= TODAY && (next == null || v.expiry < next)) next = v.expiry;
      if (v.lastVisitAt != null && (last == null || v.lastVisitAt > last)) last = v.lastVisitAt;
    }
    c.vehicleCount = vs.length;
    c.nextInspectionAt = next;
    c.lastVisitAt = last;
    // 最後に触った時刻: 伝票を取り込んだ時刻・車を足した時刻のうち新しいもの
    let upd = c.updatedAt ?? c.createdAt;
    if (last != null) upd = Math.max(upd, importTimeFor(last));
    for (const v of vs) upd = Math.max(upd, v.createdAt);
    c.updatedAt = upd;
    for (const v of vs) {
      v.updatedAt = Math.max(v.createdAt, v.lastVisitAt != null ? importTimeFor(v.lastVisitAt) : 0, v.updatedAt ?? 0);
    }
  }
}

const tsOrNull = (ms) => (ms == null ? null : ts(ms));
let ts = null; // admin 読み込み後に差し替える

function customerDoc(c) {
  const nonEmpty = (s) => (s == null || String(s).trim() === '' ? null : String(s).trim());
  return {
    kind: c.kind,
    name: c.name.trim(),
    nameKana: nonEmpty(c.nameKana),
    contactPerson: nonEmpty(c.contactPerson),
    phone: nonEmpty(c.phone),
    email: nonEmpty(c.email),
    postalCode: nonEmpty(c.postalCode),
    address: nonEmpty(c.address),
    note: nonEmpty(c.note),
    externalId: nonEmpty(c.externalId),
    // LedgerCustomer.searchKey: フリガナがあればフリガナ、無ければ名前
    searchKey: nameKey(nonEmpty(c.nameKana) ?? c.name),
    vehicleCount: c.vehicleCount,
    nextInspectionAt: tsOrNull(c.nextInspectionAt),
    lastVisitAt: tsOrNull(c.lastVisitAt),
    linkedUserId: c.linkedUserId,
    isLinked: c.linkedUserId != null,
    source: c.source,
    createdAt: ts(c.createdAt),
    updatedAt: ts(c.updatedAt),
    ...META,
  };
}

function vehicleDoc(v) {
  return {
    customerId: v.customerId,
    customerName: v.customerName,
    plate: v.plate,
    plateKey: v.plate == null ? null : plateKey(v.plate),
    plateNumber: v.plate == null ? null : plateNumber(v.plate),
    maker: v.maker,
    model: v.model,
    year: v.year,
    modelCode: v.modelCode,
    vin: v.vin,
    inspectionExpiry: tsOrNull(v.expiry),
    lastVisitAt: tsOrNull(v.lastVisitAt),
    lastMileage: v.lastMileage,
    externalId: v.ext,
    ...(v.noticeAt != null ? { inspectionNoticeAt: ts(v.noticeAt) } : {}),
    ...(v.noticeExpiry != null ? { inspectionNoticeExpiry: ts(v.noticeExpiry) } : {}),
    // 車検の伝票が無い車にも null を書く（集計が伝票を読みに行かないように）
    lastInspectionAt: tsOrNull(v.lastInspectionAt),
    lastInspectionDueAt: tsOrNull(v.lastInspectionDueAt),
    createdAt: ts(v.createdAt),
    updatedAt: ts(v.updatedAt),
    ...META,
  };
}

function recordDoc(r) {
  // ShopLedgerService.importHistory が書く形
  const v = r.vehicle;
  return {
    customerId: v.customerId,
    customerVehicleId: v.id,
    date: ts(r.date),
    type: r.text,
    totalCost: r.cost,
    mileage: r.mileage,
    maker: v.maker,
    model: v.model,
    year: v.year,
    externalId: r.slip,
    source: 'csv',
    updatedAt: ts(importTimeFor(r.date)),
    ...(r.detailSentAt != null ? { detailSentAt: ts(r.detailSentAt), detailInquiryId: r.detailInquiryId } : {}),
    ...META,
  };
}

// ---------------------------------------------------------------------------
// 操作の記録（1年分）
// ---------------------------------------------------------------------------
function buildAudit() {
  const owner = ACTORS[0];
  const staffAt = (at) => ACTORS.filter((a, i) => i === 0 || at >= dayMs(-STAFF[i - 1].addedDays));
  const csvCount = out.customers.filter((c) => c.source === 'csv').length;

  out.audit.push({ at: ROSTER_IMPORT_AT, actor: owner, action: 'importRoster', detail: `顧客 ${csvCount}件・車両 ${out.vehicles.filter((v) => v.ext).length}台（新規 ${csvCount}件）` });

  // 週1回の整備履歴の取込（月曜の朝）
  const imports = new Map();
  for (const r of out.records) {
    const t = importTimeFor(r.date);
    if (t < ROSTER_IMPORT_AT) continue;
    imports.set(t, (imports.get(t) || 0) + 1);
  }
  for (const [t, n] of [...imports.entries()].sort((a, b) => a[0] - b[0])) {
    const actor = t >= dayMs(-STAFF[3].addedDays) ? ACTORS[4] : owner;
    out.audit.push({ at: t + 5 * 60 * 1000, actor, action: 'importHistory', detail: `${n}件` });
  }

  // 車検案内の宛名の書き出し
  for (const at of NOTICE_EXPORTS) {
    const n = out.vehicles.filter((v) => v.noticeAt === at).length;
    if (n === 0) continue;
    out.audit.push({ at, actor: at >= dayMs(-STAFF[2].addedDays) ? ACTORS[3] : owner, action: 'exportInspectionNotice', detail: `${n}件` });
  }

  // 手で登録した顧客・車
  for (const c of out.customers) {
    if (c.source === 'manual' && !c.persona) {
      const actor = pick(staffAt(c.createdAt));
      out.audit.push({ at: c.createdAt, actor, action: 'createCustomer', targetId: c.id, targetLabel: c.name });
    }
  }
  for (const v of out.vehicles) {
    if (v.addedInYear || (v.createdAt > ROSTER_IMPORT_AT && v.profile !== 'persona')) {
      const c = out.customers.find((x) => x.id === v.customerId);
      out.audit.push({ at: v.createdAt + 5 * 60 * 1000, actor: pick(staffAt(v.createdAt)), action: 'saveVehicle', targetId: v.customerId, targetLabel: c?.name, detail: v.plate ?? `${v.maker} ${v.model}` });
    }
  }

  // ふだんの「顧客を見た」「顧客を直した」（営業日ごとに数件）
  const pool = out.customers.filter((c) => !c.persona);
  // 今日の分は作らない（流す時刻で件数が変わると、流し直しで数が揃わない）
  for (let d = -358; d <= -1; d++) {
    const day = dayMs(d);
    const wd = new Date(day).getDay();
    if (wd === 0) continue; // 日曜定休
    const views = between(2, wd === 6 ? 4 : 9);
    for (let k = 0; k < views; k++) {
      const at = day + between(9 * 60, 18 * 60) * 60 * 1000;
      const c = pick(pool);
      const actor = pick(staffAt(at));
      out.audit.push({ at, actor, action: 'viewCustomer', targetId: c.id, targetLabel: c.name });
      if (chance(0.08)) {
        out.audit.push({ at: at + between(1, 6) * 60 * 1000, actor, action: 'updateCustomer', targetId: c.id, targetLabel: c.name, detail: pick(['電話番号', '住所', 'メモ', '担当者', 'フリガナ']) });
      }
    }
  }

  // まれな操作
  const deleted = [
    ['重複登録 山田 太郎', '同じ人が2件（CSV取込前に手で登録していた）'],
    ['テスト 顧客', '操作の練習で作った'],
    ['株式会社岡南運輸（旧）', '社名変更で新しく登録し直した'],
  ];
  deleted.forEach(([label, detail], i) => {
    const at = dayMs(-between(30, 330)) + 15 * HOUR;
    out.audit.push({ at, actor: owner, action: 'deleteCustomer', targetId: `deleted_${i}_${autoId().slice(0, 8)}`, targetLabel: label, detail });
  });
  for (let i = 0; i < 6; i++) {
    const c = pick(pool);
    out.audit.push({ at: dayMs(-between(10, 340)) + 16 * HOUR, actor: pick(ACTORS), action: 'deleteVehicle', targetId: c.id, targetLabel: c.name, detail: pick(['廃車', '売却', '乗り換え']) });
  }
  out.audit.push({ at: dayMs(-180) + 17 * HOUR, actor: owner, action: 'exportLedger', detail: `顧客 ${out.customers.length}件` });
  out.audit.push({ at: dayMs(-12) + 17 * HOUR, actor: owner, action: 'exportLedger', detail: `顧客 ${out.customers.length}件` });

  out.audit.sort((a, b) => a.at - b.at);
}

// ---------------------------------------------------------------------------
// 書き込み・削除
// ---------------------------------------------------------------------------
const SUBCOLLECTIONS = ['customers', 'customer_vehicles', 'service_records', 'audit_logs', 'members'];
const TOP_COLLECTIONS = ['shop_staff', 'shop_staff_invites', 'shop_invites', 'maintenance_records', 'users'];

async function seededDocs(db, colRef) {
  const snap = await colRef.where('seedTag', '==', SEED_TAG).select().get();
  return snap.docs;
}

async function wipe(db, keep) {
  const shop = db.collection('shops').doc(SHOP_ID);
  const w = db.bulkWriter();
  const removed = {};
  const consider = (name, docs) => {
    let n = 0;
    for (const d of docs) {
      if (keep && keep.has(d.ref.path)) continue;
      w.delete(d.ref);
      n++;
    }
    removed[name] = n;
  };
  for (const c of SUBCOLLECTIONS) consider(c, await seededDocs(db, shop.collection(c)));
  for (const c of TOP_COLLECTIONS) consider(c, await seededDocs(db, db.collection(c)));
  // スレッドはメッセージごと
  const inq = await seededDocs(db, db.collection('inquiries'));
  let msgN = 0;
  for (const d of inq) {
    const msgs = await d.ref.collection('messages').where('seedTag', '==', SEED_TAG).select().get();
    for (const m of msgs.docs) {
      if (keep && keep.has(m.ref.path)) continue;
      w.delete(m.ref);
      msgN++;
    }
  }
  consider('inquiries', inq);
  removed.messages = msgN;
  await w.close();

  if (!keep) {
    // 札から、このシードが足した項目だけを外す（札そのものは seed_shop_owner.js のもの）
    for (const p of PERSONAS) {
      const ref = db.collection('shop_customers').doc(p.uid);
      const doc = await ref.get();
      if (doc.exists && doc.data().inviteCode === p.invite) {
        await ref.update({
          customerId: admin.firestore.FieldValue.delete(),
          inviteCode: admin.firestore.FieldValue.delete(),
        });
      }
    }
    if (EMULATOR) {
      for (const s of STAFF) {
        try {
          await admin.auth().deleteUser(s.uid);
        } catch (e) {
          // いなければよい
        }
      }
    }
  }
  return removed;
}

let admin = null;

async function main() {
  admin = require('firebase-admin');
  if (!admin.apps.length) admin.initializeApp({ projectId: 'trust-car-platform' });
  ts = (ms) => admin.firestore.Timestamp.fromMillis(ms);
  const db = admin.firestore();
  const t0 = Date.now();

  if (DELETE) {
    if (DRY_RUN) {
      console.log('[DRY-RUN] 削除は行いません');
      return;
    }
    const removed = await wipe(db, null);
    console.log('[DELETE] 消した件数:');
    for (const [k, n] of Object.entries(removed)) console.log(`  ${k.padEnd(20)} ${n}`);
    console.log(`\n削除しました（${((Date.now() - t0) / 1000).toFixed(1)}秒）。`);
    return;
  }

  if (!DRY_RUN) {
    const shopDoc = await db.collection('shops').doc(SHOP_ID).get();
    if (!shopDoc.exists || shopDoc.data().ownerId !== OWNER_UID) {
      console.error(`[ERROR] shops/${SHOP_ID} が無いか、店主が紐づいていません。先に seed_shops.js → seed_personas.js → seed_shop_owner.js を流してください。`);
      process.exitCode = 1;
      return;
    }
    for (const p of PERSONAS) {
      const link = await db.collection('shop_customers').doc(p.uid).get();
      if (!link.exists || link.data().shopId !== SHOP_ID) {
        console.error(`[ERROR] shop_customers/${p.uid} がタカヤモーターを指していません。先に seed_shop_owner.js を流してください。`);
        process.exitCode = 1;
        return;
      }
    }
  }

  // ---- 生成 ----
  buildCustomers();
  buildVehiclesAndHistory();
  const extras = await buildPersonas(DRY_RUN ? null : db);
  applyInspections();
  summarize();
  buildAudit();

  // ---- 書き込む文書 ----
  const shop = db.collection('shops').doc(SHOP_ID);
  const writes = [];
  for (const c of out.customers) writes.push([shop.collection('customers').doc(c.id), customerDoc(c)]);
  for (const v of out.vehicles) writes.push([shop.collection('customer_vehicles').doc(v.id), vehicleDoc(v)]);
  for (const r of out.records) writes.push([shop.collection('service_records').doc(r.id), recordDoc(r)]);
  out.audit.forEach((a, i) => {
    writes.push([shop.collection('audit_logs').doc(`seedlog_${String(i).padStart(6, '0')}`), {
      actorUid: a.actor.uid, actorName: a.actor.name, action: a.action,
      ...(a.targetId ? { targetId: a.targetId } : {}),
      ...(a.targetLabel ? { targetLabel: a.targetLabel } : {}),
      ...(a.detail ? { detail: a.detail } : {}),
      at: ts(a.at), ...META,
    }]);
  });

  // スタッフ
  writes.push([shop.collection('members').doc(OWNER_UID), { role: 'owner', displayName: OWNER_NAME, addedAt: ts(ROSTER_IMPORT_AT - 2 * DAY), ...META }]);
  for (const s of STAFF) {
    const added = dayMs(-s.addedDays) + 10 * HOUR;
    writes.push([shop.collection('members').doc(s.uid), { role: 'staff', displayName: s.name, email: s.email, inviteCode: s.code, addedAt: ts(added), ...META }]);
    writes.push([db.collection('shop_staff').doc(s.uid), { shopId: SHOP_ID, shopName: SHOP_NAME, ...META }]);
    writes.push([db.collection('shop_staff_invites').doc(s.code), {
      shopId: SHOP_ID, shopName: SHOP_NAME, issuedBy: OWNER_UID,
      createdAt: ts(added - 3 * HOUR), expiresAt: ts(added - 3 * HOUR + 7 * DAY),
      usedBy: s.uid, usedAt: ts(added), ...META,
    }]);
    writes.push([db.collection('users').doc(s.uid), {
      email: s.email, displayName: s.name, accountType: 'business', companyName: SHOP_NAME,
      planType: 'free', createdAt: ts(added), updatedAt: ts(added), ...META,
    }]);
  }
  // まだ使われていないコード（有効）と、期限切れのコード
  writes.push([db.collection('shop_staff_invites').doc('R5NV2G'), {
    shopId: SHOP_ID, shopName: SHOP_NAME, issuedBy: OWNER_UID,
    createdAt: ts(dayMs(-2) + 10 * HOUR), expiresAt: ts(dayMs(5) + 10 * HOUR), usedBy: null, ...META,
  }]);
  writes.push([db.collection('shop_staff_invites').doc('X8CF3J'), {
    shopId: SHOP_ID, shopName: SHOP_NAME, issuedBy: OWNER_UID,
    createdAt: ts(dayMs(-40) + 10 * HOUR), expiresAt: ts(dayMs(-33) + 10 * HOUR), usedBy: null, ...META,
  }]);

  // ペルソナのつながり・明細
  for (const inv of extras.invites) writes.push([db.collection('shop_invites').doc(inv.code), inv.data]);
  for (const q of extras.inquiries) writes.push([db.collection('inquiries').doc(q.id), q.data]);
  for (const m of extras.messages) writes.push([db.collection('inquiries').doc(m.inquiryId).collection('messages').doc(m.id), m.data]);
  for (const r of extras.appRecords) writes.push([db.collection('maintenance_records').doc(r.id), r.data]);

  // ---- 件数 ----
  const ind = out.customers.filter((c) => c.kind === 'individual');
  const corp = out.customers.filter((c) => c.kind === 'corporate');
  const lapsedSince = new Date(TODAY);
  lapsedSince.setFullYear(lapsedSince.getFullYear() - 1);
  const in30 = out.vehicles.filter((v) => v.expiry != null && v.expiry >= TODAY && v.expiry < TODAY + 31 * DAY).length;
  const in60 = out.vehicles.filter((v) => v.expiry != null && v.expiry >= TODAY && v.expiry < TODAY + 61 * DAY).length;
  const expired = out.vehicles.filter((v) => v.expiry != null && v.expiry < TODAY).length;
  const noticedNow = out.vehicles.filter((v) => v.noticeExpiry != null && v.noticeExpiry === v.expiry).length;
  const corpSizes = corp.map((c) => c.vehicleCount);
  const yearRecords = out.records.filter((r) => r.date >= YEAR_START).length;
  console.log(`■ タカヤモーターの顧客台帳（基準日 ${new Date(TODAY).toLocaleDateString('ja-JP')}・最後の履歴取込 ${new Date(LAST_IMPORT).toLocaleString('ja-JP')}）`);
  console.log(`  顧客          ${out.customers.length}（個人 ${ind.length}・法人 ${corp.length}・アプリ利用中 ${out.customers.filter((c) => c.linkedUserId).length}）`);
  console.log(`                取込 csv ${out.customers.filter((c) => c.source === 'csv').length}・手入力 manual ${out.customers.filter((c) => c.source === 'manual').length}`);
  console.log(`                しばらく来ていない（最終来店が1年より前）${out.customers.filter((c) => c.lastVisitAt != null && c.lastVisitAt < lapsedSince.getTime()).length}・来店記録なし ${out.customers.filter((c) => c.lastVisitAt == null).length}`);
  console.log(`  車両          ${out.vehicles.length}（法人の台数 ${Math.min(...corpSizes)}〜${Math.max(...corpSizes)}台）`);
  console.log(`                車検 期限切れ ${expired}・30日以内 ${in30}・60日以内 ${in60}・満了日なし ${out.vehicles.filter((v) => v.expiry == null).length}`);
  console.log(`                いまの満了日で案内済み ${noticedNow}`);
  console.log(`  整備履歴      ${out.records.length}（うち直近1年 ${yearRecords}・明細送付済み ${out.records.filter((r) => r.detailSentAt != null).length}）`);
  console.log(`  操作の記録    ${out.audit.length}`);
  console.log(`  スタッフ      店主 1・スタッフ ${STAFF.length}`);
  console.log(`  ペルソナ      スレッド ${extras.inquiries.length}・明細メッセージ ${extras.messages.length}・取り込み済みの明細 ${extras.appRecords.length}`);
  console.log(`  書き込む文書  ${writes.length}`);

  if (DRY_RUN) {
    console.log('\n[DRY-RUN] 書き込みは行いません');
    return;
  }

  // ---- Auth（スタッフ。エミュレータのみ） ----
  for (const s of STAFF) {
    try {
      await admin.auth().createUser({ uid: s.uid, email: s.email, password: DEMO_PASSWORD, displayName: s.name });
    } catch (e) {
      if (e.code !== 'auth/uid-already-exists' && e.code !== 'auth/email-already-exists') throw e;
    }
  }

  // ---- 書き込み ----
  const w = db.bulkWriter();
  let done = 0;
  for (const [ref, data] of writes) {
    w.set(ref, data).then(() => {
      done++;
      if (done % 5000 === 0) process.stdout.write(`  ... ${done}/${writes.length}\n`);
    });
  }
  await w.close();

  // 札に台帳の顧客IDを足す（お客さんが顧客専用コードを入れたときと同じ形）
  for (const l of extras.links) {
    await db.collection('shop_customers').doc(l.uid).set(
      { customerId: l.customerId, inviteCode: l.inviteCode, linkedAt: ts(l.linkedAt) },
      { merge: true },
    );
  }

  // ---- 前回の分のうち、今回作らなかったものを消す（流し直しても増えない） ----
  const keep = new Set(writes.map(([ref]) => ref.path));
  const removed = await wipe(db, keep);
  const removedTotal = Object.values(removed).reduce((s, n) => s + n, 0);

  console.log(`\n[SUCCESS] ${writes.length} 件を書き込みました（前回の残り ${removedTotal} 件を削除・${((Date.now() - t0) / 1000).toFixed(1)}秒）。`);
  console.log('店側でログイン: shop.owner@example.com / password123（スタッフは staff1〜4.takaya@example.com / password123）');
  console.log('後片付け: node seed_shop_ledger_year.js --delete --emulator');
}

if (require.main === module) {
  guardTarget();
  main().catch((e) => {
    console.error('[FATAL]', e);
    process.exit(1);
  });
}

module.exports = { nameKey, plateKey, plateNumber, guessMaintenanceType, idForExternal };
