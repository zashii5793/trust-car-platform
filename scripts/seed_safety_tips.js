#!/usr/bin/env node
/**
 * SafetyTip Seed Data — Firestore 登録スクリプト (Node.js)
 *
 * Usage:
 *   node scripts/seed_safety_tips.js [--dry-run] [--emulator]
 *
 * Options:
 *   --dry-run    Firestore に書かず、登録予定データを標準出力に表示する
 *   --emulator   Firebase Emulator (localhost:8080) に接続する
 *
 * Requirements:
 *   npm install firebase-admin
 *
 * Example:
 *   # Emulator で動作確認
 *   firebase emulators:start --only firestore
 *   node scripts/seed_safety_tips.js --dry-run
 *   node scripts/seed_safety_tips.js --emulator
 *
 *   # 本番に登録
 *   export GOOGLE_APPLICATION_CREDENTIALS=path/to/serviceAccount.json
 *   node scripts/seed_safety_tips.js
 *
 * Note: safety_tips collection は allow write: if false のため、
 *       本番環境では Admin SDK（このスクリプト）経由でのみ書き込み可能。
 */

const isDryRun    = process.argv.includes('--dry-run');
const useEmulator = process.argv.includes('--emulator');

if (useEmulator) {
  process.env.FIRESTORE_EMULATOR_HOST = 'localhost:8080';
}

const admin = (() => {
  try { return require('firebase-admin'); }
  catch {
    console.error('[ERROR] firebase-admin が見つかりません。');
    console.error('        npm install firebase-admin を実行してください。');
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
const { Timestamp } = admin.firestore;

// ---------------------------------------------------------------------------
// シードデータ定義
// ---------------------------------------------------------------------------
// SafetyTipCategory enum values: drivingBasics, seasonalDriving, vehicleCheck,
//                                emergencyResponse, childSafety, elderlyDriving
// SafetyTipSource enum values:   jaf, npa, mlit, fdma, itarda

const now = Timestamp.now();

const safetyTips = [
  {
    id: 'tip_seatbelt_all_seats',
    data: {
      title: 'シートベルトは全席着用',
      body: '後部座席のシートベルト着用は法律で義務付けられています。一般道では反則金はありませんが、高速道路では違反となります。事故時の致死率は着用時に比べ約5倍（後席）に高まるというデータがあります。同乗者全員分を確認してから発車しましょう。',
      category: 'drivingBasics',
      source: 'npa',
      sourceUrl: 'https://www.npa.go.jp/bureau/traffic/seatbelt/',
      isActive: true,
      publishedAt: now,
    },
  },
  {
    id: 'tip_rain_braking_distance',
    data: {
      title: '雨天時は制動距離が2〜3倍に延びる',
      body: '雨で濡れた路面では、タイヤと路面の摩擦係数が大幅に低下します。時速60 km/h 走行時の制動距離は乾燥路の約2〜3倍になることがあります。十分な車間距離の確保と速度を落とした運転を心がけましょう。特に降り始め直後は路面の油分が浮き出るため危険です。',
      category: 'seasonalDriving',
      source: 'jaf',
      sourceUrl: 'https://jaf.or.jp/common/safety-drive/car-test/index/',
      isActive: true,
      publishedAt: now,
    },
  },
  {
    id: 'tip_winter_road_driving',
    data: {
      title: '冬道走行の注意点',
      body: '積雪・凍結路面では急発進・急ブレーキ・急ハンドルを避けることが重要です。冬用タイヤ（スタッドレス）への早期交換、タイヤチェーンの携行（指定区間では装着義務）も確認しましょう。ブラックアイスバーン（見た目が濡れているだけに見える凍結路面）は特に危険です。',
      category: 'seasonalDriving',
      source: 'mlit',
      sourceUrl: 'https://www.mlit.go.jp/road/road/traffic/winter/',
      isActive: true,
      publishedAt: now,
    },
  },
  {
    id: 'tip_pre_drive_inspection',
    data: {
      title: '乗車前の日常点検',
      body: 'エンジンオイル・冷却水・ブレーキ液・バッテリー液面、タイヤの空気圧・亀裂・溝の深さ、灯火類の点灯確認など、乗車前の日常点検は道路運送車両法で義務付けられています。点検整備記録簿に記録し、異常を感じたらすぐに整備工場へ相談しましょう。',
      category: 'vehicleCheck',
      source: 'mlit',
      sourceUrl: 'https://www.mlit.go.jp/jidosha/jidosha_fr7_000007.html',
      isActive: true,
      publishedAt: now,
    },
  },
  {
    id: 'tip_child_in_car_danger',
    data: {
      title: '子どもの車内放置は危険',
      body: '夏場の密閉された車内温度は、外気温35℃の場合でも60℃を超えることがあります。子どもの体温調節機能は未発達なため、短時間でも熱中症・最悪の場合は死亡事故につながります。また、冬場のアイドリング中は一酸化炭素中毒のリスクもあります。子どもは必ず同伴して降車しましょう。',
      category: 'childSafety',
      source: 'fdma',
      sourceUrl: 'https://www.fdma.go.jp/relocation/neuter/topics/heatstroke/',
      isActive: true,
      publishedAt: now,
    },
  },
  {
    id: 'tip_elderly_cognitive_check',
    data: {
      title: '高齢ドライバーの認知機能チェック',
      body: '75歳以上の方は運転免許更新時に認知機能検査（30分程度）が義務付けられています。また、信号無視・逆走等の違反があった場合は臨時検査の対象となります。認知症の疑いがある場合は任意での返納・自主休止も選択肢です。警察庁の「運転免許自主返納サポート制度」を活用してください。',
      category: 'elderlyDriving',
      source: 'npa',
      sourceUrl: 'https://www.npa.go.jp/bureau/traffic/koutuu/koureisha/',
      isActive: true,
      publishedAt: now,
    },
  },
];

// ---------------------------------------------------------------------------
// 実行
// ---------------------------------------------------------------------------
async function main() {
  console.log('=== SafetyTip Seed Script ===');
  console.log(`dry-run  : ${isDryRun}`);
  console.log(`emulator : ${useEmulator}`);
  console.log(`登録件数  : ${safetyTips.length}`);
  console.log('');

  if (isDryRun) {
    console.log('--- [DRY RUN] 登録予定データ ---');
    for (const tip of safetyTips) {
      console.log(`ID: ${tip.id}`);
      console.log(`  title   : ${tip.data.title}`);
      console.log(`  category: ${tip.data.category}`);
      console.log(`  source  : ${tip.data.source}`);
      console.log('');
    }
    console.log('--- [DRY RUN] 完了（Firestore への書き込みは行っていません）---');
    return;
  }

  const batch = db.batch();

  for (const tip of safetyTips) {
    const ref = db.collection('safety_tips').doc(tip.id);
    batch.set(ref, tip.data, { merge: true });
    console.log(`[QUEUED] safety_tips/${tip.id} — ${tip.data.title}`);
  }

  await batch.commit();
  console.log('');
  console.log(`[SUCCESS] ${safetyTips.length} 件を Firestore に登録しました。`);
}

main().catch((err) => {
  console.error('[ERROR]', err);
  process.exit(1);
});
