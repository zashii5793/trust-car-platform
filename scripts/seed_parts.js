#!/usr/bin/env node
/**
 * パーツ出品（part_listings）シードデータ — Firestore 登録スクリプト
 *
 * Usage:
 *   node scripts/seed_parts.js [--dry-run] [--emulator] [--count 300] [--delete]
 *
 * Options:
 *   --dry-run    Firestore に書かず、登録予定の要約を表示する
 *   --emulator   Firebase Emulator (localhost:8080) に接続する
 *   --count N    生成件数（既定 300）
 *   --delete     demo_part_* を全部消す
 *
 * ⚠️ 商品名・ブランド名・型番はすべて架空です。実在のメーカー名は使っていません。
 *    ID は demo_part_ で始まるので、--delete で一括削除できます。
 *    本番に入れたまま公開しないこと（docs/HUMAN_TASKS.md P1-11 と同じ扱い）。
 *
 * 生成の考え方:
 *   - 17 カテゴリを均等に回す（絞り込みが全カテゴリで試せる）
 *   - ペルソナが持っている車種に「適合するもの／しないもの」を混ぜる
 *     → 車種フィルターが効いているかを、見分けられるようにする
 *   - 価格は「範囲あり／単価のみ／要問合せ」の 3 通りを混ぜる
 *     → 一覧の価格表示が全パターン出る
 *   - 画像は付けない（Storage を汚さない）。空表示の見え方も確認できる
 */

const args = process.argv.slice(2);
const isDryRun = args.includes('--dry-run');
const useEmulator = args.includes('--emulator');
const doDelete = args.includes('--delete');
const countArg = args.indexOf('--count');
const COUNT = countArg >= 0 ? parseInt(args[countArg + 1], 10) : 300;

