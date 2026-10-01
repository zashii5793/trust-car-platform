/**
 * Firestore セキュリティルール 自動テスト
 *
 * 対象: accessory_showcases/{showcaseId}/comments/{commentId}
 *   - read:   認証済みユーザーは閲覧可・未認証は不可
 *   - create: 投稿者本人（userId == uid）のみ作成可
 *   - delete: 投稿者本人のみ削除可
 *   - update: 投稿者本人のみ編集可。ただし userId（所有者）は変更不可
 *
 * 実行:
 *   cd test/rules
 *   npm install
 *   npm test   # Firestore/Storage Emulator を起動してテスト実行
 */

const fs = require('fs');
const path = require('path');
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');
const {
  doc,
  getDoc,
  setDoc,
  updateDoc,
  deleteDoc,
  collection,
  getDocs,
  query,
  where,
  orderBy,
  limit,
  documentId,
  serverTimestamp,
  Timestamp,
} = require('firebase/firestore');

// 既定は本番と同じ projectId。ローカルの Emulator にシードデータを入れたまま
// テストしたいときは RULES_TEST_PROJECT_ID で別プロジェクトに逃がす
// （clearFirestore() が projectId 単位で走るため、シードを壊さずに済む）。
const PROJECT_ID = process.env.RULES_TEST_PROJECT_ID || 'trust-car-platform';
const OWNER_UID = 'owner_user_123';
const OTHER_UID = 'other_user_456';

const SHOWCASE_ID = 'sc_1';
const COMMENT_ID = 'c_1';
const commentPath = `accessory_showcases/${SHOWCASE_ID}/comments/${COMMENT_ID}`;

let testEnv;

beforeAll(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: fs.readFileSync(
        path.resolve(__dirname, '../../firestore.rules'),
        'utf8',
      ),
      host: 'localhost',
      port: 8080,
    },
  });
});

afterAll(async () => {
  await testEnv.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

function dbFor(uid) {
  return testEnv.authenticatedContext(uid).firestore();
}
function unauthDb() {
  return testEnv.unauthenticatedContext().firestore();
}

// ルールを無効化した管理コンテキストでコメントを事前配置する。
async function seedComment({ userId = OWNER_UID, content = '元のコメント' } = {}) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), commentPath), {
      showcaseId: SHOWCASE_ID,
      userId,
      content,
      isEdited: false,
      likeCount: 0,
      reportCount: 0,
    });
  });
}

const likePath = (uid) => `${commentPath}/likes/${uid}`;

describe('accessory_showcases/{id}/comments — read', () => {
  test('認証済みユーザーはコメントを閲覧できる', async () => {
    await seedComment();
    await assertSucceeds(getDoc(doc(dbFor(OTHER_UID), commentPath)));
  });

  test('未認証ユーザーは閲覧できない', async () => {
    await seedComment();
    await assertFails(getDoc(doc(unauthDb(), commentPath)));
  });
});

describe('accessory_showcases/{id}/comments — create', () => {
  test('投稿者本人（userId == uid）は作成できる', async () => {
    await assertSucceeds(
      setDoc(doc(dbFor(OWNER_UID), commentPath), {
        showcaseId: SHOWCASE_ID,
        userId: OWNER_UID,
        content: '新規コメント',
        isEdited: false,
      }),
    );
  });

  test('他人の userId を詐称した作成は拒否される', async () => {
    await assertFails(
      setDoc(doc(dbFor(OTHER_UID), commentPath), {
        showcaseId: SHOWCASE_ID,
        userId: OWNER_UID,
        content: 'なりすまし',
        isEdited: false,
      }),
    );
  });

  test('未認証ユーザーは作成できない', async () => {
    await assertFails(
      setDoc(doc(unauthDb(), commentPath), {
        showcaseId: SHOWCASE_ID,
        userId: OWNER_UID,
        content: 'x',
        isEdited: false,
      }),
    );
  });
});

describe('accessory_showcases/{id}/comments — delete', () => {
  test('投稿者本人は削除できる', async () => {
    await seedComment({ userId: OWNER_UID });
    await assertSucceeds(deleteDoc(doc(dbFor(OWNER_UID), commentPath)));
  });

  test('他ユーザーは削除できない', async () => {
    await seedComment({ userId: OWNER_UID });
    await assertFails(deleteDoc(doc(dbFor(OTHER_UID), commentPath)));
  });
});

describe('accessory_showcases/{id}/comments — update', () => {
  test('投稿者本人は内容を編集できる', async () => {
    await seedComment({ userId: OWNER_UID });
    await assertSucceeds(
      updateDoc(doc(dbFor(OWNER_UID), commentPath), {
        content: '編集後',
        isEdited: true,
      }),
    );
  });

  test('他ユーザーは編集できない', async () => {
    await seedComment({ userId: OWNER_UID });
    await assertFails(
      updateDoc(doc(dbFor(OTHER_UID), commentPath), { content: '改ざん' }),
    );
  });

  test('userId（所有者）の変更は拒否される', async () => {
    await seedComment({ userId: OWNER_UID });
    await assertFails(
      updateDoc(doc(dbFor(OWNER_UID), commentPath), { userId: OTHER_UID }),
    );
  });
});

describe('accessory_showcases/{id}/comments — likeCount update（いいね）', () => {
  test('誰でも likeCount を +1 できる（いいね）', async () => {
    await seedComment({ userId: OWNER_UID });
    await assertSucceeds(
      updateDoc(doc(dbFor(OTHER_UID), commentPath), { likeCount: 1 }),
    );
  });

  test('likeCount を -1 できる（いいね解除）', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), commentPath), {
        showcaseId: SHOWCASE_ID,
        userId: OWNER_UID,
        content: 'x',
        isEdited: false,
        likeCount: 1,
      });
    });
    await assertSucceeds(
      updateDoc(doc(dbFor(OTHER_UID), commentPath), { likeCount: 0 }),
    );
  });

  test('±1 を超える likeCount 変更は拒否される', async () => {
    await seedComment({ userId: OWNER_UID });
    await assertFails(
      updateDoc(doc(dbFor(OTHER_UID), commentPath), { likeCount: 5 }),
    );
  });

  test('非投稿者が likeCount と一緒に content も変更すると拒否される', async () => {
    await seedComment({ userId: OWNER_UID });
    await assertFails(
      updateDoc(doc(dbFor(OTHER_UID), commentPath), {
        likeCount: 1,
        content: '改ざん',
      }),
    );
  });
});

describe('accessory_showcases/{id}/comments — モデレーションフィールドはクライアント書込不可', () => {
  // 通報集計は Cloud Function（onCommentReportCreated, サービスアカウント）が
  // reportCount / isHidden を書く。クライアントからの直接書き換えは全て拒否。
  test('クライアントは reportCount を書き換えられない（+1 も不可）', async () => {
    await seedComment({ userId: OWNER_UID });
    await assertFails(
      updateDoc(doc(dbFor(OTHER_UID), commentPath), { reportCount: 1 }),
    );
  });

  test('投稿者本人でも reportCount を書き換えられない', async () => {
    await seedComment({ userId: OWNER_UID });
    await assertFails(
      updateDoc(doc(dbFor(OWNER_UID), commentPath), { reportCount: 1 }),
    );
  });

  test('クライアントは isHidden を立てられない', async () => {
    await seedComment({ userId: OWNER_UID });
    await assertFails(
      updateDoc(doc(dbFor(OTHER_UID), commentPath), { isHidden: true }),
    );
  });

  test('投稿者は自分のコメントの isHidden を解除できない（モデレーション回避不可）', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), commentPath), {
        showcaseId: SHOWCASE_ID,
        userId: OWNER_UID,
        content: 'x',
        isEdited: false,
        likeCount: 0,
        reportCount: 3,
        isHidden: true,
      });
    });
    await assertFails(
      updateDoc(doc(dbFor(OWNER_UID), commentPath), { isHidden: false }),
    );
  });

  test('投稿者が編集に紛れて reportCount を変えると拒否される', async () => {
    await seedComment({ userId: OWNER_UID });
    await assertFails(
      updateDoc(doc(dbFor(OWNER_UID), commentPath), {
        content: '編集後',
        reportCount: 3,
      }),
    );
  });
});

describe('accessory_showcases/{id}/comments/{id}/likes — like マーカー', () => {
  test('本人は自分の like マーカーを作成できる', async () => {
    await seedComment();
    await assertSucceeds(
      setDoc(doc(dbFor(OWNER_UID), likePath(OWNER_UID)), {
        userId: OWNER_UID,
        showcaseId: SHOWCASE_ID,
      }),
    );
  });

  test('他人の uid の like マーカー作成は拒否される', async () => {
    await seedComment();
    await assertFails(
      setDoc(doc(dbFor(OTHER_UID), likePath(OWNER_UID)), {
        userId: OWNER_UID,
        showcaseId: SHOWCASE_ID,
      }),
    );
  });

  test('userId フィールドの詐称は拒否される', async () => {
    await seedComment();
    await assertFails(
      setDoc(doc(dbFor(OWNER_UID), likePath(OWNER_UID)), {
        userId: OTHER_UID,
        showcaseId: SHOWCASE_ID,
      }),
    );
  });

  test('本人は自分の like マーカーを削除できる', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), likePath(OWNER_UID)), {
        userId: OWNER_UID,
        showcaseId: SHOWCASE_ID,
      });
    });
    await assertSucceeds(deleteDoc(doc(dbFor(OWNER_UID), likePath(OWNER_UID))));
  });

  test('他ユーザーは他人の like マーカーを削除できない', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), likePath(OWNER_UID)), {
        userId: OWNER_UID,
        showcaseId: SHOWCASE_ID,
      });
    });
    await assertFails(deleteDoc(doc(dbFor(OTHER_UID), likePath(OWNER_UID))));
  });
});

// ==================== 車両履歴共有権限 ====================

const VEHICLE_OWNER_UID = 'vehicle_owner_001';
// shopId == shop owner's Firebase UID (schema invariant)
const SHOP_OWNER_UID = 'shop_owner_002';
const UNRELATED_UID = 'unrelated_003';
const VEHICLE_ID = 'vehicle_abc';
const permDocId = `${VEHICLE_ID}_${SHOP_OWNER_UID}`;
const permPath = `vehicle_sharing_permissions/${permDocId}`;

async function seedPermission(overrides = {}) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    // 店のドキュメント（本番では必ずある）。店主かどうかは ownerId で決まる
    await setDoc(doc(ctx.firestore(), `shops/${SHOP_OWNER_UID}`), {
      name: '工場', ownerId: SHOP_OWNER_UID,
    });
    await setDoc(doc(ctx.firestore(), permPath), {
      vehicleId: VEHICLE_ID,
      shopId: SHOP_OWNER_UID,
      ownerId: VEHICLE_OWNER_UID,
      isActive: true,
      grantedAt: 1000000,
      ...overrides,
    });
  });
}

describe('vehicle_sharing_permissions — get', () => {
  test('車両オーナーは自分の許可ドキュメントを取得できる', async () => {
    await seedPermission();
    await assertSucceeds(getDoc(doc(dbFor(VEHICLE_OWNER_UID), permPath)));
  });

  test('許可された工場オーナーは許可ドキュメントを取得できる', async () => {
    await seedPermission();
    await assertSucceeds(getDoc(doc(dbFor(SHOP_OWNER_UID), permPath)));
  });

  test('関係のないユーザーは取得できない', async () => {
    await seedPermission();
    await assertFails(getDoc(doc(dbFor(UNRELATED_UID), permPath)));
  });

  test('未認証ユーザーは取得できない', async () => {
    await seedPermission();
    await assertFails(getDoc(doc(unauthDb(), permPath)));
  });
});

describe('vehicle_sharing_permissions — list（一覧）', () => {
  test('車両オーナーは自分の許可を一覧できる', async () => {
    await seedPermission();
    const q = query(
      collection(dbFor(VEHICLE_OWNER_UID), 'vehicle_sharing_permissions'),
      where('ownerId', '==', VEHICLE_OWNER_UID),
      where('vehicleId', '==', VEHICLE_ID),
    );
    await assertSucceeds(getDocs(q));
  });

  test('店は自分宛ての許可を一覧できる', async () => {
    await seedPermission();
    const q = query(
      collection(dbFor(SHOP_OWNER_UID), 'vehicle_sharing_permissions'),
      where('shopId', '==', SHOP_OWNER_UID),
      where('isActive', '==', true),
    );
    await assertSucceeds(getDocs(q));
  });

  test('絞り込みなしの一覧は拒否される（誰が共有したかを列挙させない）', async () => {
    await seedPermission();
    await assertFails(
      getDocs(collection(dbFor(UNRELATED_UID), 'vehicle_sharing_permissions')),
    );
  });

  test('他店の shopId では一覧できない', async () => {
    await seedPermission();
    const q = query(
      collection(dbFor(UNRELATED_UID), 'vehicle_sharing_permissions'),
      where('shopId', '==', SHOP_OWNER_UID),
    );
    await assertFails(getDocs(q));
  });
});

describe('vehicle_sharing_permissions — create（許可付与）', () => {
  test('車両オーナーは許可を付与できる', async () => {
    await assertSucceeds(
      setDoc(doc(dbFor(VEHICLE_OWNER_UID), permPath), {
        vehicleId: VEHICLE_ID,
        shopId: SHOP_OWNER_UID,
        ownerId: VEHICLE_OWNER_UID,
        isActive: true,
        grantedAt: 1000000,
      }),
    );
  });

  test('ownerId を他ユーザーに詐称した作成は拒否される', async () => {
    await assertFails(
      setDoc(doc(dbFor(UNRELATED_UID), permPath), {
        vehicleId: VEHICLE_ID,
        shopId: SHOP_OWNER_UID,
        ownerId: VEHICLE_OWNER_UID,
        isActive: true,
        grantedAt: 1000000,
      }),
    );
  });

  test('vehicleId が空の場合は拒否される', async () => {
    await assertFails(
      setDoc(doc(dbFor(VEHICLE_OWNER_UID), permPath), {
        vehicleId: '',
        shopId: SHOP_OWNER_UID,
        ownerId: VEHICLE_OWNER_UID,
        isActive: true,
        grantedAt: 1000000,
      }),
    );
  });

  test('shopId が空の場合は拒否される', async () => {
    await assertFails(
      setDoc(doc(dbFor(VEHICLE_OWNER_UID), permPath), {
        vehicleId: VEHICLE_ID,
        shopId: '',
        ownerId: VEHICLE_OWNER_UID,
        isActive: true,
        grantedAt: 1000000,
      }),
    );
  });

  test('未認証ユーザーは許可を付与できない', async () => {
    await assertFails(
      setDoc(doc(unauthDb(), permPath), {
        vehicleId: VEHICLE_ID,
        shopId: SHOP_OWNER_UID,
        ownerId: VEHICLE_OWNER_UID,
        isActive: true,
        grantedAt: 1000000,
      }),
    );
  });
});

describe('vehicle_sharing_permissions — update（再付与・フィールド保護）', () => {
  test('車両オーナーは許可を更新できる（isActive 変更など）', async () => {
    await seedPermission();
    await assertSucceeds(
      updateDoc(doc(dbFor(VEHICLE_OWNER_UID), permPath), {
        isActive: false,
        vehicleId: VEHICLE_ID,
        shopId: SHOP_OWNER_UID,
        ownerId: VEHICLE_OWNER_UID,
      }),
    );
  });

  test('ownerId の変更は拒否される（所有権乗っ取り防止）', async () => {
    await seedPermission();
    await assertFails(
      updateDoc(doc(dbFor(VEHICLE_OWNER_UID), permPath), {
        ownerId: UNRELATED_UID,
      }),
    );
  });

  test('vehicleId の変更は拒否される', async () => {
    await seedPermission();
    await assertFails(
      updateDoc(doc(dbFor(VEHICLE_OWNER_UID), permPath), {
        vehicleId: 'different_vehicle',
      }),
    );
  });

  test('shopId の変更は拒否される', async () => {
    await seedPermission();
    await assertFails(
      updateDoc(doc(dbFor(VEHICLE_OWNER_UID), permPath), {
        shopId: UNRELATED_UID,
      }),
    );
  });

  test('他ユーザーによる更新は拒否される', async () => {
    await seedPermission();
    await assertFails(
      updateDoc(doc(dbFor(UNRELATED_UID), permPath), { isActive: false }),
    );
  });
});

describe('vehicle_sharing_permissions — delete（権限取り消し）', () => {
  test('車両オーナーは許可を取り消せる', async () => {
    await seedPermission();
    await assertSucceeds(deleteDoc(doc(dbFor(VEHICLE_OWNER_UID), permPath)));
  });

  test('関係のないユーザーは取り消せない', async () => {
    await seedPermission();
    await assertFails(deleteDoc(doc(dbFor(UNRELATED_UID), permPath)));
  });

  test('工場オーナーは取り消せない（車両オーナー専用操作）', async () => {
    await seedPermission();
    await assertFails(deleteDoc(doc(dbFor(SHOP_OWNER_UID), permPath)));
  });

  test('未認証ユーザーは取り消せない', async () => {
    await seedPermission();
    await assertFails(deleteDoc(doc(unauthDb(), permPath)));
  });
});

describe('comment_reports — コメント通報', () => {
  const reportId = `${COMMENT_ID}_${OWNER_UID}`;
  const reportPath = `comment_reports/${reportId}`;

  test('本人は自分の通報を作成できる', async () => {
    await assertSucceeds(
      setDoc(doc(dbFor(OWNER_UID), reportPath), {
        showcaseId: SHOWCASE_ID,
        commentId: COMMENT_ID,
        reporterId: OWNER_UID,
        reason: 'spam',
        status: 'pending',
      }),
    );
  });

  test('reporterId の詐称は拒否される', async () => {
    await assertFails(
      setDoc(doc(dbFor(OTHER_UID), reportPath), {
        showcaseId: SHOWCASE_ID,
        commentId: COMMENT_ID,
        reporterId: OWNER_UID,
        reason: 'spam',
        status: 'pending',
      }),
    );
  });

  test('未認証ユーザーは通報を作成できない', async () => {
    await assertFails(
      setDoc(doc(unauthDb(), reportPath), {
        showcaseId: SHOWCASE_ID,
        commentId: COMMENT_ID,
        reporterId: OWNER_UID,
        reason: 'spam',
        status: 'pending',
      }),
    );
  });

  test('クライアントは通報を読み取れない（サーバー専用）', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), reportPath), {
        showcaseId: SHOWCASE_ID,
        commentId: COMMENT_ID,
        reporterId: OWNER_UID,
        reason: 'spam',
        status: 'pending',
      });
    });
    await assertFails(getDoc(doc(dbFor(OWNER_UID), reportPath)));
  });
});

