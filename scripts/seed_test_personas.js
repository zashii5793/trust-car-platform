#!/usr/bin/env node
/**
 * 動作確認用ペルソナの作成スクリプト
 *
 * Usage:
 *   node scripts/seed_test_personas.js [--dry-run] [--emulator] [--delete]
 *
 * Options:
 *   --dry-run    書き込まず、作成予定の内容を表示する
 *   --emulator   Firebase Emulator に接続する（localhost:9099 / 8080）
 *   --delete     作成したペルソナ（Auth ユーザーと関連ドキュメント）を削除する
 *
 * Requirements:
 *   npm install firebase-admin   （scripts/ で実行）
 *
 * Example:
 *   # Emulator で試す
 *   firebase emulators:start --only auth,firestore
 *   node scripts/seed_test_personas.js --emulator
 *
 *   # 本番に作る（Web版の動作確認はこちら）
 *   export GOOGLE_APPLICATION_CREDENTIALS=path/to/serviceAccount.json
 *   node scripts/seed_test_personas.js
 *
 *   # 確認が終わったら消す
 *   node scripts/seed_test_personas.js --delete
 *
 * ⚠️ パスワードについて
 *
 * パスワードはこのファイルに書きません。実行時にランダム生成し、**標準出力に
 * 一度だけ表示**します。リポジトリに残さないためです。
 * 実行結果の画面を閉じると二度と分からないので、控えておいてください
 * （忘れた場合は --delete してから作り直せます）。
 *
 * ⚠️ 本番環境について
 *
 * Web版（GitHub Pages）は本番の Firebase に接続します。--emulator を付けずに
 * 実行すると、ここで作るアカウントは本番のデータになります。確認が終わったら
 * --delete で消してください。
 */

const admin = require('firebase-admin');
const crypto = require('crypto');

const DRY_RUN = process.argv.includes('--dry-run');
const EMULATOR = process.argv.includes('--emulator');
const DELETE = process.argv.includes('--delete');

if (EMULATOR) {
  process.env.FIRESTORE_EMULATOR_HOST = 'localhost:8080';
  process.env.FIREBASE_AUTH_EMULATOR_HOST = 'localhost:9099';
}

// ---------------------------------------------------------------------------
// ペルソナ定義
// ---------------------------------------------------------------------------
//
// 「アカウントを作るだけ」では再現できない状態がある。プレミアムなら
// users.planType、提携工場なら shops.subscriptionStatus を併せて書かないと
// 画面が想定どおりにならない。ペルソナごとに必要な状態をここに集約する。

const PERSONAS = [
  {
    key: 'free',
    email: 'persona.free@trustcar-test.example',
    displayName: 'テスト太郎（無料）',
    label: '個人ユーザー / 無料プラン',
    checkPoints: [
      'マイカー登録（メーカー・車種・グレードの自由入力、オプション・装備）',
      'PDF出力を押すとプレミアム案内が出る',
    ],
    user: { planType: 'free', accountType: 'personal' },
    withVehicle: true,
  },
  {
    key: 'premium',
    email: 'persona.premium@trustcar-test.example',
    displayName: 'テスト花子（プレミアム）',
    label: '個人ユーザー / プレミアムプラン',
    checkPoints: ['データのエクスポート（PDF）が使える'],
    user: {
      planType: 'premium',
      accountType: 'personal',
      prefecture: '東京都',
      city: '世田谷区',
    },
    withVehicle: true,
  },
  {
    key: 'business',
    email: 'persona.business@trustcar-test.example',
    displayName: '法人担当者',
    label: '法人アカウント（社用車管理）',
    checkPoints: [
      '⚠️ 法人向けの一覧画面は未実装です。現時点ではアカウント種別が',
      '   business になるだけで、専用画面はまだありません',
    ],
    user: {
      planType: 'free',
      accountType: 'business',
      companyName: 'テスト運輸株式会社',
    },
    withVehicle: true,
  },
  {
    key: 'shop_partner',
    email: 'persona.shop.partner@trustcar-test.example',
    displayName: '提携工場オーナー',
    label: '整備工場オーナー / 提携（有料）',
    checkPoints: [
      '工場詳細に「この工場に問い合わせる」が出る',
      '実績セクションが表示される',
    ],
    user: { planType: 'free', accountType: 'personal' },
    shop: {
      name: 'テスト提携ガレージ',
      subscriptionStatus: 'active',
      planType: 'standard',
      isVerified: true,
    },
  },
  {
    key: 'shop_free',
    email: 'persona.shop.free@trustcar-test.example',
    displayName: '未提携工場オーナー',
    label: '整備工場 / 未提携（地図由来の参考情報）',
    checkPoints: [
      '工場詳細に「アプリ未提携」の注記が出る',
      '問い合わせボタンが出ず、電話番号が案内される',
    ],
    user: { planType: 'free', accountType: 'personal' },
    shop: {
      name: 'テスト未提携モータース',
      subscriptionStatus: 'free',
      planType: 'free',
      isVerified: false,
    },
  },
];

/// 推測されにくいパスワードを都度生成する。
///
/// 固定値をスクリプトに書くと、リポジトリを見た誰でもログインできてしまう。
function generatePassword() {
  // 記号は端末やIMEで打ち間違えやすいので英数字のみにする。
  return crypto.randomBytes(12).toString('base64url').slice(0, 16);
}

// ---------------------------------------------------------------------------