if (useEmulator) {
  process.env.FIRESTORE_EMULATOR_HOST = 'localhost:8080';
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

// --------------------------------------------------------------------------
// 素材（すべて架空）
// --------------------------------------------------------------------------

const SHOPS = [
  'demo_kanto_auto_service',
  'demo_minato_motors',
  'demo_nagoya_carcare',
  'demo_naniwa_shaken',
  'demo_sapporo_north_garage',
  'demo_fukuoka_auto_factory',
];

/** 架空ブランド。実在の商標を避ける。 */
const BRANDS = [
  'ソラリス', 'カゲロウ', 'ツバサ', 'ハヤテ工房', 'アオイ・レーシング',
  'ミナモ', 'コトブキ', 'シラヌイ', 'ヤマセミ', 'トキワ',
];

/**
 * カテゴリごとの品名パターンと価格帯。
 * category は lib/models/part_listing.dart の PartCategory と同じ綴り。
 */
const CATALOG = [
  { category: 'aero', names: ['フロントリップスポイラー', 'サイドステップ', 'リアディフューザー', 'GTウイング'], price: [28000, 180000] },
  { category: 'wheel', names: ['鍛造17インチホイール', '軽量18インチホイール', '5本スポークホイール'], price: [48000, 260000] },
  { category: 'tire', names: ['低燃費タイヤ 195/65R15', 'スポーツタイヤ 225/40R18', 'スタッドレス 205/55R16'], price: [24000, 96000] },
  { category: 'suspension', names: ['車高調キット', 'ダウンサス', 'ストラットタワーバー'], price: [18000, 145000] },
  { category: 'exhaust', names: ['スポーツマフラー', 'エキゾーストマニホールド', '触媒ストレートパイプ'], price: [32000, 210000] },
  { category: 'intake', names: ['エアクリーナー', 'インテークパイプ', 'ラムエアダクト'], price: [8000, 62000] },
  { category: 'brake', names: ['スリットブレーキローター', 'スポーツブレーキパッド', 'ステンメッシュホース'], price: [12000, 98000] },
  { category: 'interior', names: ['バケットシート', 'ステアリング 350mm', 'シフトノブ', 'フロアマット4枚組'], price: [6000, 128000] },
  { category: 'exterior', names: ['カーボンドアミラーカバー', 'メッキグリル', 'ルーフレール'], price: [9000, 74000] },
  { category: 'lighting', names: ['LEDヘッドライトバルブ', 'LEDフォグランプ', 'シーケンシャルウインカー'], price: [4800, 42000] },
  { category: 'audio', names: ['16cmコアキシャルスピーカー', '4chパワーアンプ', 'サブウーファー20cm'], price: [7800, 88000] },
  { category: 'navigation', names: ['9インチディスプレイオーディオ', 'ドライブレコーダー前後2カメラ', 'ETC2.0車載器'], price: [11000, 96000] },
  { category: 'safety', names: ['後方センサー4個セット', 'ブラインドスポットミラー', 'チャイルドシート'], price: [3200, 58000] },
  { category: 'performance', names: ['サブコンピュータ', 'インタークーラーキット', '強化クラッチ'], price: [26000, 240000] },
  { category: 'maintenance', names: ['0W-20 エンジンオイル 4L', 'オイルフィルター', 'ワイパーブレード2本組', 'バッテリー 60B24L'], price: [1200, 26000] },
  { category: 'accessory', names: ['ドリンクホルダー', 'スマホホルダー', 'トランクトレイ', 'サンシェード'], price: [980, 12000] },
  { category: 'other', names: ['汎用ステー金具セット', '配線コネクタキット'], price: [800, 9800] },
];

/**
 * ペルソナが実際に持っている車種。
 *
 * **ID の綴りは実装に合わせる。** `PartRecommendationService` は
 * `_getMakerId` / `_getModelId` で車両を
 *   maker → 小文字（'Toyota' → 'toyota'）
 *   model → '<maker>_<model>' の小文字（'Prius' → 'toyota_prius'）
 * に変換してから照合する。表示名（'Toyota' / 'Prius'）で書くと 1 件も当たらない。
 */
const OWNED = [
  { makerId: 'toyota', modelId: 'toyota_alphard', label: 'トヨタ アルファード', yearFrom: 2018, yearTo: 2024 },
  { makerId: 'toyota', modelId: 'toyota_prius', label: 'トヨタ プリウス', yearFrom: 2012, yearTo: 2023 },
  { makerId: 'toyota', modelId: 'toyota_hiace', label: 'トヨタ ハイエース', yearFrom: 2019, yearTo: 2024 },
  { makerId: 'nissan', modelId: 'nissan_note', label: '日産 ノート', yearFrom: 2020, yearTo: 2024 },
  { makerId: 'nissan', modelId: 'nissan_serena', label: '日産 セレナ', yearFrom: 2016, yearTo: 2024 },
  { makerId: 'nissan', modelId: 'nissan_leaf', label: '日産 リーフ', yearFrom: 2018, yearTo: 2024 },
  { makerId: 'honda', modelId: 'honda_fit', label: 'ホンダ フィット', yearFrom: 2017, yearTo: 2023 },
  { makerId: 'honda', modelId: 'honda_n_box', label: 'ホンダ N-BOX', yearFrom: 2017, yearTo: 2024 },
  { makerId: 'honda', modelId: 'honda_beat', label: 'ホンダ ビート', yearFrom: 1991, yearTo: 1996 },
  { makerId: 'mazda', modelId: 'mazda_roadster', label: 'マツダ ロードスター', yearFrom: 2015, yearTo: 2024 },
];

/** 誰も持っていない車種。**車種フィルターが効いていれば、これは出ない。** */
const NOT_OWNED = [
  { makerId: 'subaru', modelId: 'subaru_impreza', label: 'スバル インプレッサ', yearFrom: 2016, yearTo: 2023 },
  { makerId: 'suzuki', modelId: 'suzuki_jimny', label: 'スズキ ジムニー', yearFrom: 2018, yearTo: 2024 },
  { makerId: 'mitsubishi', modelId: 'mitsubishi_delica', label: '三菱 デリカ', yearFrom: 2019, yearTo: 2024 },
  { makerId: 'daihatsu', modelId: 'daihatsu_tanto', label: 'ダイハツ タント', yearFrom: 2019, yearTo: 2024 },
];

const COMPAT = ['perfect', 'compatible', 'conditional'];

const PROS = [
  '取り付けが簡単で、専用工具が要りません',
  '純正の見た目を大きく変えずに交換できます',
  '同クラスでは軽量な部類です',
  '車検対応品です',
];
const CONS = [
  '装着後に光軸・アライメントの調整が必要です',
  '純正部品より交換の頻度が上がります',
  '走行音が大きくなる場合があります',
  '在庫が少なく、取り寄せに時間がかかります',
];

// --------------------------------------------------------------------------
// 生成
// --------------------------------------------------------------------------

/** 決まった順で回す。**乱数を使わない** — 何度流しても同じものが入る。 */
function build(count) {
  const rows = [];
  for (let i = 0; i < count; i++) {
    const cat = CATALOG[i % CATALOG.length];
    const name = cat.names[i % cat.names.length];
    const brand = BRANDS[i % BRANDS.length];
    const grade = ['', ' Type-S', ' EVO', ' Lite', ' Pro'][i % 5];
    const [lo, hi] = cat.price;
    const step = Math.round((hi - lo) / 7);
    const base = lo + step * (i % 7);

    // 価格は 3 通りを回す。一覧の表示パターンを全部出すため。
    let priceFrom = null;
    let priceTo = null;
    let negotiable = false;
    if (i % 3 === 0) {
      priceFrom = base;
      priceTo = base + step;
    } else if (i % 3 === 1) {
      priceFrom = base;
    } else {
      negotiable = true; // 要問合せ
    }

    // 4 件に 3 件は「誰かが持っている車種」、1 件は持っていない車種。
    // **車種フィルターが効いていないと、この 1 件も提案に混ざる。**
    const owned = i % 4 !== 3;
    const pool = owned ? OWNED : NOT_OWNED;
    const spec = pool[i % pool.length];

    rows.push({
      id: `demo_part_${String(i + 1).padStart(4, '0')}`,
      shopId: SHOPS[i % SHOPS.length],
      name: `${brand} ${name}${grade}`.trim(),
      description:
        `${spec.label}（${spec.yearFrom}〜${spec.yearTo}年式）向けの` +
        `${name}です。動作確認用の架空データで、実在の商品ではありません。`,
      category: cat.category,
      imageUrls: [],
      priceFrom,
      priceTo,
      isPriceNegotiable: negotiable,
      compatibleVehicles: [
        {
          makerId: spec.makerId,
          modelId: spec.modelId,
          yearFrom: spec.yearFrom,
          yearTo: spec.yearTo,
          gradePattern: null,
          bodyType: null,
        },
      ],
      defaultCompatibility: COMPAT[i % COMPAT.length],
      prosAndCons: [
        { type: 'pro', text: PROS[i % PROS.length] },
        { type: 'con', text: CONS[i % CONS.length] },
      ],
      brand,
      partNumber: `DEMO-${cat.category.toUpperCase().slice(0, 4)}-${String(i + 1).padStart(4, '0')}`,
      tags: [cat.category, spec.makerId, spec.modelId, spec.label],
      // 5 件に 1 件は評価なし（★の空表示も確認できるように）
      rating: i % 5 === 0 ? null : Number((3.2 + (i % 9) * 0.2).toFixed(1)),
      reviewCount: i % 5 === 0 ? 0 : (i % 47) + 1,
      isActive: true,
      isFeatured: i % 25 === 0,
    });
  }
  return rows;
}

// --------------------------------------------------------------------------
// 実行
// --------------------------------------------------------------------------

async function main() {
  const rows = build(COUNT);

  if (isDryRun) {
    const byCat = {};
    rows.forEach((r) => (byCat[r.category] = (byCat[r.category] || 0) + 1));
    console.log(`[dry-run] ${rows.length} 件を生成しました（書き込みません）`);
    console.log('  カテゴリ内訳:');
    Object.entries(byCat)
      .sort((a, b) => b[1] - a[1])
      .forEach(([k, v]) => console.log(`    ${k.padEnd(14)} ${v}`));
    const notOwned = rows.filter((r) =>
      NOT_OWNED.some((n) => n.modelId === r.compatibleVehicles[0].modelId)
    ).length;
    console.log(`  持っていない車種向け: ${notOwned} 件`);
    console.log(`  要問合せ: ${rows.filter((r) => r.isPriceNegotiable).length} 件`);
    console.log('  例:');
    rows.slice(0, 3).forEach((r) => console.log(`    ${r.id}  ${r.name}`));
    return;
  }

  if (!useEmulator && !process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    console.error('[ERROR] --emulator も GOOGLE_APPLICATION_CREDENTIALS も無い状態では実行しません。');
    console.error('        本番へ誤って入れないための歯止めです。');
    process.exit(1);
  }

  admin.initializeApp(
    useEmulator ? { projectId: 'trust-car-platform' } : undefined
  );
  const db = admin.firestore();
  const col = db.collection('part_listings');

  if (doDelete) {
    const snap = await col.get();
    const targets = snap.docs.filter((d) => d.id.startsWith('demo_part_'));
    let removed = 0;
    for (let i = 0; i < targets.length; i += 400) {
      const batch = db.batch();
      targets.slice(i, i + 400).forEach((d) => batch.delete(d.ref));
      await batch.commit();
      removed += Math.min(400, targets.length - i);
    }
    console.log(`demo_part_* を ${removed} 件削除しました。`);
    return;
  }

  const now = admin.firestore.FieldValue.serverTimestamp();
  let written = 0;
  for (let i = 0; i < rows.length; i += 400) {
    const batch = db.batch();
    rows.slice(i, i + 400).forEach((r) => {
      const { id, ...data } = r;
      // 固定 ID ＋ merge。**何度流しても増えない。**
      batch.set(col.doc(id), { ...data, createdAt: now, updatedAt: now }, { merge: true });
    });
    await batch.commit();
    written += Math.min(400, rows.length - i);
    console.log(`  ${written}/${rows.length} 件`);
  }
  console.log(`part_listings に ${written} 件を登録しました（demo_part_*）。`);
  console.log('消すときは: node scripts/seed_parts.js --emulator --delete');
}

main().catch((e) => {
  console.error('[ERROR]', e);
  process.exit(1);
});
