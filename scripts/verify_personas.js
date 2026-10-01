#!/usr/bin/env node
/**
 * verify_personas.js — ペルソナを実際にログインさせて、1年ぶんのデータを通す
 *
 * Usage:
 *   firebase emulators:start --only auth,firestore     # 別ターミナル
 *   （docs/TEST_DATA_GUIDE.md の順でシードを流しておく）
 *   node scripts/verify_personas.js
 *
 * なぜ要るか:
 *   Dart のペルソナテスト（test/integration/persona_*.dart）は
 *   FakeFirebaseFirestore で動く。**FakeFirestore はセキュリティルールを
 *   評価しない**ので、「テストは緑なのに本番では1件も返らない」クエリを
 *   原理的に検出できない。2026-09-08 のレビューで14件見つかり、直したのは
 *   4件だけで残りは未検出のまま残っていた。
 *
 *   このスクリプトは **Auth エミュレータで本当にログインし**、アプリが投げる
 *   のと同じ形のクエリを、**本物の firestore.rules 越しに**流す。ルールに
 *   弾かれるクエリはここで落ちる。
 *
 * 出すもの:
 *   各ペルソナごとの [OK] / [NG] と、最後に NG の一覧。NG が1件でもあれば
 *   終了コード 1（CI から呼べる）。
 */

const { initializeApp } = require('../test/rules/node_modules/firebase/app');
const {
  getAuth,
  connectAuthEmulator,
  signInWithEmailAndPassword,
  signOut,
} = require('../test/rules/node_modules/firebase/auth');
const {
  getFirestore,
  connectFirestoreEmulator,
  collection,
  collectionGroup,
  doc,
  getDoc,
  getDocs,
  query,
  where,
  orderBy,
  limit,
  getCountFromServer,
} = require('../test/rules/node_modules/firebase/firestore');

const PASSWORD = 'password123';

const app = initializeApp({ projectId: 'trust-car-platform', apiKey: 'demo-key' });
const auth = getAuth(app);
connectAuthEmulator(auth, 'http://localhost:9099', { disableWarnings: true });
const db = getFirestore(app);
connectFirestoreEmulator(db, 'localhost', 8080);

const results = [];
let currentPersona = '';

/**
 * 1つの確認。fn は件数（数値）か真偽値を返す。
 * expect を渡すと件数がその条件を満たすかまで見る。
 */
async function check(label, fn, expect) {
  try {
    const got = await fn();
    const n = typeof got === 'number' ? got : got ? 1 : 0;
    const ok = expect ? expect(n) : n >= 0;
    results.push({ persona: currentPersona, label, ok, detail: `${n} 件` });
    console.log(`  ${ok ? '[OK]' : '[NG]'} ${label} — ${n} 件`);
  } catch (e) {
    // ルールに弾かれた読み取りは permission-denied で来る。
    const detail = e.code || e.message;
    results.push({ persona: currentPersona, label, ok: false, detail });
    console.log(`  [NG] ${label} — ${detail}`);
  }
}

const count = async (q) => (await getDocs(q)).size;

/** 「拒否されること」を確かめる。通ってしまったら NG。 */
async function denies(label, fn) {
  let denied = false;
  let detail = '読めてしまった';
  try {
    await fn();
  } catch (e) {
    denied = e.code === 'permission-denied';
    detail = e.code || e.message;
  }
  results.push({ persona: currentPersona, label, ok: denied, detail });
  console.log(`  ${denied ? '[OK]' : '[NG]'} ${label} — ${detail}`);
}

async function as(email, name, body) {
  currentPersona = name;
  console.log(`\n=== ${name}（${email}）===`);
  const cred = await signInWithEmailAndPassword(auth, email, PASSWORD);
  await body(cred.user.uid);
  await signOut(auth);
}