// ---------------------------------------------------------------------------
// account_deletions/{uid} — アカウント削除要求
//   create/delete: 本人(uid==auth.uid)のみ / read・update: サーバー専用(不可)
// ---------------------------------------------------------------------------
describe('account_deletions/{uid}', () => {
  const marker = (uid) => ({ uid, requestedAt: new Date(), status: 'pending' });

  test('本人は自分の削除要求を作成できる', async () => {
    await assertSucceeds(
      setDoc(doc(dbFor(OWNER_UID), `account_deletions/${OWNER_UID}`),
        marker(OWNER_UID)),
    );
  });

  test('他人のuidの削除要求は作成できない', async () => {
    await assertFails(
      setDoc(doc(dbFor(OTHER_UID), `account_deletions/${OWNER_UID}`),
        marker(OWNER_UID)),
    );
  });

  test('未認証は作成できない', async () => {
    await assertFails(
      setDoc(doc(unauthDb(), `account_deletions/${OWNER_UID}`),
        marker(OWNER_UID)),
    );
  });

  test('本人は自分の削除要求を取り消せる（delete）', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `account_deletions/${OWNER_UID}`),
        marker(OWNER_UID));
    });
    await assertSucceeds(
      deleteDoc(doc(dbFor(OWNER_UID), `account_deletions/${OWNER_UID}`)),
    );
  });

  test('読み取りはサーバー専用（本人でも不可）', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `account_deletions/${OWNER_UID}`),
        marker(OWNER_UID));
    });
    await assertFails(
      getDoc(doc(dbFor(OWNER_UID), `account_deletions/${OWNER_UID}`)),
    );
  });
});

// ---------------------------------------------------------------------------
// vehicles — 法人フリート（companyId）
//
// フリート管理画面は vehicles を companyId でクエリする。read ルールが userId
// しか見ていないと list クエリごと拒否され、画面が「車両データの取得に失敗
// しました」で固まる（実機確認 2026-08-20 で再現）。
// ---------------------------------------------------------------------------

const FLEET_OWNER_UID = 'fleet_owner_789';

// フリート車両を配置する。companyId は法人オーナーの uid。
async function seedFleetVehicle(id, { userId, companyId }) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), `vehicles/${id}`), {
      userId,
      companyId,
      maker: 'Nissan',
      model: 'Serena',
      year: 2023,
      mileage: 80000,
    });
  });
}

describe('vehicles — 法人フリートの companyId クエリ', () => {
  test('法人オーナーは companyId == 自分の uid で車両一覧を取得できる', async () => {
    await seedFleetVehicle('veh_fleet_1', {
      userId: FLEET_OWNER_UID,
      companyId: FLEET_OWNER_UID,
    });
    await assertSucceeds(
      getDocs(
        query(
          collection(dbFor(FLEET_OWNER_UID), 'vehicles'),
          where('companyId', '==', FLEET_OWNER_UID),
        ),
      ),
    );
  });

  test('フリートに参加した他ユーザーの車両も法人オーナーは読める', async () => {
    await seedFleetVehicle('veh_fleet_2', {
      userId: OTHER_UID,
      companyId: FLEET_OWNER_UID,
    });
    await assertSucceeds(
      getDoc(doc(dbFor(FLEET_OWNER_UID), 'vehicles/veh_fleet_2')),
    );
  });

  test('他人の companyId ではクエリできない', async () => {
    await seedFleetVehicle('veh_fleet_3', {
      userId: FLEET_OWNER_UID,
      companyId: FLEET_OWNER_UID,
    });
    await assertFails(
      getDocs(
        query(
          collection(dbFor(OTHER_UID), 'vehicles'),
          where('companyId', '==', FLEET_OWNER_UID),
        ),
      ),
    );
  });

  test('自分の車両（userId == uid）のクエリは従来どおり取得できる', async () => {
    await seedFleetVehicle('veh_own_1', {
      userId: OWNER_UID,
      companyId: null,
    });
    await assertSucceeds(
      getDocs(
        query(
          collection(dbFor(OWNER_UID), 'vehicles'),
          where('userId', '==', OWNER_UID),
        ),
      ),
    );
  });

  test('無条件の全件クエリは拒否される', async () => {
    await seedFleetVehicle('veh_own_2', {
      userId: OWNER_UID,
      companyId: null,
    });
    await assertFails(getDocs(collection(dbFor(OWNER_UID), 'vehicles')));
  });
});

// ---------------------------------------------------------------------------
// fuel_records / drive_waypoints — 一覧クエリが所有者で絞られているか
//
// どちらもルールは resource.data.userId == uid を read の条件にしている。
// Firestore は「クエリがルールを満たすこと」を静的に証明できないと list を
// 丸ごと弾くため、**関連ID（vehicleId / driveLogId）だけで引くクエリは
// 本番で1件も返らない**。アプリ側は 2026-09-08 に userId 付きへ直した。
// ここでは「直した形は通る／直す前の形は弾かれる」を固定する。
// ---------------------------------------------------------------------------

describe('fuel_records — 給油履歴のクエリ', () => {
  beforeEach(async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'fuel_records/fuel_q1'), {
        userId: OWNER_UID,
        vehicleId: 'veh_1',
        date: new Date('2026-08-01'),
        liters: 40,
        cost: 7000,
        isFullTank: true,
        createdAt: new Date('2026-08-01'),
      });
    });
  });

  test('vehicleId だけのクエリは弾かれる（直す前のアプリの形）', async () => {
    await assertFails(
      getDocs(
        query(
          collection(dbFor(OWNER_UID), 'fuel_records'),
          where('vehicleId', '==', 'veh_1'),
        ),
      ),
    );
  });

  test('userId と vehicleId で絞れば取得できる', async () => {
    await assertSucceeds(
      getDocs(
        query(
          collection(dbFor(OWNER_UID), 'fuel_records'),
          where('userId', '==', OWNER_UID),
          where('vehicleId', '==', 'veh_1'),
        ),
      ),
    );
  });

  test('他人の userId では取得できない', async () => {
    await assertFails(
      getDocs(
        query(
          collection(dbFor(OTHER_UID), 'fuel_records'),
          where('userId', '==', OWNER_UID),
        ),
      ),
    );
  });
});

describe('drive_waypoints — 経路のクエリと書き込み', () => {
  test('userId を書かない create は弾かれる（直す前のアプリの形）', async () => {
    await assertFails(
      setDoc(doc(dbFor(OWNER_UID), 'drive_waypoints/wp_no_user'), {
        driveLogId: 'log_1',
        location: { latitude: 35.6, longitude: 139.6 },
        timestamp: new Date('2026-08-01T10:00:00Z'),
      }),
    );
  });

  test('userId を書けば create できる', async () => {
    await assertSucceeds(
      setDoc(doc(dbFor(OWNER_UID), 'drive_waypoints/wp_with_user'), {
        driveLogId: 'log_1',
        userId: OWNER_UID,
        location: { latitude: 35.6, longitude: 139.6 },
        timestamp: new Date('2026-08-01T10:00:00Z'),
      }),
    );
  });

  test('driveLogId だけのクエリは弾かれる', async () => {
    await assertFails(
      getDocs(
        query(
          collection(dbFor(OWNER_UID), 'drive_waypoints'),
          where('driveLogId', '==', 'log_1'),
        ),
      ),
    );
  });

  test('userId と driveLogId で絞れば取得できる', async () => {
    await assertSucceeds(
      getDocs(
        query(
          collection(dbFor(OWNER_UID), 'drive_waypoints'),
          where('userId', '==', OWNER_UID),
          where('driveLogId', '==', 'log_1'),
        ),
      ),
    );
  });
});

// ---------------------------------------------------------------------------
// inquiries/{id}/messages — 会話の閲覧
//
// メッセージ単体の senderId / receiverId で判定していると list クエリを静的に
// 検証できず、チャット画面が常に「メッセージはまだありません」になる。
// アプリは receiverId を書き込まないため get も通らない（実機確認 2026-08-20）。
// 判定は親 inquiry の当事者（userId / shopId）で行う。
// ---------------------------------------------------------------------------

const INQUIRY_ID = 'inq_1';
const SHOP_UID = 'shop_owner_321';
const inquiryPath = `inquiries/${INQUIRY_ID}`;
const messagesPath = `${inquiryPath}/messages`;

// 問い合わせ本体とショップからの返信メッセージを配置する。
async function seedInquiryThread() {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), `shops/${SHOP_UID}`), {
      name: '工場', ownerId: SHOP_UID,
    });
    await setDoc(doc(ctx.firestore(), inquiryPath), {
      userId: OWNER_UID,
      shopId: SHOP_UID,
      subject: '車検見積もりのお願い',
      status: 'replied',
    });
    // ショップからの返信。アプリは receiverId を書かない。
    await setDoc(doc(ctx.firestore(), `${messagesPath}/m_1`), {
      senderId: SHOP_UID,
      isFromShop: true,
      isRead: false,
      content: '概算で8万円前後です。',
    });
    await setDoc(doc(ctx.firestore(), `${messagesPath}/m_2`), {
      senderId: OWNER_UID,
      isFromShop: false,
      isRead: true,
      content: '火曜の午前でお願いできますか？',
    });
  });
}

describe('inquiries/{id}/messages — 会話の閲覧', () => {
  test('問い合わせ本人はメッセージ一覧を取得できる', async () => {
    await seedInquiryThread();
    await assertSucceeds(
      getDocs(collection(dbFor(OWNER_UID), messagesPath)),
    );
  });

  test('宛先ショップはメッセージ一覧を取得できる', async () => {
    await seedInquiryThread();
    await assertSucceeds(getDocs(collection(dbFor(SHOP_UID), messagesPath)));
  });

  test('本人は相手が送ったメッセージ単体も読める', async () => {
    await seedInquiryThread();
    await assertSucceeds(
      getDoc(doc(dbFor(OWNER_UID), `${messagesPath}/m_1`)),
    );
  });

  test('無関係のユーザーは取得できない', async () => {
    await seedInquiryThread();
    await assertFails(getDocs(collection(dbFor(OTHER_UID), messagesPath)));
  });

  test('未認証は取得できない', async () => {
    await seedInquiryThread();
    await assertFails(getDocs(collection(unauthDb(), messagesPath)));
  });
});

describe('inquiries/{id}/messages — 送信・既読', () => {
  test('当事者は自分が送信者のメッセージを作成できる', async () => {
    await seedInquiryThread();
    await assertSucceeds(
      setDoc(doc(dbFor(OWNER_UID), `${messagesPath}/m_3`), {
        senderId: OWNER_UID,
        isFromShop: false,
        isRead: false,
        content: '了解しました',
      }),
    );
  });

  test('当事者でないユーザーは作成できない', async () => {
    await seedInquiryThread();
    await assertFails(
      setDoc(doc(dbFor(OTHER_UID), `${messagesPath}/m_4`), {
        senderId: OTHER_UID,
        isFromShop: false,
        isRead: false,
        content: '割り込み',
      }),
    );
  });

  test('受信者は既読フラグだけ更新できる', async () => {
    await seedInquiryThread();
    await assertSucceeds(
      updateDoc(doc(dbFor(OWNER_UID), `${messagesPath}/m_1`), {
        isRead: true,
      }),
    );
  });

  test('本文の書き換えは拒否される', async () => {
    await seedInquiryThread();
    await assertFails(
      updateDoc(doc(dbFor(OWNER_UID), `${messagesPath}/m_1`), {
        content: '改ざん',
      }),
    );
  });

  test('自分が送ったメッセージを既読にすることはできない', async () => {
    await seedInquiryThread();
    await assertFails(
      updateDoc(doc(dbFor(OWNER_UID), `${messagesPath}/m_2`), {
        isRead: false,
      }),
    );
  });
});

// ---------------------------------------------------------------------------
// vehicles — フリートオーナーによる担当者アサイン
//
// fleet_service.assignVehicle() は他ユーザー名義の車両に対しても
// assigneeId / assigneeName を書き込む。update が所有者限定のままだと、
// フリートに参加してもらった車両へ担当者を割り当てられない。
// 逆に何でも書けてしまうと車両を奪える（companyId の書き換え）ため、
// 許可するキーは担当者まわりに限定する。
// ---------------------------------------------------------------------------

describe('vehicles — フリートオーナーの担当者アサイン', () => {
  // 他ユーザー名義でフリートに参加している車両。
  async function seedJoinedVehicle() {
    await seedFleetVehicle('veh_assign_1', {
      userId: OTHER_UID,
      companyId: FLEET_OWNER_UID,
    });
  }

  const assignPath = 'vehicles/veh_assign_1';

  test('フリートオーナーは担当者を割り当てられる', async () => {
    await seedJoinedVehicle();
    await assertSucceeds(
      updateDoc(doc(dbFor(FLEET_OWNER_UID), assignPath), {
        assigneeId: 'driver_1',
        assigneeName: 'ドライバー1',
        updatedAt: new Date(),
      }),
    );
  });

  test('フリートオーナーは担当者を外せる（null 代入）', async () => {
    await seedJoinedVehicle();
    await assertSucceeds(
      updateDoc(doc(dbFor(FLEET_OWNER_UID), assignPath), {
        assigneeId: null,
        assigneeName: null,
        updatedAt: new Date(),
      }),
    );
  });

  test('フリートオーナーは companyId を書き換えられない', async () => {
    await seedJoinedVehicle();
    await assertFails(
      updateDoc(doc(dbFor(FLEET_OWNER_UID), assignPath), {
        companyId: 'another_company',
      }),
    );
  });

  test('フリートオーナーは走行距離など他の項目を書き換えられない', async () => {
    await seedJoinedVehicle();
    await assertFails(
      updateDoc(doc(dbFor(FLEET_OWNER_UID), assignPath), {
        mileage: 1,
        updatedAt: new Date(),
      }),
    );
  });

  test('フリートオーナーは車両を削除できない', async () => {
    await seedJoinedVehicle();
    await assertFails(deleteDoc(doc(dbFor(FLEET_OWNER_UID), assignPath)));
  });

  test('無関係のユーザーは担当者を割り当てられない', async () => {
    await seedJoinedVehicle();
    await assertFails(
      updateDoc(doc(dbFor(OWNER_UID), assignPath), {
        assigneeId: 'driver_1',
        assigneeName: 'ドライバー1',
        updatedAt: new Date(),
      }),
    );
  });

  test('車両の所有者は従来どおり自由に更新できる', async () => {
    await seedJoinedVehicle();
    await assertSucceeds(
      updateDoc(doc(dbFor(OTHER_UID), assignPath), {
        mileage: 90000,
        updatedAt: new Date(),
      }),
    );
  });

  test('車両の所有者は従来どおり削除できる', async () => {
    await seedJoinedVehicle();
    await assertSucceeds(deleteDoc(doc(dbFor(OTHER_UID), assignPath)));
  });
});

// ---------------------------------------------------------------------------
// comments — 添付画像の枚数制限
//
// コメントに画像を付けられるようにしたので、壊れたクライアントが
// 何十枚も貼り付けてフィードを埋めないよう、サーバー側でも枚数を止める。
// ---------------------------------------------------------------------------

describe('comments — 添付画像', () => {
  const commentPath2 = 'comments/cmt_img_1';

  function commentData(imageUrls) {
    return {
      postId: 'post_1',
      userId: OWNER_UID,
      content: 'ここが気になります',
      imageUrls,
      parentCommentId: null,
      likeCount: 0,
      replyCount: 0,
      isEdited: false,
    };
  }

  test('画像なしのコメントは作成できる', async () => {
    await assertSucceeds(
      setDoc(doc(dbFor(OWNER_UID), commentPath2), commentData([])),
    );
  });

  test('画像2枚までは作成できる', async () => {
    await assertSucceeds(
      setDoc(
        doc(dbFor(OWNER_UID), commentPath2),
        commentData(['https://example.com/a.jpg', 'https://example.com/b.jpg']),
      ),
    );
  });

  test('画像3枚以上は拒否される', async () => {
    await assertFails(
      setDoc(
        doc(dbFor(OWNER_UID), commentPath2),
        commentData([
          'https://example.com/a.jpg',
          'https://example.com/b.jpg',
          'https://example.com/c.jpg',
        ]),
      ),
    );
  });

  test('imageUrls が配列でないコメントは拒否される', async () => {
    await assertFails(
      setDoc(
        doc(dbFor(OWNER_UID), commentPath2),
        commentData('https://example.com/a.jpg'),
      ),
    );
  });

  test('他人の userId を詐称したコメントは拒否される', async () => {
    await assertFails(
      setDoc(doc(dbFor(OTHER_UID), commentPath2), commentData([])),
    );
  });
});

// ---------------------------------------------------------------------------
// feedback — アプリ内の「ご意見・不具合の報告」
//
// 書き込み専用。他人の報告が読めると、連絡先メールと不具合内容がそのまま漏れる。
// ---------------------------------------------------------------------------

const feedbackPath = 'feedback/fb_1';

function feedbackDoc(overrides = {}) {
  return {
    userId: OWNER_UID,
    type: 'bug',
    message: '車検証OCRが読み取れません',
    appVersion: '1.0.0',
    platform: 'android',
    status: 'open',
    ...overrides,
  };
}

async function seedFeedback() {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), feedbackPath), feedbackDoc());
  });
}

