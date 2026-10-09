#!/usr/bin/env node
/**
 * verify_shop_ledger.js — 店主・スタッフ・お客さんとして本当にログインし、
 * 顧客台帳（seed_shop_ledger_year.js）がアプリと同じクエリで読めるかを確かめる
 *
 * Usage:
 *   firebase emulators:start --only auth,firestore,storage   # 別ターミナル
 *   ./scripts/seed_usability_test.sh                        # シードを流す（最後にこれも走る）
 *   node scripts/verify_shop_ledger.js
 *
 * なぜ要るか:
 *   verify_personas.js と同じ理由。Admin SDK で書いたデータは、ルールを
 *   通らずに入る。**アプリはクライアント SDK でルール越しに読む**ので、
 *   「シードは入ったのに、店主の画面には1件も出ない」が起こりうる。
 *   ここでは lib/services/shop_ledger_service.dart ほかと同じ形のクエリを、
 *   本物の firestore.rules 越しに流す。
 *
 * NG が1件でもあれば終了コード 1。
 */

const { initializeApp } = require('firebase/app');
const {
  getAuth, connectAuthEmulator, signInWithEmailAndPassword, signOut,
} = require('firebase/auth');
const {
  getFirestore, connectFirestoreEmulator, collection, doc, getDoc, getDocs,
  query, where, orderBy, limit, getCountFromServer, Timestamp,
} = require('firebase/firestore');

const { nameKey, plateNumber, searchDigits } = require('./seed_shop_ledger_year.js');

const PASSWORD = 'password123';
const SHOP_ID = 'shop_takaya_motor_okayama';
const RANGE_END = ''; // LedgerSearch.rangeEnd
const PAGE = 20; // ShopLedgerService.pageSize

const app = initializeApp({ projectId: 'trust-car-platform', apiKey: 'demo-key' });
const auth = getAuth(app);
connectAuthEmulator(auth, `http://${process.env.FIREBASE_AUTH_EMULATOR_HOST || 'localhost:9099'}`, { disableWarnings: true });
const db = getFirestore(app);
{
  const [h, p] = (process.env.FIRESTORE_EMULATOR_HOST || 'localhost:8080').split(':');
  connectFirestoreEmulator(db, h, Number(p));
}

const results = [];
let who = '';

async function check(label, fn, expect) {
  try {
    const got = await fn();
    const { n, note } = typeof got === 'object' && got !== null ? got : { n: got };
    const ok = expect ? expect(n) : true;
    results.push({ who, label, ok });
    console.log(`  ${ok ? '[OK]' : '[NG]'} ${label} — ${n}${note ? `（${note}）` : ''}`);
  } catch (e) {
    results.push({ who, label, ok: false });
    console.log(`  [NG] ${label} — ${e.code || e.message}`);
  }
}

async function denies(label, fn) {
  let denied = false;
  let detail = '読めてしまった';
  try {
    await fn();
  } catch (e) {
    denied = e.code === 'permission-denied';
    detail = e.code || e.message;
  }
  results.push({ who, label, ok: denied });
  console.log(`  ${denied ? '[OK]' : '[NG]'} ${label} — ${detail}`);
}

async function as(email, name, body) {
  who = name;
  console.log(`\n=== ${name}（${email}）===`);
  const cred = await signInWithEmailAndPassword(auth, email, PASSWORD);
  await body(cred.user.uid);
  await signOut(auth);
}

const shopCol = (c) => collection(db, 'shops', SHOP_ID, c);
const today = (() => {
  const d = new Date();
  d.setHours(0, 0, 0, 0);
  return d;
})();
const fmt = (t) => (t ? t.toDate().toLocaleDateString('ja-JP') : '-');

