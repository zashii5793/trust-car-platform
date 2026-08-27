#!/usr/bin/env node
/**
 * 店舗ペルソナ（タカヤモーターの店主）シード
 *
 * Usage:
 *   node scripts/seed_shop_owner.js [--dry-run] [--emulator] [--delete]
 *
 * ⚠️ Auth ユーザーの作成は --emulator 時のみ（本番 Auth を汚さないため）。
 *
 * なぜ要るか:
 *   2026-08-27 時点で、**店主のアカウントが1つも無かった**。
 *   ペルソナ A〜J は全員「クルマを持っている人」で、店の側に立つ人がいない。
 *   そのため店側の画面（掲載管理・問い合わせ一覧・月次レポート・招待コード）が
 *   一度も実データで確かめられていなかった。
 *
 *   `docs/BUSINESS_MODEL_RETHINK_2026-08-27.md` で前提を「自社の道具」に
 *   置き直した以上、**確かめるべき主役は店側**になる。
 *
 * 作るもの:
 *   Auth        shop.owner@example.com（password123）
 *   users       店主のユーザー文書（accountType: business）
 *   shops       タカヤモーターに ownerId を紐づける（既存文書を更新）
 *   shop_invites 配布用の招待コード1件（上限なし・カウンター用）
 *   shop_customers ペルソナ A/C/J をタカヤモーターの顧客として紐づける
 *
 * 前提: 先に seed_shops.js と seed_personas.js を流しておくこと。
 */

const args = process.argv.slice(2);
const isDryRun = args.includes('--dry-run');
const useEmulator = args.includes('--emulator');
const doDelete = args.includes('--delete');

if (useEmulator) {
  process.env.FIRESTORE_EMULATOR_HOST = 'localhost:8080';
  process.env.FIREBASE_AUTH_EMULATOR_HOST = 'localhost:9099';
}

const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp({ projectId: 'trust-car-platform' });
}

const db = admin.firestore();
const now = admin.firestore.Timestamp.now();

const SHOP_ID = 'shop_takaya_motor_okayama';
const OWNER_UID = 'shop-owner-takaya';
const OWNER_EMAIL = 'shop.owner@example.com';
const DEMO_PASSWORD = 'password123';

// カウンターに置くQR用。上限なし・期限なし。
// 紛らわしい文字（0/O・1/I/L）を使わない規則に合わせてある。
const INVITE_CODE = 'TAKAYA'.replace(/[OIL]/g, (c) =>
  ({ O: '0', I: '1', L: '1' }[c]),
);

// タカヤモーターの顧客としてつなぐペルソナ。
// A（4台混在・ハイエース持ち）/ C（工場比較中）/ J（配送業・貨物3台）
const CUSTOMER_UIDS = ['user-a', 'user-c', 'persona-j-user'];

async function deleteAll() {
  console.log('[DELETE] 店舗ペルソナを削除します');

  await db.collection('shop_invites').doc(INVITE_CODE).delete();
  for (const uid of CUSTOMER_UIDS) {
    await db.collection('shop_customers').doc(uid).delete();
  }
  await db.collection('users').doc(OWNER_UID).delete();
  await db
    .collection('shops')
    .doc(SHOP_ID)
    .set({ ownerId: admin.firestore.FieldValue.delete() }, { merge: true });

  if (useEmulator) {
    try {
      await admin.auth().deleteUser(OWNER_UID);
      console.log(`[AUTH] deleted ${OWNER_EMAIL}`);
    } catch (e) {
      // いなければそれでよい
    }
  }

  console.log('[DONE] 削除しました');
}