describe('feedback — create', () => {
  test('本人は自分の userId で作成できる', async () => {
    await assertSucceeds(
      setDoc(doc(dbFor(OWNER_UID), feedbackPath), feedbackDoc()),
    );
  });

  test('他人の userId を詐称した作成は拒否される', async () => {
    await assertFails(
      setDoc(
        doc(dbFor(OTHER_UID), feedbackPath),
        feedbackDoc({ userId: OWNER_UID }),
      ),
    );
  });

  test('未認証ユーザーは作成できない', async () => {
    await assertFails(setDoc(doc(unauthDb(), feedbackPath), feedbackDoc()));
  });

  test('空の本文は拒否される', async () => {
    await assertFails(
      setDoc(doc(dbFor(OWNER_UID), feedbackPath), feedbackDoc({ message: '' })),
    );
  });

  test('2000文字を超える本文は拒否される', async () => {
    await assertFails(
      setDoc(
        doc(dbFor(OWNER_UID), feedbackPath),
        feedbackDoc({ message: 'あ'.repeat(2001) }),
      ),
    );
  });

  test('status を open 以外にして作成することはできない', async () => {
    await assertFails(
      setDoc(
        doc(dbFor(OWNER_UID), feedbackPath),
        feedbackDoc({ status: 'resolved' }),
      ),
    );
  });
});

describe('feedback — read / update / delete', () => {
  test('本人でも自分の報告を読み返せない（運用側専用）', async () => {
    await seedFeedback();
    await assertFails(getDoc(doc(dbFor(OWNER_UID), feedbackPath)));
  });

  test('他人の報告は読めない', async () => {
    await seedFeedback();
    await assertFails(getDoc(doc(dbFor(OTHER_UID), feedbackPath)));
  });

  test('本人でも更新できない', async () => {
    await seedFeedback();
    await assertFails(
      updateDoc(doc(dbFor(OWNER_UID), feedbackPath), { message: '書き換え' }),
    );
  });

  test('本人でも削除できない', async () => {
    await seedFeedback();
    await assertFails(deleteDoc(doc(dbFor(OWNER_UID), feedbackPath)));
  });
});

// ---------------------------------------------------------------------------
// client_errors — ウェブ版の不具合（Crashlytics の代わり）
//
// 作成はログイン中の本人だけ（2026-10-01 オーナー判断。いたずらの書き込みを防ぐため、
// ログイン前に落ちるエラーは拾わない）。項目・型・長さも厳しく決め、
// 何でも置ける場所にしない。読むのは運営者だけ。
// ---------------------------------------------------------------------------

const clientErrorPath = 'client_errors/ce_1';
const DAY_MS = 24 * 60 * 60 * 1000;

function clientErrorDoc(overrides = {}) {
  return {
    message: 'Bad state: 壊れた',
    stack: '#0 main (main.dart.js:1:2345)',
    source: 'flutter',
    buildId: 'a1b2c3d',
    path: '/',
    userAgent: 'Mozilla/5.0',
    uid: OWNER_UID,
    platform: 'web',
    createdAt: serverTimestamp(),
    expireAt: Timestamp.fromMillis(Date.now() + 90 * DAY_MS),
    ...overrides,
  };
}

async function seedClientError() {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(
      doc(ctx.firestore(), clientErrorPath),
      clientErrorDoc({ createdAt: new Date() }),
    );
  });
}

describe('client_errors — create', () => {
  test('未ログインでは作成できない', async () => {
    await assertFails(
      setDoc(doc(unauthDb(), clientErrorPath), clientErrorDoc({ uid: null })),
    );
  });

  test('ログイン中は自分の uid を付けて作成できる', async () => {
    await assertSucceeds(
      setDoc(
        doc(dbFor(OWNER_UID), clientErrorPath),
        clientErrorDoc({ uid: OWNER_UID }),
      ),
    );
  });

  test('userAgent は省ける', async () => {
    const d = clientErrorDoc();
    delete d.userAgent;
    await assertSucceeds(setDoc(doc(dbFor(OWNER_UID), clientErrorPath), d));
  });

  test('ログイン中でも uid を省くと拒否される', async () => {
    const d = clientErrorDoc();
    delete d.uid;
    await assertFails(setDoc(doc(dbFor(OWNER_UID), clientErrorPath), d));
  });

  test('他人の uid を名乗ると拒否される', async () => {
    await assertFails(
      setDoc(
        doc(dbFor(OTHER_UID), clientErrorPath),
        clientErrorDoc({ uid: OWNER_UID }),
      ),
    );
  });

  test('未ログインで uid を名乗ると拒否される', async () => {
    await assertFails(
      setDoc(
        doc(unauthDb(), clientErrorPath),
        clientErrorDoc({ uid: OWNER_UID }),
      ),
    );
  });

  test('余計な項目（email など）があると拒否される', async () => {
    await assertFails(
      setDoc(
        doc(dbFor(OWNER_UID), clientErrorPath),
        clientErrorDoc({ email: 'a@b.jp' }),
      ),
    );
  });

  test('必須の項目（message）が無いと拒否される', async () => {
    const d = clientErrorDoc();
    delete d.message;
    await assertFails(setDoc(doc(dbFor(OWNER_UID), clientErrorPath), d));
  });

  test('空のメッセージは拒否される', async () => {
    await assertFails(
      setDoc(doc(dbFor(OWNER_UID), clientErrorPath), clientErrorDoc({ message: '' })),
    );
  });

  test('500文字を超えるメッセージは拒否される', async () => {
    await assertFails(
      setDoc(
        doc(dbFor(OWNER_UID), clientErrorPath),
        clientErrorDoc({ message: 'あ'.repeat(501) }),
      ),
    );
  });

  test('500文字ちょうどのメッセージは通る', async () => {
    await assertSucceeds(
      setDoc(
        doc(dbFor(OWNER_UID), clientErrorPath),
        clientErrorDoc({ message: 'あ'.repeat(500) }),
      ),
    );
  });

  test('4000文字を超えるスタックは拒否される', async () => {
    await assertFails(
      setDoc(
        doc(dbFor(OWNER_UID), clientErrorPath),
        clientErrorDoc({ stack: 'x'.repeat(4001) }),
      ),
    );
  });

  test('長すぎる userAgent・path・buildId は拒否される', async () => {
    await assertFails(
      setDoc(
        doc(dbFor(OWNER_UID), clientErrorPath),
        clientErrorDoc({ userAgent: 'u'.repeat(301) }),
      ),
    );
    await assertFails(
      setDoc(
        doc(dbFor(OWNER_UID), clientErrorPath),
        clientErrorDoc({ path: '/' + 'p'.repeat(200) }),
      ),
    );
    await assertFails(
      setDoc(
        doc(dbFor(OWNER_UID), clientErrorPath),
        clientErrorDoc({ buildId: 'b'.repeat(41) }),
      ),
    );
  });

  test('決められていない source は拒否される', async () => {
    await assertFails(
      setDoc(
        doc(dbFor(OWNER_UID), clientErrorPath),
        clientErrorDoc({ source: 'manual' }),
      ),
    );
  });

  test('platform が web 以外は拒否される', async () => {
    await assertFails(
      setDoc(
        doc(dbFor(OWNER_UID), clientErrorPath),
        clientErrorDoc({ platform: 'android' }),
      ),
    );
  });

  test('createdAt がサーバ時刻でないと拒否される', async () => {
    await assertFails(
      setDoc(
        doc(dbFor(OWNER_UID), clientErrorPath),
        clientErrorDoc({ createdAt: new Date('2020-01-01') }),
      ),
    );
  });

  test('expireAt が過去・遠すぎる未来・無しは拒否される', async () => {
    await assertFails(
      setDoc(
        doc(dbFor(OWNER_UID), clientErrorPath),
        clientErrorDoc({ expireAt: Timestamp.fromMillis(Date.now() - DAY_MS) }),
      ),
    );
    await assertFails(
      setDoc(
        doc(dbFor(OWNER_UID), clientErrorPath),
        clientErrorDoc({
          expireAt: Timestamp.fromMillis(Date.now() + 365 * DAY_MS),
        }),
      ),
    );
    const d = clientErrorDoc();
    delete d.expireAt;
    await assertFails(setDoc(doc(dbFor(OWNER_UID), clientErrorPath), d));
  });

  test('message が文字列でないと拒否される', async () => {
    await assertFails(
      setDoc(doc(dbFor(OWNER_UID), clientErrorPath), clientErrorDoc({ message: 123 })),
    );
  });
});

describe('client_errors — read / update / delete', () => {
  test('書いた本人でも読めない（運営者専用）', async () => {
    await seedClientError();
    await assertFails(getDoc(doc(dbFor(OWNER_UID), clientErrorPath)));
    await assertFails(getDoc(doc(unauthDb(), clientErrorPath)));
  });

  test('一覧も取れない', async () => {
    await seedClientError();
    await assertFails(getDocs(collection(dbFor(OWNER_UID), 'client_errors')));
  });

  test('更新できない', async () => {
    await seedClientError();
    await assertFails(
      updateDoc(doc(dbFor(OWNER_UID), clientErrorPath), { message: '書き換え' }),
    );
    await assertFails(
      updateDoc(doc(unauthDb(), clientErrorPath), { message: '書き換え' }),
    );
  });

  test('削除できない', async () => {
    await seedClientError();
    await assertFails(deleteDoc(doc(dbFor(OWNER_UID), clientErrorPath)));
    await assertFails(deleteDoc(doc(unauthDb(), clientErrorPath)));
  });

  test('既にある ID への上書き（set）もできない', async () => {
    await seedClientError();
    await assertFails(
      setDoc(doc(unauthDb(), clientErrorPath), clientErrorDoc()),
    );
  });
});

// ---------------------------------------------------------------------------
// 招待コード / かかりつけ / 給油記録（2026-08-27 追加）
//
// ここを緩めると「他店の顧客名簿が読める」「勝手に顧客にされる」という、
// 気づきにくい壊れ方をする。実際に Emulator へ書いて確かめる。
// ---------------------------------------------------------------------------

const INVITE_SHOP_OWNER_UID = 'shop_owner_777';
const INVITE_CUSTOMER_UID = 'customer_888';
const INVITE_CODE = 'ABC234';
const invitePath = `shop_invites/${INVITE_CODE}`;
const INVITE_SHOP_ID = 'shop_777';

const inviteDoc = (overrides = {}) => ({
  shopId: INVITE_SHOP_ID,
  shopName: 'タカヤモーター',
  shopOwnerId: INVITE_SHOP_OWNER_UID,
  createdAt: new Date(),
  isActive: true,
  usedCount: 0,
  ...overrides,
});

const linkDoc = (uid, overrides = {}) => ({
  shopId: INVITE_SHOP_ID,
  shopName: 'タカヤモーター',
  userId: uid,
  linkedAt: new Date(),
  ...overrides,
});

const fuelDoc = (uid, overrides = {}) => ({
  vehicleId: 'v1',
  userId: uid,
  date: new Date(),
  liters: 40,
  cost: 6800,
  isFullTank: true,
  createdAt: new Date(),
  ...overrides,
});

async function seedInvite(overrides = {}) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), invitePath), inviteDoc(overrides));
    await setDoc(doc(ctx.firestore(), `shops/${INVITE_SHOP_ID}`), {
      name: 'タカヤモーター',
      ownerId: INVITE_SHOP_OWNER_UID,
    });
  });
}

describe('shop_invites', () => {
  test('店主は自分の招待を作れる', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `shops/${INVITE_SHOP_ID}`), {
        name: 'タカヤモーター', ownerId: INVITE_SHOP_OWNER_UID,
      });
    });
    await assertSucceeds(
      setDoc(doc(dbFor(INVITE_SHOP_OWNER_UID), invitePath), inviteDoc()),
    );
  });

  test('他人の店主IDを詐称した発行は拒否される', async () => {
    await assertFails(
      setDoc(doc(dbFor(INVITE_CUSTOMER_UID), invitePath), inviteDoc()),
    );
  });

  test('使用回数を最初から水増しした発行は拒否される', async () => {
    await assertFails(
      setDoc(
        doc(dbFor(INVITE_SHOP_OWNER_UID), invitePath),
        inviteDoc({ usedCount: 100 }),
      ),
    );
  });

  test('コードを知っていれば読める（引き換えに必要）', async () => {
    await seedInvite();
    await assertSucceeds(getDoc(doc(dbFor(INVITE_CUSTOMER_UID), invitePath)));
  });

  test('未認証では読めない', async () => {
    await seedInvite();
    await assertFails(getDoc(doc(unauthDb(), invitePath)));
  });

  test('引き換えで使用回数だけ増やせる', async () => {
    await seedInvite();
    await assertSucceeds(
      updateDoc(doc(dbFor(INVITE_CUSTOMER_UID), invitePath), { usedCount: 1 }),
    );
  });

  test('顧客が招待の中身を書き換えることはできない', async () => {
    await seedInvite();
    await assertFails(
      updateDoc(doc(dbFor(INVITE_CUSTOMER_UID), invitePath), { shopId: 'other_shop' }),
    );
  });

  test('顧客が招待を消すことはできない', async () => {
    await seedInvite();
    await assertFails(deleteDoc(doc(dbFor(INVITE_CUSTOMER_UID), invitePath)));
  });

  test('店主は自分の招待を止められる', async () => {
    await seedInvite();
    await assertSucceeds(
      updateDoc(doc(dbFor(INVITE_SHOP_OWNER_UID), invitePath), { isActive: false }),
    );
  });
});

describe('shop_customers（かかりつけ）', () => {
  const linkPath = `shop_customers/${INVITE_CUSTOMER_UID}`;

  test('本人は自分の紐づけを作れる', async () => {
    await assertSucceeds(
      setDoc(doc(dbFor(INVITE_CUSTOMER_UID), linkPath), linkDoc(INVITE_CUSTOMER_UID)),
    );
  });

  test('店が勝手に顧客を作ることはできない', async () => {
    // ここが通ると、店が名簿を勝手に増やせてしまう。
    await assertFails(
      setDoc(doc(dbFor(INVITE_SHOP_OWNER_UID), linkPath), linkDoc(INVITE_CUSTOMER_UID)),
    );
  });

  test('他人になりすました紐づけは拒否される', async () => {
    await assertFails(
      setDoc(doc(dbFor(OTHER_UID), linkPath), linkDoc(INVITE_CUSTOMER_UID)),
    );
  });

  test('本人は自分の紐づけを読める', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), linkPath), linkDoc(INVITE_CUSTOMER_UID));
    });
    await assertSucceeds(getDoc(doc(dbFor(INVITE_CUSTOMER_UID), linkPath)));
  });

  test('紐づいた店は自分の顧客を読める', async () => {
    await seedInvite();
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), linkPath), linkDoc(INVITE_CUSTOMER_UID));
    });
    await assertSucceeds(getDoc(doc(dbFor(INVITE_SHOP_OWNER_UID), linkPath)));
  });

  test('無関係の第三者は読めない', async () => {
    await seedInvite();
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), linkPath), linkDoc(INVITE_CUSTOMER_UID));
    });
    await assertFails(getDoc(doc(dbFor(OTHER_UID), linkPath)));
  });

  test('本人は自分の紐づけを外せる', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), linkPath), linkDoc(INVITE_CUSTOMER_UID));
    });
    await assertSucceeds(deleteDoc(doc(dbFor(INVITE_CUSTOMER_UID), linkPath)));
  });

  test('店が顧客の紐づけを外すことはできない', async () => {
    await seedInvite();
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), linkPath), linkDoc(INVITE_CUSTOMER_UID));
    });
    await assertFails(deleteDoc(doc(dbFor(INVITE_SHOP_OWNER_UID), linkPath)));
  });

  test('店は自分の shopId で顧客を一覧できる', async () => {
    await seedInvite();
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), linkPath), linkDoc(INVITE_CUSTOMER_UID));
    });
    const q = query(
      collection(dbFor(INVITE_SHOP_OWNER_UID), 'shop_customers'),
      where('shopId', '==', INVITE_SHOP_ID),
    );
    await assertSucceeds(getDocs(q));
  });

  test('他店の顧客名簿は一覧できない', async () => {
    await seedInvite();
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), linkPath), linkDoc(INVITE_CUSTOMER_UID));
    });
    const q = query(
      collection(dbFor(OTHER_UID), 'shop_customers'),
      where('shopId', '==', INVITE_SHOP_ID),
    );
    await assertFails(getDocs(q));
  });

  test('絞り込みなしで全店の顧客を一覧することはできない', async () => {
    await seedInvite();
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), linkPath), linkDoc(INVITE_CUSTOMER_UID));
    });
    await assertFails(getDocs(collection(dbFor(OTHER_UID), 'shop_customers')));
  });

  // 車検満了日の共有（案A）。
  // docs/BUSINESS_MODEL_RETHINK_2026-08-27.md §6-2。
  // 店に vehicles を開けず、顧客が満了日だけを置く形にしてある。
  // ここが緩むと、この文書が名簿の代わりになってしまう。
  describe('車検満了日の共有', () => {
    test('本人は満了日を置ける', async () => {
      await assertSucceeds(
        setDoc(
          doc(dbFor(INVITE_CUSTOMER_UID), linkPath),
          linkDoc(INVITE_CUSTOMER_UID, {
            inspectionExpiries: [new Date('2026-11-20')],
            vehicleCount: 2,
            sharesInspectionExpiry: true,
          }),
        ),
      );
    });

    test('紐づいた店は満了日を読める', async () => {
      await seedInvite();
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await setDoc(
          doc(ctx.firestore(), linkPath),
          linkDoc(INVITE_CUSTOMER_UID, {
            inspectionExpiries: [new Date('2026-11-20')],
            vehicleCount: 1,
          }),
        );
      });
      await assertSucceeds(getDoc(doc(dbFor(INVITE_SHOP_OWNER_UID), linkPath)));
    });

    test('店が顧客の満了日を書き換えることはできない', async () => {
      // 書けると、店が「まだ先」に書き換えて取りこぼしを隠せてしまう。
      await seedInvite();
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await setDoc(doc(ctx.firestore(), linkPath), linkDoc(INVITE_CUSTOMER_UID));
      });
      await assertFails(
        updateDoc(doc(dbFor(INVITE_SHOP_OWNER_UID), linkPath), {
          inspectionExpiries: [new Date('2027-01-01')],
        }),
      );
    });

    test('満了日を大量に詰め込むことはできない', async () => {
      const many = Array.from({ length: 21 }, () => new Date('2026-11-20'));
      await assertFails(
        setDoc(
          doc(dbFor(INVITE_CUSTOMER_UID), linkPath),
          linkDoc(INVITE_CUSTOMER_UID, { inspectionExpiries: many }),
        ),
      );
    });

    test('満了日が配列でなければ拒否される', async () => {
      await assertFails(
        setDoc(
          doc(dbFor(INVITE_CUSTOMER_UID), linkPath),
          linkDoc(INVITE_CUSTOMER_UID, { inspectionExpiries: '2026-11-20' }),
        ),
      );
    });

    test('あり得ない台数は拒否される', async () => {
      await assertFails(
        setDoc(
          doc(dbFor(INVITE_CUSTOMER_UID), linkPath),
          linkDoc(INVITE_CUSTOMER_UID, { vehicleCount: 1000 }),
        ),
      );
    });

    test('共有フラグが真偽値でなければ拒否される', async () => {
      await assertFails(
        setDoc(
          doc(dbFor(INVITE_CUSTOMER_UID), linkPath),
          linkDoc(INVITE_CUSTOMER_UID, { sharesInspectionExpiry: 'yes' }),
        ),
      );
    });

    test('本人は共有を切れる', async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await setDoc(
          doc(ctx.firestore(), linkPath),
          linkDoc(INVITE_CUSTOMER_UID, {
            inspectionExpiries: [new Date('2026-11-20')],
            vehicleCount: 1,
          }),
        );
      });
      await assertSucceeds(
        updateDoc(doc(dbFor(INVITE_CUSTOMER_UID), linkPath), {
          sharesInspectionExpiry: false,
          inspectionExpiries: [],
          vehicleCount: 0,
        }),
      );
    });
  });
});

