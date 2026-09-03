#!/usr/bin/env node
/**
 * アプリ内フィードバックを読み出す。
 *
 * feedback コレクションは、セキュリティルール上クライアントからは誰も読めない。
 * 他人の報告が読めると、連絡先メールと不具合内容がそのまま漏れるため。
 * 読めるのは Admin SDK（このスクリプト）と Firebase Console だけ。
 *
 * Usage:
 *   export GOOGLE_APPLICATION_CREDENTIALS=path/to/serviceAccount.json
 *   node scripts/read_feedback.js                    # 未対応（status=open）を新しい順
 *   node scripts/read_feedback.js --all              # 対応済みも含める
 *   node scripts/read_feedback.js --type bug         # 種別で絞る（request / bug / other）
 *   node scripts/read_feedback.js --since 2026-08-24 # 日付以降
 *   node scripts/read_feedback.js --json             # 生の JSON（他のツールへ渡す用）
 *   node scripts/read_feedback.js --emulator         # Emulator を見る
 *
 * Requirements:
 *   cd scripts && npm install
 */

const args = process.argv.slice(2);
const hasFlag = (name) => args.includes(name);
const getOpt = (name) => {
  const i = args.indexOf(name);
  return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
};

const showAll     = hasFlag('--all');
const asJson      = hasFlag('--json');
const useEmulator = hasFlag('--emulator');
const typeFilter  = getOpt('--type');
const sinceRaw    = getOpt('--since');

if (typeFilter && !['request', 'bug', 'other'].includes(typeFilter)) {
  console.error(`[ERROR] --type は request / bug / other のいずれかです（受け取った値: ${typeFilter}）`);
  process.exit(1);
}

let since = null;
if (sinceRaw) {
  since = new Date(sinceRaw);
  if (Number.isNaN(since.getTime())) {
    console.error(`[ERROR] --since の日付を解釈できません: ${sinceRaw}`);
    process.exit(1);
  }
}

if (useEmulator) {
  process.env.FIRESTORE_EMULATOR_HOST = 'localhost:8080';
}

const admin = (() => {
  try { return require('firebase-admin'); }
  catch {
    console.error('[ERROR] firebase-admin が見つかりません。');
    console.error('        cd scripts && npm install を実行してください。');
    process.exit(1);
  }
})();

if (!admin.apps.length) {
  if (useEmulator) {
    admin.initializeApp({ projectId: 'trust-car-platform' });
  } else {
    if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) {
      console.error('[ERROR] GOOGLE_APPLICATION_CREDENTIALS が未設定です。');
      console.error('        Firebase Console → プロジェクト設定 → サービスアカウント');
      console.error('        → 新しい秘密鍵を生成 でダウンロードした JSON のパスを指定してください。');
      process.exit(1);
    }
    admin.initializeApp({ credential: admin.credential.applicationDefault() });
  }
}

const db = admin.firestore();

const TYPE_LABEL = {
  request: 'こうしてほしい',
  bug:     'うまく動かない',
  other:   'その他',
};

function formatDate(ts) {
  if (!ts) return '(日時なし)';
  const d = ts.toDate ? ts.toDate() : new Date(ts);
  const pad = (n) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

(async () => {
  // 複合インデックスを増やしたくないので、絞り込みは取得後に JS でやる。
  // フィードバックは件数が知れているため、これで十分。
  let query = db.collection('feedback').orderBy('createdAt', 'desc').limit(500);

  const snapshot = await query.get();

  let rows = snapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() }));

  if (!showAll)    rows = rows.filter((r) => (r.status ?? 'open') === 'open');
  if (typeFilter)  rows = rows.filter((r) => r.type === typeFilter);
  if (since)       rows = rows.filter((r) => r.createdAt?.toDate?.() >= since);

  if (asJson) {
    console.log(JSON.stringify(
      rows.map((r) => ({ ...r, createdAt: r.createdAt?.toDate?.()?.toISOString() ?? null })),
      null, 2,
    ));
    process.exit(0);
  }

  if (rows.length === 0) {
    console.log(showAll ? 'フィードバックはまだありません。' : '未対応のフィードバックはありません。');
    process.exit(0);
  }

  const counts = rows.reduce((acc, r) => {
    acc[r.type ?? 'other'] = (acc[r.type ?? 'other'] ?? 0) + 1;
    return acc;
  }, {});

  console.log(`${rows.length}件${showAll ? '' : '（未対応のみ）'}`);
  console.log(Object.entries(counts).map(([t, n]) => `  ${TYPE_LABEL[t] ?? t}: ${n}`).join('\n'));
  console.log('');

  for (const r of rows) {
    const label = TYPE_LABEL[r.type] ?? r.type ?? '(種別なし)';
    console.log('─'.repeat(72));
    console.log(`[${label}] ${formatDate(r.createdAt)}  ${r.platform ?? '?'} / ${r.appVersion ?? '?'}`);
    console.log(`  画面: ${r.screen ?? '(不明)'}   status: ${r.status ?? 'open'}   id: ${r.id}`);
    if (r.contactEmail) console.log(`  返信先: ${r.contactEmail}`);
    console.log('');
    console.log(String(r.message ?? '').split('\n').map((l) => `  ${l}`).join('\n'));
    console.log('');
  }
  console.log('─'.repeat(72));
  console.log('対応済みにするには Firebase Console で status を open 以外に変えてください。');
})().catch((e) => {
  console.error('[ERROR]', e.message);
  process.exit(1);
});