// ShopLedgerService.listCustomers(search:) と同じ（2026-10-09 から searchKeys の
// array-contains。LedgerSearch.queryKey: 数字と区切りだけで5桁以上なら電話番号）
const isPhoneQuery = (text) => searchDigits(text).length >= 5 && /^[0-9０-９\s\-‐－ー()（）+]+$/.test(text);
const searchCustomers = (text) => {
  const key = isPhoneQuery(text) ? searchDigits(text) : nameKey(text);
  return getDocs(query(shopCol('customers'),
    where('searchKeys', 'array-contains', Array.from(key).slice(0, 20).join('')),
    orderBy('searchKey'), limit(PAGE + 1)));
};
// ShopLedgerService.findVehiclesByPlateNumber と同じ（2桁以上は plateTails）
const searchPlates = (text) => {
  const key = plateNumber(text);
  return getDocs(query(shopCol('customer_vehicles'),
    key.length === 1 ? where('plateNumber', '==', key) : where('plateTails', 'array-contains', key),
    limit(PAGE)));
};

async function ownerChecks() {
  // ---- 件数（counts） ----
  const col = shopCol('customers');
  await check('件数 count()：全体', async () => (await getCountFromServer(col)).data().count, (n) => n === 4100);
  await check('件数 count()：個人', async () => (await getCountFromServer(query(col, where('kind', '==', 'individual')))).data().count, (n) => n === 4000);
  await check('件数 count()：法人', async () => (await getCountFromServer(query(col, where('kind', '==', 'corporate')))).data().count, (n) => n === 100);
  await check('件数 count()：アプリ利用中', async () => (await getCountFromServer(query(col, where('isLinked', '==', true)))).data().count, (n) => n === 3);

  // ---- 一覧の並べ方 ----
  await check('50音順（1ページ目）', async () => {
    const s = await getDocs(query(col, orderBy('searchKey'), limit(PAGE + 1)));
    const keys = s.docs.map((d) => d.get('searchKey'));
    const sorted = keys.every((k, i) => i === 0 || keys[i - 1] <= k);
    return { n: sorted ? s.size : -1, note: `先頭 ${s.docs[0]?.get('name')}` };
  }, (n) => n === PAGE + 1);
  await check('最近来た順', async () => {
    const s = await getDocs(query(col, orderBy('lastVisitAt', 'desc'), limit(PAGE + 1)));
    return { n: s.size, note: `いちばん最近 ${fmt(s.docs[0]?.get('lastVisitAt'))}` };
  }, (n) => n === PAGE + 1);
  await check('登録の新しい順', async () => {
    const s = await getDocs(query(col, orderBy('createdAt', 'desc'), limit(PAGE + 1)));
    return { n: s.size, note: `先頭 ${s.docs[0]?.get('name')}（${s.docs[0]?.get('source')}）` };
  }, (n) => n === PAGE + 1);

  // ---- フリガナ検索 ----
  await check('フリガナ検索「やまだ」', async () => {
    const s = await searchCustomers('やまだ');
    return { n: s.size, note: s.docs.slice(0, 3).map((d) => d.get('name')).join('・') };
  }, (n) => n > 0);
  await check('フリガナ検索「ﾔﾏﾀﾞ」（半角カナでも同じ人が出る）', async () => {
    const a = (await searchCustomers('やまだ')).docs.map((d) => d.id).join();
    const b = (await searchCustomers('ﾔﾏﾀﾞ')).docs.map((d) => d.id).join();
    return { n: a === b && a.length > 0 ? 1 : 0 };
  }, (n) => n === 1);
  await check('フリガナ検索「ヤマダ タ」（カタカナ・空白入り）', async () => {
    const s = await searchCustomers('ヤマダ タ');
    return { n: s.size, note: s.docs.slice(0, 3).map((d) => d.get('name')).join('・') };
  }, (n) => n > 0);
  await check('フリガナ検索「こじん」→ ペルソナA', async () => {
    const s = await searchCustomers('こじん');
    return { n: s.docs.filter((d) => d.get('linkedUserId') === 'user-a').length };
  }, (n) => n === 1);
  await check('フリガナ検索「きび」（法人・法人格を除いたフリガナ）', async () => {
    const s = await searchCustomers('きび');
    return { n: s.docs.filter((d) => d.get('kind') === 'corporate').length, note: s.docs.slice(0, 2).map((d) => d.get('name')).join('・') };
  }, (n) => n > 0);

  // ---- 漢字・名だけ・電話番号（2026-10-09） ----
  await check('漢字の姓「青木」で、青木さんが全員（1ページ目）', async () => {
    const s = await searchCustomers('青木');
    const all = s.docs.every((d) => d.get('name').startsWith('青木'));
    return { n: all ? s.size : -1, note: s.docs.slice(0, 4).map((d) => d.get('name')).join('・') };
  }, (n) => n > 1);
  await check('漢字の名だけ「太郎」→ ペルソナA を含む', async () => {
    let found = false;
    let s = await searchCustomers('太郎');
    const n = s.size;
    found = s.docs.some((d) => d.get('linkedUserId') === 'user-a');
    if (!found) {
      // 1ページに収まらないときは、名前の近い順の先まで見る
      const all = await getDocs(query(shopCol('customers'), where('searchKeys', 'array-contains', '太郎')));
      found = all.docs.some((d) => d.get('linkedUserId') === 'user-a');
    }
    return { n: found ? 1 : 0, note: `1ページ目 ${n}件` };
  }, (n) => n === 1);
  await check('名のフリガナだけ「たろう」', async () => (await searchCustomers('たろう')).size, (n) => n > 0);
  await check('電話番号の先頭「090-0418」→ ペルソナA', async () => {
    const s = await searchCustomers('090-0418');
    return { n: s.docs.filter((d) => d.get('linkedUserId') === 'user-a').length, note: `${s.size}件` };
  }, (n) => n === 1);
  await check('検索用の項目が全員にある（searchVersion=2）', async () => {
    const all = (await getCountFromServer(col)).data().count;
    const ok = (await getCountFromServer(query(col, where('searchVersion', '==', 2)))).data().count;
    return { n: all - ok, note: `${ok}/${all}` };
  }, (n) => n === 0);

  // ---- ナンバー末尾（findVehiclesByPlateNumber） ----
  const vcol = shopCol('customer_vehicles');
  await check('ナンバー末尾「22-22」→ ペルソナAのハイエース', async () => {
    const s = await searchPlates('22-22');
    return { n: s.docs.filter((d) => d.get('customerName') === '個人 太郎').length, note: `${s.size}台が該当` };
  }, (n) => n === 1);
  await check('ナンバー末尾（全角「２２－２２」でも同じ車が引ける）', async () => {
    const s = await searchPlates('２２－２２');
    return { n: s.docs.filter((d) => d.get('customerName') === '個人 太郎').length, note: s.docs.map((d) => d.get('plate')).join(' / ') };
  }, (n) => n === 1);
  await check('ナンバー末尾2桁「35」（2026-10-09。末尾が35の車がすべて当たる）', async () => {
    const s = await searchPlates('35');
    const ok = s.docs.every((d) => plateNumber(d.get('plate')).endsWith('35'));
    return { n: ok ? s.size : -1, note: s.docs.slice(0, 3).map((d) => d.get('plate')).join(' / ') };
  }, (n) => n > 0);
  await check('ナンバー末尾3桁「222」→ ペルソナAのハイエース', async () => {
    const all = await getDocs(query(vcol, where('plateTails', 'array-contains', '222')));
    return { n: all.docs.filter((d) => d.get('customerName') === '個人 太郎').length, note: `${all.size}台` };
  }, (n) => n === 1);

  // ---- 車検が近い順（listVehiclesByInspection） ----
  await check('車検が近い順（今日以降・1ページ目）', async () => {
    const s = await getDocs(query(vcol, where('inspectionExpiry', '>=', Timestamp.fromDate(today)), orderBy('inspectionExpiry'), limit(PAGE + 1)));
    const ds = s.docs.map((d) => d.get('inspectionExpiry').toMillis());
    const ok = ds.every((t, i) => t >= today.getTime() && (i === 0 || ds[i - 1] <= t));
    return { n: ok ? s.size : -1, note: `${fmt(s.docs[0]?.get('inspectionExpiry'))}〜${fmt(s.docs[s.size - 1]?.get('inspectionExpiry'))}` };
  }, (n) => n === PAGE + 1);
  const in30 = new Date(today); in30.setDate(in30.getDate() + 30);
  const in60 = new Date(today); in60.setDate(in60.getDate() + 60);
  await check('車検 30日以内', async () => (await getCountFromServer(query(vcol, where('inspectionExpiry', '>=', Timestamp.fromDate(today)), where('inspectionExpiry', '<', Timestamp.fromDate(in30))))).data().count, (n) => n > 0);
  await check('車検 60日以内', async () => (await getCountFromServer(query(vcol, where('inspectionExpiry', '>=', Timestamp.fromDate(today)), where('inspectionExpiry', '<', Timestamp.fromDate(in60))))).data().count, (n) => n > 0);
  await check('車検 期限切れ', async () => (await getCountFromServer(query(vcol, where('inspectionExpiry', '<', Timestamp.fromDate(today))))).data().count, (n) => n > 0);

  // 車検案内（_noticeCandidates：2か月以内）
  await check('車検案内の候補（2か月以内・案内済みの数）', async () => {
    const to = new Date(today); to.setMonth(to.getMonth() + 2); to.setDate(to.getDate() + 1);
    const s = await getDocs(query(vcol, where('inspectionExpiry', '>=', Timestamp.fromDate(today)), where('inspectionExpiry', '<', Timestamp.fromDate(to)), orderBy('inspectionExpiry')));
    const noticed = s.docs.filter((d) => d.get('inspectionNoticeAt') && d.get('inspectionNoticeExpiry')?.toMillis() === d.get('inspectionExpiry').toMillis()).length;
    return { n: s.size, note: `うち案内済み ${noticed}台` };
  }, (n) => n > 0);

  // ---- しばらく来ていない（listLapsedCustomers） ----
  await check('しばらく来ていない（最終来店が1年より前・古い順）', async () => {
    const since = new Date(today); since.setFullYear(since.getFullYear() - 1);
    const s = await getDocs(query(col, where('lastVisitAt', '<', Timestamp.fromDate(since)), orderBy('lastVisitAt'), limit(PAGE + 1)));
    const total = (await getCountFromServer(query(col, where('lastVisitAt', '<', Timestamp.fromDate(since))))).data().count;
    return { n: s.size, note: `全体 ${total}人・いちばん古い ${fmt(s.docs[0]?.get('lastVisitAt'))}` };
  }, (n) => n === PAGE + 1);

  // ---- ある顧客の車（vehiclesOf） ----
  await check('法人の車（vehiclesOf・いちばん台数の多い法人）', async () => {
    const s = await getDocs(query(col, where('kind', '==', 'corporate'), orderBy('vehicleCount', 'desc'), limit(1)));
    const c = s.docs[0];
    const vs = await getDocs(query(vcol, where('customerId', '==', c.id)));
    return { n: vs.size === c.get('vehicleCount') ? vs.size : -1, note: `${c.get('name')}・vehicleCount=${c.get('vehicleCount')}` };
  }, (n) => n >= 2);

  // ---- 取りこぼし（lossReport の読み取り） ----
  const rcol = shopCol('service_records');
  await check('整備履歴：最後の取込（updatedAt の新しい順）', async () => {
    const s = await getDocs(query(rcol, orderBy('updatedAt', 'desc'), limit(1)));
    const t = s.docs[0]?.get('updatedAt')?.toDate();
    const days = t ? Math.floor((today - t) / 86400000) : 999;
    return { n: days, note: `${t?.toLocaleString('ja-JP')}（30日を超えると率を出さない）` };
  }, (n) => n <= 30);
  // lossReport は伝票を読まず、車の lastInspectionAt / lastInspectionDueAt で数える
  // （2026-10-09）。満了日が進んだ車も「入庫した」に数え、率が 100% に張り付かないこと
  await check('取りこぼし：直近12か月の率（車だけで数える）', async () => {
    const from = new Date(today.getFullYear(), today.getMonth() - 11, 1);
    const expired = await getDocs(query(vcol, where('inspectionExpiry', '>=', Timestamp.fromDate(from)), where('inspectionExpiry', '<', Timestamp.fromDate(today))));
    const unknown = expired.docs.filter((d) => !('lastInspectionAt' in d.data())).length;
    const lost = expired.docs.filter((d) => {
      const last = d.get('lastInspectionAt');
      const ws = new Date(d.get('inspectionExpiry').toDate()); ws.setDate(ws.getDate() - 60);
      return !last || last.toDate() < ws;
    }).length;
    const renewed = (await getCountFromServer(query(vcol, where('lastInspectionDueAt', '>=', Timestamp.fromDate(from)), where('lastInspectionDueAt', '<', Timestamp.fromDate(today))))).data().count;
    const overlap = expired.docs.filter((d) => { const t = d.get('lastInspectionDueAt')?.toMillis(); return t != null && t >= from.getTime() && t < today.getTime(); }).length;
    const returned = renewed - overlap + (expired.size - lost);
    const rate = Math.round((lost / (lost + returned)) * 100);
    return { n: unknown === 0 ? rate : -1, note: `取りこぼし ${lost}台・入庫 ${returned}台・最後の車検日が無い車 ${unknown}台` };
  }, (n) => n > 0 && n < 50);
  await check('整備履歴：直近1年', async () => {
    const from = new Date(today); from.setFullYear(from.getFullYear() - 1);
    return (await getCountFromServer(query(rcol, where('date', '>=', Timestamp.fromDate(from))))).data().count;
  }, (n) => n > 5000);

  // ---- 送っていない明細（DetailDeliveryService.pending） ----
  await check('送っていない明細（アプリ利用中の客・90日）', async () => {
    const linked = await getDocs(query(col, where('isLinked', '==', true)));
    const ids = new Set(linked.docs.map((d) => d.id));
    const since = new Date(today); since.setDate(since.getDate() - 90);
    const s = await getDocs(query(rcol, where('date', '>=', Timestamp.fromDate(since))));
    const mine = s.docs.filter((d) => ids.has(d.get('customerId')));
    const sent = mine.filter((d) => d.get('detailSentAt')).length;
    return { n: mine.length - sent, note: `アプリ利用客の入庫 ${mine.length}件・送付済み ${sent}件` };
  }, (n) => n >= 1);

  // ---- スタッフ・操作の記録 ----
  await check('スタッフ（members）', async () => (await getDocs(shopCol('members'))).size, (n) => n === 5);
  await check('操作の記録（新しい順・1ページ目）', async () => {
    const s = await getDocs(query(shopCol('audit_logs'), orderBy('at', 'desc'), limit(PAGE + 1)));
    return { n: s.size, note: `最新 ${s.docs[0]?.get('actorName')}「${s.docs[0]?.get('action')}」` };
  }, (n) => n === PAGE + 1);
  await check('操作の記録（ペルソナAの顧客について）', async () => {
    const a = await searchCustomers('こじんたろう');
    const id = a.docs[0].id;
    const s = await getDocs(query(shopCol('audit_logs'), where('targetId', '==', id), orderBy('at', 'desc'), limit(PAGE + 1)));
    return { n: s.size, note: s.docs.map((d) => d.get('action')).join(',') };
  }, (n) => n >= 2);

  // ---- 店から開いたスレッド ----
  await check('店の問い合わせ一覧（shopId・updatedAt の新しい順）', async () => {
    const s = await getDocs(query(collection(db, 'inquiries'), where('shopId', '==', SHOP_ID), orderBy('updatedAt', 'desc'), limit(50)));
    return { n: s.docs.filter((d) => d.get('openedByShop')).length, note: `全体 ${s.size}件` };
  }, (n) => n === 3);
}