describe('fuel_records（給油記録）', () => {
  const fuelPath = 'fuel_records/f1';

  test('本人は自分の記録を作れる', async () => {
    await assertSucceeds(
      setDoc(doc(dbFor(INVITE_CUSTOMER_UID), fuelPath), fuelDoc(INVITE_CUSTOMER_UID)),
    );
  });

  test('他人の userId を詐称した作成は拒否される', async () => {
    await assertFails(
      setDoc(doc(dbFor(OTHER_UID), fuelPath), fuelDoc(INVITE_CUSTOMER_UID)),
    );
  });

  test('給油量0は拒否される', async () => {
    await assertFails(
      setDoc(
        doc(dbFor(INVITE_CUSTOMER_UID), fuelPath),
        fuelDoc(INVITE_CUSTOMER_UID, { liters: 0 }),
      ),
    );
  });

  test('あり得ない給油量は拒否される', async () => {
    await assertFails(
      setDoc(
        doc(dbFor(INVITE_CUSTOMER_UID), fuelPath),
        fuelDoc(INVITE_CUSTOMER_UID, { liters: 9999 }),
      ),
    );
  });

  test('負の金額は拒否される', async () => {
    await assertFails(
      setDoc(
        doc(dbFor(INVITE_CUSTOMER_UID), fuelPath),
        fuelDoc(INVITE_CUSTOMER_UID, { cost: -1 }),
      ),
    );
  });

  test('本人は自分の記録を読める', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), fuelPath), fuelDoc(INVITE_CUSTOMER_UID));
    });
    await assertSucceeds(getDoc(doc(dbFor(INVITE_CUSTOMER_UID), fuelPath)));
  });

  test('店にも見せない（燃費や行動が読めてしまう）', async () => {
    await seedInvite();
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), fuelPath), fuelDoc(INVITE_CUSTOMER_UID));
    });
    await assertFails(getDoc(doc(dbFor(INVITE_SHOP_OWNER_UID), fuelPath)));
  });

  test('他人は消せない', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), fuelPath), fuelDoc(INVITE_CUSTOMER_UID));
    });
    await assertFails(deleteDoc(doc(dbFor(OTHER_UID), fuelPath)));
  });
});

// ---------------------------------------------------------------------------
// shop_inquiry_demands — 店舗オーナーの一覧クエリ
//
// ルールは read を resource.data.userId == uid || resource.data.shopOwnerId == uid
// に絞る。Firestore は list クエリがこの条件を満たすことを静的に証明できないと
// 丸ごと拒否するので、shopId だけで絞った旧クエリは本番で 1 件も返らない
// （fake_cloud_firestore はルールを見ないため単体テストは緑だった）。
// ここで「旧形は弾かれ、shopOwnerId を足した形は通る」を固定する。
// ---------------------------------------------------------------------------
describe('shop_inquiry_demands — 店舗オーナーの一覧', () => {
  const DEMAND_SHOP_ID = 'shop_demand_1';
  const DEMAND_OWNER_UID = 'demand_shop_owner_uid';
  const DEMAND_USER_UID = 'demand_customer_uid';

  async function seedDemands() {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, `shops/${DEMAND_SHOP_ID}`), {
        name: '店', ownerId: DEMAND_OWNER_UID,
      });
      await setDoc(doc(db, 'shop_inquiry_demands/d1'), {
        shopId: DEMAND_SHOP_ID,
        shopOwnerId: DEMAND_OWNER_UID,
        userId: DEMAND_USER_UID,
        type: 'estimate',
        subject: 'タイヤ交換',
        createdAt: new Date('2026-09-01'),
      });
      await setDoc(doc(db, 'shop_inquiry_demands/d2'), {
        shopId: DEMAND_SHOP_ID,
        shopOwnerId: DEMAND_OWNER_UID,
        userId: OTHER_UID,
        type: 'estimate',
        subject: 'オイル交換',
        createdAt: new Date('2026-09-02'),
      });
    });
  }

  // 2026-09-29: 店主かどうかは、需要データに写した shopOwnerId ではなく
  // 店の ownerId で決める（引き継ぎ後に前の店主が読めないように）。
  test('shopId だけで絞っても、いまの店主なら読める', async () => {
    await seedDemands();
    const q = query(
      collection(dbFor(DEMAND_OWNER_UID), 'shop_inquiry_demands'),
      where('shopId', '==', DEMAND_SHOP_ID),
    );
    await assertSucceeds(getDocs(q));
  });

  test('店主でない人は shopId で絞っても読めない', async () => {
    await seedDemands();
    const q = query(
      collection(dbFor(OTHER_UID), 'shop_inquiry_demands'),
      where('shopId', '==', DEMAND_SHOP_ID),
    );
    await assertFails(getDocs(q));
  });

  test('shopId + 自分の shopOwnerId で絞れば、オーナーは読める', async () => {
    await seedDemands();
    const q = query(
      collection(dbFor(DEMAND_OWNER_UID), 'shop_inquiry_demands'),
      where('shopId', '==', DEMAND_SHOP_ID),
      where('shopOwnerId', '==', DEMAND_OWNER_UID),
    );
    const snap = await assertSucceeds(getDocs(q));
    expect(snap.size).toBe(2);
  });

  test('他人が shopOwnerId を偽っても読めない', async () => {
    await seedDemands();
    const q = query(
      collection(dbFor(OTHER_UID), 'shop_inquiry_demands'),
      where('shopId', '==', DEMAND_SHOP_ID),
      where('shopOwnerId', '==', DEMAND_OWNER_UID),
    );
    await assertFails(getDocs(q));
  });

  test('未認証は読めない', async () => {
    await seedDemands();
    const q = query(
      collection(unauthDb(), 'shop_inquiry_demands'),
      where('shopId', '==', DEMAND_SHOP_ID),
      where('shopOwnerId', '==', DEMAND_OWNER_UID),
    );
    await assertFails(getDocs(q));
  });
});

// ---------------------------------------------------------------------------
// faqs / faq_answers / faq_helpful_votes（Issue #191）
// FaqService の読み書きが本番ルールで通ることを固定する。
// ---------------------------------------------------------------------------
describe('faqs — 質問', () => {
  const FAQ_AUTHOR = 'faq_author_uid';
  const faqPath = 'faqs/faq_1';
  const faqDoc = (overrides = {}) => ({
    question: 'オイル交換の目安は？',
    category: 'maintenance',
    authorId: FAQ_AUTHOR,
    createdAt: new Date('2026-09-01'),
    viewCount: 0,
    answerCount: 0,
    allowShopResponse: true,
    tags: [],
    ...overrides,
  });
  async function seedFaq(overrides = {}) {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), faqPath), faqDoc(overrides));
    });
  }

  test('未認証は読めない', async () => {
    await seedFaq();
    await assertFails(getDoc(doc(unauthDb(), faqPath)));
  });

  test('認証済みなら誰でも読める・一覧できる', async () => {
    await seedFaq();
    await assertSucceeds(getDoc(doc(dbFor(OTHER_UID), faqPath)));
    await assertSucceeds(
      getDocs(query(collection(dbFor(OTHER_UID), 'faqs'), where('category', '==', 'maintenance'))),
    );
  });

  test('本人名義でカウンタ 0 なら作れる', async () => {
    await assertSucceeds(setDoc(doc(dbFor(FAQ_AUTHOR), faqPath), faqDoc()));
  });

  test('他人名義では作れない', async () => {
    await assertFails(setDoc(doc(dbFor(OTHER_UID), faqPath), faqDoc()));
  });

  test('カウンタを 0 以外で作れない', async () => {
    await assertFails(
      setDoc(doc(dbFor(FAQ_AUTHOR), faqPath), faqDoc({ viewCount: 5 })),
    );
  });

  test('本人は本文を直せるが、authorId は変えられない', async () => {
    await seedFaq();
    await assertSucceeds(
      updateDoc(doc(dbFor(FAQ_AUTHOR), faqPath), { question: '直した質問' }),
    );
    await assertFails(
      updateDoc(doc(dbFor(FAQ_AUTHOR), faqPath), { authorId: OTHER_UID }),
    );
  });

  test('他人は本文を直せない', async () => {
    await seedFaq();
    await assertFails(
      updateDoc(doc(dbFor(OTHER_UID), faqPath), { question: '乗っ取り' }),
    );
  });

  test('誰でも閲覧数・回答数は +1 だけできる', async () => {
    await seedFaq();
    await assertSucceeds(updateDoc(doc(dbFor(OTHER_UID), faqPath), { viewCount: 1 }));
    await assertSucceeds(updateDoc(doc(dbFor(OTHER_UID), faqPath), { answerCount: 1 }));
    await assertFails(updateDoc(doc(dbFor(OTHER_UID), faqPath), { viewCount: 10 }));
  });

  test('本人だけが消せる', async () => {
    await seedFaq();
    await assertFails(deleteDoc(doc(dbFor(OTHER_UID), faqPath)));
    await assertSucceeds(deleteDoc(doc(dbFor(FAQ_AUTHOR), faqPath)));
  });
});

describe('faq_answers / faq_helpful_votes — 回答と投票', () => {
  const FAQ_AUTHOR = 'faq_author_uid';
  const ANSWERER = 'faq_answerer_uid';
  const faqPath = 'faqs/faq_1';
  const answerPath = 'faq_answers/ans_1';
  const answerDoc = (overrides = {}) => ({
    faqId: 'faq_1',
    content: '5,000km か半年が目安です',
    authorId: ANSWERER,
    isShopResponse: false,
    helpfulCount: 0,
    isBestAnswer: false,
    createdAt: new Date('2026-09-02'),
    ...overrides,
  });
  async function seed({ answer = true } = {}) {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, faqPath), {
        question: 'オイル交換の目安は？',
        category: 'maintenance',
        authorId: FAQ_AUTHOR,
        createdAt: new Date('2026-09-01'),
        viewCount: 0,
        answerCount: 0,
        allowShopResponse: true,
        tags: [],
      });
      if (answer) await setDoc(doc(db, answerPath), answerDoc());
    });
  }

  test('本人名義・初期値なら回答を作れる', async () => {
    await seed({ answer: false });
    await assertSucceeds(setDoc(doc(dbFor(ANSWERER), answerPath), answerDoc()));
  });

  test('isBestAnswer=true や helpfulCount>0 では作れない', async () => {
    await seed({ answer: false });
    await assertFails(
      setDoc(doc(dbFor(ANSWERER), answerPath), answerDoc({ isBestAnswer: true })),
    );
    await assertFails(
      setDoc(doc(dbFor(ANSWERER), answerPath), answerDoc({ helpfulCount: 3 })),
    );
  });

  test('getAnswers のクエリ（faqId 絞り込み）は認証済みなら通る', async () => {
    await seed();
    const snap = await assertSucceeds(
      getDocs(query(collection(dbFor(OTHER_UID), 'faq_answers'), where('faqId', '==', 'faq_1'))),
    );
    expect(snap.size).toBe(1);
  });

  test('ベストアンサーは質問の作者だけが選べる', async () => {
    await seed();
    await assertFails(
      updateDoc(doc(dbFor(ANSWERER), answerPath), { isBestAnswer: true }),
    );
    await assertFails(
      updateDoc(doc(dbFor(OTHER_UID), answerPath), { isBestAnswer: true }),
    );
    await assertSucceeds(
      updateDoc(doc(dbFor(FAQ_AUTHOR), answerPath), { isBestAnswer: true }),
    );
  });

  test('「役に立った」は誰でも +1 だけ', async () => {
    await seed();
    await assertSucceeds(updateDoc(doc(dbFor(OTHER_UID), answerPath), { helpfulCount: 1 }));
    await assertFails(updateDoc(doc(dbFor(OTHER_UID), answerPath), { helpfulCount: 3 }));
    await assertFails(updateDoc(doc(dbFor(OTHER_UID), answerPath), { content: '改ざん' }));
  });

  test('投票マーカーは <answerId>_<uid> の ID で本人だけが作れる', async () => {
    await seed();
    const votePath = `faq_helpful_votes/ans_1_${OTHER_UID}`;
    await assertSucceeds(
      setDoc(doc(dbFor(OTHER_UID), votePath), {
        answerId: 'ans_1',
        userId: OTHER_UID,
        faqId: 'faq_1',
        createdAt: new Date(),
      }),
    );
    // 他人の名義や、ID の形が違うものは作れない
    await assertFails(
      setDoc(doc(dbFor(OTHER_UID), `faq_helpful_votes/ans_1_${ANSWERER}`), {
        answerId: 'ans_1',
        userId: ANSWERER,
        faqId: 'faq_1',
        createdAt: new Date(),
      }),
    );
    await assertFails(
      setDoc(doc(dbFor(OTHER_UID), 'faq_helpful_votes/free_form_id'), {
        answerId: 'ans_1',
        userId: OTHER_UID,
        faqId: 'faq_1',
        createdAt: new Date(),
      }),
    );
  });

  test('回答は本人だけが消せる', async () => {
    await seed();
    await assertFails(deleteDoc(doc(dbFor(OTHER_UID), answerPath)));
    await assertSucceeds(deleteDoc(doc(dbFor(ANSWERER), answerPath)));
  });
});

// ===========================================================================
// maintenance_records の検証フィールド（「工場裏書き」バッジの根拠）
//
// 画面は `record.isVerified` で「工場裏書き」バッジを出している
// （vehicle_detail_screen.dart:2186）。その根拠は次の2つ:
//
//   verificationSource = 'shopVerified'（明示）
//   inquiryId != null                  → getter が shopImported に導出
//
// **どちらもユーザー自身が書けてしまうと、バッジは何も保証しない。**
// 2026-09-22 時点のルールは `allow update, delete: if isDocumentOwner();`
// だけで、検証フィールドを一切守っていなかった。
//
// 査定に使える記録にするには「工場を通ったものだけが裏書きされる」ことが
// 要る。ここはその境界を固定するテスト。
// ===========================================================================

const MR_USER_UID = 'mr_user_001';
const MR_SHOP_UID = 'mr_shop_002';
const MR_RECORD_ID = 'mr_record_1';
const MR_INQUIRY_ID = 'mr_inquiry_1';
const mrPath = `maintenance_records/${MR_RECORD_ID}`;

function mrDoc(extra = {}) {
  return {
    vehicleId: 'veh_1',
    userId: MR_USER_UID,
    type: 'oilChange',
    title: 'エンジンオイル交換',
    cost: 6000,
    date: new Date('2026-09-01'),
    createdAt: new Date('2026-09-01'),
    ...extra,
  };
}

/** ルール無効の管理コンテキストで、当事者付きの問い合わせを置く。 */
async function seedInquiryFor(uid, shopId = MR_SHOP_UID) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), `inquiries/${MR_INQUIRY_ID}`), {
      userId: uid,
      shopId,
      type: 'estimate',
      status: 'replied',
      subject: '車検見積もり',
      initialMessage: 'お願いします',
    });
  });
}

/** ルール無効で記録を置く。 */
async function seedRecord(extra = {}) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), mrPath), mrDoc(extra));
  });
}

describe('maintenance_records — 自己申告の記録', () => {
  test('自分の記録は作れる', async () => {
    await assertSucceeds(setDoc(doc(dbFor(MR_USER_UID), mrPath), mrDoc()));
  });

  test('他人名義の記録は作れない', async () => {
    await assertFails(
      setDoc(doc(dbFor(MR_USER_UID), mrPath), mrDoc({ userId: 'someone_else' })),
    );
  });

  test('自分の記録は直せる（費用の打ち間違いなど）', async () => {
    await seedRecord();
    await assertSucceeds(
      updateDoc(doc(dbFor(MR_USER_UID), mrPath), { cost: 6500 }),
    );
  });
});

