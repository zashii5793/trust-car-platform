#!/usr/bin/env node
/**
 * Vehicle Image Migration — 車両画像パスの所有者スコープ移行スクリプト (Node.js)
 *
 * 目的:
 *   旧形式 `vehicles/{uuid}.jpg`（userId 未スコープ）で保存された車両画像を、
 *   新形式 `vehicles/{userId}/{uuid}.jpg` へコピーし、Firestore の imageUrl を
 *   新しい URL に更新する。storage.rules の isOwner(userId) スコープに整合させ、
 *   将来的に後方互換ルール（match /vehicles/{fileName}）を削除可能にする。
 *
 * 処理:
 *   1. Firestore の vehicles コレクションを全件走査
 *   2. imageUrl から Storage オブジェクトパスを抽出
 *   3. 旧形式（vehicles/{単一セグメント}）のみ対象。新形式・外部URL・空はスキップ
 *   4. doc.userId を使って vehicles/{userId}/{fileName} へコピー
 *   5. 新しい getDownloadURL() を取得し Firestore の imageUrl を更新
 *   6. --delete-old 指定時のみ旧オブジェクトを削除（既定は残す＝安全側）
 *
 * Usage:
 *   node scripts/migrate_vehicle_images.js [--dry-run] [--emulator] [--delete-old]
 *
 * Options:
 *   --dry-run      実際の copy / Firestore 更新を行わず、対象一覧のみ表示する
 *   --emulator     Firebase Emulator (Firestore:8080 / Storage:9199) に接続する
 *   --delete-old   移行成功後に旧オブジェクト（vehicles/{uuid}.jpg）を削除する
 *
 * Requirements:
 *   npm install firebase-admin
 *
 * Example:
 *   # まず本番で対象件数を確認（書き込みなし）
 *   export GOOGLE_APPLICATION_CREDENTIALS=path/to/serviceAccount.json
 *   node scripts/migrate_vehicle_images.js --dry-run
 *
 *   # 本番移行（旧ファイルは残す）
 *   node scripts/migrate_vehicle_images.js
 *
 *   # 動作確認後、旧ファイルも削除
 *   node scripts/migrate_vehicle_images.js --delete-old
 *
 * 注意:
 *   - 本番バケットは trust-car-platform.firebasestorage.app
 *   - 旧 URL は移行後も Firestore からは参照されなくなるが、--delete-old を
 *     付けるまで Storage 上には残る。ロールバック猶予を取りたい場合は残すこと。
 */

const isDryRun    = process.argv.includes('--dry-run');
const useEmulator = process.argv.includes('--emulator');
const deleteOld   = process.argv.includes('--delete-old');

const STORAGE_BUCKET = 'trust-car-platform.firebasestorage.app';

// Emulator 接続設定（--emulator フラグ時）
if (useEmulator) {
  process.env.FIRESTORE_EMULATOR_HOST = 'localhost:8080';
  process.env.FIREBASE_STORAGE_EMULATOR_HOST = 'localhost:9199';
}

const admin = (() => {
  try { return require('firebase-admin'); }
  catch {
    console.error('[ERROR] firebase-admin が見つかりません。');
    console.error('        npm install firebase-admin を実行してください。');
    process.exit(1);
  }
})();

// ---------------------------------------------------------------------------
// Firebase 初期化
// ---------------------------------------------------------------------------
if (!admin.apps.length) {
  if (useEmulator) {
    admin.initializeApp({ projectId: 'trust-car-platform', storageBucket: STORAGE_BUCKET });
  } else {
    admin.initializeApp({
      credential: admin.credential.applicationDefault(),
      storageBucket: STORAGE_BUCKET,
    });
  }
}

const db = admin.firestore();
const bucket = admin.storage().bucket();

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/**
 * Firebase Storage の downloadURL から Storage オブジェクトパスを抽出する。
 * 例: https://.../o/vehicles%2Fabc.jpg?alt=media&token=... → 'vehicles/abc.jpg'
 * gs:// 形式や生パス（'vehicles/abc.jpg'）もそのまま受け付ける。
 * 抽出できない場合は null。
 */
function extractObjectPath(imageUrl) {
  if (!imageUrl || typeof imageUrl !== 'string') return null;

  // 生パス（URLでない）
  if (!imageUrl.includes('://') && imageUrl.startsWith('vehicles/')) {
    return imageUrl.split('?')[0];
  }

  // gs://bucket/path 形式
  if (imageUrl.startsWith('gs://')) {
    const withoutScheme = imageUrl.slice('gs://'.length);
    const slash = withoutScheme.indexOf('/');
    return slash === -1 ? null : withoutScheme.slice(slash + 1).split('?')[0];
  }

  // https://.../o/<encoded-path>?... 形式
  const match = imageUrl.match(/\/o\/([^?]+)/);
  if (!match) return null;
  return decodeURIComponent(match[1]);
}

