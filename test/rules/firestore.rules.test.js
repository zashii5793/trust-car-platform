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