describe('maintenance_records — 裏書きの偽装を止める', () => {
  test('自分で shopVerified を名乗る記録は作れない', async () => {
    await assertFails(
      setDoc(
        doc(dbFor(MR_USER_UID), mrPath),
        mrDoc({ verificationSource: 'shopVerified' }),
      ),
    );
  });

  test('自分で verifiedByShopId を書いた記録は作れない', async () => {
    await assertFails(
      setDoc(
        doc(dbFor(MR_USER_UID), mrPath),
        mrDoc({ verifiedByShopId: MR_SHOP_UID, verifiedAt: new Date() }),
      ),
    );
  });

  test('あとから shopVerified に書き換えることはできない', async () => {
    await seedRecord();
    await assertFails(
      updateDoc(doc(dbFor(MR_USER_UID), mrPath), {
        verificationSource: 'shopVerified',
      }),
    );
  });

  test('あとから verifiedByShopId を足すことはできない', async () => {
    await seedRecord();
    await assertFails(
      updateDoc(doc(dbFor(MR_USER_UID), mrPath), {
        verifiedByShopId: MR_SHOP_UID,
      }),
    );
  });

  test('当事者でない問い合わせIDを付けて裏書きを装うことはできない', async () => {
    // 他人のスレッドのIDを借りてくる形。これが通ると inquiryId 由来の
    // shopImported が自作できてしまう。
    await seedInquiryFor('someone_else');
    await assertFails(
      setDoc(
        doc(dbFor(MR_USER_UID), mrPath),
        mrDoc({ inquiryId: MR_INQUIRY_ID }),
      ),
    );
  });
});

describe('maintenance_records — 工場を通った記録', () => {
  test('自分が当事者の問い合わせからなら取り込める', async () => {
    await seedInquiryFor(MR_USER_UID);
    await assertSucceeds(
      setDoc(
        doc(dbFor(MR_USER_UID), mrPath),
        mrDoc({ inquiryId: MR_INQUIRY_ID }),
      ),
    );
  });

  test('取り込んだ記録の出所は、あとから消せない', async () => {
    await seedInquiryFor(MR_USER_UID);
    await seedRecord({ inquiryId: MR_INQUIRY_ID });

    // 不都合な記録の出所だけ消して「自己申告」に見せかける、を止める。
    await assertFails(
      updateDoc(doc(dbFor(MR_USER_UID), mrPath), { inquiryId: null }),
    );
  });

  test('取り込んだ記録でも、削除は本人ができる', async () => {
    await seedInquiryFor(MR_USER_UID);
    await seedRecord({ inquiryId: MR_INQUIRY_ID });
    await assertSucceeds(deleteDoc(doc(dbFor(MR_USER_UID), mrPath)));
  });
});

// ==================== 店の顧客台帳 ====================
// docs/SHOP_CRM_DESIGN_2026-09-27.md
// 店のスタッフだけが読み書きできる。ここが緩むと、何千人分の名簿が漏れる。

const LEDGER_SHOP_ID = 'takaya_ledger';
const LEDGER_OWNER_UID = 'ledger_owner_1';
const LEDGER_STAFF_UID = 'ledger_staff_2';
const LEDGER_OUTSIDER_UID = 'ledger_outsider_3';
const LEDGER_APP_USER_UID = 'ledger_app_user_4';
const ledgerCustomerPath = `shops/${LEDGER_SHOP_ID}/customers/c1`;
const ledgerVehiclePath = `shops/${LEDGER_SHOP_ID}/customer_vehicles/v1`;

const ledgerCustomer = (overrides = {}) => ({
  kind: 'individual',
  name: '山田太郎',
  searchKey: 'やまだたろう',
  isLinked: false,
  linkedUserId: null,
  vehicleCount: 0,
  ...overrides,
});

const ledgerVehicle = (overrides = {}) => ({
  customerId: 'c1',
  customerName: '山田太郎',
  maker: 'MINI',
  model: 'クーパー',
  ...overrides,
});

async function seedLedgerShop() {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    // シードの店は docId が店主の uid ではない（タカヤがそう）
    await setDoc(doc(db, `shops/${LEDGER_SHOP_ID}`), {
      name: 'タカヤモーター',
      ownerId: LEDGER_OWNER_UID,
    });
    await setDoc(doc(db, `shops/${LEDGER_SHOP_ID}/members/${LEDGER_STAFF_UID}`), {
      role: 'staff',
    });
  });
}

async function seedLedgerCustomer(overrides = {}) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), ledgerCustomerPath), ledgerCustomer(overrides));
  });
}

describe('shops/{id}/customers — 顧客台帳', () => {
  test('店主は顧客を登録できる（docId が uid でない店でも）', async () => {
    await seedLedgerShop();
    await assertSucceeds(
      setDoc(doc(dbFor(LEDGER_OWNER_UID), ledgerCustomerPath), ledgerCustomer()),
    );
  });

  test('スタッフも登録・閲覧できる', async () => {
    await seedLedgerShop();
    await assertSucceeds(
      setDoc(doc(dbFor(LEDGER_STAFF_UID), ledgerCustomerPath), ledgerCustomer()),
    );
    await assertSucceeds(getDoc(doc(dbFor(LEDGER_STAFF_UID), ledgerCustomerPath)));
  });

  test('店と無関係の人は読めない', async () => {
    await seedLedgerShop();
    await seedLedgerCustomer();
    await assertFails(getDoc(doc(dbFor(LEDGER_OUTSIDER_UID), ledgerCustomerPath)));
  });

  test('店と無関係の人は一覧も件数も取れない', async () => {
    await seedLedgerShop();
    await seedLedgerCustomer();
    await assertFails(
      getDocs(collection(dbFor(LEDGER_OUTSIDER_UID), `shops/${LEDGER_SHOP_ID}/customers`)),
    );
  });

  test('スタッフは一覧できる', async () => {
    await seedLedgerShop();
    await seedLedgerCustomer();
    await assertSucceeds(
      getDocs(collection(dbFor(LEDGER_STAFF_UID), `shops/${LEDGER_SHOP_ID}/customers`)),
    );
  });

  test('未認証では読めない', async () => {
    await seedLedgerShop();
    await seedLedgerCustomer();
    await assertFails(getDoc(doc(unauthDb(), ledgerCustomerPath)));
  });

  test('無関係の人は書けない', async () => {
    await seedLedgerShop();
    await assertFails(
      setDoc(doc(dbFor(LEDGER_OUTSIDER_UID), ledgerCustomerPath), ledgerCustomer()),
    );
  });

  test('名前が空の顧客は登録できない', async () => {
    await seedLedgerShop();
    await assertFails(
      setDoc(doc(dbFor(LEDGER_OWNER_UID), ledgerCustomerPath), ledgerCustomer({ name: '' })),
    );
  });

  test('知らない区分は登録できない', async () => {
    await seedLedgerShop();
    await assertFails(
      setDoc(doc(dbFor(LEDGER_OWNER_UID), ledgerCustomerPath), ledgerCustomer({ kind: 'vip' })),
    );
  });

  test('アプリ利用者とのつながりを、店が勝手に名乗ることはできない', async () => {
    await seedLedgerShop();
    await assertFails(
      setDoc(
        doc(dbFor(LEDGER_OWNER_UID), ledgerCustomerPath),
        ledgerCustomer({ linkedUserId: LEDGER_APP_USER_UID, isLinked: true }),
      ),
    );
  });

  test('その人がこの店のかかりつけ札を置いていれば、つなげられる', async () => {
    await seedLedgerShop();
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `shop_customers/${LEDGER_APP_USER_UID}`), {
        shopId: LEDGER_SHOP_ID,
        userId: LEDGER_APP_USER_UID,
      });
    });
    await assertSucceeds(
      setDoc(
        doc(dbFor(LEDGER_OWNER_UID), ledgerCustomerPath),
        ledgerCustomer({ linkedUserId: LEDGER_APP_USER_UID, isLinked: true }),
      ),
    );
  });

  test('他店の札では、つなげられない', async () => {
    await seedLedgerShop();
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `shop_customers/${LEDGER_APP_USER_UID}`), {
        shopId: 'other_shop',
        userId: LEDGER_APP_USER_UID,
      });
    });
    await assertFails(
      setDoc(
        doc(dbFor(LEDGER_OWNER_UID), ledgerCustomerPath),
        ledgerCustomer({ linkedUserId: LEDGER_APP_USER_UID, isLinked: true }),
      ),
    );
  });

  test('isLinked だけ立てて、つながっているように見せることはできない', async () => {
    await seedLedgerShop();
    await assertFails(
      setDoc(
        doc(dbFor(LEDGER_OWNER_UID), ledgerCustomerPath),
        ledgerCustomer({ isLinked: true }),
      ),
    );
  });

  test('スタッフは顧客を消せる。無関係の人は消せない', async () => {
    await seedLedgerShop();
    await seedLedgerCustomer();
    await assertFails(deleteDoc(doc(dbFor(LEDGER_OUTSIDER_UID), ledgerCustomerPath)));
    await assertSucceeds(deleteDoc(doc(dbFor(LEDGER_STAFF_UID), ledgerCustomerPath)));
  });
});

describe('shops/{id}/customer_vehicles — 台帳の車両', () => {
  test('スタッフは車両を登録・一覧できる', async () => {
    await seedLedgerShop();
    await assertSucceeds(
      setDoc(doc(dbFor(LEDGER_STAFF_UID), ledgerVehiclePath), ledgerVehicle()),
    );
    await assertSucceeds(
      getDocs(collection(dbFor(LEDGER_STAFF_UID), `shops/${LEDGER_SHOP_ID}/customer_vehicles`)),
    );
  });

  test('無関係の人は読めない', async () => {
    await seedLedgerShop();
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), ledgerVehiclePath), ledgerVehicle());
    });
    await assertFails(getDoc(doc(dbFor(LEDGER_OUTSIDER_UID), ledgerVehiclePath)));
  });

  test('車種が空の車両は登録できない', async () => {
    await seedLedgerShop();
    await assertFails(
      setDoc(doc(dbFor(LEDGER_OWNER_UID), ledgerVehiclePath), ledgerVehicle({ model: '' })),
    );
  });

  // 車検案内の宛名を書き出したときに、案内した日を付ける（2026-09-30）
  describe('案内した日', () => {
    async function seedVehicle() {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await setDoc(doc(ctx.firestore(), ledgerVehiclePath), ledgerVehicle());
      });
    }

    test('スタッフは案内した日を付けられる', async () => {
      await seedLedgerShop();
      await seedVehicle();
      await assertSucceeds(
        updateDoc(doc(dbFor(LEDGER_STAFF_UID), ledgerVehiclePath), {
          inspectionNoticeAt: new Date('2026-09-30'),
          inspectionNoticeExpiry: new Date('2026-11-05'),
        }),
      );
    });

    test('満了日の無い車には、満了日なし（null）で付けられる', async () => {
      await seedLedgerShop();
      await seedVehicle();
      await assertSucceeds(
        updateDoc(doc(dbFor(LEDGER_OWNER_UID), ledgerVehiclePath), {
          inspectionNoticeAt: new Date('2026-09-30'),
          inspectionNoticeExpiry: null,
        }),
      );
    });

    test('店の外の人は付けられない', async () => {
      await seedLedgerShop();
      await seedVehicle();
      await assertFails(
        updateDoc(doc(dbFor(LEDGER_OUTSIDER_UID), ledgerVehiclePath), {
          inspectionNoticeAt: new Date('2026-09-30'),
        }),
      );
    });

    test('日付でない値は入れられない', async () => {
      await seedLedgerShop();
      await seedVehicle();
      await assertFails(
        updateDoc(doc(dbFor(LEDGER_STAFF_UID), ledgerVehiclePath), {
          inspectionNoticeAt: '2026-09-30',
        }),
      );
      await assertFails(
        updateDoc(doc(dbFor(LEDGER_STAFF_UID), ledgerVehiclePath), {
          inspectionNoticeAt: new Date('2026-09-30'),
          inspectionNoticeExpiry: 'いつか',
        }),
      );
    });
  });
});

describe('shops/{id}/members — スタッフ', () => {
  const staffPath = (uid) => `shops/${LEDGER_SHOP_ID}/members/${uid}`;

  test('店主はスタッフを追加できる', async () => {
    await seedLedgerShop();
    await assertSucceeds(
      setDoc(doc(dbFor(LEDGER_OWNER_UID), staffPath('new_staff')), { role: 'staff' }),
    );
  });

  test('スタッフは他のスタッフを追加できない（店主だけ）', async () => {
    await seedLedgerShop();
    await assertFails(
      setDoc(doc(dbFor(LEDGER_STAFF_UID), staffPath('new_staff')), { role: 'staff' }),
    );
  });

  test('自分で自分をスタッフにすることはできない', async () => {
    await seedLedgerShop();
    await assertFails(
      setDoc(doc(dbFor(LEDGER_OUTSIDER_UID), staffPath(LEDGER_OUTSIDER_UID)), { role: 'staff' }),
    );
  });

  test('知らない役割は付けられない', async () => {
    await seedLedgerShop();
    await assertFails(
      setDoc(doc(dbFor(LEDGER_OWNER_UID), staffPath('new_staff')), { role: 'admin' }),
    );
  });

  test('スタッフは自分で抜けられる', async () => {
    await seedLedgerShop();
    await assertSucceeds(deleteDoc(doc(dbFor(LEDGER_STAFF_UID), staffPath(LEDGER_STAFF_UID))));
  });

  test('無関係の人はスタッフ一覧を見られない', async () => {
    await seedLedgerShop();
    await assertFails(
      getDocs(collection(dbFor(LEDGER_OUTSIDER_UID), `shops/${LEDGER_SHOP_ID}/members`)),
    );
  });
});

// ==================== 店に渡す車の写し ====================
// docs/SHOP_CRM_DESIGN_2026-09-27.md §7

describe('shops/{id}/shared_vehicles — 車の写し', () => {
  const OWNER = 'share_owner_1';
  const VEHICLE = 'share_vehicle_1';
  const sharePath = `shops/${LEDGER_SHOP_ID}/shared_vehicles/${VEHICLE}`;

  const shareDoc = (overrides = {}) => ({
    vehicleId: VEHICLE,
    shopId: LEDGER_SHOP_ID,
    shopName: 'タカヤモーター',
    ownerId: OWNER,
    maker: 'MINI',
    model: 'クーパー',
    records: [],
    includesCosts: false,
    sharedAt: new Date(),
    expiresAt: new Date(Date.now() + 30 * 24 * 3600 * 1000),
    ...overrides,
  });

  async function seedVehicleAndShop() {
    await seedLedgerShop();
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `vehicles/${VEHICLE}`), {
        userId: OWNER,
        maker: 'MINI',
        model: 'クーパー',
      });
    });
  }

  async function seedShare(overrides = {}) {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), sharePath), shareDoc(overrides));
    });
  }

  test('本人は自分の車を店に渡せる', async () => {
    await seedVehicleAndShop();
    await assertSucceeds(setDoc(doc(dbFor(OWNER), sharePath), shareDoc()));
  });

  test('他人の車は渡せない', async () => {
    await seedVehicleAndShop();
    await assertFails(
      setDoc(doc(dbFor(LEDGER_OUTSIDER_UID), sharePath),
        shareDoc({ ownerId: LEDGER_OUTSIDER_UID })),
    );
  });

  test('91日を超える期間では渡せない', async () => {
    await seedVehicleAndShop();
    await assertFails(
      setDoc(doc(dbFor(OWNER), sharePath),
        shareDoc({ expiresAt: new Date(Date.now() + 120 * 24 * 3600 * 1000) })),
    );
  });

  test('記録が201件以上なら渡せない', async () => {
    await seedVehicleAndShop();
    const records = Array.from({ length: 201 }, () => ({ title: 'x' }));
    await assertFails(setDoc(doc(dbFor(OWNER), sharePath), shareDoc({ records })));
  });

  test('店のスタッフは読める・無関係の人は読めない', async () => {
    await seedVehicleAndShop();
    await seedShare();
    await assertSucceeds(getDoc(doc(dbFor(LEDGER_STAFF_UID), sharePath)));
    await assertFails(getDoc(doc(dbFor(LEDGER_OUTSIDER_UID), sharePath)));
  });

  test('店は「開いた」「登録した」の印だけ付けられる', async () => {
    await seedVehicleAndShop();
    await seedShare();
    await assertSucceeds(
      updateDoc(doc(dbFor(LEDGER_STAFF_UID), sharePath), {
        seenAt: new Date(),
        importedCustomerId: 'c1',
      }),
    );
  });

  test('店が写しの中身を書き換えることはできない', async () => {
    await seedVehicleAndShop();
    await seedShare();
    await assertFails(
      updateDoc(doc(dbFor(LEDGER_STAFF_UID), sharePath), { model: '改ざん' }),
    );
  });

  test('本人はいつでも取り消せる', async () => {
    await seedVehicleAndShop();
    await seedShare();
    await assertSucceeds(deleteDoc(doc(dbFor(OWNER), sharePath)));
  });

  test('無関係の人は消せない', async () => {
    await seedVehicleAndShop();
    await seedShare();
    await assertFails(deleteDoc(doc(dbFor(LEDGER_OUTSIDER_UID), sharePath)));
  });
});

describe('model_cost_reports — 車種別の維持費レポート', () => {
  const path = 'model_cost_reports/mini__くーぱー';

  test('ログインしていれば読める', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), path), { ownerCount: 5 });
    });
    await assertSucceeds(getDoc(doc(dbFor(LEDGER_OUTSIDER_UID), path)));
  });

  test('未認証では読めない', async () => {
    await assertFails(getDoc(doc(unauthDb(), path)));
  });

  test('誰も書けない（数字を作れてしまう）', async () => {
    await assertFails(setDoc(doc(dbFor(LEDGER_OWNER_UID), path), { ownerCount: 999 }));
  });
});

describe('shops/{id}/service_records — 店の整備実績', () => {
  const path = `shops/${LEDGER_SHOP_ID}/service_records/r1`;
  const rec = (o = {}) => ({
    customerVehicleId: 'v1',
    date: new Date(),
    totalCost: 55000,
    type: '車検',
    ...o,
  });

  test('スタッフは書ける・読める', async () => {
    await seedLedgerShop();
    await assertSucceeds(setDoc(doc(dbFor(LEDGER_STAFF_UID), path), rec()));
    await assertSucceeds(getDoc(doc(dbFor(LEDGER_STAFF_UID), path)));
  });

  test('無関係の人は読めない', async () => {
    await seedLedgerShop();
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), path), rec());
    });
    await assertFails(getDoc(doc(dbFor(LEDGER_OUTSIDER_UID), path)));
  });

  test('マイナスの金額は書けない', async () => {
    await seedLedgerShop();
    await assertFails(setDoc(doc(dbFor(LEDGER_OWNER_UID), path), rec({ totalCost: -1 })));
  });
});

