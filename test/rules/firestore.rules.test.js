/**
 * Firebase Firestore セキュリティルール 自動テスト
 *
 * 対象: firestore.rules の主要セキュリティパスの検証。
 *   - shops/{shopId}/caseStudies — オーナースコープ書き込み・公開読み取り
 *   - users/{userId} — 本人スコープ読み書き・planType 変更禁止
 *   - vehicles/{vehicleId} — 本人スコープ読み書き
 *   - inquiries/{inquiryId} — バイヤー・ショップ双方向アクセス
 *   - デフォルト拒否 — 未定義パスの拒否確認
 *
 * 実行:
 *   cd test/rules
 *   npm run test:firestore   # Firestore Emulator を起動してテスト実行
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
const SHOP_UID = 'shop_owner_789';

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

function firestoreFor(uid) {
  return testEnv.authenticatedContext(uid).firestore();
}
function unauthFirestore() {
  return testEnv.unauthenticatedContext().firestore();
}

async function seed(docPath, data) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), docPath), data);
  });
}

// ---------------------------------------------------------------------------
// shops/{shopId}/caseStudies — 施工事例サブコレクション
// ---------------------------------------------------------------------------

describe('shops/{shopId}/caseStudies — 施工事例サブコレクション', () => {
  const shopId = SHOP_UID;
  const caseStudyPath = `shops/${shopId}/caseStudies/cs1`;
  const validData = { shopId, title: 'ドア板金', createdAt: new Date() };
  const wrongShopData = { shopId: OTHER_UID, title: 'ドア板金', createdAt: new Date() };

  describe('write（作成）', () => {
    test('オーナーは施工事例を作成できる', async () => {
      await assertSucceeds(
        setDoc(doc(firestoreFor(shopId), caseStudyPath), validData),
      );
    });

    test('他ユーザーは作成できない', async () => {
      await assertFails(
        setDoc(doc(firestoreFor(OTHER_UID), caseStudyPath), validData),
      );
    });

    test('未認証ユーザーは作成できない', async () => {
      await assertFails(
        setDoc(doc(unauthFirestore(), caseStudyPath), validData),
      );
    });

    test('shopIdフィールドが不一致の場合は作成できない', async () => {
      await assertFails(
        setDoc(doc(firestoreFor(shopId), caseStudyPath), wrongShopData),
      );
    });
  });

  describe('read（読み取り）', () => {
    beforeEach(async () => {
      await seed(caseStudyPath, validData);
    });

    test('認証済みユーザーは閲覧できる（公開情報）', async () => {
      await assertSucceeds(
        getDoc(doc(firestoreFor(OTHER_UID), caseStudyPath)),
      );
    });

    test('オーナー自身も閲覧できる', async () => {
      await assertSucceeds(
        getDoc(doc(firestoreFor(shopId), caseStudyPath)),
      );
    });

    test('未認証ユーザーは閲覧できない', async () => {
      await assertFails(getDoc(doc(unauthFirestore(), caseStudyPath)));
    });
  });

  describe('update（更新）', () => {
    beforeEach(async () => {
      await seed(caseStudyPath, validData);
    });

    test('オーナーは更新できる', async () => {
      await assertSucceeds(
        updateDoc(doc(firestoreFor(shopId), caseStudyPath), {
          title: '板金・塗装',
        }),
      );
    });

    test('他ユーザーは更新できない', async () => {
      await assertFails(
        updateDoc(doc(firestoreFor(OTHER_UID), caseStudyPath), {
          title: '板金・塗装',
        }),
      );
    });
  });

  describe('delete（削除）', () => {
    beforeEach(async () => {
      await seed(caseStudyPath, validData);
    });

    test('オーナーは削除できる', async () => {
      await assertSucceeds(
        deleteDoc(doc(firestoreFor(shopId), caseStudyPath)),
      );
    });

    test('他ユーザーは削除できない', async () => {
      await assertFails(
        deleteDoc(doc(firestoreFor(OTHER_UID), caseStudyPath)),
      );
    });

    test('未認証ユーザーは削除できない', async () => {
      await assertFails(deleteDoc(doc(unauthFirestore(), caseStudyPath)));
    });
  });
});

// ---------------------------------------------------------------------------
// users/{userId} — ユーザードキュメント
// ---------------------------------------------------------------------------

describe('users/{userId} — ユーザードキュメント', () => {
  const userId = OWNER_UID;
  const userPath = `users/${userId}`;
  const userData = {
    userId,
    displayName: 'テストユーザー',
    planType: 'free',
  };

  test('本人は自分のデータを読み取れる', async () => {
    await seed(userPath, userData);
    await assertSucceeds(getDoc(doc(firestoreFor(userId), userPath)));
  });

  test('他ユーザーは読み取れない', async () => {
    await seed(userPath, userData);
    await assertFails(getDoc(doc(firestoreFor(OTHER_UID), userPath)));
  });

  test('未認証ユーザーは読み取れない', async () => {
    await seed(userPath, userData);
    await assertFails(getDoc(doc(unauthFirestore(), userPath)));
  });

  test('本人は自分のドキュメントを作成できる', async () => {
    await assertSucceeds(
      setDoc(doc(firestoreFor(userId), userPath), userData),
    );
  });

  test('他人のuserIdでの作成は拒否される', async () => {
    await assertFails(
      setDoc(doc(firestoreFor(OTHER_UID), userPath), userData),
    );
  });

  test('planTypeの更新は拒否される（Cloud Functions経由のみ）', async () => {
    await seed(userPath, userData);
    await assertFails(
      updateDoc(doc(firestoreFor(userId), userPath), { planType: 'premium' }),
    );
  });

  test('planType以外のフィールド更新は許可される', async () => {
    await seed(userPath, userData);
    await assertSucceeds(
      updateDoc(doc(firestoreFor(userId), userPath), {
        displayName: '更新されたユーザー名',
      }),
    );
  });
});

// ---------------------------------------------------------------------------
// vehicles/{vehicleId} — 車両データ
// ---------------------------------------------------------------------------

describe('vehicles/{vehicleId} — 車両データ', () => {
  const userId = OWNER_UID;
  const vehiclePath = 'vehicles/v1';
  const vehicleData = { userId, maker: 'トヨタ', model: 'アクア' };

  test('所有者は自分の車両を読み取れる', async () => {
    await seed(vehiclePath, vehicleData);
    await assertSucceeds(getDoc(doc(firestoreFor(userId), vehiclePath)));
  });

  test('他ユーザーは読み取れない', async () => {
    await seed(vehiclePath, vehicleData);
    await assertFails(getDoc(doc(firestoreFor(OTHER_UID), vehiclePath)));
  });

  test('未認証ユーザーは読み取れない', async () => {
    await seed(vehiclePath, vehicleData);
    await assertFails(getDoc(doc(unauthFirestore(), vehiclePath)));
  });

  test('所有者は自分のuserIdで車両を作成できる', async () => {
    await assertSucceeds(
      setDoc(doc(firestoreFor(userId), vehiclePath), vehicleData),
    );
  });

  test('他人のuserIdでの作成は拒否される', async () => {
    await assertFails(
      setDoc(doc(firestoreFor(OTHER_UID), vehiclePath), vehicleData),
    );
  });

  test('所有者は自分の車両を更新できる', async () => {
    await seed(vehiclePath, vehicleData);
    await assertSucceeds(
      updateDoc(doc(firestoreFor(userId), vehiclePath), { mileage: 10000 }),
    );
  });

  test('他ユーザーは更新できない', async () => {
    await seed(vehiclePath, vehicleData);
    await assertFails(
      updateDoc(doc(firestoreFor(OTHER_UID), vehiclePath), { mileage: 10000 }),
    );
  });
});

// ---------------------------------------------------------------------------
// inquiries/{inquiryId} — 問い合わせ（バイヤー・ショップ双方向）
// ---------------------------------------------------------------------------

describe('inquiries/{inquiryId} — 問い合わせ', () => {
  const buyerId = OWNER_UID;
  const shopId = SHOP_UID;
  const thirdPartyId = OTHER_UID;
  const inquiryPath = 'inquiries/inq1';
  const inquiryData = {
    userId: buyerId,
    shopId,
    subject: '修理について',
    status: 'pending',
  };

  describe('read（読み取り）', () => {
    beforeEach(async () => {
      await seed(inquiryPath, inquiryData);
    });

    test('バイヤーは自分の問い合わせを読み取れる', async () => {
      await assertSucceeds(getDoc(doc(firestoreFor(buyerId), inquiryPath)));
    });

    test('ショップオーナーは問い合わせを読み取れる', async () => {
      await assertSucceeds(getDoc(doc(firestoreFor(shopId), inquiryPath)));
    });

    test('第三者は読み取れない', async () => {
      await assertFails(
        getDoc(doc(firestoreFor(thirdPartyId), inquiryPath)),
      );
    });

    test('未認証ユーザーは読み取れない', async () => {
      await assertFails(getDoc(doc(unauthFirestore(), inquiryPath)));
    });
  });

  describe('write（作成）', () => {
    test('バイヤーは自分のuserIdで問い合わせを作成できる', async () => {
      await assertSucceeds(
        setDoc(doc(firestoreFor(buyerId), inquiryPath), inquiryData),
      );
    });

    test('他人のuserIdで作成しようとしても拒否される', async () => {
      const fakeData = { userId: shopId, shopId, subject: '偽装' };
      await assertFails(
        setDoc(doc(firestoreFor(buyerId), inquiryPath), fakeData),
      );
    });
  });

  describe('update（更新）', () => {
    beforeEach(async () => {
      await seed(inquiryPath, inquiryData);
    });

    test('バイヤーは更新できる（既読フラグ等）', async () => {
      await assertSucceeds(
        updateDoc(doc(firestoreFor(buyerId), inquiryPath), {
          status: 'inProgress',
        }),
      );
    });

    test('ショップオーナーも更新できる', async () => {
      await assertSucceeds(
        updateDoc(doc(firestoreFor(shopId), inquiryPath), {
          status: 'replied',
        }),
      );
    });

    test('第三者は更新できない', async () => {
      await assertFails(
        updateDoc(doc(firestoreFor(thirdPartyId), inquiryPath), {
          status: 'closed',
        }),
      );
    });
  });
});

// ---------------------------------------------------------------------------
// デフォルト拒否
// ---------------------------------------------------------------------------

describe('デフォルト拒否', () => {
  test('未定義パスへの書き込みは拒否される', async () => {
    await assertFails(
      setDoc(doc(firestoreFor(OWNER_UID), 'unknown_collection/doc1'), {
        data: 'test',
      }),
    );
  });

  test('未定義パスへの読み取りも拒否される', async () => {
    await seed('unknown_collection/doc1', { data: 'test' });
    await assertFails(
      getDoc(doc(firestoreFor(OWNER_UID), 'unknown_collection/doc1')),
    );
  });
});
