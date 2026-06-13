#!/usr/bin/env node
/**
 * migrate_vehicle_images.js のエンドツーエンド検証（Emulator専用・本番非接続）
 *
 * Storage / Firestore Emulator 上で:
 *   1. 旧形式 vehicles/{uuid}.jpg のオブジェクトと、それを指す vehicles ドキュメントを作成
 *   2. migrate_vehicle_images.js を --emulator で実行
 *   3. 新パス vehicles/{userId}/{uuid}.jpg が生成され Firestore の imageUrl が更新されたか検証
 *   4. 既定では旧オブジェクトが残ること、--delete-old で削除されることを検証
 *
 * 実行:
 *   cd scripts
 *   npm install
 *   npm run verify-migration   # emulators:exec が Emulator を起動して本ファイルを実行
 */

const { execFileSync } = require('child_process');
const path = require('path');

process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || 'localhost:8080';
process.env.FIREBASE_STORAGE_EMULATOR_HOST =
  process.env.FIREBASE_STORAGE_EMULATOR_HOST || 'localhost:9199';

const admin = require('firebase-admin');
const STORAGE_BUCKET = 'trust-car-platform.firebasestorage.app';

admin.initializeApp({ projectId: 'trust-car-platform', storageBucket: STORAGE_BUCKET });
const db = admin.firestore();
const bucket = admin.storage().bucket();

const USER_ID = 'verify_user_1';
const UUID = 'legacy-uuid-123';
const OLD_PATH = `vehicles/${UUID}.jpg`;
const NEW_PATH = `vehicles/${USER_ID}/${UUID}.jpg`;
const PNG = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);

function assert(cond, msg) {
  if (!cond) {
    console.error(`  [FAIL] ${msg}`);
    process.exitCode = 1;
    throw new Error(msg);
  }
  console.log(`  [OK] ${msg}`);
}

function runMigration(extraArgs) {
  const script = path.resolve(__dirname, 'migrate_vehicle_images.js');
  execFileSync('node', [script, '--emulator', ...extraArgs], { stdio: 'inherit' });
}

async function main() {
  console.log('=== 移行スクリプト E2E 検証（Emulator）===');

  // 1. 旧形式オブジェクト + Firestore ドキュメントを作成
  await bucket.file(OLD_PATH).save(PNG, { contentType: 'image/png' });
  const docRef = db.collection('vehicles').doc('vehicle_verify_1');
  const oldImageUrl =
    `http://localhost:9199/v0/b/${STORAGE_BUCKET}/o/${encodeURIComponent(OLD_PATH)}?alt=media&token=seed`;
  await docRef.set({ userId: USER_ID, imageUrl: oldImageUrl, maker: 'Test', model: 'Car' });
  console.log(`seed 完了: ${OLD_PATH} と vehicles/vehicle_verify_1`);

  // 2. dry-run（書き込みなし）
  console.log('\n--- dry-run ---');
  runMigration(['--dry-run']);
  const afterDry = (await docRef.get()).data();
  assert(afterDry.imageUrl === oldImageUrl, 'dry-run では imageUrl が変わらない');
  const [newExistsAfterDry] = await bucket.file(NEW_PATH).exists();
  assert(!newExistsAfterDry, 'dry-run では新パスが作られない');

  // 3. 本実行（旧ファイル保持）
  console.log('\n--- 本実行（--delete-old なし）---');
  runMigration([]);
  const afterRun = (await docRef.get()).data();
  assert(afterRun.imageUrl.includes(encodeURIComponent(NEW_PATH)), 'imageUrl が新パスに更新される');
  const [newExists] = await bucket.file(NEW_PATH).exists();
  assert(newExists, '新パスのオブジェクトが生成される');
  const [oldStillExists] = await bucket.file(OLD_PATH).exists();
  assert(oldStillExists, '既定では旧オブジェクトが残る（ロールバック猶予）');

  // 4. 冪等性: 再実行しても新形式はスキップされる
  console.log('\n--- 再実行（冪等性）---');
  runMigration([]);
  const afterReRun = (await docRef.get()).data();
  assert(afterReRun.imageUrl === afterRun.imageUrl, '再実行で imageUrl が変化しない（冪等）');

  // 5. --delete-old: 旧オブジェクト削除。ただし imageUrl は既に新形式なので
  //    対象にならない。旧ファイル削除の検証用に再度 seed して実行する。
  console.log('\n--- --delete-old 検証 ---');
  await bucket.file(OLD_PATH).save(PNG, { contentType: 'image/png' });
  await docRef.update({ imageUrl: oldImageUrl });
  runMigration(['--delete-old']);
  const [oldGone] = await bucket.file(OLD_PATH).exists();
  assert(!oldGone, '--delete-old で旧オブジェクトが削除される');

  console.log('\n=== 検証成功: すべてのアサーションを通過 ===');
}

main().catch((e) => {
  console.error('[FATAL]', e.message);
  process.exit(1);
});