// ==================== アプリが実際に書く形 ====================
// MaintenanceRecord.toMap() は verificationSource を**常に**書く
// （自己申告なら 'selfReported'、問い合わせ経由なら 'shopImported'）。
// 2026-09-22 のルールは「この項目を持っていたら拒否」だったため、
// デプロイするとアプリからの追加・編集がすべて拒否されるところだった。

describe('maintenance_records — アプリが実際に書く形', () => {
  const appDoc = (extra = {}) =>
    mrDoc({ verificationSource: 'selfReported', workItems: [], parts: [], ...extra });

  test('自己申告の記録を、アプリの形のまま追加できる', async () => {
    await assertSucceeds(setDoc(doc(dbFor(MR_USER_UID), mrPath), appDoc()));
  });

  test('問い合わせ経由の記録を、アプリの形のまま取り込める', async () => {
    await seedInquiryFor(MR_USER_UID);
    await assertSucceeds(
      setDoc(
        doc(dbFor(MR_USER_UID), mrPath),
        appDoc({ inquiryId: MR_INQUIRY_ID, verificationSource: 'shopImported' }),
      ),
    );
  });

  test('問い合わせ無しで shopImported を名乗ることはできない', async () => {
    await assertFails(
      setDoc(doc(dbFor(MR_USER_UID), mrPath), appDoc({ verificationSource: 'shopImported' })),
    );
  });

  test('自己申告の記録は、アプリの形のまま直せる（費用も）', async () => {
    await seedRecord({ verificationSource: 'selfReported' });
    await assertSucceeds(
      setDoc(doc(dbFor(MR_USER_UID), mrPath), appDoc({ cost: 7000 })),
    );
  });

  test('項目の無い古い記録も、アプリの形で直せる', async () => {
    await seedRecord();
    await assertSucceeds(
      setDoc(doc(dbFor(MR_USER_UID), mrPath), appDoc({ cost: 7000 })),
    );
  });

  test('自己申告の記録を、あとから shopImported に書き換えることはできない', async () => {
    await seedRecord({ verificationSource: 'selfReported' });
    await assertFails(
      updateDoc(doc(dbFor(MR_USER_UID), mrPath), { verificationSource: 'shopImported' }),
    );
  });

  describe('工場から受け取った記録', () => {
    const imported = () => ({
      inquiryId: MR_INQUIRY_ID,
      verificationSource: 'shopImported',
      workItems: [{ name: 'オイル交換', laborCost: 2000 }],
      parts: [],
      laborCost: 2000,
    });

    test('金額は書き換えられない（出所の印を残したまま中身を変えさせない）', async () => {
      await seedInquiryFor(MR_USER_UID);
      await seedRecord(imported());
      await assertFails(updateDoc(doc(dbFor(MR_USER_UID), mrPath), { cost: 1 }));
    });

    test('日付・内容・内訳も書き換えられない', async () => {
      await seedInquiryFor(MR_USER_UID);
      await seedRecord(imported());
      for (const change of [
        { date: new Date('2020-01-01') },
        { title: '別の作業' },
        { workItems: [] },
        { laborCost: 0 },
        { mileageAtService: 1 },
      ]) {
        await assertFails(updateDoc(doc(dbFor(MR_USER_UID), mrPath), change));
      }
    });

    test('メモと写真は足せる', async () => {
      await seedInquiryFor(MR_USER_UID);
      await seedRecord(imported());
      await assertSucceeds(
        updateDoc(doc(dbFor(MR_USER_UID), mrPath), {
          description: '次回はタイヤも見てもらう',
          imageUrls: ['https://example.com/a.jpg'],
        }),
      );
    });

    test('工場の印（shopVerified）が付いた記録も、金額は書き換えられない', async () => {
      await seedRecord({
        verificationSource: 'shopVerified',
        verifiedByShopId: MR_SHOP_UID,
        verifiedAt: new Date(),
      });
      await assertFails(updateDoc(doc(dbFor(MR_USER_UID), mrPath), { cost: 1 }));
      await assertSucceeds(
        updateDoc(doc(dbFor(MR_USER_UID), mrPath), { description: 'メモ' }),
      );
    });
  });
});

describe('vehicle_profiles — 愛車ページ', () => {
  const OWNER = 'vp_owner';
  const VID = 'vp_vehicle';
  const path = `vehicle_profiles/${VID}`;
  const profile = (o = {}) => ({
    vehicleId: VID,
    ownerId: OWNER,
    ownerName: 'みにお',
    maker: 'MINI',
    model: 'クーパー',
    isPublic: true,
    showsMaintenance: false,
    maintenance: [],
    updatedAt: new Date(),
    ...o,
  });
  async function seedVehicle() {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `vehicles/${VID}`), { userId: OWNER, maker: 'MINI', model: 'クーパー' });
    });
  }
  async function seedProfile(o = {}) {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), path), profile(o));
    });
  }

  test('本人は自分の車のページを作れる', async () => {
    await seedVehicle();
    await assertSucceeds(setDoc(doc(dbFor(OWNER), path), profile()));
  });

  test('他人の車のページは作れない', async () => {
    await seedVehicle();
    await assertFails(setDoc(doc(dbFor(OTHER_UID), path), profile({ ownerId: OTHER_UID })));
  });

  test('走行距離やナンバーは載せられない', async () => {
    await seedVehicle();
    await assertFails(setDoc(doc(dbFor(OWNER), path), profile({ mileage: 48000 })));
    await assertFails(setDoc(doc(dbFor(OWNER), path), profile({ licensePlate: '品川300あ1' })));
  });

  test('整備を出さないと決めたのに、中身を載せることはできない', async () => {
    await seedVehicle();
    await assertFails(
      setDoc(doc(dbFor(OWNER), path), profile({ maintenance: [{ type: '車検', count: 1 }] })),
    );
  });

  test('公開していれば他人も読める。非公開なら本人だけ', async () => {
    await seedVehicle();
    await seedProfile();
    await assertSucceeds(getDoc(doc(dbFor(OTHER_UID), path)));
    await seedProfile({ isPublic: false });
    await assertFails(getDoc(doc(dbFor(OTHER_UID), path)));
    await assertSucceeds(getDoc(doc(dbFor(OWNER), path)));
  });

  test('他人は消せない', async () => {
    await seedVehicle();
    await seedProfile();
    await assertFails(deleteDoc(doc(dbFor(OTHER_UID), path)));
  });
});

describe('スタッフの招待と参加', () => {
  const CODE = 'ABC234';
  const invitePath = `shop_staff_invites/${CODE}`;
  const NEW_STAFF = 'new_staff_9';
  const memberPath = `shops/${LEDGER_SHOP_ID}/members/${NEW_STAFF}`;
  const linkPath = `shop_staff/${NEW_STAFF}`;
  const inFuture = () => new Date(Date.now() + 3 * 24 * 3600 * 1000);

  async function seedStaffInvite(o = {}) {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), invitePath), {
        shopId: LEDGER_SHOP_ID,
        shopName: 'タカヤモーター',
        expiresAt: inFuture(),
        usedBy: null,
        ...o,
      });
    });
  }

  async function join(uid) {
    const db = dbFor(uid);
    const { writeBatch } = require('firebase/firestore');
    const batch = writeBatch(db);
    batch.update(doc(db, invitePath), { usedBy: uid, usedAt: new Date() });
    batch.set(doc(db, `shops/${LEDGER_SHOP_ID}/members/${uid}`), {
      role: 'staff', displayName: 'スタッフ', inviteCode: CODE, addedAt: new Date(),
    });
    batch.set(doc(db, `shop_staff/${uid}`), { shopId: LEDGER_SHOP_ID, shopName: 'タカヤモーター' });
    return batch.commit();
  }

  test('店主はコードを発行できる。スタッフは発行できない', async () => {
    await seedLedgerShop();
    const data = { shopId: LEDGER_SHOP_ID, shopName: 'x', expiresAt: inFuture(), usedBy: null };
    await assertSucceeds(setDoc(doc(dbFor(LEDGER_OWNER_UID), invitePath), data));
    await assertFails(setDoc(doc(dbFor(LEDGER_STAFF_UID), 'shop_staff_invites/XYZ789'), data));
  });

  test('コードを入れると、名簿と札が一度に書ける', async () => {
    await seedLedgerShop();
    await seedStaffInvite();
    await assertSucceeds(join(NEW_STAFF));
    // 入ったあとは台帳が読める
    await assertSucceeds(getDocs(collection(dbFor(NEW_STAFF), `shops/${LEDGER_SHOP_ID}/customers`)));
  });

  test('使用済みのコードでは入れない', async () => {
    await seedLedgerShop();
    await seedStaffInvite({ usedBy: 'someone' });
    await assertFails(join(NEW_STAFF));
  });

  test('期限切れのコードでは入れない', async () => {
    await seedLedgerShop();
    await seedStaffInvite({ expiresAt: new Date(Date.now() - 1000) });
    await assertFails(join(NEW_STAFF));
  });

  test('コードなしで自分を名簿に載せることはできない', async () => {
    await seedLedgerShop();
    await assertFails(
      setDoc(doc(dbFor(NEW_STAFF), memberPath), { role: 'staff', inviteCode: 'NOPE00' }),
    );
  });

  test('コードで入っても owner にはなれない', async () => {
    await seedLedgerShop();
    await seedStaffInvite();
    const db = dbFor(NEW_STAFF);
    const { writeBatch } = require('firebase/firestore');
    const batch = writeBatch(db);
    batch.update(doc(db, invitePath), { usedBy: NEW_STAFF, usedAt: new Date() });
    batch.set(doc(db, memberPath), { role: 'owner', inviteCode: CODE });
    await assertFails(batch.commit());
  });

  test('名簿に載っていないのに札だけ作ることはできない', async () => {
    await seedLedgerShop();
    await assertFails(
      setDoc(doc(dbFor(NEW_STAFF), linkPath), { shopId: LEDGER_SHOP_ID, shopName: 'x' }),
    );
  });

  test('店主はスタッフの札を消せる（外すとき）', async () => {
    await seedLedgerShop();
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), linkPath), { shopId: LEDGER_SHOP_ID });
    });
    await assertSucceeds(deleteDoc(doc(dbFor(LEDGER_OWNER_UID), linkPath)));
  });

  test('他人の札は読めない', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), linkPath), { shopId: LEDGER_SHOP_ID });
    });
    await assertFails(getDoc(doc(dbFor(OTHER_UID), linkPath)));
  });
});

describe('台帳の顧客とアプリの利用者をつなぐ', () => {
  const SHOP = 'shop_owner_link';
  const APP_USER = 'app_user_link';
  const CODE = 'CUS234';
  const linkPath = `shop_customers/${APP_USER}`;

  async function seed({ customerId = 'c1' } = {}) {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, `shops/${SHOP}`), { name: '店', ownerId: SHOP });
      await setDoc(doc(db, `shop_invites/${CODE}`), {
        shopId: SHOP, shopName: '店', shopOwnerId: SHOP,
        isActive: true, usedCount: 0, createdAt: new Date(), customerId,
      });
    });
  }
  const link = (o = {}) => ({
    shopId: SHOP, shopName: '店', userId: APP_USER, linkedAt: new Date(),
    customerId: 'c1', inviteCode: CODE, ...o,
  });

  test('その顧客宛ての招待を使えば、札に顧客IDを書ける', async () => {
    await seed();
    await assertSucceeds(setDoc(doc(dbFor(APP_USER), linkPath), link()));
  });

  test('招待と違う顧客IDを名乗ることはできない（別人の明細を受け取らせない）', async () => {
    await seed();
    await assertFails(setDoc(doc(dbFor(APP_USER), linkPath), link({ customerId: 'c999' })));
  });

  test('招待コードなしに顧客IDだけ書くことはできない', async () => {
    await seed();
    await assertFails(
      setDoc(doc(dbFor(APP_USER), linkPath), link({ inviteCode: null })),
    );
  });

  test('顧客IDの無い札は、これまでどおり作れる', async () => {
    await seed();
    await assertSucceeds(
      setDoc(doc(dbFor(APP_USER), linkPath), link({ customerId: null, inviteCode: null })),
    );
  });

  const inquiry = (o = {}) => ({
    userId: APP_USER, shopId: SHOP, type: 'general', status: 'pending',
    subject: '整備明細のお届け', initialMessage: 'x', openedByShop: true,
    createdAt: new Date(), updatedAt: new Date(), ...o,
  });

  test('つながったお客さんには、店からスレッドを開ける', async () => {
    await seed();
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), linkPath), link());
    });
    await assertSucceeds(setDoc(doc(dbFor(SHOP), 'inquiries/i1'), inquiry()));
  });

  test('つながっていない人には、店から話しかけられない', async () => {
    await seed();
    await assertFails(setDoc(doc(dbFor(SHOP), 'inquiries/i1'), inquiry()));
  });

  test('他店のお客さんには、店から話しかけられない', async () => {
    await seed();
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), linkPath), link({ shopId: 'other_shop' }));
    });
    await assertFails(setDoc(doc(dbFor(SHOP), 'inquiries/i1'), inquiry()));
  });
});

describe('vehicle_follows — 愛車ページのフォロー', () => {
  const OWNER = 'vf_owner';
  const VID = 'vf_vehicle';
  const FAN = 'vf_fan';
  async function seedProfile(isPublic = true) {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `vehicle_profiles/${VID}`), {
        vehicleId: VID, ownerId: OWNER, isPublic, maintenance: [],
      });
    });
  }
  const follow = (uid) => ({ uid, vehicleId: VID, ownerId: OWNER, createdAt: new Date() });

  test('公開中のページはフォローできる', async () => {
    await seedProfile();
    await assertSucceeds(setDoc(doc(dbFor(FAN), `vehicle_follows/${FAN}_${VID}`), follow(FAN)));
  });

  test('非公開のページはフォローできない', async () => {
    await seedProfile(false);
    await assertFails(setDoc(doc(dbFor(FAN), `vehicle_follows/${FAN}_${VID}`), follow(FAN)));
  });

  test('自分の車はフォローできない', async () => {
    await seedProfile();
    await assertFails(setDoc(doc(dbFor(OWNER), `vehicle_follows/${OWNER}_${VID}`), follow(OWNER)));
  });

  test('他人の名前でフォローすることはできない', async () => {
    await seedProfile();
    await assertFails(setDoc(doc(dbFor(OTHER_UID), `vehicle_follows/${FAN}_${VID}`), follow(FAN)));
  });

  test('やめられるのは本人だけ', async () => {
    await seedProfile();
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `vehicle_follows/${FAN}_${VID}`), follow(FAN));
    });
    await assertFails(deleteDoc(doc(dbFor(OTHER_UID), `vehicle_follows/${FAN}_${VID}`)));
    await assertSucceeds(deleteDoc(doc(dbFor(FAN), `vehicle_follows/${FAN}_${VID}`)));
  });

  test('同じ車種の公開ページを一覧できる（非公開は条件に入れないと拒否）', async () => {
    await seedProfile();
    const { query: q, where: w } = require('firebase/firestore');
    await assertSucceeds(getDocs(q(collection(dbFor(FAN), 'vehicle_profiles'),
      w('isPublic', '==', true), w('modelKey', '==', 'くーぱー'))));
    await assertFails(getDocs(q(collection(dbFor(FAN), 'vehicle_profiles'),
      w('modelKey', '==', 'くーぱー'))));
  });
});

describe('スタッフも明細を送れる（2026-09-28）', () => {
  const SHOP = 'shop_owner_staffsend';
  const STAFF = 'staff_send_1';
  const APP_USER = 'app_user_staffsend';
  const inqPath = 'inquiries/staff_i1';

  async function seed() {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, `shops/${SHOP}`), { name: '店', ownerId: SHOP });
      await setDoc(doc(db, `shops/${SHOP}/members/${STAFF}`), { role: 'staff' });
      await setDoc(doc(db, `shop_customers/${APP_USER}`), { shopId: SHOP, userId: APP_USER });
    });
  }
  const inquiry = () => ({
    userId: APP_USER, shopId: SHOP, type: 'general', status: 'pending',
    subject: '整備明細のお届け', initialMessage: 'x', openedByShop: true,
    createdAt: new Date(), updatedAt: new Date(),
  });

  test('スタッフは、つながったお客さんへのスレッドを開ける', async () => {
    await seed();
    await assertSucceeds(setDoc(doc(dbFor(STAFF), inqPath), inquiry()));
  });

  test('スタッフは明細のメッセージを送れ、読める', async () => {
    await seed();
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), inqPath), inquiry());
    });
    await assertSucceeds(setDoc(doc(dbFor(STAFF), `${inqPath}/messages/m1`), {
      senderId: STAFF, isFromShop: true, content: '明細', sentAt: new Date(), isRead: false,
    }));
    await assertSucceeds(getDocs(collection(dbFor(STAFF), `${inqPath}/messages`)));
    await assertSucceeds(getDoc(doc(dbFor(STAFF), inqPath)));
  });

  test('スタッフは札を読め、つながった顧客を探せる', async () => {
    await seed();
    await assertSucceeds(getDoc(doc(dbFor(STAFF), `shop_customers/${APP_USER}`)));
    const { query: q, where: w } = require('firebase/firestore');
    await assertSucceeds(getDocs(q(collection(dbFor(STAFF), 'shop_customers'), w('shopId', '==', SHOP))));
  });

  test('スタッフは顧客専用コードを発行できる', async () => {
    await seed();
    await assertSucceeds(setDoc(doc(dbFor(STAFF), 'shop_invites/STF234'), {
      shopId: SHOP, shopName: '店', shopOwnerId: SHOP, usedCount: 0, isActive: true,
      createdAt: new Date(), customerId: 'c1',
    }));
  });

  test('店と無関係の人は、スレッドも札も触れない', async () => {
    await seed();
    await assertFails(setDoc(doc(dbFor(OTHER_UID), inqPath), inquiry()));
    await assertFails(getDoc(doc(dbFor(OTHER_UID), `shop_customers/${APP_USER}`)));
  });

  test('スタッフが問い合わせを使って、自分の記録に工場の印を付けることはできない', async () => {
    await seed();
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), inqPath), inquiry());
    });
    await assertFails(setDoc(doc(dbFor(STAFF), 'maintenance_records/fake'), {
      vehicleId: 'v', userId: STAFF, type: 'oilChange', title: 'x', cost: 1,
      date: new Date(), createdAt: new Date(),
      inquiryId: 'staff_i1', verificationSource: 'shopImported',
    }));
  });
});

