/**
 * seed_media.js
 *
 * 投稿とコメントに「写真」を付ける。
 *
 * シードの投稿は本文だけで、詳細画面を開いても絵が一枚も無い。実機で見ると
 * 「画像は投稿できないのか」と読めてしまうため、表示経路まで通したデモ用の
 * 画像を Storage に置いて posts.media / comments.imageUrls に紐づける。
 *
 * 画像は外部から取ってこず、その場で生成する（PNG を zlib で組み立てる）。
 * 車の写真ではなく色面 + 帯のプレースホルダなので、実機確認・レイアウト検証用。
 *
 * 書き込み先:
 *   Storage  post_images/seed/{postId}/{n}.png
 *            comment_images/seed/{commentId}/{n}.png
 *   posts.media[]        （既存投稿へ追記）
 *   comments.imageUrls[] （既存コメントへ追記）
 *
 * 使い方:
 *   node seed_media.js --emulator
 *   node seed_media.js --dry-run
 *   node seed_media.js --delete --emulator
 */

const zlib = require('zlib');
const admin = require('firebase-admin');

const has = (f) => process.argv.includes(f);
const EMULATOR = has('--emulator');
const DRY_RUN = has('--dry-run');
const DELETE = has('--delete');

if (EMULATOR) {
  process.env.FIRESTORE_EMULATOR_HOST =
    process.env.FIRESTORE_EMULATOR_HOST || 'localhost:8080';
  process.env.FIREBASE_STORAGE_EMULATOR_HOST =
    process.env.FIREBASE_STORAGE_EMULATOR_HOST || 'localhost:9199';
}

const PROJECT_ID = 'trust-car-platform';
const BUCKET = 'trust-car-platform.firebasestorage.app';
const SEED_TAG = 'seed_media_v1';

// ---------------------------------------------------------------------------
// PNG の生成
//
// 依存を増やしたくないので、PNG のチャンクを手で組み立てる。
// 上下グラデーション + 中央の帯（写真らしい輪郭を持たせるため）。
// ---------------------------------------------------------------------------

function crc32(buf) {
  let c;
  const table = [];
  for (let n = 0; n < 256; n++) {
    c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    table[n] = c >>> 0;
  }
  let crc = 0xffffffff;
  for (let i = 0; i < buf.length; i++) {
    crc = table[(crc ^ buf[i]) & 0xff] ^ (crc >>> 8);
  }
  return (crc ^ 0xffffffff) >>> 0;
}

function chunk(type, data) {
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length, 0);
  const typeBuf = Buffer.from(type, 'ascii');
  const crcBuf = Buffer.alloc(4);
  crcBuf.writeUInt32BE(crc32(Buffer.concat([typeBuf, data])), 0);
  return Buffer.concat([len, typeBuf, data, crcBuf]);
}

/**
 * width x height の PNG を作る。
 * base = [r, g, b]。上から下へ暗くし、中央に明るい帯を入れる。
 */
function makePng(width, height, base) {
  const raw = Buffer.alloc((width * 3 + 1) * height);
  let pos = 0;
  for (let y = 0; y < height; y++) {
    raw[pos++] = 0; // filter type: none
    const shade = 1 - (y / height) * 0.45;
    const bandTop = Math.floor(height * 0.58);
    const bandBottom = Math.floor(height * 0.72);
    const inBand = y >= bandTop && y <= bandBottom;
    for (let x = 0; x < width; x++) {
      const edge = 1 - Math.abs(x / width - 0.5) * 0.35;
      const lift = inBand ? 1.35 : 1;
      raw[pos++] = Math.min(255, Math.round(base[0] * shade * edge * lift));
      raw[pos++] = Math.min(255, Math.round(base[1] * shade * edge * lift));
      raw[pos++] = Math.min(255, Math.round(base[2] * shade * edge * lift));
    }
  }

  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(width, 0);
  ihdr.writeUInt32BE(height, 4);
  ihdr[8] = 8; // bit depth
  ihdr[9] = 2; // color type: truecolor
  ihdr[10] = 0;
  ihdr[11] = 0;
  ihdr[12] = 0;

  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk('IHDR', ihdr),
    chunk('IDAT', zlib.deflateSync(raw, { level: 9 })),
    chunk('IEND', Buffer.alloc(0)),
  ]);
}

// ---------------------------------------------------------------------------
// 何をどこに付けるか
// ---------------------------------------------------------------------------

// 投稿ID -> 画像の色（投稿の雰囲気に合わせて変える）
const POST_IMAGES = {
  'post-cv-garage-4cars': [[46, 92, 158], [38, 70, 120]], // 4台のガレージ
  'post-cv-beat-parts-hunting': [[142, 96, 52]], // 旧車の部品探し
  'post-cv-ev-winter-efficiency': [[38, 122, 95]], // EV の冬の電費
  'post-cv-coating-worth-it': [[70, 110, 140]], // コーティング1年後
  'post-cv-body-shop-quote-gap': [[96, 84, 104]], // 見積もり比較
  'post-cv-first-car-anxiety': [[86, 110, 150]], // 初マイカー
  'post-cv-dashcam-recommendation': [[64, 84, 104]], // ドラレコ
};