async function seed() {
  const plan = [
    ['users', OWNER_UID, '店主のユーザー文書'],
    ['shops', SHOP_ID, 'ownerId を紐づける'],
    ['shop_invites', INVITE_CODE, `招待コード ${INVITE_CODE}`],
    ...CUSTOMER_UIDS.map((uid) => ['shop_customers', uid, `顧客 ${uid}`]),
  ];

  console.log('登録するもの:');
  for (const [col, id, note] of plan) {
    console.log(`  ${col}/${id}  — ${note}`);
  }
  console.log(`  auth: ${OWNER_EMAIL}（--emulator 時のみ）`);
  console.log('');

  if (isDryRun) {
    console.log('[DRY-RUN] 書き込みは行いません');
    return;
  }

  // 店舗が無いと紐づけようがない。先に seed_shops.js を流す必要がある。
  const shopDoc = await db.collection('shops').doc(SHOP_ID).get();
  if (!shopDoc.exists) {
    console.error(
      `[ERROR] shops/${SHOP_ID} がありません。先に node scripts/seed_shops.js を流してください。`,
    );
    process.exitCode = 1;
    return;
  }

  // 1) Auth（エミュレータのみ）
  if (useEmulator) {
    try {
      await admin.auth().createUser({
        uid: OWNER_UID,
        email: OWNER_EMAIL,
        password: DEMO_PASSWORD,
        displayName: 'タカヤ 店長（店舗ペルソナ）',
      });
      console.log(`[AUTH] created ${OWNER_EMAIL} (uid=${OWNER_UID})`);
    } catch (e) {
      if (e.code === 'auth/uid-already-exists') {
        console.log(`[AUTH] already exists ${OWNER_EMAIL}`);
      } else {
        throw e;
      }
    }
  } else {
    console.log('[SKIP] Auth ユーザー作成は --emulator 時のみ実行します。');
  }

  // 2) 店主のユーザー文書
  await db.collection('users').doc(OWNER_UID).set(
    {
      email: OWNER_EMAIL,
      displayName: 'タカヤ 店長（店舗ペルソナ）',
      accountType: 'business',
      companyName: 'タカヤモーター株式会社',
      planType: 'free',
      createdAt: now,
      updatedAt: now,
    },
    { merge: true },
  );
  console.log(`[OK] users/${OWNER_UID}`);

  // 3) 店に ownerId を紐づける
  //    これが無いと、店主が自分の店の管理画面に入れない。
  await db
    .collection('shops')
    .doc(SHOP_ID)
    .set({ ownerId: OWNER_UID, updatedAt: now }, { merge: true });
  console.log(`[OK] shops/${SHOP_ID}.ownerId = ${OWNER_UID}`);

  // 4) 招待コード（カウンター用・上限なし）
  await db.collection('shop_invites').doc(INVITE_CODE).set({
    shopId: SHOP_ID,
    shopName: 'タカヤモーター株式会社',
    shopOwnerId: OWNER_UID,
    createdAt: now,
    isActive: true,
    usedCount: CUSTOMER_UIDS.length,
  });
  console.log(`[OK] shop_invites/${INVITE_CODE}`);

  // 5) 顧客の紐づけ
  for (const uid of CUSTOMER_UIDS) {
    await db.collection('shop_customers').doc(uid).set({
      shopId: SHOP_ID,
      shopName: 'タカヤモーター株式会社',
      userId: uid,
      linkedAt: now,
    });
    console.log(`[OK] shop_customers/${uid}`);
  }

  console.log('');
  console.log('[SUCCESS] 店舗ペルソナを登録しました。');
  console.log('');
  console.log('店側でログイン（Auth エミュレータ）:');
  console.log(`  メール     : ${OWNER_EMAIL}`);
  console.log(`  パスワード : ${DEMO_PASSWORD}`);
  console.log('');
  console.log(`顧客に配る招待コード: ${INVITE_CODE}`);
  console.log('  （顧客側でこのコードを入れると、かかりつけがタカヤモーターになります）');
}

(async () => {
  try {
    if (doDelete) {
      await deleteAll();
    } else {
      await seed();
    }
  } catch (e) {
    console.error('[FATAL]', e);
    process.exitCode = 1;
  }
})();
