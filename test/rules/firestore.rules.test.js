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