describe('shops/{id}/audit_logs — 操作の記録', () => {
  const path = `shops/${LEDGER_SHOP_ID}/audit_logs/l1`;
  const log = (uid, o = {}) => ({
    actorUid: uid, actorName: 'x', action: 'viewCustomer', targetId: 'c1', at: new Date(), ...o,
  });
  async function seedLog() {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), path), log(LEDGER_STAFF_UID));
    });
  }

  test('スタッフは自分の名前で記録できる', async () => {
    await seedLedgerShop();
    await assertSucceeds(setDoc(doc(dbFor(LEDGER_STAFF_UID), path), log(LEDGER_STAFF_UID)));
  });

  test('他人の名前では記録できない', async () => {
    await seedLedgerShop();
    await assertFails(setDoc(doc(dbFor(LEDGER_STAFF_UID), path), log(LEDGER_OWNER_UID)));
  });

  test('店と無関係の人は記録できない', async () => {
    await seedLedgerShop();
    await assertFails(setDoc(doc(dbFor(LEDGER_OUTSIDER_UID), path), log(LEDGER_OUTSIDER_UID)));
  });

  test('読めるのは店主だけ（スタッフは読めない）', async () => {
    await seedLedgerShop();
    await seedLog();
    await assertSucceeds(getDoc(doc(dbFor(LEDGER_OWNER_UID), path)));
    await assertFails(getDoc(doc(dbFor(LEDGER_STAFF_UID), path)));
  });

  test('店主でも書き換え・削除はできない', async () => {
    await seedLedgerShop();
    await seedLog();
    await assertFails(updateDoc(doc(dbFor(LEDGER_OWNER_UID), path), { action: 'x' }));
    await assertFails(deleteDoc(doc(dbFor(LEDGER_OWNER_UID), path)));
    await assertFails(deleteDoc(doc(dbFor(LEDGER_STAFF_UID), path)));
  });

  test('決まった項目以外は書けない', async () => {
    await seedLedgerShop();
    await assertFails(setDoc(doc(dbFor(LEDGER_STAFF_UID), path), log(LEDGER_STAFF_UID, { extra: 1 })));
  });
});

// ==================== 店主の引き継ぎ（2026-09-29） ====================
// 店のドキュメントIDは最初の店主の uid のまま。引き継いだあとは、
// **ドキュメントIDと同じ uid の前の店主**が店主として振る舞えてはいけない。

describe('店主の引き継ぎ', () => {
  const OLD = 'old_owner';   // = 店のドキュメントID
  const NEW = 'new_owner';
  const SHOP_PATH = `shops/${OLD}`;

  async function seedTransferred() {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, SHOP_PATH), { name: '店', ownerId: NEW });
      await setDoc(doc(db, `${SHOP_PATH}/members/${NEW}`), { role: 'owner' });
      await setDoc(doc(db, 'inquiries/tr1'), {
        userId: 'cust', shopId: OLD, type: 'general', status: 'pending',
        subject: 'x', initialMessage: 'x',
      });
      await setDoc(doc(db, `${SHOP_PATH}/private/p1`), { revenue: 1 });
    });
  }

  test('店主は、スタッフ名簿に載っている人にだけ店を渡せる', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, SHOP_PATH), { name: '店', ownerId: OLD });
      await setDoc(doc(db, `${SHOP_PATH}/members/${NEW}`), { role: 'staff' });
    });
    await assertFails(updateDoc(doc(dbFor(OLD), SHOP_PATH), { ownerId: 'stranger' }));
    await assertSucceeds(updateDoc(doc(dbFor(OLD), SHOP_PATH), { ownerId: NEW }));
  });

  test('引き継いだあと、前の店主は問い合わせ・非公開の情報を読めない', async () => {
    await seedTransferred();
    await assertFails(getDoc(doc(dbFor(OLD), 'inquiries/tr1')));
    await assertFails(getDoc(doc(dbFor(OLD), `${SHOP_PATH}/private/p1`)));
  });

  test('引き継いだあと、新しい店主は読める', async () => {
    await seedTransferred();
    await assertSucceeds(getDoc(doc(dbFor(NEW), 'inquiries/tr1')));
    await assertSucceeds(getDoc(doc(dbFor(NEW), `${SHOP_PATH}/private/p1`)));
  });

  test('引き継いだあと、前の店主は店として招待・メニュー・ニュースレターを出せない', async () => {
    await seedTransferred();
    await assertFails(setDoc(doc(dbFor(OLD), 'shop_invites/OLD234'), {
      shopId: OLD, shopName: '店', shopOwnerId: OLD, usedCount: 0, isActive: true,
      createdAt: new Date(),
    }));
    await assertFails(setDoc(doc(dbFor(OLD), 'service_menus/m1'), { shopId: OLD, name: '車検' }));
    await assertFails(setDoc(doc(dbFor(OLD), 'newsletters/n1'), {
      authorId: OLD, status: 'draft', title: 'x',
    }));
  });

  test('新しい店主は、店として招待・メニュー・ニュースレターを出せる', async () => {
    await seedTransferred();
    await assertSucceeds(setDoc(doc(dbFor(NEW), 'shop_invites/NEW234'), {
      shopId: OLD, shopName: '店', shopOwnerId: NEW, usedCount: 0, isActive: true,
      createdAt: new Date(),
    }));
    await assertSucceeds(setDoc(doc(dbFor(NEW), 'service_menus/m2'), { shopId: OLD, name: '車検' }));
    await assertSucceeds(setDoc(doc(dbFor(NEW), 'newsletters/n2'), {
      authorId: OLD, status: 'draft', title: 'x',
    }));
  });

  test('個人のニュースレター（店でない書き手）は、これまでどおり本人だけ', async () => {
    await assertSucceeds(setDoc(doc(dbFor('person1'), 'newsletters/n3'), {
      authorId: 'person1', status: 'draft', title: 'x',
    }));
    await assertFails(setDoc(doc(dbFor('person2'), 'newsletters/n4'), {
      authorId: 'person1', status: 'draft', title: 'x',
    }));
  });
});


describe('店主の引き継ぎ（アプリが実際に書く形）', () => {
  const OLD = 'old_owner2';
  const NEW = 'new_owner2';
  const SHOP_PATH = `shops/${OLD}`;

  async function seed() {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, SHOP_PATH), { name: '店', ownerId: OLD });
      await setDoc(doc(db, `${SHOP_PATH}/members/${NEW}`), { role: 'staff', displayName: '佐藤' });
      await setDoc(doc(db, `shop_staff/${NEW}`), { shopId: OLD, shopName: '店' });
    });
  }

  function transfer(uid) {
    const { writeBatch } = require('firebase/firestore');
    const db = dbFor(uid);
    const b = writeBatch(db);
    b.update(doc(db, SHOP_PATH), { ownerId: NEW, updatedAt: new Date() });
    b.update(doc(db, `${SHOP_PATH}/members/${NEW}`), { role: 'owner' });
    b.set(doc(db, `${SHOP_PATH}/members/${OLD}`), { role: 'staff', displayName: '前', addedAt: new Date() });
    b.set(doc(db, `shop_staff/${OLD}`), { shopId: OLD, shopName: '店' });
    b.delete(doc(db, `shop_staff/${NEW}`));
    return b.commit();
  }

  test('店主は、1回の書き込みで引き継げる', async () => {
    await seed();
    await assertSucceeds(transfer(OLD));
  });

  test('スタッフが勝手に引き継ぎを書くことはできない', async () => {
    await seed();
    await assertFails(transfer(NEW));
  });
});

// ==================== 店舗プランの申し込み（請求書払い・2026-09-30） ====================
// 店舗プランは当面、請求書払い（銀行振込）。アプリは申し込みを置くだけで、
// プランの切り替え（planType・subscriptionStatus）は運営者がサーバ側で行う。

describe('shops/{id}/plan_requests — 請求書払いの申し込み', () => {
  const { serverTimestamp, addDoc } = require('firebase/firestore');
  const SHOP = 'plan_shop';
  const OWNER = 'plan_owner';
  const STAFF = 'plan_staff';
  const OTHER_SHOP_OWNER = 'plan_other_owner';
  const reqPath = `shops/${SHOP}/plan_requests/r1`;

  const planRequest = (o = {}) => ({
    plan: 'standard',
    currentPlan: 'free',
    requesterUid: OWNER,
    contactEmail: 'shop@example.com',
    billingName: '株式会社タカヤモーター',
    status: 'pending',
    createdAt: serverTimestamp(),
    ...o,
  });

  async function seed({ planType = 'free' } = {}) {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, `shops/${SHOP}`), {
        name: '店',
        ownerId: OWNER,
        planType,
        subscriptionStatus: planType === 'free' ? 'free' : 'active',
      });
      await setDoc(doc(db, `shops/${SHOP}/members/${STAFF}`), { role: 'staff' });
      await setDoc(doc(db, `shops/${OTHER_SHOP_OWNER}`), { name: '他店', ownerId: OTHER_SHOP_OWNER });
    });
  }

  async function seedRequest() {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), reqPath), { ...planRequest(), createdAt: new Date() });
    });
  }

  test('店主は受付中の申し込みを作れる', async () => {
    await seed();
    await assertSucceeds(setDoc(doc(dbFor(OWNER), reqPath), planRequest()));
  });

  test('アプリが書く形（add・ご要望つき）で作れる', async () => {
    await seed();
    await assertSucceeds(addDoc(collection(dbFor(OWNER), `shops/${SHOP}/plan_requests`),
      planRequest({ note: '来月からお願いします' })));
  });

  test('エンタープライズの見積もり相談・フリーへの変更も同じ形で作れる', async () => {
    await seed({ planType: 'standard' });
    await assertSucceeds(setDoc(doc(dbFor(OWNER), reqPath),
      planRequest({ plan: 'enterprise', currentPlan: 'standard' })));
    await assertSucceeds(setDoc(doc(dbFor(OWNER), `shops/${SHOP}/plan_requests/r2`),
      planRequest({ plan: 'free', currentPlan: 'standard' })));
  });

  test('スタッフは申し込めない（契約は店主が結ぶ）', async () => {
    await seed();
    await assertFails(setDoc(doc(dbFor(STAFF), reqPath), planRequest({ requesterUid: STAFF })));
  });

  test('他店の店主は申し込めない', async () => {
    await seed();
    await assertFails(setDoc(doc(dbFor(OTHER_SHOP_OWNER), reqPath),
      planRequest({ requesterUid: OTHER_SHOP_OWNER })));
  });

  test('未ログインでは申し込めない', async () => {
    await seed();
    await assertFails(setDoc(doc(unauthDb(), reqPath), planRequest()));
  });

  test('申込者を他人の名前にはできない', async () => {
    await seed();
    await assertFails(setDoc(doc(dbFor(OWNER), reqPath), planRequest({ requesterUid: STAFF })));
  });

  test('受付中（pending）以外の状態では作れない', async () => {
    await seed();
    for (const status of ['completed', 'approved', 'cancelled']) {
      await assertFails(setDoc(doc(dbFor(OWNER), reqPath), planRequest({ status })));
    }
  });

  test('申込日時はサーバの時刻だけ', async () => {
    await seed();
    await assertFails(setDoc(doc(dbFor(OWNER), reqPath),
      planRequest({ createdAt: new Date('2020-01-01') })));
  });

  test('知らないプラン・いまと同じプランは申し込めない', async () => {
    await seed();
    await assertFails(setDoc(doc(dbFor(OWNER), reqPath), planRequest({ plan: 'platinum' })));
    await assertFails(setDoc(doc(dbFor(OWNER), reqPath), planRequest({ plan: 'free' })));
  });

  test('いまのプラン（currentPlan）は店のドキュメントと一致していること', async () => {
    await seed({ planType: 'standard' });
    await assertFails(setDoc(doc(dbFor(OWNER), reqPath),
      planRequest({ plan: 'premium', currentPlan: 'free' })));
  });

  test('メールアドレス・宛名の形を確かめる', async () => {
    await seed();
    await assertFails(setDoc(doc(dbFor(OWNER), reqPath), planRequest({ contactEmail: 'shop' })));
    await assertFails(setDoc(doc(dbFor(OWNER), reqPath), planRequest({ contactEmail: '' })));
    await assertFails(setDoc(doc(dbFor(OWNER), reqPath), planRequest({ billingName: '' })));
    await assertFails(setDoc(doc(dbFor(OWNER), reqPath), planRequest({ billingName: 'あ'.repeat(101) })));
    await assertSucceeds(setDoc(doc(dbFor(OWNER), reqPath), planRequest({ billingName: 'あ'.repeat(100) })));
  });

  test('ご要望は1000文字まで', async () => {
    await seed();
    await assertFails(setDoc(doc(dbFor(OWNER), reqPath), planRequest({ note: 'あ'.repeat(1001) })));
  });

  test('決まった項目以外は書けない（プランの有効化などを混ぜられない）', async () => {
    await seed();
    await assertFails(setDoc(doc(dbFor(OWNER), reqPath), planRequest({ subscriptionStatus: 'active' })));
  });

  test('店主は自分の店の申し込みを読める（1件・一覧）', async () => {
    await seed();
    await seedRequest();
    await assertSucceeds(getDoc(doc(dbFor(OWNER), reqPath)));
    await assertSucceeds(getDocs(query(
      collection(dbFor(OWNER), `shops/${SHOP}/plan_requests`),
      where('status', '==', 'pending'),
    )));
  });

  test('スタッフ・他店・未ログインは読めない', async () => {
    await seed();
    await seedRequest();
    await assertFails(getDoc(doc(dbFor(STAFF), reqPath)));
    await assertFails(getDoc(doc(dbFor(OTHER_SHOP_OWNER), reqPath)));
    await assertFails(getDocs(collection(dbFor(OTHER_SHOP_OWNER), `shops/${SHOP}/plan_requests`)));
    await assertFails(getDoc(doc(unauthDb(), reqPath)));
  });

  test('作ったあとは店主でも書き換え・削除できない', async () => {
    await seed();
    await seedRequest();
    await assertFails(updateDoc(doc(dbFor(OWNER), reqPath), { status: 'completed' }));
    await assertFails(updateDoc(doc(dbFor(OWNER), reqPath), { plan: 'premium' }));
    await assertFails(setDoc(doc(dbFor(OWNER), reqPath), planRequest({ plan: 'premium' })));
    await assertFails(deleteDoc(doc(dbFor(OWNER), reqPath)));
  });
});

describe('shops — プランは店主でも書けない（請求書払いの切り替えは運営者）', () => {
  const OWNER = 'billing_owner';
  const SHOP_PATH = `shops/${OWNER}`;

  async function seedShop(o = {}) {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), SHOP_PATH), {
        name: '店',
        ownerId: OWNER,
        planType: 'free',
        subscriptionStatus: 'free',
        planExpiresAt: null,
        ...o,
      });
    });
  }

  test('店主は店の名前などはこれまでどおり直せる', async () => {
    await seedShop();
    await assertSucceeds(updateDoc(doc(dbFor(OWNER), SHOP_PATH), { name: '新しい店名' }));
  });

  test('店主でも planType を書き換えられない', async () => {
    await seedShop();
    await assertFails(updateDoc(doc(dbFor(OWNER), SHOP_PATH), { planType: 'premium' }));
  });

  test('店主でも planExpiresAt・subscriptionStatus を書き換えられない', async () => {
    await seedShop();
    await assertFails(updateDoc(doc(dbFor(OWNER), SHOP_PATH), { planExpiresAt: new Date('2030-01-01') }));
    await assertFails(updateDoc(doc(dbFor(OWNER), SHOP_PATH), { subscriptionStatus: 'active' }));
  });

  test('有料プランの店でも、プランの値を変えなければ他の項目は直せる', async () => {
    await seedShop({ planType: 'premium', subscriptionStatus: 'active' });
    await assertSucceeds(updateDoc(doc(dbFor(OWNER), SHOP_PATH), {
      name: '新しい店名', planType: 'premium', subscriptionStatus: 'active',
    }));
  });

  test('作るときに有料プラン・有効を名乗れない', async () => {
    const db = dbFor(OWNER);
    await assertFails(setDoc(doc(db, SHOP_PATH), { name: '店', ownerId: OWNER, planType: 'premium' }));
    await assertFails(setDoc(doc(db, SHOP_PATH), {
      name: '店', ownerId: OWNER, planType: 'free', subscriptionStatus: 'active',
    }));
    await assertFails(setDoc(doc(db, SHOP_PATH), {
      name: '店', ownerId: OWNER, planType: 'free', planExpiresAt: new Date('2030-01-01'),
    }));
  });

  test('アプリが書く形（フリー・期限なし）なら作れる', async () => {
    await assertSucceeds(setDoc(doc(dbFor(OWNER), SHOP_PATH), {
      name: '店',
      ownerId: OWNER,
      planType: 'free',
      subscriptionStatus: 'free',
      planExpiresAt: null,
      revenueCatUserId: null,
      trialStartedAt: null,
    }));
  });

  test('プランの項目を書かずに作っても良い（既定はフリー）', async () => {
    await assertSucceeds(setDoc(doc(dbFor(OWNER), SHOP_PATH), { name: '店', ownerId: OWNER }));
  });
});