async function main() {
  admin.initializeApp({ projectId: 'trust-car-platform' });
  const auth = admin.auth();
  const db = admin.firestore();

  if (DELETE) {
    await deletePersonas(auth, db);
    return;
  }

  const created = [];

  for (const persona of PERSONAS) {
    const password = generatePassword();

    if (DRY_RUN) {
      console.log(`[dry-run] ${persona.label}: ${persona.email}`);
      continue;
    }

    // 既に居る場合はパスワードだけ差し替える。作り直すと uid が変わり、
    // 紐づけた車両や工場が孤児になる。
    let uid;
    try {
      const existing = await auth.getUserByEmail(persona.email);
      uid = existing.uid;
      await auth.updateUser(uid, { password, displayName: persona.displayName });
      console.log(`更新: ${persona.email}`);
    } catch (e) {
      if (e.code !== 'auth/user-not-found') throw e;
      const record = await auth.createUser({
        email: persona.email,
        password,
        displayName: persona.displayName,
        emailVerified: true,
      });
      uid = record.uid;
      console.log(`作成: ${persona.email}`);
    }

    const now = admin.firestore.Timestamp.now();

    await db
      .collection('users')
      .doc(uid)
      .set(
        {
          email: persona.email,
          displayName: persona.displayName,
          ...persona.user,
          createdAt: now,
          updatedAt: now,
          isTestPersona: true,
        },
        { merge: true },
      );

    if (persona.withVehicle) {
      await seedVehicle(db, uid, now);
    }
    if (persona.shop) {
      await seedShop(db, uid, persona, now);
    }

    created.push({ ...persona, uid, password });
  }

  if (DRY_RUN) {
    console.log('\n--dry-run のため何も書き込んでいません。');
    return;
  }

  printCredentials(created);
}

/// 画面が空だと確認にならないので、車両を1台入れておく。
async function seedVehicle(db, uid, now) {
  const id = `persona_vehicle_${uid}`;
  await db
    .collection('vehicles')
    .doc(id)
    .set(
      {
        userId: uid,
        maker: 'トヨタ',
        model: 'プリウス',
        year: 2020,
        grade: 'S',
        mileage: 38000,
        color: 'パールホワイト',
        licensePlate: '品川 300 あ 12-34',
        // 車検が近い状態にして、通知とダッシュボードの警告を確認できるようにする。
        inspectionExpiryDate: admin.firestore.Timestamp.fromDate(
          new Date(Date.now() + 20 * 24 * 60 * 60 * 1000),
        ),
        status: 'active',
        isDataRetained: true,
        equipment: {
          navigation: {
            installed: true,
            maker: 'カロッツェリア（パイオニア）',
            modelNumber: 'AVIC-RQ720',
          },
          driveRecorder: {
            installed: true,
            maker: 'コムテック',
            modelNumber: 'ZDR035',
          },
          etc: { installed: true, maker: 'デンソー', modelNumber: null },
          features: ['backCamera', 'keylessEntry', 'alloyWheel'],
          others: [],
        },
        createdAt: now,
        updatedAt: now,
        isTestPersona: true,
      },
      { merge: true },
    );
}

async function seedShop(db, uid, persona, now) {
  const id = `persona_shop_${persona.key}`;
  await db
    .collection('shops')
    .doc(id)
    .set(
      {
        name: persona.shop.name,
        type: 'maintenanceShop',
        description: '動作確認用のテストデータです。実在の事業者ではありません。',
        phone: '03-0000-0000',
        address: '東京都世田谷区テスト1-1-1',
        prefecture: '東京都',
        city: '世田谷区',
        // 地図に出したいので座標を入れる（location が null だとピンが出ない）。
        location: new admin.firestore.GeoPoint(35.6465, 139.6533),
        services: ['inspection', 'maintenance', 'repair'],
        supportedMakerIds: [],
        businessHours: {},
        reviewCount: 0,
        isActive: true,
        isVerified: persona.shop.isVerified,
        planType: persona.shop.planType,
        subscriptionStatus: persona.shop.subscriptionStatus,
        ownerId: uid,
        createdAt: now,
        updatedAt: now,
        isTestPersona: true,
      },
      { merge: true },
    );
}

async function deletePersonas(auth, db) {
  for (const persona of PERSONAS) {
    try {
      const record = await auth.getUserByEmail(persona.email);
      if (!DRY_RUN) {
        await db.collection('users').doc(record.uid).delete();
        await db
          .collection('vehicles')
          .doc(`persona_vehicle_${record.uid}`)
          .delete();
        if (persona.shop) {
          await db.collection('shops').doc(`persona_shop_${persona.key}`).delete();
        }
        await auth.deleteUser(record.uid);
      }
      console.log(`削除: ${persona.email}`);
    } catch (e) {
      if (e.code === 'auth/user-not-found') {
        console.log(`スキップ（存在しない）: ${persona.email}`);
        continue;
      }
      throw e;
    }
  }
}

function printCredentials(created) {
  console.log('\n' + '='.repeat(72));
  console.log('ログイン情報（この表示は一度だけです。控えておいてください）');
  console.log('='.repeat(72));
  for (const p of created) {
    console.log(`\n■ ${p.label}`);
    console.log(`  メール    : ${p.email}`);
    console.log(`  パスワード: ${p.password}`);
    for (const c of p.checkPoints) {
      console.log(`  確認ポイント: ${c}`);
    }
  }
  console.log('\n' + '='.repeat(72));
  console.log('確認が終わったら削除してください:');
  console.log('  node scripts/seed_test_personas.js --delete');
  console.log('='.repeat(72));
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