async function main() {
  // -------------------------------------------------------------------------
  // ペルソナA — 1年使い込んだ個人ユーザー
  // -------------------------------------------------------------------------
  await as('persona.a@example.com', 'A 個人オーナー（1年利用）', async (uid) => {
    await check('自分の車両', () =>
      count(query(collection(db, 'vehicles'), where('userId', '==', uid))),
      (n) => n >= 4);

    // フィールド名はアプリの実装に合わせる（drive_logs=startTime /
    // fuel_records=date）。ここを取り違えると 0 件でも素通りする。
    await check('ドライブログ（新しい順）', () =>
      count(query(
        collection(db, 'drive_logs'),
        where('userId', '==', uid),
        orderBy('startTime', 'desc'),
        limit(20),
      )), (n) => n === 20);

    // FuelService.recordsFor は userId + vehicleId で絞る（ルールが userId を
    // 要求するため。2026-09-08 のレビューで直した形）。
    await check('給油記録（車両ごと・ハイエース）', () =>
      count(query(
        collection(db, 'fuel_records'),
        where('userId', '==', uid),
        where('vehicleId', '==', 'veh-a-cargo'),
        orderBy('date', 'desc'),
      )), (n) => n >= 10);

    await check('整備記録', () =>
      count(query(collection(db, 'maintenance_records'), where('userId', '==', uid))),
      (n) => n >= 12);

    await check('アクセサリーのクチコミ', () =>
      count(query(collection(db, 'accessory_showcases'), where('userId', '==', uid))),
      (n) => n >= 4);

    // --- 店舗とのチャット（お客様側） ---
    await check('問い合わせ一覧（更新の新しい順）', () =>
      count(query(
        collection(db, 'inquiries'),
        where('userId', '==', uid),
        orderBy('updatedAt', 'desc'),
      )), (n) => n >= 8);

    await check('未読のある問い合わせ', () =>
      count(query(
        collection(db, 'inquiries'),
        where('userId', '==', uid),
        where('unreadCountUser', '>', 0),
      )), (n) => n >= 1);

    // 集計クエリ（count）は、元のクエリと同じルール検証を受ける。件数を出す
    // ために全文書を読む作りをやめた分、ここが通ることを確かめておく。
    await check('未読数を集計クエリで数える', async () => {
      const snap = await getCountFromServer(query(
        collection(db, 'inquiries'),
        where('userId', '==', uid),
        where('unreadCountUser', '>', 0),
      ));
      return snap.data().count;
    }, (n) => n >= 1);

    await check('車検スレッドの会話を開く', () =>
      count(query(
        collection(db, 'inquiries', 'inq-yu-03-hiace-shaken', 'messages'),
        orderBy('sentAt'),
      )), (n) => n === 6);

    await check('未返信スレッドの会話を開く', () =>
      count(query(
        collection(db, 'inquiries', 'inq-yu-08-roadster-noise', 'messages'),
        orderBy('sentAt'),
      )), (n) => n === 0);
  });

  // -------------------------------------------------------------------------
  // 店舗ペルソナ — 同じ会話を店側から
  // -------------------------------------------------------------------------
  await as('shop.owner@example.com', '店舗（タカヤモーター）', async (uid) => {
    await check('自分の店（shops/{uid}）が引ける', async () => {
      const d = await getDoc(doc(db, 'shops', uid));
      return d.exists();
    }, (n) => n === 1);

    await check('自店あての問い合わせ一覧', () =>
      count(query(
        collection(db, 'inquiries'),
        where('shopId', '==', uid),
        orderBy('updatedAt', 'desc'),
      )), (n) => n >= 6);

    await check('未対応（pending）の問い合わせ', () =>
      count(query(
        collection(db, 'inquiries'),
        where('shopId', '==', uid),
        where('status', '==', 'pending'),
      )), (n) => n >= 1);

    await check('店側の未読バッジ', () =>
      count(query(
        collection(db, 'inquiries'),
        where('shopId', '==', uid),
        where('unreadCountShop', '>', 0),
      )), (n) => n >= 1);

    await check('お客様と同じ会話を店側から開く', () =>
      count(query(
        collection(db, 'inquiries', 'inq-yu-03-hiace-shaken', 'messages'),
        orderBy('sentAt'),
      )), (n) => n === 6);

    await check('自店の顧客（shop_customers）', () =>
      count(query(collection(db, 'shop_customers'), where('shopId', '==', uid))),
      (n) => n >= 3);
  });

  // -------------------------------------------------------------------------
  // 他のペルソナ — 既存のシードがルール越しに読めるか
  // -------------------------------------------------------------------------
  await as('persona.b@example.com', 'B 法人フリート', async (uid) => {
    const vehicles = await getDocs(
      query(collection(db, 'vehicles'), where('userId', '==', uid)),
    );
    await check('法人の車両', () => vehicles.size, (n) => n >= 20);

    const ids = vehicles.docs.slice(0, 10).map((d) => d.id);

    // CSV 出力が使う整備サマリ。vehicleId だけで絞る形はルールが要求する
    // userId を静的に満たせず、list ごと拒否される。**拒否されるのが正しい**
    // ので、旧クエリが通ってしまったら逆に異常（ルールが緩んだ合図）。
    await denies('整備サマリの旧クエリ（vehicleId だけ）は拒否される', () =>
      getDocs(query(
        collection(db, 'maintenance_records'),
        where('vehicleId', 'in', ids),
      )));

    // 0 件でも「拒否されていない」だけは言えてしまうので、実データが返ることまで見る。
    await check('整備サマリ（userId を足した今の形）', () =>
      count(query(
        collection(db, 'maintenance_records'),
        where('userId', '==', uid),
        where('vehicleId', 'in', ids),
      )), (n) => n >= 10);
  });

  // 2026-09-08 のレビューで「ルールに合わないかもしれない」と挙がったまま
  // 未検証だったクエリ。実際に投げて、通るのか弾かれるのかを確かめる。
  await as('persona.d@example.com', 'D 投稿・スポット（積み残しの確認）', async (uid) => {
    await check('自分の投稿一覧（PostService.getUserPosts の自分向け）', () =>
      count(query(
        collection(db, 'posts'),
        where('userId', '==', uid),
        orderBy('createdAt', 'desc'),
        limit(20),
      )), (n) => n >= 1);

    await check('他人の投稿一覧（公開のみに絞る形）', () =>
      count(query(
        collection(db, 'posts'),
        where('userId', '==', 'user-a'),
        where('visibility', '==', 'public'),
        orderBy('createdAt', 'desc'),
        limit(20),
      )), (n) => n >= 1);

    await check('お気に入りスポット（spot_favorites）', () =>
      count(query(
        collection(db, 'spot_favorites'),
        where('userId', '==', uid),
        orderBy('createdAt', 'desc'),
        limit(50),
      )), (n) => n >= 0);

    // アプリは必ず isPublic で絞る（ルールが isPublic か所有者を要求するので、
    // 絞らない形は拒否されるのが正しい）。
    await check('ドライブスポット一覧（isPublic で絞る）', () =>
      count(query(
        collection(db, 'spots'),
        where('isPublic', '==', true),
        limit(10),
      )), (n) => n >= 6);

    await denies('絞らないスポット一覧は拒否される', () =>
      getDocs(query(collection(db, 'spots'), limit(10))));
  });

  await as('persona.e@example.com', 'E 新社会人', async (uid) => {
    await check('自分の問い合わせ', () =>
      count(query(collection(db, 'inquiries'), where('userId', '==', uid))),
      (n) => n >= 1);
    await check('安全情報（全体公開）', () =>
      count(query(collection(db, 'safety_tips'))), (n) => n >= 6);
  });

  await as('persona.h@example.com', 'H 旧車オーナー', async (uid) => {
    await check('自分の問い合わせ', () =>
      count(query(collection(db, 'inquiries'), where('userId', '==', uid))),
      (n) => n >= 1);
    await check('やりとりを開く', () =>
      count(query(
        collection(db, 'inquiries', 'inq-fx-h-restore', 'messages'),
        orderBy('sentAt'),
      )), (n) => n >= 1);
  });

  await as('persona.c@example.com', 'C 工場比較', async (uid) => {
    await check('自分の整備記録', () =>
      count(query(collection(db, 'maintenance_records'), where('userId', '==', uid))),
      (n) => n >= 30);
    await check('工場一覧（提携・未提携）', () =>
      count(query(collection(db, 'shops'), limit(20))), (n) => n >= 10);
    await check('コーティング見積もりのやりとり', () =>
      count(query(
        collection(db, 'inquiries', 'inq-fx-c-coating', 'messages'),
        orderBy('sentAt'),
      )), (n) => n >= 1);
  });

  await as('persona.f@example.com', 'F 売却・廃車', async (uid) => {
    // 退役させてもデータは残る、が売りなので「読めること」を見る。
    await check('退役車両を含む自分の車両', () =>
      count(query(collection(db, 'vehicles'), where('userId', '==', uid))),
      (n) => n >= 1);
    await check('自分の投稿', () =>
      count(query(collection(db, 'posts'), where('userId', '==', uid))),
      (n) => n >= 1);
  });

  await as('persona.g@example.com', 'G EVオーナー', async (uid) => {
    await check('EVの整備記録（オイル交換なし）', () =>
      count(query(collection(db, 'maintenance_records'), where('userId', '==', uid))),
      (n) => n >= 10);
    await check('コミュニティトレンド', () =>
      count(query(collection(db, 'community_maintenance_trends'), limit(10))),
      (n) => n >= 5);
  });

  await as('persona.i@example.com', 'I 中古車購入検討', async (uid) => {
    // 車両を1台も持たない状態で、画面が空で成立するか。
    await check('車両0台', () =>
      count(query(collection(db, 'vehicles'), where('userId', '==', uid))),
      (n) => n === 0);
    await check('購入相談の問い合わせ', () =>
      count(query(collection(db, 'inquiries'), where('userId', '==', uid))),
      (n) => n >= 1);
  });

  await as('persona.j@example.com', 'J 登録した直後（空の状態）', async (uid) => {
    await check('車両はある', () =>
      count(query(collection(db, 'vehicles'), where('userId', '==', uid))),
      (n) => n >= 1);
    // 記録0件でも「拒否」ではなく「0件」で返ること。空表示の前提。
    await check('整備記録0件が、拒否ではなく0件で返る', () =>
      count(query(collection(db, 'maintenance_records'), where('userId', '==', uid))),
      (n) => n === 0);
    await check('ドライブログ0件が、拒否ではなく0件で返る', () =>
      count(query(
        collection(db, 'drive_logs'),
        where('userId', '==', uid),
        orderBy('startTime', 'desc'),
        limit(20),
      )), (n) => n === 0);
    await check('問い合わせ0件が、拒否ではなく0件で返る', () =>
      count(query(
        collection(db, 'inquiries'),
        where('userId', '==', uid),
        orderBy('updatedAt', 'desc'),
      )), (n) => n === 0);
  });

  // -------------------------------------------------------------------------
  // 他人の会話は読めないこと（読めてしまったら重大）
  // -------------------------------------------------------------------------
  await as('persona.d@example.com', 'D（他人の会話に触れない）', async () => {
    await denies('他人の会話は読めない', () =>
      getDocs(collection(db, 'inquiries', 'inq-yu-03-hiace-shaken', 'messages')));

    await denies('他人の整備記録は読めない', () =>
      getDocs(query(
        collection(db, 'maintenance_records'),
        where('userId', '==', 'user-a'),
      )));
  });

  // -------------------------------------------------------------------------
  const ng = results.filter((r) => !r.ok);
  console.log(`\n${'='.repeat(60)}`);
  console.log(`確認 ${results.length} 件 / NG ${ng.length} 件`);
  if (ng.length > 0) {
    console.log('\n■ 通らなかったもの');
    ng.forEach((r) => console.log(`  - [${r.persona}] ${r.label} — ${r.detail}`));
    process.exitCode = 1;
  } else {
    console.log('すべて通りました。');
  }
}

main()
  .then(() => process.exit(process.exitCode || 0))
  .catch((e) => {
    console.error(e);
    process.exit(1);
  });