// ===========================================================================
// Issue #192 — 本番ルールで弾かれるクエリ（残り）
//
// fake_cloud_firestore はルールを評価しないので、Dart の単体テストは緑の
// まま本番で permission-denied になる。ここで「アプリと同じ形のクエリ」を
// 本物のルール越しに投げて固定する。
// ===========================================================================

describe('fleet_maintenance_summaries — 法人の整備集計（Issue #192）', () => {
  // 法人（フリート）の管理者 = vehicles.companyId に書かれた uid
  // （fleet_service.dart / vehicles のルールと同じ定義）
  const ADMIN = 'fleet_admin_uid';
  const MEMBER = 'fleet_member_uid';
  const OTHER_ADMIN = 'other_fleet_admin_uid';
  const STRANGER = 'fleet_stranger_uid';
  const MEMBER_CAR = 'fleet_car_member';
  const OTHER_FLEET_CAR = 'fleet_car_other_company';
  const PRIVATE_CAR = 'fleet_car_private';

  function summary(vehicleId, ownerId, extra = {}) {
    return {
      vehicleId,
      ownerId,
      lastMaintenanceDate: new Date('2026-09-01'),
      totalCost: 12000,
      recordCount: 2,
      updatedAt: new Date('2026-09-02'),
      ...extra,
    };
  }

  async function seedFleet() {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      // メンバーの車（ADMIN の法人に入っている）
      await setDoc(doc(db, `vehicles/${MEMBER_CAR}`), {
        userId: MEMBER, companyId: ADMIN, maker: 'トヨタ', model: 'ハイエース',
      });
      // 別の法人の車
      await setDoc(doc(db, `vehicles/${OTHER_FLEET_CAR}`), {
        userId: 'other_member_uid', companyId: OTHER_ADMIN, maker: '日産', model: 'キャラバン',
      });
      // どの法人にも入っていない個人の車
      await setDoc(doc(db, `vehicles/${PRIVATE_CAR}`), {
        userId: MEMBER, companyId: null, maker: 'ホンダ', model: 'N-BOX',
      });
      // 生の整備記録（メモ・店名など、集計に要らない項目を含む）
      await setDoc(doc(db, 'maintenance_records/fleet_mr_1'), {
        userId: MEMBER, vehicleId: MEMBER_CAR, type: 'oilChange',
        title: 'オイル交換', cost: 5000, date: new Date('2026-08-01'),
        notes: '私的なメモ', shopName: '近所の店',
      });
      await setDoc(doc(db, `fleet_maintenance_summaries/${MEMBER_CAR}`),
        summary(MEMBER_CAR, MEMBER));
      await setDoc(doc(db, `fleet_maintenance_summaries/${OTHER_FLEET_CAR}`),
        summary(OTHER_FLEET_CAR, 'other_member_uid'));
      await setDoc(doc(db, `fleet_maintenance_summaries/${PRIVATE_CAR}`),
        summary(PRIVATE_CAR, MEMBER));
    });
  }

  function summariesIn(uid, ids) {
    return getDocs(query(
      collection(dbFor(uid), 'fleet_maintenance_summaries'),
      where(documentId(), 'in', ids),
    ));
  }

  // --- 以前の形（maintenance_records を直接引く）は本番で通らない ---

  test('以前の形: 管理者が vehicleId だけで maintenance_records を引くと拒否される', async () => {
    await seedFleet();
    await assertFails(getDocs(query(
      collection(dbFor(ADMIN), 'maintenance_records'),
      where('vehicleId', 'in', [MEMBER_CAR]),
    )));
  });

  test('以前の形: 管理者がメンバーの userId で maintenance_records を引いても拒否される（生の記録は本人だけ）', async () => {
    await seedFleet();
    await assertFails(getDocs(query(
      collection(dbFor(ADMIN), 'maintenance_records'),
      where('userId', '==', MEMBER),
      where('vehicleId', 'in', [MEMBER_CAR]),
    )));
  });

  test('以前の形: 管理者自身の userId で引くと通るが、メンバーの車の記録は0件', async () => {
    await seedFleet();
    const snap = await assertSucceeds(getDocs(query(
      collection(dbFor(ADMIN), 'maintenance_records'),
      where('userId', '==', ADMIN),
      where('vehicleId', 'in', [MEMBER_CAR]),
    )));
    expect(snap.size).toBe(0);
  });

  // --- 新しい形: 集計文書を documentId in で引く（FleetService と同じ） ---

  test('管理者は、自分の法人の車の集計を documentId in で読める', async () => {
    await seedFleet();
    const snap = await assertSucceeds(summariesIn(ADMIN, [MEMBER_CAR]));
    expect(snap.size).toBe(1);
    expect(snap.docs[0].data().totalCost).toBe(12000);
  });

  test('管理者は、自分の法人の車の集計を1件ずつ読める', async () => {
    await seedFleet();
    await assertSucceeds(getDoc(doc(dbFor(ADMIN), `fleet_maintenance_summaries/${MEMBER_CAR}`)));
  });

  test('車の持ち主は、自分の車の集計を読める', async () => {
    await seedFleet();
    await assertSucceeds(summariesIn(MEMBER, [MEMBER_CAR, PRIVATE_CAR]));
  });

  test('管理者でも、別の法人の車の集計は読めない', async () => {
    await seedFleet();
    await assertFails(getDoc(doc(dbFor(ADMIN), `fleet_maintenance_summaries/${OTHER_FLEET_CAR}`)));
    await assertFails(summariesIn(ADMIN, [OTHER_FLEET_CAR]));
  });

  test('管理者でも、法人に入っていない（メンバー個人の）車の集計は読めない', async () => {
    await seedFleet();
    await assertFails(getDoc(doc(dbFor(ADMIN), `fleet_maintenance_summaries/${PRIVATE_CAR}`)));
  });

  test('自分の法人の車に他の車を混ぜたクエリは、全体が拒否される', async () => {
    await seedFleet();
    await assertFails(summariesIn(ADMIN, [MEMBER_CAR, OTHER_FLEET_CAR]));
    await assertFails(summariesIn(ADMIN, [MEMBER_CAR, PRIVATE_CAR]));
  });

  test('法人と無関係な人・未認証は読めない', async () => {
    await seedFleet();
    await assertFails(getDoc(doc(dbFor(STRANGER), `fleet_maintenance_summaries/${MEMBER_CAR}`)));
    await assertFails(summariesIn(STRANGER, [MEMBER_CAR]));
    await assertFails(getDoc(doc(unauthDb(), `fleet_maintenance_summaries/${MEMBER_CAR}`)));
  });

  test('別の法人の管理者は読めない', async () => {
    await seedFleet();
    await assertFails(getDoc(doc(dbFor(OTHER_ADMIN), `fleet_maintenance_summaries/${MEMBER_CAR}`)));
  });

  test('車が法人を抜けたら、元の管理者はすぐ読めなくなる', async () => {
    await seedFleet();
    await updateDoc(doc(dbFor(MEMBER), `vehicles/${MEMBER_CAR}`), {
      companyId: null, updatedAt: new Date(),
    });
    await assertFails(getDoc(doc(dbFor(ADMIN), `fleet_maintenance_summaries/${MEMBER_CAR}`)));
    // 持ち主は引き続き読める
    await assertSucceeds(getDoc(doc(dbFor(MEMBER), `fleet_maintenance_summaries/${MEMBER_CAR}`)));
  });

  test('集計がまだ無い法人の車は、拒否されず「無い」が返る', async () => {
    await seedFleet();
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'vehicles/fleet_car_new'), {
        userId: MEMBER, companyId: ADMIN, maker: 'スズキ', model: 'エブリイ',
      });
    });
    const snap = await assertSucceeds(
      getDoc(doc(dbFor(ADMIN), 'fleet_maintenance_summaries/fleet_car_new')));
    expect(snap.exists()).toBe(false);
  });

  test('車の文書が無い集計は、管理者を名乗っても読めない', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'fleet_maintenance_summaries/ghost_car'),
        summary('ghost_car', MEMBER));
    });
    await assertFails(getDoc(doc(dbFor(ADMIN), 'fleet_maintenance_summaries/ghost_car')));
  });

  test('集計はクライアントから書けない（持ち主・管理者とも）', async () => {
    await seedFleet();
    for (const uid of [MEMBER, ADMIN]) {
      const ref = doc(dbFor(uid), `fleet_maintenance_summaries/${MEMBER_CAR}`);
      await assertFails(setDoc(ref, summary(MEMBER_CAR, MEMBER, { totalCost: 1 })));
      await assertFails(updateDoc(ref, { totalCost: 1 }));
      await assertFails(deleteDoc(ref));
    }
    await assertFails(setDoc(doc(dbFor(MEMBER), 'fleet_maintenance_summaries/new_car'),
      summary('new_car', MEMBER)));
  });

  test('集計ができても、管理者はメンバーの生の整備記録を読めない', async () => {
    await seedFleet();
    await assertFails(getDoc(doc(dbFor(ADMIN), 'maintenance_records/fleet_mr_1')));
  });
});

describe('newsletter_subscriptions — トークンでの配信停止（Issue #192）', () => {
  const SUBSCRIBER = 'nl_subscriber_uid';
  const TOKEN = 'tok_0123456789abcdef0123456789abcdef';

  async function seedSubscription() {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `newsletter_subscriptions/${SUBSCRIBER}`), {
        userId: SUBSCRIBER,
        email: 'sub@example.com',
        isSubscribed: true,
        subscribedCategories: ['news'],
        unsubscribeToken: TOKEN,
      });
    });
  }

  // 以前の NewsletterService.unsubscribeByToken の形。メールのリンクから
  // 来る人はログインしていない（または別の人）ので、ルールで通せない。
  // → Cloud Function（unsubscribeNewsletter）に移した。
  test('以前の形: 未認証でトークン一致を引くと拒否される', async () => {
    await seedSubscription();
    await assertFails(getDocs(query(
      collection(unauthDb(), 'newsletter_subscriptions'),
      where('unsubscribeToken', '==', TOKEN),
      limit(1),
    )));
  });

  test('以前の形: 他人がトークン一致を引いても拒否される', async () => {
    await seedSubscription();
    await assertFails(getDocs(query(
      collection(dbFor(OTHER_UID), 'newsletter_subscriptions'),
      where('unsubscribeToken', '==', TOKEN),
      limit(1),
    )));
  });

  test('トークンを知っていても、他人・未認証は購読を書き換えられない', async () => {
    await seedSubscription();
    const path = `newsletter_subscriptions/${SUBSCRIBER}`;
    await assertFails(updateDoc(doc(unauthDb(), path), { isSubscribed: false }));
    await assertFails(updateDoc(doc(dbFor(OTHER_UID), path), { isSubscribed: false }));
  });

  test('本人は自分の購読を読める・止められる（設定画面の経路は従来どおり）', async () => {
    await seedSubscription();
    const path = `newsletter_subscriptions/${SUBSCRIBER}`;
    await assertSucceeds(getDoc(doc(dbFor(SUBSCRIBER), path)));
    await assertSucceeds(updateDoc(doc(dbFor(SUBSCRIBER), path), {
      userId: SUBSCRIBER, isSubscribed: false,
    }));
  });
});

describe('posts — ユーザーの投稿一覧（PostService.getUserPosts, Issue #192）', () => {
  const AUTHOR = 'posts_author_uid';
  const FOLLOWER = 'posts_follower_uid';
  const STRANGER = 'posts_stranger_uid';

  async function seedPosts({ follow = true } = {}) {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      const base = { userId: AUTHOR, content: '投稿', likeCount: 0 };
      await setDoc(doc(db, 'posts/p_public'), {
        ...base, visibility: 'public', createdAt: new Date('2026-09-03'),
      });
      await setDoc(doc(db, 'posts/p_followers'), {
        ...base, visibility: 'followers', createdAt: new Date('2026-09-02'),
      });
      await setDoc(doc(db, 'posts/p_private'), {
        ...base, visibility: 'private', createdAt: new Date('2026-09-01'),
      });
      if (follow) {
        await setDoc(doc(db, `follows/${FOLLOWER}_${AUTHOR}`), {
          followerId: FOLLOWER, followingId: AUTHOR,
        });
      }
    });
  }

  function userPosts(uid, visibilities) {
    const parts = [where('userId', '==', AUTHOR)];
    if (visibilities.length === 1) {
      parts.push(where('visibility', '==', visibilities[0]));
    } else if (visibilities.length > 1) {
      parts.push(where('visibility', 'in', visibilities));
    }
    return getDocs(query(
      collection(dbFor(uid), 'posts'),
      ...parts,
      orderBy('createdAt', 'desc'),
      limit(20),
    ));
  }

  test('本人は可視性を問わず自分の一覧を読める', async () => {
    await seedPosts();
    const snap = await assertSucceeds(userPosts(AUTHOR, []));
    expect(snap.size).toBe(3);
  });

  test('他人向け（public だけ）は、フォローしていなくても読める', async () => {
    await seedPosts({ follow: false });
    const snap = await assertSucceeds(userPosts(STRANGER, ['public']));
    expect(snap.size).toBe(1);
  });

  // Issue #192 では「exists() 依存なので list を証明できない」と机上で挙げて
  // いたが、エミュレータで実測すると通る。クエリが userId を == で固定して
  // いるので、ルールの exists() のパスがクエリから決まるため。
  test('フォロワー向け（public + followers の in）は、フォロー中なら通る', async () => {
    await seedPosts();
    const snap = await assertSucceeds(userPosts(FOLLOWER, ['public', 'followers']));
    expect(snap.size).toBe(2);
  });

  test('フォローしていない人が public + followers の in を投げると拒否される', async () => {
    await seedPosts({ follow: false });
    await assertFails(userPosts(STRANGER, ['public', 'followers']));
  });

  test('フォローを外したら、フォロワー向けの一覧は拒否される', async () => {
    await seedPosts();
    await deleteDoc(doc(dbFor(FOLLOWER), `follows/${FOLLOWER}_${AUTHOR}`));
    await assertFails(userPosts(FOLLOWER, ['public', 'followers']));
    // public だけなら引き続き読める
    await assertSucceeds(userPosts(FOLLOWER, ['public']));
  });

  test('フォロー中でも private は読めない', async () => {
    await seedPosts();
    await assertFails(userPosts(FOLLOWER, ['public', 'followers', 'private']));
  });

  test('フォローしていない人の followers 指定は拒否される', async () => {
    await seedPosts({ follow: false });
    await assertFails(userPosts(STRANGER, ['followers']));
  });

  test('他人は userId だけで絞った一覧を読めない', async () => {
    await seedPosts();
    await assertFails(userPosts(STRANGER, []));
  });
});

describe('spots — お気に入りスポット（DriveLogService.getUserFavoriteSpots, Issue #192）', () => {
  const VIEWER = 'spots_viewer_uid';
  const CREATOR = 'spots_creator_uid';

  async function seedSpots() {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, 'spots/s_public'), {
        userId: CREATOR, name: '公開スポット', isPublic: true,
      });
      await setDoc(doc(db, 'spots/s_mine_private'), {
        userId: VIEWER, name: '自分の非公開スポット', isPublic: false,
      });
      await setDoc(doc(db, 'spots/s_other_private'), {
        userId: CREATOR, name: '後から非公開にされたスポット', isPublic: false,
      });
    });
  }

  function spotsIn(uid, ids) {
    return getDocs(query(
      collection(dbFor(uid), 'spots'),
      where(documentId(), 'in', ids),
    ));
  }

  test('他人の公開スポットと自分の非公開スポットは、documentId in でまとめて読める', async () => {
    await seedSpots();
    const snap = await assertSucceeds(spotsIn(VIEWER, ['s_public', 's_mine_private']));
    expect(snap.size).toBe(2);
  });

  // 以前の形（documentId in だけ）。お気に入りの1件が後から非公開にされると
  // お気に入り一覧そのものが permission-denied になる。
  test('以前の形: 後から非公開にされたスポットが混ざると、クエリ全体が拒否される', async () => {
    await seedSpots();
    await assertFails(spotsIn(VIEWER, ['s_public', 's_other_private']));
  });

  test('以前の形: 消されたスポットの ID が混ざっても、クエリ全体が拒否される', async () => {
    await seedSpots();
    // documentId in は文書ごとに評価され、無い文書では resource が null に
    // なってルールが評価エラーになる。お気に入りのスポットが消されるだけで
    // お気に入り一覧そのものが開けなくなっていた。
    await assertFails(spotsIn(VIEWER, ['s_public', 's_deleted']));
  });

  test('isPublic == true を足しても、documentId in は文書ごとに評価されるので救えない', async () => {
    await seedSpots();
    await assertFails(getDocs(query(
      collection(dbFor(VIEWER), 'spots'),
      where(documentId(), 'in', ['s_public', 's_other_private']),
      where('isPublic', '==', true),
    )));
  });

  // 新しい形（DriveLogService.getUserFavoriteSpots）: 1件ずつ get する。
  // 読めない1件（非公開にされた・消された）は、その1件だけが拒否される。
  test('新しい形: 1件ずつなら、読めるものは読め、読めないものだけが拒否される', async () => {
    await seedSpots();
    const db = dbFor(VIEWER);
    await assertSucceeds(getDoc(doc(db, 'spots/s_public')));
    await assertSucceeds(getDoc(doc(db, 'spots/s_mine_private')));
    await assertFails(getDoc(doc(db, 'spots/s_other_private')));
    // 消されたスポットは「無い」ではなく拒否になる（resource が null のため）
    await assertFails(getDoc(doc(db, 'spots/s_deleted')));
  });

  test('他人を名乗って userId で絞っても、非公開スポットは読めない', async () => {
    await seedSpots();
    await assertFails(getDocs(query(
      collection(dbFor(VIEWER), 'spots'),
      where(documentId(), 'in', ['s_other_private']),
      where('userId', '==', CREATOR),
    )));
  });

  test('未認証は公開スポットも読めない', async () => {
    await seedSpots();
    await assertFails(getDocs(query(
      collection(unauthDb(), 'spots'),
      where(documentId(), 'in', ['s_public']),
      where('isPublic', '==', true),
    )));
  });
});
