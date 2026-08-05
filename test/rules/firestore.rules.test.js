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
} = require('firebase/firestore');

const PROJECT_ID = 'trust-car-platform';
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

describe('accessory_showcases/{id}/comments — reportCount update（通報集計）', () => {
  test('誰でも reportCount を +1 できる（通報）', async () => {
    await seedComment({ userId: OWNER_UID });
    await assertSucceeds(
      updateDoc(doc(dbFor(OTHER_UID), commentPath), { reportCount: 1 }),
    );
  });

  test('reportCount を -1（減算）はできない', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), commentPath), {
        showcaseId: SHOWCASE_ID,
        userId: OWNER_UID,
        content: 'x',
        isEdited: false,
        likeCount: 0,
        reportCount: 2,
      });
    });
    await assertFails(
      updateDoc(doc(dbFor(OTHER_UID), commentPath), { reportCount: 1 }),
    );
  });

  test('+1 を超える reportCount 変更は拒否される', async () => {
    await seedComment({ userId: OWNER_UID });
    await assertFails(
      updateDoc(doc(dbFor(OTHER_UID), commentPath), { reportCount: 5 }),
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

describe('post_comment_reports — SNS投稿コメント通報', () => {
  const postCommentId = 'pc_1';
  const postReportId = `${postCommentId}_${OWNER_UID}`;
  const postReportPath = `post_comment_reports/${postReportId}`;

  const validReport = () => ({
    commentId: postCommentId,
    reporterId: OWNER_UID,
    reason: 'spam',
    status: 'pending',
  });

  test('本人は自分の通報を作成できる', async () => {
    await assertSucceeds(
      setDoc(doc(dbFor(OWNER_UID), postReportPath), validReport()),
    );
  });

  test('reporterId の詐称は拒否される', async () => {
    await assertFails(
      setDoc(doc(dbFor(OTHER_UID), postReportPath), validReport()),
    );
  });

  test('未認証ユーザーは通報を作成できない', async () => {
    await assertFails(
      setDoc(doc(unauthDb(), postReportPath), validReport()),
    );
  });

  test('status が pending 以外は拒否される', async () => {
    await assertFails(
      setDoc(doc(dbFor(OWNER_UID), postReportPath), {
        ...validReport(),
        status: 'resolved',
      }),
    );
  });

  test('クライアントは通報を読み取れない（サーバー専用）', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), postReportPath), validReport());
    });
    await assertFails(getDoc(doc(dbFor(OWNER_UID), postReportPath)));
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