// コメントID -> 画像の色
const COMMENT_IMAGES = {
  'cmt-cv-body-shop-quote-gap-0': [[110, 96, 84]],
  'cmt-cv-beat-parts-hunting-1': [[132, 104, 64]],
  'cmt-cv-battery-dead-0': [[92, 96, 110]],
};

const WIDTH = 480;
const HEIGHT = 320;

// ダウンロードトークン。アプリは Image.network で素の GET を投げるため、
// トークンの無い ?alt=media だけの URL は storage.rules の
// `allow read: if isAuthenticated()` に弾かれる（403）。
// SDK の getDownloadURL が返すのと同じ形式に揃える。
function tokenFor(objectPath) {
  // パスから決めうちで作る。何度流しても同じ URL になり、参照が壊れない。
  let hash = 0;
  for (let i = 0; i < objectPath.length; i++) {
    hash = (hash * 31 + objectPath.charCodeAt(i)) >>> 0;
  }
  const hex = hash.toString(16).padStart(8, '0');
  return `${hex}-seed-4000-8000-${hex}${hex}`;
}

function publicUrl(objectPath) {
  const encoded = encodeURIComponent(objectPath);
  const token = tokenFor(objectPath);
  const host = EMULATOR
    ? 'http://localhost:9199'
    : 'https://firebasestorage.googleapis.com';
  return `${host}/v0/b/${BUCKET}/o/${encoded}?alt=media&token=${token}`;
}

async function upload(bucket, objectPath, buffer) {
  const file = bucket.file(objectPath);
  await file.save(buffer, {
    contentType: 'image/png',
    metadata: {
      metadata: {
        seedTag: SEED_TAG,
        firebaseStorageDownloadTokens: tokenFor(objectPath),
      },
    },
  });
  return publicUrl(objectPath);
}

async function main() {
  const postCount = Object.values(POST_IMAGES).reduce((n, a) => n + a.length, 0);
  const commentCount = Object.values(COMMENT_IMAGES).reduce(
    (n, a) => n + a.length,
    0,
  );

  console.log('');
  console.log('投稿・コメントの画像シード');
  console.log('----------------------------------------');
  console.log(`  投稿画像    : ${postCount} 枚 / ${Object.keys(POST_IMAGES).length} 投稿`);
  console.log(`  コメント画像: ${commentCount} 枚 / ${Object.keys(COMMENT_IMAGES).length} コメント`);
  console.log(`  サイズ      : ${WIDTH}x${HEIGHT} PNG（その場で生成）`);
  console.log('');

  if (DRY_RUN) {
    console.log('[DRY-RUN] 書き込みは行いませんでした。');
    return;
  }

  admin.initializeApp({ projectId: PROJECT_ID, storageBucket: BUCKET });
  const db = admin.firestore();
  const bucket = admin.storage().bucket();

  if (DELETE) {
    for (const postId of Object.keys(POST_IMAGES)) {
      await db.collection('posts').doc(postId).update({ media: [] })
        .catch(() => {});
    }
    for (const commentId of Object.keys(COMMENT_IMAGES)) {
      await db.collection('comments').doc(commentId).update({ imageUrls: [] })
        .catch(() => {});
    }
    await bucket.deleteFiles({ prefix: 'post_images/seed/' }).catch(() => {});
    await bucket.deleteFiles({ prefix: 'comment_images/seed/' }).catch(() => {});
    console.log('[DELETE] 画像と参照を削除しました。');
    return;
  }

  let written = 0;

  for (const [postId, colors] of Object.entries(POST_IMAGES)) {
    const snap = await db.collection('posts').doc(postId).get();
    if (!snap.exists) {
      console.log(`  [SKIP] posts/${postId} が見つかりません`);
      continue;
    }

    const media = [];
    for (let i = 0; i < colors.length; i++) {
      const url = await upload(
        bucket,
        `post_images/seed/${postId}/${i}.png`,
        makePng(WIDTH, HEIGHT, colors[i]),
      );
      media.push({ url, type: 'image', width: WIDTH, height: HEIGHT });
      written++;
    }

    await db.collection('posts').doc(postId).update({ media });
    console.log(`  [OK] posts/${postId} — ${media.length}枚`);
  }

  for (const [commentId, colors] of Object.entries(COMMENT_IMAGES)) {
    const snap = await db.collection('comments').doc(commentId).get();
    if (!snap.exists) {
      console.log(`  [SKIP] comments/${commentId} が見つかりません`);
      continue;
    }

    const urls = [];
    for (let i = 0; i < colors.length; i++) {
      urls.push(
        await upload(
          bucket,
          `comment_images/seed/${commentId}/${i}.png`,
          makePng(WIDTH, HEIGHT, colors[i]),
        ),
      );
      written++;
    }

    await db.collection('comments').doc(commentId).update({ imageUrls: urls });
    console.log(`  [OK] comments/${commentId} — ${urls.length}枚`);
  }

  console.log('');
  console.log(`[SUCCESS] ${written} 枚を Storage に置き、参照を書き込みました。`);
  console.log('後片付け: node seed_media.js --delete --emulator');
}

main().catch((e) => {
  console.error(e.message);
  process.exit(1);
});