/**
 * 旧形式 `vehicles/{fileName}`（userId サブフォルダなし）かどうか判定。
 * 新形式 `vehicles/{userId}/{fileName}` は false。
 */
function isLegacyVehiclePath(objectPath) {
  if (!objectPath || !objectPath.startsWith('vehicles/')) return false;
  const rest = objectPath.slice('vehicles/'.length);
  // セグメント数が 1 なら旧形式（uuid.jpg のみ）
  return rest.length > 0 && !rest.includes('/');
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------
async function main() {
  console.log('=== Vehicle Image Migration ===');
  console.log(`  mode       : ${isDryRun ? 'DRY-RUN（書き込みなし）' : '本番反映'}`);
  console.log(`  target     : ${useEmulator ? 'Emulator' : '本番 (' + STORAGE_BUCKET + ')'}`);
  console.log(`  delete-old : ${deleteOld ? 'あり（旧ファイル削除）' : 'なし（旧ファイル保持）'}`);
  console.log('');

  const snapshot = await db.collection('vehicles').get();
  console.log(`vehicles ドキュメント総数: ${snapshot.size}`);

  let migrated = 0;
  let skipped = 0;
  let failed = 0;

  for (const doc of snapshot.docs) {
    const data = doc.data();
    const vehicleId = doc.id;
    const userId = data.userId;
    const imageUrl = data.imageUrl;

    const objectPath = extractObjectPath(imageUrl);

    // 画像なし / 抽出不能 / 新形式 はスキップ
    if (!objectPath || !isLegacyVehiclePath(objectPath)) {
      skipped++;
      continue;
    }

    if (!userId) {
      console.warn(`[SKIP] vehicle ${vehicleId}: userId が空のため移行不可 (${objectPath})`);
      skipped++;
      continue;
    }

    const fileName = objectPath.slice('vehicles/'.length);   // 例: abc.jpg
    const newPath = `vehicles/${userId}/${fileName}`;

    console.log(`[MIGRATE] ${vehicleId}: ${objectPath} -> ${newPath}`);

    if (isDryRun) {
      migrated++;
      continue;
    }

    try {
      const srcFile = bucket.file(objectPath);
      const [exists] = await srcFile.exists();
      if (!exists) {
        console.warn(`  [WARN] 旧オブジェクトが存在しません。Firestore のみ更新対象から除外: ${objectPath}`);
        skipped++;
        continue;
      }

      // 1. 新パスへコピー
      const destFile = bucket.file(newPath);
      await srcFile.copy(destFile);

      // 2. 新しいダウンロードURLを取得（download token を付与して getDownloadURL 相当のURLを生成）
      const newUrl = await getDownloadUrl(destFile);

      // 3. Firestore の imageUrl を更新
      await doc.ref.update({ imageUrl: newUrl });

      // 4. 旧オブジェクト削除（任意）
      if (deleteOld) {
        await srcFile.delete();
        console.log(`  旧オブジェクト削除済み: ${objectPath}`);
      }

      migrated++;
    } catch (e) {
      console.error(`  [ERROR] vehicle ${vehicleId} の移行に失敗: ${e.message}`);
      failed++;
    }
  }

  console.log('');
  console.log('=== 完了 ===');
  console.log(`  移行${isDryRun ? '対象' : '成功'}: ${migrated}`);
  console.log(`  スキップ        : ${skipped}`);
  console.log(`  失敗            : ${failed}`);
  if (isDryRun) {
    console.log('');
    console.log('DRY-RUN のため実際の変更は行っていません。本番反映は --dry-run を外して再実行してください。');
  }
}

/**
 * オブジェクトに download token を発行し、getDownloadURL() 相当の公開URLを返す。
 * Admin SDK には getDownloadURL が無いため、メタデータの firebaseStorageDownloadTokens を利用する。
 */
async function getDownloadUrl(file) {
  // 既存トークンがあれば再利用、なければ新規発行
  const [metadata] = await file.getMetadata();
  let token = metadata.metadata && metadata.metadata.firebaseStorageDownloadTokens;
  if (!token) {
    token = generateToken();
    await file.setMetadata({ metadata: { firebaseStorageDownloadTokens: token } });
  }
  const encodedPath = encodeURIComponent(file.name);
  const host = useEmulator
    ? `http://localhost:9199/v0/b/${bucket.name}/o/${encodedPath}`
    : `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/${encodedPath}`;
  return `${host}?alt=media&token=${token}`;
}

/** UUID 風のダウンロードトークンを生成（crypto 利用） */
function generateToken() {
  return require('crypto').randomUUID();
}

main()
  .then(() => process.exit(0))
  .catch((e) => {
    console.error('[FATAL]', e);
    process.exit(1);
  });