async function main() {
  await as('shop.owner@example.com', '店主（タカヤモーター）', ownerChecks);

  await as('staff2.takaya@example.com', 'スタッフ（整備士）', async () => {
    await check('台帳を読める（count）', async () => (await getCountFromServer(shopCol('customers'))).data().count, (n) => n === 4100);
    await check('車検が近い順を読める', async () => (await getDocs(query(shopCol('customer_vehicles'), where('inspectionExpiry', '>=', Timestamp.fromDate(today)), orderBy('inspectionExpiry'), limit(PAGE + 1)))).size, (n) => n === PAGE + 1);
    await denies('操作の記録は読めない（店主だけ）', () => getDocs(query(shopCol('audit_logs'), orderBy('at', 'desc'), limit(1))));
  });

  await as('persona.a@example.com', 'ペルソナA（店から明細が届いた人）', async (uid) => {
    let inquiryId = null;
    await check('問い合わせ一覧に店からのスレッドがある', async () => {
      const s = await getDocs(query(collection(db, 'inquiries'), where('userId', '==', uid), orderBy('updatedAt', 'desc'), limit(50)));
      const t = s.docs.find((d) => d.get('openedByShop') === true && d.get('shopId') === SHOP_ID);
      inquiryId = t?.id ?? null;
      return { n: t ? 1 : 0, note: t ? `「${t.get('subject')}」未読 ${t.get('unreadCountUser')}` : '' };
    }, (n) => n === 1);
    await check('スレッドの明細（maintenancePayload 付きのメッセージ）', async () => {
      const s = await getDocs(query(collection(db, 'inquiries', inquiryId, 'messages'), orderBy('sentAt'), limit(50)));
      const withPayload = s.docs.filter((d) => d.get('isFromShop') && d.get('maintenancePayload'));
      return { n: withPayload.length, note: withPayload.map((d) => `${d.get('maintenancePayload').title} ¥${d.get('maintenancePayload').cost}`).join(' / ') };
    }, (n) => n === 2);
    await check('取り込んだ明細が自分の記録にある（出所: shopImported・inquiryId 付き）', async () => {
      const s = await getDocs(query(collection(db, 'maintenance_records'), where('userId', '==', uid)));
      const fromShop = s.docs.filter((d) => d.get('verificationSource') === 'shopImported' && d.get('inquiryId') === inquiryId);
      return { n: fromShop.length, note: fromShop.map((d) => d.get('title')).join('・') };
    }, (n) => n === 1);
    await check('自分の札（shop_customers）に台帳の顧客IDがある', async () => {
      const d = await getDoc(doc(db, 'shop_customers', uid));
      return { n: d.get('customerId') ? 1 : 0, note: d.get('customerId') };
    }, (n) => n === 1);
    await denies('店の台帳は読めない', () => getDocs(query(shopCol('customers'), limit(1))));
  });

  await as('persona.j@example.com', 'ペルソナJ（法人・明細が届いた人）', async (uid) => {
    await check('取り込んだ明細が自分の記録にある', async () => {
      const s = await getDocs(query(collection(db, 'maintenance_records'), where('userId', '==', uid)));
      return s.docs.filter((d) => d.get('verificationSource') === 'shopImported').length;
    }, (n) => n === 1);
  });

  const ng = results.filter((r) => !r.ok);
  console.log(`\n${results.length} 件中 NG ${ng.length} 件`);
  for (const r of ng) console.log(`  [NG] ${r.who}: ${r.label}`);
  process.exit(ng.length ? 1 : 0);
}

main().catch((e) => {
  console.error('[FATAL]', e);
  process.exit(1);
});
