/**
 * Firebase Storage セキュリティルール 自動テスト
 *
 * 対象: storage.rules の車両画像パスの所有者スコープ検証。
 *   - 現行: vehicles/{userId}/{fileName}（所有者スコープ）
 *   - 旧パス: vehicles/{userId}/{vehicleId}/{fileName}（3セグメント・所有者スコープ）
 *
 * 重要: storage.rules には旧々形式 vehicles/{fileName}（userId 未スコープ・単一
 *       セグメント）のルールが存在しない。よってその形式の既存画像はデフォルト
 *       拒否で読めなくなる。scripts/migrate_vehicle_images.js で
 *       vehicles/{userId}/{fileName} へ移行することが前提（Admin SDK はルールを
 *       迂回するため移行自体は可能）。本テストはその「拒否」も明示的に検証する。
 *
 * 実行:
 *   cd test/rules
 *   npm install
 *   npm test          # Storage Emulator を起動してテスト実行（firebase emulators:exec）
 */

const fs = require('fs');
const path = require('path');
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');
const {
  ref,
  uploadBytes,
  getDownloadURL,
  deleteObject,
} = require('firebase/storage');

const PROJECT_ID = 'trust-car-platform';
const OWNER_UID = 'owner_user_123';
const OTHER_UID = 'other_user_456';

// 1x1 PNG（最小の正当な画像バイト列）
const PNG_BYTES = new Uint8Array([
  0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00, 0x00, 0x00, 0x0d,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1f, 0x15, 0xc4, 0x89, 0x00, 0x00, 0x00,
  0x0a, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9c, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0d, 0x0a, 0x2d, 0xb4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4e, 0x44, 0xae, 0x42, 0x60, 0x82,
]);
const PNG_META = { contentType: 'image/png' };

let testEnv;

beforeAll(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    storage: {
      rules: fs.readFileSync(path.resolve(__dirname, '../../storage.rules'), 'utf8'),
      host: 'localhost',
      port: 9199,
    },
  });
});

afterAll(async () => {
  await testEnv.cleanup();
});

beforeEach(async () => {
  await testEnv.clearStorage();
});

// 認証済みコンテキストの Storage インスタンス取得ヘルパ
function storageFor(uid) {
  return testEnv.authenticatedContext(uid).storage();
}
function unauthStorage() {
  return testEnv.unauthenticatedContext().storage();
}

// テスト用にオブジェクトを事前配置（ルールを無効化した管理コンテキストで書き込む）
async function seed(objectPath) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await uploadBytes(ref(ctx.storage(), objectPath), PNG_BYTES, PNG_META);
  });
}

describe('vehicles/{userId}/{fileName} — 現行パスの所有者スコープ', () => {
  const ownerPath = `vehicles/${OWNER_UID}/abc.jpg`;

  describe('write（アップロード）', () => {
    test('所有者は自分のパスに画像を書き込める', async () => {
      await assertSucceeds(
        uploadBytes(ref(storageFor(OWNER_UID), ownerPath), PNG_BYTES, PNG_META),
      );
    });

    test('他ユーザーは所有者のパスに書き込めない', async () => {
      await assertFails(
        uploadBytes(ref(storageFor(OTHER_UID), ownerPath), PNG_BYTES, PNG_META),
      );
    });

    test('未認証ユーザーは書き込めない', async () => {
      await assertFails(
        uploadBytes(ref(unauthStorage(), ownerPath), PNG_BYTES, PNG_META),
      );
    });

    test('非画像コンテンツは書き込めない（isImageFile）', async () => {
      await assertFails(
        uploadBytes(ref(storageFor(OWNER_UID), ownerPath), new Uint8Array([1, 2, 3]), {
          contentType: 'application/pdf',
        }),
      );
    });

    test('5MB以上の画像は書き込めない（isValidFileSize）', async () => {
      const big = new Uint8Array(5 * 1024 * 1024 + 1);
      await assertFails(
        uploadBytes(ref(storageFor(OWNER_UID), ownerPath), big, PNG_META),
      );
    });
  });

  describe('read（閲覧）', () => {
    beforeEach(async () => {
      await seed(ownerPath);
    });

    test('所有者は閲覧できる', async () => {
      await assertSucceeds(getDownloadURL(ref(storageFor(OWNER_UID), ownerPath)));
    });

    test('他の認証済みユーザーも閲覧できる（公開表示を許容）', async () => {
      await assertSucceeds(getDownloadURL(ref(storageFor(OTHER_UID), ownerPath)));
    });

    test('未認証ユーザーは閲覧できない', async () => {
      await assertFails(getDownloadURL(ref(unauthStorage(), ownerPath)));
    });
  });

  describe('delete（削除）', () => {
    beforeEach(async () => {
      await seed(ownerPath);
    });

    test('所有者は削除できる', async () => {
      await assertSucceeds(deleteObject(ref(storageFor(OWNER_UID), ownerPath)));
    });

    test('他ユーザーは削除できない', async () => {
      await assertFails(deleteObject(ref(storageFor(OTHER_UID), ownerPath)));
    });
  });
});

describe('vehicles/{userId}/{vehicleId}/{fileName} — 旧3セグメントパスの所有者スコープ', () => {
  const ownerNestedPath = `vehicles/${OWNER_UID}/vehicle_1/abc.jpg`;

  test('所有者は書き込める', async () => {
    await assertSucceeds(
      uploadBytes(ref(storageFor(OWNER_UID), ownerNestedPath), PNG_BYTES, PNG_META),
    );
  });

  test('他ユーザーは書き込めない', async () => {
    await assertFails(
      uploadBytes(ref(storageFor(OTHER_UID), ownerNestedPath), PNG_BYTES, PNG_META),
    );
  });

  test('認証済みユーザーは閲覧できる', async () => {
    await seed(ownerNestedPath);
    await assertSucceeds(getDownloadURL(ref(storageFor(OTHER_UID), ownerNestedPath)));
  });
});

describe('vehicles/{fileName} — 旧々形式（userId未スコープ）は拒否される', () => {
  // storage.rules に単一セグメントの vehicles/{fileName} ルールは無いため
  // デフォルト拒否となる。既存画像は migrate_vehicle_images.js での移行が前提。
  const legacyPath = 'vehicles/legacy-uuid.jpg';

  test('書き込みは拒否される（デフォルト拒否）', async () => {
    await assertFails(
      uploadBytes(ref(storageFor(OWNER_UID), legacyPath), PNG_BYTES, PNG_META),
    );
  });

  test('閲覧も拒否される（移行が必要なことを示す）', async () => {
    await seed(legacyPath);
    await assertFails(getDownloadURL(ref(storageFor(OWNER_UID), legacyPath)));
  });
});

describe('デフォルト拒否', () => {
  test('未定義パスへの書き込みは拒否される', async () => {
    await assertFails(
      uploadBytes(ref(storageFor(OWNER_UID), 'unknown/foo.jpg'), PNG_BYTES, PNG_META),
    );
  });
});
