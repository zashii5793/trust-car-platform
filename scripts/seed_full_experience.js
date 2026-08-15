#!/usr/bin/env node
/**
 * 「全機能を実機で触れる」状態を作るフル体験シード
 *
 * Usage:
 *   node scripts/seed_full_experience.js [--dry-run] [--emulator] [--delete]
 *
 * seed_personas.js が作るペルソナ A〜I（uid: user-a / president-uid / user-c /
 * persona-d-user 〜 persona-i-user）に紐づけて、コミュニティ・マーケット・
 * 工場検索・ドライブ機能のデータを投入する。
 *
 * 前提: 先に seed_personas.js を流しておくこと（users / vehicles / Auth）。
 *       本スクリプトは users や vehicles を作らず、既存 uid / vehicleId を参照する。
 *
 * 作るもの:
 *   posts               愛車投稿（複数ペルソナ）
 *   comments            投稿へのコメント（返信スレッド含む）
 *   post_likes          投稿への「いいね」（docId = `${postId}_${userId}`）
 *   comment_likes       コメントへの「いいね」（docId = `${commentId}_${userId}`）
 *   user_part_listings  C2C パーツ出品（中古ナビ・ホイール・マフラー等）
 *   shops               整備工場 10件（提携 active 4 / 未提携 free 6、東京・神奈川・埼玉）
 *   spots               ドライブスポット
 *                       ※ アプリは FirestoreCollections.spots = 'spots' を読む
 *                         （'drive_spots' 定数は存在するが未使用）ため 'spots' に入れる
 *   spot_ratings        スポット評価（averageRating / ratingCount と整合）
 *   inquiries           ユーザー→提携工場の問い合わせ（返信あり・未返信を混在）
 *   inquiries/{id}/messages  問い合わせスレッドの返信
 *   drive_logs          公開ドライブログ（isPublic: true, statistics サブマップ付き）
 *   drive_log_likes     ドライブログへの「いいね」
 *
 * 冪等性: 全ドキュメント固定ID + set(merge: true)。何度流しても増殖しない。
 * 後片付け: 全ドキュメントに isSeed: true / seedTag: 'full_experience_v1' を
 *           付けており、--delete はそれを目印に削除する（messages サブコレクション
 *           は親 inquiry 経由で削除）。
 *
 * ⚠️ --emulator を付けないと本番 Firestore に書き込みます。
 */

const admin = require('firebase-admin');

const argv = process.argv.slice(2);
const has = (f) => argv.includes(f);

const DRY_RUN = has('--dry-run');
const EMULATOR = has('--emulator');
const DELETE = has('--delete');

if (EMULATOR) {
  process.env.FIRESTORE_EMULATOR_HOST = 'localhost:8080';
  process.env.FIREBASE_AUTH_EMULATOR_HOST = 'localhost:9099';
}

const SEED_TAG = 'full_experience_v1';

const DAY = 24 * 60 * 60 * 1000;
const NOW = Date.now();

// 決定的な乱数（seed_fleet_year.js と同じ線形合同法・シード固定）。
// 実行のたびに「いいね」の顔ぶれが変わると動作確認にならないため。
let _seed = 20260809;
function rand() {
  _seed = (_seed * 1103515245 + 12345) % 2147483648;
  return _seed / 2147483648;
}
const between = (a, b) => a + Math.floor(rand() * (b - a + 1));

const ts = (ms) => admin.firestore.Timestamp.fromMillis(ms);
const daysAgo = (d) => ts(NOW - d * DAY);
const { GeoPoint } = admin.firestore;

// 共通メタ（全ドキュメントに付与）
const META = { isSeed: true, seedTag: SEED_TAG };

// ---------------------------------------------------------------------------
// ペルソナ（seed_personas.js の uid / displayName と一致させること）
// ---------------------------------------------------------------------------

const P = {
  a: { uid: 'user-a', name: '個人 太郎（A: 4台混在）' },
  b: { uid: 'president-uid', name: '田中 花子（B: 法人20台）' },
  c: { uid: 'user-c', name: '比較 花子（C: 工場比較）' },
  d: { uid: 'persona-d-user', name: 'プリウス 大郎（D: 長期整備）' },
  e: { uid: 'persona-e-user', name: '新人 みどり（E: 新社会人）' },
  f: { uid: 'persona-f-user', name: '売却 三郎（F: 売却/廃車）' },
  g: { uid: 'persona-g-user', name: 'EV 四郎（G: 日産リーフ）' },
  h: { uid: 'persona-h-user', name: '旧車 五郎（H: Beat 1994）' },
  i: { uid: 'persona-i-user', name: '購入 六郎（I: 中古SUV検討）' },
};
const ALL_PERSONAS = Object.values(P);
const nameOf = (uid) => ALL_PERSONAS.find((p) => p.uid === uid).name;

/// author 以外のペルソナから n 人を決定的に選ぶ（offset でずらして偏りを防ぐ）
function pickLikers(authorUid, n, offset) {
  const others = ALL_PERSONAS.filter((p) => p.uid !== authorUid);
  const out = [];
  for (let k = 0; k < Math.min(n, others.length); k++) {
    out.push(others[(offset + k) % others.length].uid);
  }
  return out;
}

// ---------------------------------------------------------------------------
// 1) 愛車投稿（posts）＋ コメント（comments）＋ いいね
// ---------------------------------------------------------------------------
//
// Post.fromFirestore が期待する形（lib/models/post.dart）:
//   category/visibility は enum name 文字列、vehicleTag はサブマップ、
//   likeCount/commentCount はカウントフィールド（実データと整合させる）。

const POSTS = [
  {
    id: 'post-fx-a-roadster',
    author: P.a,
    category: 'carLife',
    daysAgo: 2,
    content:
      '早起きして箱根ターンパイクへ。ロードスターの幌を開けて走る朝は最高です。'
      + ' #ロードスター #朝活ドライブ',
    hashtags: ['ロードスター', '朝活ドライブ'],
    vehicleTag: { vehicleId: 'veh-a-sports', makerName: 'Mazda', modelName: 'Roadster', year: 2019 },
    likes: 4,
    comments: [
      { author: P.h, content: 'オープンで走る朝、いいですね。今度ご一緒したいです！' },
      { author: P.g, content: '大観山の展望台は行きましたか？富士山が綺麗に見えますよ。' },
      { author: P.a, content: '大観山、寄りました！写真も撮ったので後で上げます。', replyTo: 1 },
      { author: P.e, content: '幌車憧れます。維持って大変ですか？' },
      { author: P.d, content: '天気も良くて羨ましい限りです。' },
    ],
  },
  {
    id: 'post-fx-h-beat-restore',
    author: P.h,
    category: 'customization',
    daysAgo: 5,
    content:
      'Beat のレストア進捗。内装を全バラして 30年物のホコリと格闘中。'
      + '幌の張り替えも自分でやってみます。 #ビート #レストア #旧車',
    hashtags: ['ビート', 'レストア', '旧車'],
    vehicleTag: { vehicleId: 'veh-h-beat', makerName: 'Honda', modelName: 'Beat', year: 1994 },
    likes: 5,
    comments: [
      { author: P.a, content: '30年前の軽をここまで維持されているのが凄い。続報待ってます。' },
      { author: P.d, content: '幌の張り替え、DIYでできるものなんですね。' },
      { author: P.h, content: 'キットが出ているので根気があれば大丈夫です！', replyTo: 1 },
      { author: P.g, content: '内装の写真、参考になります。' },
      { author: P.e, content: '旧車ってロマンありますね…！' },
      { author: P.c, content: '部品の入手はどうされてるんですか？' },
    ],
  },
  {
    id: 'post-fx-g-ev-cost',
    author: P.g,
    category: 'review',
    daysAgo: 8,
    content:
      'リーフ納車から2年の電費レポート。月間走行1,000km・自宅充電メインで'
      + '電気代は月4,200円ほど。ガソリン時代の1/3になりました。 #EV #リーフ #維持費',
    hashtags: ['EV', 'リーフ', '維持費'],
    vehicleTag: { vehicleId: 'veh-g-leaf', makerName: 'Nissan', modelName: 'Leaf', year: 2022 },
    likes: 3,
    comments: [
      { author: P.e, content: '維持費1/3は魅力的…。充電設備の工事費はどれくらいでしたか？' },
      { author: P.i, content: '中古EVも検討リストに入れてみます。参考になりました。' },
      { author: P.a, content: '冬場の電費の落ち込みはどうですか？' },
      { author: P.b, content: '社用車のEV化を検討中なのでとても参考になります。' },
    ],
  },
  {
    id: 'post-fx-d-prius-tips',
    author: P.d,
    category: 'maintenance',
    daysAgo: 12,
    content:
      'プリウスのエアコンフィルター交換を自分でやりました。工具不要・10分で完了、'
      + '部品代2,000円ほど。手順を写真付きでまとめたので質問あればどうぞ。 #DIY整備 #プリウス',
    hashtags: ['DIY整備', 'プリウス'],
    vehicleTag: { vehicleId: 'veh-d-prius', makerName: 'Toyota', modelName: 'Prius', year: 2020 },
    likes: 3,
    comments: [
      { author: P.e, content: 'これなら私にもできそう。今度やってみます！' },
      { author: P.c, content: '工場に頼むと5,000円くらい取られるので助かります。' },
      { author: P.a, content: 'グローブボックスの外し方が分からなかったので参考になりました。' },
      { author: P.g, content: 'EVでも同じ要領でできますか？' },
    ],
  },
  {
    id: 'post-fx-e-first-car',
    author: P.e,
    category: 'carLife',
    daysAgo: 15,
    content:
      '初めてのマイカー、N-BOX が納車されて3ヶ月。週末が待ち遠しくなりました。'
      + '先輩方、オススメの最初のカスタムがあれば教えてください！ #初マイカー #NBOX',
    hashtags: ['初マイカー', 'NBOX'],
    vehicleTag: { vehicleId: 'veh-e-nbox', makerName: 'Honda', modelName: 'N-BOX', year: 2023 },
    likes: 4,
    comments: [
      { author: P.a, content: 'まずはドラレコとフロアマットが定番ですよ。' },
      { author: P.h, content: '納車おめでとうございます！大事に乗ってあげてください。' },
      { author: P.d, content: 'スマホホルダーは安くて満足度高いのでオススメです。' },
    ],
  },
  {
    id: 'post-fx-c-shop-question',
    author: P.c,
    category: 'question',
    daysAgo: 18,
    content:
      '車検の見積もりを3社で比較したら金額が2万円以上違いました。'
      + '安い工場って何か落とし穴があるんでしょうか？経験談を聞きたいです。 #車検 #工場選び',
    hashtags: ['車検', '工場選び'],
    vehicleTag: { vehicleId: 'veh-c-fit', makerName: 'Honda', modelName: 'Fit', year: 2020 },
    likes: 2,
    comments: [
      { author: P.d, content: '交換部品の範囲が違うことが多いです。見積の内訳を並べて比較すると分かりますよ。' },
      { author: P.a, content: '代車の有無や保証内容も含めて比較するのがオススメです。' },
      { author: P.b, content: '法人で複数台出してますが、安くても整備記録がしっかり残る工場なら問題ないです。' },
    ],
  },
  {
    id: 'post-fx-a-drive-izu',
    author: P.a,
    category: 'drive',
    daysAgo: 20,
    content:
      '週末は伊豆スカイラインへ。天気に恵まれて富士山も駿河湾も一望できました。'
      + '走行180km、休憩は亀石峠のパーキングで。 #伊豆スカイライン #ドライブ日和',
    hashtags: ['伊豆スカイライン', 'ドライブ日和'],
    vehicleTag: { vehicleId: 'veh-a-sports', makerName: 'Mazda', modelName: 'Roadster', year: 2019 },
    likes: 3,
    comments: [
      { author: P.g, content: '伊豆スカイライン、EVだと下りで回生が効いて楽しいんですよ。' },
      { author: P.e, content: '写真だけでも気持ちよさが伝わります！' },
      { author: P.h, content: '来月のツーリングのルート候補にさせてもらいます。' },
      { author: P.d, content: '亀石峠のPA、トイレも綺麗で好きです。' },
    ],
  },
  {
    id: 'post-fx-h-event',
    author: P.h,
    category: 'event',
    daysAgo: 25,
    content:
      '【告知】来月第2日曜、宮ヶ瀬湖畔で90年代軽スポーツの集まりをやります。'
      + 'ビート・カプチーノ・AZ-1、もちろん見学だけでも歓迎です。 #旧車イベント #軽スポーツ',
    hashtags: ['旧車イベント', '軽スポーツ'],
    vehicleTag: { vehicleId: 'veh-h-beat', makerName: 'Honda', modelName: 'Beat', year: 1994 },
    likes: 2,
    comments: [
      { author: P.a, content: 'ロードスターですが見学に行ってもいいですか？' },
      { author: P.h, content: 'もちろん大歓迎です！お待ちしてます。', replyTo: 0 },
      { author: P.e, content: '軽スポーツ見てみたいので行ってみます！' },
    ],
  },
  {
    id: 'post-fx-i-question-suv',
    author: P.i,
    category: 'question',
    daysAgo: 28,
    content:
      '家族4人・予算400万円で中古SUVを探しています。RAV4、CX-5、エクストレイルで'
      + '迷い中。維持費や使い勝手のリアルな声を聞かせてください。 #中古車 #SUV選び',
    hashtags: ['中古車', 'SUV選び'],
    vehicleTag: null,
    likes: 1,
    comments: [
      { author: P.a, content: '家族使いなら後席の広さとラゲッジの開口部を実車で確認するのが一番です。' },
      { author: P.g, content: 'ハイブリッド車なら燃費でかなり差が出ますよ。' },
    ],
  },
];

/// posts / comments / post_likes / comment_likes のエントリを組み立てる。
/// likeCount・commentCount・replyCount は実データ件数から計算して整合させる。
function buildCommunity() {
  const entries = [];
  const counts = { posts: 0, comments: 0, post_likes: 0, comment_likes: 0 };

  POSTS.forEach((post, pi) => {
    const postCreated = NOW - post.daysAgo * DAY;

    // ---- コメント ----
    const commentIds = [];
    post.comments.forEach((c, ci) => {
      const cid = `cmt-fx-${post.id.replace('post-fx-', '')}-${ci}`;
      commentIds.push(cid);
      const parentId = c.replyTo != null ? commentIds[c.replyTo] : null;
      const createdMs = postCreated + (ci + 1) * between(30, 180) * 60 * 1000;
      const replyCount = post.comments.filter((x) => x.replyTo === ci).length;
      // コメントいいね: 各投稿の先頭コメントに 1〜2件（合計20件以上の一部を担う）
      const likerUids = ci === 0 ? pickLikers(c.author.uid, (pi % 2) + 1, pi + 3) : [];

      entries.push({
        col: 'comments',
        id: cid,
        data: {
          postId: post.id,
          userId: c.author.uid,
          userDisplayName: c.author.name,
          userPhotoUrl: null,
          content: c.content,
          ...(parentId ? { parentCommentId: parentId } : {}),
          likeCount: likerUids.length,
          replyCount,
          isEdited: false,
          createdAt: ts(createdMs),
          updatedAt: ts(createdMs),
          ...META,
        },
      });
      counts.comments++;

      likerUids.forEach((uid) => {
        entries.push({
          col: 'comment_likes',
          id: `${cid}_${uid}`, // アプリ実装（post_service.likeComment）と同じ docId 規約
          data: {
            commentId: cid,
            userId: uid,
            createdAt: ts(createdMs + 60 * 60 * 1000),
            ...META,
          },
        });
        counts.comment_likes++;
      });
    });

    // ---- 投稿いいね ----
    const likerUids = pickLikers(post.author.uid, post.likes, pi);
    likerUids.forEach((uid, li) => {
      entries.push({
        col: 'post_likes',
        id: `${post.id}_${uid}`, // アプリ実装（post_service.likePost）と同じ docId 規約
        data: {
          postId: post.id,
          userId: uid,
          createdAt: ts(postCreated + (li + 1) * 3 * 60 * 60 * 1000),
          ...META,
        },
      });
      counts.post_likes++;
    });

    // ---- 投稿本体 ----
    entries.push({
      col: 'posts',
      id: post.id,
      data: {
        userId: post.author.uid,
        userDisplayName: post.author.name,
        userPhotoUrl: null,
        category: post.category,
        visibility: 'public',
        content: post.content,
        media: [],
        ...(post.vehicleTag ? { vehicleTag: post.vehicleTag } : {}),
        hashtags: post.hashtags,
        mentionedUserIds: [],
        likeCount: likerUids.length,
        commentCount: post.comments.length, // 返信もカウント（アプリの increment 挙動に合わせる）
        shareCount: 0,
        viewCount: between(20, 300),
        isEdited: false,
        createdAt: ts(postCreated),
        updatedAt: ts(postCreated),
        ...META,
      },
    });
    counts.posts++;
  });

  return { entries, counts };
}

// ---------------------------------------------------------------------------
// 2) パーツ出品（user_part_listings）
// ---------------------------------------------------------------------------
//
// UserPartListing.fromFirestore（lib/models/user_part_listing.dart）と
// PartListingService.createListing（lib/services/part_listing_service.dart）に合わせる:
//   ドキュメント内に 'id' フィールドを持ち、payout = price - max(ceil(price*8%), 100)。

const COMMISSION_RATE = 0.08;
const COMMISSION_MIN = 100;
const payoutOf = (price) => {
  const fee = Math.max(Math.ceil(price * COMMISSION_RATE), COMMISSION_MIN);
  return Math.max(price - fee, 0);
};

const PART_LISTINGS = [
  { id: 'upl-fx-navi-a', seller: P.a, title: '中古 7インチ メモリーナビ（2021年地図）', category: 'navigation', condition: 'goodCondition', price: 25000, description: 'アルファードから取り外した純正ナビ。動作確認済み、地図データは2021年版です。配線・取付ステー付属。', compatibleVehicle: 'トヨタ車全般（要ハーネス確認）', shipping: 'includedInPrice', status: 'active', daysAgo: 3 },
  { id: 'upl-fx-studless-a', seller: P.a, title: 'スタッドレスタイヤ 4本 195/65R15（溝7分山）', category: 'tire', condition: 'minorScratches', price: 32000, description: '2シーズン使用。ひび割れなし、溝は7分山です。ホイールなしタイヤのみ。', compatibleVehicle: '195/65R15 適合車', shipping: 'buyerPays', status: 'active', daysAgo: 6 },
  { id: 'upl-fx-muffler-h', seller: P.h, title: 'ビート用 社外マフラー（砲弾型）', category: 'exhaust', condition: 'minorScratches', price: 18000, description: 'Beat(PP1)に装着していた社外マフラー。出口に小傷ありますが排気漏れなし。車検対応品です。', compatibleVehicle: 'ホンダ ビート PP1', shipping: 'buyerPays', status: 'active', daysAgo: 7 },
  { id: 'upl-fx-wheel-h', seller: P.h, title: 'ビート純正ホイール 前後セット', category: 'wheel', condition: 'heavilyUsed', price: 12000, description: 'レストアで社外品に交換したため出品。ガリ傷・塗装剥げありますが歪みはありません。リペアベースにどうぞ。', compatibleVehicle: 'ホンダ ビート PP1', shipping: 'faceToFace', status: 'active', daysAgo: 9 },
  { id: 'upl-fx-coilover-h', seller: P.h, title: '軽自動車用 車高調キット（要OH）', category: 'suspension', condition: 'heavilyUsed', price: 22000, description: '抜けはありませんがオーバーホール前提でお願いします。取付後3万kmほど使用。', compatibleVehicle: 'ホンダ ビート PP1', shipping: 'buyerPays', status: 'active', daysAgo: 12 },
  { id: 'upl-fx-charger-g', seller: P.g, title: 'EV充電ケーブル 200V 15A（5m）', category: 'accessory', condition: 'likeNew', price: 15000, description: '買い替えのため出品。使用半年・屋内保管です。リーフ・サクラ等の200V普通充電に。', compatibleVehicle: 'J1772 対応EV全般', shipping: 'includedInPrice', status: 'active', daysAgo: 10 },
  { id: 'upl-fx-alloywheel-d', seller: P.d, title: 'プリウス純正 15インチ アルミホイール 4本', category: 'wheel', condition: 'goodCondition', price: 28000, description: 'インチアップしたため純正ホイールを出品。目立つ傷なし、センターキャップ付き。', compatibleVehicle: 'トヨタ プリウス 50系', shipping: 'buyerPays', status: 'active', daysAgo: 14 },
  { id: 'upl-fx-chain-d', seller: P.d, title: '非金属タイヤチェーン（195/65R15用・未開封）', category: 'accessory', condition: 'brandNew', price: 8000, description: '購入したものの一度も使わず未開封のまま。箱に保管によるスレあり。', compatibleVehicle: '195/65R15 装着車', shipping: 'includedInPrice', status: 'active', daysAgo: 16 },
  { id: 'upl-fx-dorareko-e', seller: P.e, title: '前後2カメラ ドライブレコーダー（保証書付き）', category: 'safety', condition: 'likeNew', price: 9500, description: '納車キャンペーンでもらったものの、別の機種を取り付けたため出品。開封のみの未使用品です。', compatibleVehicle: '12V車全般', shipping: 'includedInPrice', status: 'active', daysAgo: 18 },
  { id: 'upl-fx-roofbox-f', seller: P.f, title: 'ルーフボックス 300L（ベースキャリア別売）', category: 'exterior', condition: 'minorScratches', price: 17000, description: '車を手放したため出品。天面に小傷ありますが割れ・ヒンジのガタつきなし。直接引き取り希望です。', compatibleVehicle: 'ベースキャリア装着車全般', shipping: 'faceToFace', status: 'active', daysAgo: 20 },
  { id: 'upl-fx-seatcover-f', seller: P.f, title: 'プリウス用 レザー調シートカバー 1台分', category: 'interior', condition: 'goodCondition', price: 6500, description: '売却前まで使用していたシートカバー。破れなし。30プリウス用です。', compatibleVehicle: 'トヨタ プリウス 30系', shipping: 'includedInPrice', status: 'active', daysAgo: 22 },
  { id: 'upl-fx-led-c', seller: P.c, title: 'LEDヘッドライトバルブ H4 左右セット', category: 'lighting', condition: 'likeNew', price: 5800, description: '車検対応6000K。取付後すぐ純正戻ししたためほぼ未使用です。→ご購入ありがとうございました。', compatibleVehicle: 'H4 バルブ採用車', shipping: 'includedInPrice', status: 'soldOut', daysAgo: 26 },
];

function buildPartListings() {
  const entries = PART_LISTINGS.map((l) => ({
    col: 'user_part_listings',
    id: l.id,
    data: {
      id: l.id, // アプリ実装は doc.id と同じ値を 'id' フィールドにも書く
      sellerId: l.seller.uid,
      title: l.title,
      category: l.category,
      condition: l.condition,
      price: l.price,
      payout: payoutOf(l.price),
      description: l.description,
      compatibleVehicle: l.compatibleVehicle,
      imageUrls: [],
      shippingMethod: l.shipping,
      status: l.status,
      createdAt: daysAgo(l.daysAgo),
      updatedAt: daysAgo(l.daysAgo),
      ...META,
    },
  }));
  return { entries, counts: { user_part_listings: entries.length } };
}

// ---------------------------------------------------------------------------
// 3) 整備工場（shops）
// ---------------------------------------------------------------------------
//
// Shop.fromFirestore（lib/models/shop.dart）に合わせる。
// 「提携」= subscriptionStatus が active/trialing（Shop.isPartner）。
// 店名はすべて架空（「テスト」を含む）。電話番号は誤発信防止のため null。

const HOURS_WEEKDAY = {
  0: { openTime: null, closeTime: null, isClosed: true },
  1: { openTime: '09:00', closeTime: '18:00', isClosed: false },
  2: { openTime: '09:00', closeTime: '18:00', isClosed: false },
  3: { openTime: '09:00', closeTime: '18:00', isClosed: false },
  4: { openTime: '09:00', closeTime: '18:00', isClosed: false },
  5: { openTime: '09:00', closeTime: '18:00', isClosed: false },
  6: { openTime: '09:00', closeTime: '17:00', isClosed: false },
};
const HOURS_NO_HOLIDAY = {
  0: { openTime: '10:00', closeTime: '17:00', isClosed: false },
  1: { openTime: '09:30', closeTime: '19:00', isClosed: false },
  2: { openTime: '09:30', closeTime: '19:00', isClosed: false },
  3: { openTime: null, closeTime: null, isClosed: true },
  4: { openTime: '09:30', closeTime: '19:00', isClosed: false },
  5: { openTime: '09:30', closeTime: '19:00', isClosed: false },
  6: { openTime: '09:30', closeTime: '19:00', isClosed: false },
};
// businessHours の Firestore 上のキーは文字列（Shop.toMap と同じ形）
const hoursMap = (h) => Object.fromEntries(Object.entries(h).map(([k, v]) => [String(k), v]));

const SHOPS = [
  // ---- 提携（subscriptionStatus: active）4件 ----
  { id: 'fx-shop-shinagawa', name: 'テストオート品川整備センター', type: 'maintenanceShop', pref: '東京都', city: '品川区', address: '南大井9-9-9', lat: 35.5885, lng: 139.7345, services: ['inspection', 'maintenance', 'repair', 'tire'], reservation: ['phone', 'web'], appeal: ['土日も車検対応', '代車無料'], rating: 4.6, reviews: 88, plan: 'standard', sub: 'active', hours: HOURS_WEEKDAY, note: '祝日は要事前確認' },
  { id: 'fx-shop-yokohama', name: '横浜テストモータース', type: 'customShop', pref: '神奈川県', city: '横浜市都筑区', address: '池辺町テスト1-2-3', lat: 35.5155, lng: 139.5810, services: ['customization', 'partsInstall', 'bodyWork'], reservation: ['line', 'web'], appeal: ['旧車・絶版車の持込パーツ取付歓迎'], rating: 4.4, reviews: 52, plan: 'premium', sub: 'active', hours: HOURS_NO_HOLIDAY, note: '水曜定休' },
  { id: 'fx-shop-omiya', name: 'さいたまテストガレージ大宮店', type: 'maintenanceShop', pref: '埼玉県', city: 'さいたま市北区', address: '宮原町テスト4-5-6', lat: 35.9420, lng: 139.6200, services: ['inspection', 'maintenance', 'tire', 'coating'], reservation: ['phone', 'web', 'walkIn'], appeal: ['最短60分の立会い車検', 'キッズスペースあり'], rating: 4.7, reviews: 134, plan: 'standard', sub: 'active', hours: HOURS_WEEKDAY, note: null },
  { id: 'fx-shop-kawasaki', name: '川崎テスト自動車工業', type: 'bodyShop', pref: '神奈川県', city: '川崎市中原区', address: '木月テスト7-8-9', lat: 35.5735, lng: 139.6560, services: ['bodyWork', 'repair', 'coating'], reservation: ['phone', 'email'], appeal: ['保険修理の実績多数', '見積無料'], rating: 4.2, reviews: 33, plan: 'premium', sub: 'active', hours: HOURS_WEEKDAY, note: '日曜・祝日休み' },
  // ---- 未提携（subscriptionStatus: free）6件 ----
  { id: 'fx-shop-setagaya', name: '世田谷テストカーサービス', type: 'usedCarDealer', pref: '東京都', city: '世田谷区', address: '砧テスト1-1-1', lat: 35.6355, lng: 139.6180, services: ['purchase', 'sale', 'maintenance'], reservation: ['phone'], appeal: ['買取査定無料'], rating: 3.9, reviews: 12, plan: 'free', sub: 'free', hours: HOURS_NO_HOLIDAY, note: null },
  { id: 'fx-shop-hachioji', name: '八王子テストオートワークス', type: 'maintenanceShop', pref: '東京都', city: '八王子市', address: '横山町テスト2-2-2', lat: 35.6560, lng: 139.3390, services: ['maintenance', 'repair', 'tire'], reservation: ['phone', 'walkIn'], appeal: ['輸入車もOK'], rating: 4.1, reviews: 9, plan: 'free', sub: 'free', hours: HOURS_WEEKDAY, note: null },
  { id: 'fx-shop-kawaguchi', name: '川口テストピットイン', type: 'gasStation', pref: '埼玉県', city: '川口市', address: '本町テスト3-3-3', lat: 35.8080, lng: 139.7220, services: ['tire', 'maintenance', 'coating'], reservation: ['walkIn'], appeal: ['オイル交換は予約不要'], rating: 3.8, reviews: 21, plan: 'free', sub: 'free', hours: HOURS_NO_HOLIDAY, note: '年中無休' },
  { id: 'fx-shop-tokorozawa', name: '所沢テストカーケア', type: 'carWash', pref: '埼玉県', city: '所沢市', address: '東住吉テスト4-4-4', lat: 35.7860, lng: 139.4690, services: ['coating'], reservation: ['web', 'line'], appeal: ['ガラスコーティング専門', '施工後3年保証'], rating: 4.5, reviews: 40, plan: 'free', sub: 'free', hours: HOURS_NO_HOLIDAY, note: '雨天時は要相談' },
  { id: 'fx-shop-fujisawa', name: '湘南テストオート藤沢', type: 'partsShop', pref: '神奈川県', city: '藤沢市', address: '辻堂テスト5-5-5', lat: 35.3365, lng: 139.4470, services: ['partsInstall', 'customization'], reservation: ['phone', 'web'], appeal: ['持込パーツ取付歓迎'], rating: 4.0, reviews: 17, plan: 'free', sub: 'free', hours: HOURS_WEEKDAY, note: null },
  { id: 'fx-shop-adachi', name: '足立テストモーター商会', type: 'maintenanceShop', pref: '東京都', city: '足立区', address: '梅田テスト6-6-6', lat: 35.7635, lng: 139.7920, services: ['inspection', 'maintenance', 'repair'], reservation: ['phone'], appeal: ['商用車・貨物車の整備が得意'], rating: 3.7, reviews: 6, plan: 'free', sub: 'free', hours: HOURS_WEEKDAY, note: '土曜は午前のみ' },
];

function buildShops() {
  const entries = SHOPS.map((s, i) => {
    const isPartner = s.sub === 'active';
    return {
      col: 'shops',
      id: s.id,
      data: {
        name: s.name,
        type: s.type,
        description: `${s.pref}${s.city}の${s.name}です。※アプリ動作確認用の架空店舗データ`,
        logoUrl: null,
        imageUrls: [],
        phone: null, // 架空店舗のため誤発信防止で null
        email: null,
        website: null,
        lineUrl: null,
        bookingUrl: null,
        reservationMethods: s.reservation,
        appealPoints: s.appeal,
        chainId: null,
        chainName: null,
        address: s.address,
        prefecture: s.pref,
        city: s.city,
        location: new GeoPoint(s.lat, s.lng),
        services: s.services,
        supportedMakerIds: [],
        businessHours: hoursMap(s.hours),
        businessHoursNote: s.note,
        rating: s.rating,
        reviewCount: s.reviews,
        isVerified: isPartner,
        isFeatured: s.plan === 'premium',
        verifiedAt: isPartner ? daysAgo(120 + i * 10) : null,
        planType: s.plan,
        planExpiresAt: isPartner ? ts(NOW + 300 * DAY) : null,
        subscriptionStatus: s.sub,
        revenueCatUserId: null,
        trialStartedAt: null,
        ownerId: null,
        isActive: true,
        createdAt: daysAgo(150 + i * 10),
        updatedAt: daysAgo(1),
        ...META,
      },
    };
  });
  return { entries, counts: { shops: entries.length } };
}

// ---------------------------------------------------------------------------
// 4) ドライブスポット（spots）＋ 評価（spot_ratings）
// ---------------------------------------------------------------------------
//
// 注意: アプリ（drive_log_service.dart）は FirestoreCollections.spots = 'spots' を
// 読む。'drive_spots' 定数は未使用のため、こちらの 'spots' に投入する。
// DriveSpot.fromMap は createdAt/updatedAt を Timestamp 必須で読むので必ず入れる。

const SPOTS = [
  {
    id: 'fx-spot-daikanzan', owner: P.a, name: '大観山展望台', category: 'scenicView',
    desc: '芦ノ湖と富士山を一望できる定番スポット。ターンパイクの終点で駐車場も広い。',
    lat: 35.2110, lng: 139.0140, pref: '神奈川県', city: '箱根町', parking: 100,
    tags: ['富士山', '絶景', 'ツーリング'],
    ratings: [
      { user: P.h, rating: 5, comment: '早朝は空いていて富士山がくっきり。' , days: 10 },
      { user: P.g, rating: 4, comment: '売店のコーヒーを飲みながらの景色が最高。', days: 30 },
      { user: P.e, rating: 5, comment: '初めて行きましたが感動しました！', days: 45 },
    ],
  },
  {
    id: 'fx-spot-miyagase', owner: P.h, name: '宮ヶ瀬湖畔園地', category: 'lake',
    desc: '湖沿いの気持ちいいワインディングの先にある広い園地。日曜午前は車好きが集まる。',
    lat: 35.5410, lng: 139.2480, pref: '神奈川県', city: '清川村', parking: 300,
    tags: ['湖', 'ツーリング', '旧車ミーティング'],
    ratings: [
      { user: P.a, rating: 4, comment: '道中のオギノパンに寄るのが定番です。', days: 15 },
      { user: P.d, rating: 4, comment: '駐車場が広くて停めやすい。', days: 60 },
    ],
  },
  {
    id: 'fx-spot-umihotaru', owner: P.g, name: '海ほたるPA', category: 'serviceArea',
    desc: '東京湾のど真ん中にあるパーキングエリア。360度海に囲まれた展望デッキが名物。',
    lat: 35.4640, lng: 139.8750, pref: '千葉県', city: '木更津市', parking: 400,
    tags: ['アクアライン', '夜景', 'デート'],
    ratings: [
      { user: P.e, rating: 5, comment: '夜景が想像以上でした。', days: 20 },
      { user: P.a, rating: 4, comment: '週末夕方は駐車場待ちの列に注意。', days: 50 },
      { user: P.i, rating: 4, comment: '家族連れでも楽しめました。', days: 70 },
    ],
  },
  {
    id: 'fx-spot-hitsujiyama', owner: P.d, name: '羊山公園 見晴しの丘', category: 'park',
    desc: '秩父市街と武甲山を見渡せる丘。春の芝桜シーズンは大混雑するので平日推奨。',
    lat: 35.9880, lng: 139.0900, pref: '埼玉県', city: '秩父市', parking: 80,
    tags: ['芝桜', '秩父', '紅葉'],
    ratings: [
      { user: P.c, rating: 4, comment: '芝桜の時期は本当にきれい。渋滞は覚悟。', days: 25 },
      { user: P.h, rating: 3, comment: 'シーズン外は静かでのんびりできます。', days: 90 },
    ],
  },
  {
    id: 'fx-spot-okutama', owner: P.a, name: '奥多摩湖 ダムサイトパーキング', category: 'mountain',
    desc: '奥多摩周遊道路の入口。紅葉シーズンの湖面の色は必見。早朝はバイクが多い。',
    lat: 35.7890, lng: 139.0480, pref: '東京都', city: '奥多摩町', parking: 60,
    tags: ['奥多摩', '紅葉', 'ワインディング'],
    ratings: [
      { user: P.g, rating: 4, comment: 'EVは麓で充電してから登るのが安心です。', days: 35 },
      { user: P.h, rating: 5, comment: '旧車で走ると気持ちいい道。休憩にちょうどいい。', days: 55 },
    ],
  },
  {
    id: 'fx-spot-cafe-miura', owner: P.e, name: 'シーサイドカフェ・テスト三浦', category: 'cafe',
    desc: '三浦海岸沿いの架空カフェ（動作確認用データ）。テラス席から愛車と海が一緒に眺められる設定。',
    lat: 35.1620, lng: 139.6540, pref: '神奈川県', city: '三浦市', parking: 12,
    tags: ['海沿い', 'カフェ', '愛車撮影'],
    ratings: [
      { user: P.a, rating: 4, comment: '駐車場から海バックで写真が撮れます。', days: 12 },
      { user: P.c, rating: 5, comment: 'テラス席が気持ちいい。', days: 40 },
    ],
  },
];

function buildSpots() {
  const entries = [];
  const counts = { spots: 0, spot_ratings: 0 };

  SPOTS.forEach((s, si) => {
    // averageRating / ratingCount は投入する評価から計算して整合させる
    const avg = s.ratings.reduce((sum, r) => sum + r.rating, 0) / s.ratings.length;

    s.ratings.forEach((r, ri) => {
      entries.push({
        col: 'spot_ratings',
        id: `fx-rating-${s.id.replace('fx-spot-', '')}-${ri}`,
        data: {
          spotId: s.id,
          userId: r.user.uid,
          userName: r.user.name,
          rating: r.rating,
          comment: r.comment,
          photoUrls: [],
          visitedAt: daysAgo(r.days + 1),
          createdAt: daysAgo(r.days),
          ...META,
        },
      });
      counts.spot_ratings++;
    });

    entries.push({
      col: 'spots',
      id: s.id,
      data: {
        userId: s.owner.uid,
        name: s.name,
        description: s.desc,
        category: s.category,
        tags: s.tags,
        location: { latitude: s.lat, longitude: s.lng }, // GeoPoint2D.toMap の形
        prefecture: s.pref,
        city: s.city,
        businessHours: [],
        isParkingAvailable: true,
        parkingCapacity: s.parking,
        images: [],
        averageRating: Math.round(avg * 10) / 10,
        ratingCount: s.ratings.length,
        visitCount: between(10, 120),
        isPublic: true,
        favoriteCount: between(0, 15),
        createdAt: daysAgo(100 + si * 7),
        updatedAt: daysAgo(s.ratings[0].days),
        ...META,
      },
    });
    counts.spots++;
  });

  return { entries, counts };
}

// ---------------------------------------------------------------------------
// 5) 問い合わせ（inquiries）＋ メッセージ（inquiries/{id}/messages）
// ---------------------------------------------------------------------------
//
// Inquiry.fromFirestore / InquiryMessage.fromMap（lib/models/inquiry.dart）に合わせる。
// 初回メッセージは inquiry.initialMessage に持ち、返信のみ messages サブコレクション
// に入る（inquiry_service.createInquiry の挙動）。messageCount = 1 + 返信数。

const INQUIRIES = [
  {
    // 返信あり・やりとり継続中（ユーザー側に未読1件）
    id: 'inq-fx-a-hiace',
    user: P.a, shopId: 'fx-shop-shinagawa', shopName: 'テストオート品川整備センター',
    vehicleId: 'veh-a-cargo', maker: 'Toyota', model: 'Hiace', year: 2022,
    type: 'estimate', status: 'replied', daysAgo: 6, repliedDaysAgo: 5,
    subject: 'ハイエースの車検見積もりをお願いします',
    initialMessage: '貨物登録のハイエース（毎年車検）です。車検期限が近いため、概算見積もりと入庫可能日を教えてください。',
    messages: [
      { fromShop: true, days: 5, read: true, content: 'お問い合わせありがとうございます。ハイエースDXでしたら基本料金＋法定費用で概算11万円前後です。来週火曜以降で入庫可能です。' },
      { fromShop: false, days: 4, read: true, content: 'ありがとうございます。火曜の午前でお願いできますか？代車があると助かります。' },
      { fromShop: true, days: 3, read: false, content: '火曜9時でお取りしました。代車（軽バン）もご用意します。当日は車検証と自賠責保険証をお持ちください。' },
    ],
  },
  {
    // 返信あり・対応中
    id: 'inq-fx-h-restore',
    user: P.h, shopId: 'fx-shop-yokohama', shopName: '横浜テストモータース',
    vehicleId: 'veh-h-beat', maker: 'Honda', model: 'Beat', year: 1994,
    type: 'serviceInquiry', status: 'inProgress', daysAgo: 10, repliedDaysAgo: 9,
    subject: '旧車（ビート）の幌張り替えは対応可能ですか',
    initialMessage: '1994年式ホンダビートの幌の張り替えを検討しています。持込パーツでの施工は可能でしょうか。',
    messages: [
      { fromShop: true, days: 9, read: true, content: '対応可能です。持込の幌キットでも施工できます（工賃目安3.5万円〜）。現車確認のうえ正式にお見積もりしますので、ご都合の良い日時をお知らせください。' },
    ],
  },
  {
    // 未返信（工場側に未読1件）
    id: 'inq-fx-e-first',
    user: P.e, shopId: 'fx-shop-omiya', shopName: 'さいたまテストガレージ大宮店',
    vehicleId: 'veh-e-nbox', maker: 'Honda', model: 'N-BOX', year: 2023,
    type: 'appointment', status: 'pending', daysAgo: 1, repliedDaysAgo: null,
    subject: '初回点検の予約をしたいです',
    initialMessage: '納車から半年になるN-BOXの点検をお願いしたいです。土曜日の午後は空いていますか？初めてなので流れも教えてもらえると嬉しいです。',
    messages: [],
  },
  {
    // 返信あり（コーティング見積もり）
    id: 'inq-fx-c-coating',
    user: P.c, shopId: 'fx-shop-kawasaki', shopName: '川崎テスト自動車工業',
    vehicleId: 'veh-c-fit', maker: 'Honda', model: 'Fit', year: 2020,
    type: 'estimate', status: 'replied', daysAgo: 14, repliedDaysAgo: 13,
    subject: 'ガラスコーティングの料金を教えてください',
    initialMessage: 'フィット（2020年式）のガラスコーティングを検討しています。料金と所要日数を教えてください。',
    messages: [
      { fromShop: true, days: 13, read: false, content: 'フィットクラスですと5.5万円（下地処理込み）、お預かり2日間です。今月中のご成約で撥水メンテナンスキットをお付けしています。' },
    ],
  },
];

function buildInquiries() {
  const entries = [];
  const counts = { inquiries: 0, 'inquiries/messages': 0 };

  for (const q of INQUIRIES) {
    const unreadUser = q.messages.filter((m) => m.fromShop && !m.read).length;
    const unreadShop =
      q.messages.filter((m) => !m.fromShop && !m.read).length + (q.status === 'pending' ? 1 : 0);
    const lastMs = q.messages.length
      ? NOW - Math.min(...q.messages.map((m) => m.days)) * DAY
      : NOW - q.daysAgo * DAY;

    entries.push({
      col: 'inquiries',
      id: q.id,
      data: {
        userId: q.user.uid,
        shopId: q.shopId,
        vehicleId: q.vehicleId,
        partListingId: null,
        type: q.type,
        status: q.status,
        subject: q.subject,
        initialMessage: q.initialMessage,
        attachmentUrls: [],
        shopName: q.shopName,
        vehicleMaker: q.maker,
        vehicleModel: q.model,
        vehicleYear: q.year,
        createdAt: daysAgo(q.daysAgo),
        updatedAt: ts(lastMs),
        repliedAt: q.repliedDaysAgo != null ? daysAgo(q.repliedDaysAgo) : null,
        closedAt: null,
        messageCount: 1 + q.messages.length, // 初回 + 返信数（サービス実装と同じ数え方）
        unreadCountUser: unreadUser,
        unreadCountShop: unreadShop,
        ...META,
      },
    });
    counts.inquiries++;

    q.messages.forEach((m, mi) => {
      entries.push({
        // messages は inquiries/{id}/messages サブコレクション
        path: `inquiries/${q.id}/messages/msg-fx-${mi}`,
        col: 'inquiries/messages',
        data: {
          senderId: m.fromShop ? q.shopId : q.user.uid,
          isFromShop: m.fromShop,
          content: m.content,
          attachmentUrls: [],
          sentAt: daysAgo(m.days),
          isRead: m.read,
          ...META,
        },
      });
      counts['inquiries/messages']++;
    });
  }

  return { entries, counts };
}

// ---------------------------------------------------------------------------
// 6) 公開ドライブログ（drive_logs）＋ いいね（drive_log_likes）
// ---------------------------------------------------------------------------
//
// DriveLog.fromMap（lib/models/drive_log.dart）に合わせる。
// statistics はサブマップ（DriveStatistics.toMap の形）。
// likeCount は drive_log_likes の件数と整合させる。

const DRIVE_LOGS = [
  {
    id: 'dl-fx-a-izu', user: P.a, vehicleId: 'veh-a-sports',
    title: '伊豆スカイライン 早朝ツーリング',
    desc: '熱海峠から天城高原まで。雲ひとつない快晴で富士山も駿河湾も見放題でした。',
    daysAgo: 20, km: 182.4, hours: 4.0, maxSpeed: 88, weather: 'sunny',
    roadTypes: ['highway', 'mountainRoad'], tags: ['伊豆', 'ツーリング', '絶景'],
    start: { lat: 35.6335, lng: 139.7385, addr: '東京都品川区' },
    end: { lat: 34.8940, lng: 139.0610, addr: '静岡県伊豆市（天城高原）' },
    fuel: { consumed: 12.8, efficiency: 14.3 },
    likes: 4,
  },
  {
    id: 'dl-fx-g-karuizawa', user: P.g, vehicleId: 'veh-g-leaf',
    title: 'リーフで軽井沢往復（充電1回）',
    desc: '碓氷軽井沢ICそばで30分急速充電を挟んで往復。冬より電費が伸びて快適でした。',
    daysAgo: 13, km: 165.0, hours: 3.5, maxSpeed: 95, weather: 'cloudy',
    roadTypes: ['highway', 'nationalRoad'], tags: ['EV', '軽井沢', '長距離'],
    start: { lat: 35.5308, lng: 139.7030, addr: '神奈川県川崎市' },
    end: { lat: 36.3420, lng: 138.6350, addr: '長野県軽井沢町' },
    fuel: null, // EV のため燃料統計なし
    likes: 3,
  },
  {
    id: 'dl-fx-h-miyagase', user: P.h, vehicleId: 'veh-h-beat',
    title: '宮ヶ瀬 日曜朝ミーティング参加',
    desc: 'ビートで湖畔の朝ミーティングへ。カプチーノ2台とAZ-1にも会えました。',
    daysAgo: 9, km: 78.6, hours: 2.2, maxSpeed: 72, weather: 'sunny',
    roadTypes: ['prefecturalRoad', 'mountainRoad'], tags: ['旧車', '宮ヶ瀬', 'ミーティング'],
    start: { lat: 35.6090, lng: 139.7300, addr: '東京都品川区' },
    end: { lat: 35.5410, lng: 139.2480, addr: '神奈川県清川村（宮ヶ瀬湖畔園地）' },
    fuel: { consumed: 4.9, efficiency: 16.0 },
    likes: 3,
  },
  {
    id: 'dl-fx-e-shonan', user: P.e, vehicleId: 'veh-e-nbox',
    title: 'はじめての湘南ドライブ',
    desc: '納車後はじめての遠出。江の島まで海沿いを走りました。渋滞も楽しい！',
    daysAgo: 6, km: 52.3, hours: 2.8, maxSpeed: 62, weather: 'sunny',
    roadTypes: ['nationalRoad', 'coastalRoad'], tags: ['湘南', '初ドライブ'],
    start: { lat: 35.4660, lng: 139.6220, addr: '神奈川県横浜市' },
    end: { lat: 35.3020, lng: 139.4800, addr: '神奈川県藤沢市（江の島）' },
    fuel: { consumed: 3.1, efficiency: 16.9 },
    likes: 2,
  },
  {
    id: 'dl-fx-d-chichibu', user: P.d, vehicleId: 'veh-d-prius',
    title: '秩父 紅葉と羊山公園',
    desc: '正丸峠経由で秩父へ。プリウスの燃費は28km/L。羊山公園の見晴しの丘で休憩。',
    daysAgo: 4, km: 148.9, hours: 4.5, maxSpeed: 76, weather: 'sunny',
    roadTypes: ['nationalRoad', 'mountainRoad'], tags: ['秩父', '紅葉', '燃費記録'],
    start: { lat: 35.7355, lng: 139.6530, addr: '東京都練馬区' },
    end: { lat: 35.9880, lng: 139.0900, addr: '埼玉県秩父市（羊山公園）' },
    fuel: { consumed: 5.3, efficiency: 28.1 },
    likes: 2,
  },
];

function buildDriveLogs() {
  const entries = [];
  const counts = { drive_logs: 0, drive_log_likes: 0 };

  DRIVE_LOGS.forEach((d, di) => {
    const startMs = NOW - d.daysAgo * DAY + 8 * 60 * 60 * 1000; // 朝8時出発の体
    const durationSec = Math.round(d.hours * 3600);
    const likers = pickLikers(d.user.uid, d.likes, di + 2);

    likers.forEach((uid, li) => {
      entries.push({
        col: 'drive_log_likes',
        id: `${d.id}_${uid}`,
        data: {
          driveLogId: d.id,
          userId: uid,
          createdAt: ts(startMs + durationSec * 1000 + (li + 1) * 5 * 60 * 60 * 1000),
          ...META,
        },
      });
      counts.drive_log_likes++;
    });

    entries.push({
      col: 'drive_logs',
      id: d.id,
      data: {
        userId: d.user.uid,
        vehicleId: d.vehicleId,
        status: 'completed',
        title: d.title,
        description: d.desc,
        startLocation: { latitude: d.start.lat, longitude: d.start.lng },
        endLocation: { latitude: d.end.lat, longitude: d.end.lng },
        startAddress: d.start.addr,
        endAddress: d.end.addr,
        startTime: ts(startMs),
        endTime: ts(startMs + durationSec * 1000),
        statistics: {
          totalDistance: d.km,
          totalDuration: durationSec,
          averageSpeed: Math.round((d.km / d.hours) * 10) / 10,
          maxSpeed: d.maxSpeed,
          ...(d.fuel
            ? { fuelConsumed: d.fuel.consumed, fuelEfficiency: d.fuel.efficiency }
            : {}),
          stopCount: between(1, 5),
          totalStopDuration: between(600, 3600),
        },
        weather: d.weather,
        roadTypes: d.roadTypes,
        photoUrls: [],
        isPublic: true, // 公開ログ（コミュニティのドライブフィードに出す）
        likeCount: likers.length,
        commentCount: 0,
        tags: d.tags,
        createdAt: ts(startMs + durationSec * 1000),
        updatedAt: ts(startMs + durationSec * 1000),
        ...META,
      },
    });
    counts.drive_logs++;
  });

  return { entries, counts };
}

// ---------------------------------------------------------------------------
// 書き込み / 削除
// ---------------------------------------------------------------------------

/// Firestore の一括書き込みは1バッチ500件が上限のため 400件で分割する。
async function commitInChunks(db, entries, label) {
  const CHUNK = 400;
  for (let i = 0; i < entries.length; i += CHUNK) {
    const batch = db.batch();
    for (const e of entries.slice(i, i + CHUNK)) {
      const ref = e.path ? db.doc(e.path) : db.collection(e.col).doc(e.id);
      batch.set(ref, e.data, { merge: true }); // 固定ID + merge で冪等
    }
    await batch.commit();
    console.log(`  ${label}: ${Math.min(i + CHUNK, entries.length)}/${entries.length}`);
  }
}

/// seedTag を目印に削除する。inquiries は messages サブコレクションを先に消す。
async function deleteSeed(db) {
  // inquiries（サブコレクション持ち）を先に処理
  {
    const snap = await db
      .collection('inquiries')
      .where('seedTag', '==', SEED_TAG)
      .get();
    let msgCount = 0;
    for (const doc of snap.docs) {
      const msgs = await doc.ref.collection('messages').get();
      if (!DRY_RUN) {
        const batch = db.batch();
        msgs.docs.forEach((m) => batch.delete(m.ref));
        batch.delete(doc.ref);
        await batch.commit();
      }
      msgCount += msgs.size;
    }
    console.log(`削除 inquiries: ${snap.size}件（messages: ${msgCount}件）`);
  }

  const cols = [
    'posts', 'comments', 'post_likes', 'comment_likes',
    'user_part_listings', 'shops', 'spots', 'spot_ratings',
    'drive_logs', 'drive_log_likes',
  ];
  for (const col of cols) {
    let total = 0;
    for (;;) {
      const snap = await db
        .collection(col)
        .where('seedTag', '==', SEED_TAG)
        .limit(400)
        .get();
      if (snap.empty) break;
      if (!DRY_RUN) {
        const batch = db.batch();
        snap.docs.forEach((d) => batch.delete(d.ref));
        await batch.commit();
      }
      total += snap.size;
      if (DRY_RUN) break;
    }
    console.log(`削除 ${col}: ${total}件`);
  }
}

async function main() {
  // dry-run はデータ組み立てと件数表示のみで Firestore に触れないため、
  // 認証情報がない環境でも動くよう初期化をスキップする。
  // （Timestamp / GeoPoint は initializeApp なしで生成できる）
  if (!DRY_RUN) {
    admin.initializeApp({ projectId: 'trust-car-platform' });
  }

  if (DELETE) {
    if (DRY_RUN) {
      console.log('--delete は --dry-run と併用できません（削除対象の検索に接続が必要です）。');
      return;
    }
    await deleteSeed(admin.firestore());
    return;
  }

  const parts = [
    buildCommunity(),
    buildPartListings(),
    buildShops(),
    buildSpots(),
    buildInquiries(),
    buildDriveLogs(),
  ];
  const entries = parts.flatMap((p) => p.entries);
  const counts = Object.assign({}, ...parts.map((p) => p.counts));

  console.log(`--- 作成予定（seedTag: ${SEED_TAG}）---`);
  const labels = {
    posts: '愛車投稿          ',
    comments: 'コメント          ',
    post_likes: '投稿いいね        ',
    comment_likes: 'コメントいいね    ',
    user_part_listings: 'パーツ出品        ',
    shops: '整備工場          ',
    spots: 'ドライブスポット  ',
    spot_ratings: 'スポット評価      ',
    inquiries: '問い合わせ        ',
    'inquiries/messages': '└ 返信メッセージ ',
    drive_logs: '公開ドライブログ  ',
    drive_log_likes: 'ドライブログいいね',
  };
  for (const [key, label] of Object.entries(labels)) {
    console.log(`  ${label}: ${counts[key]}件`);
  }
  console.log(`  合計ドキュメント  : ${entries.length}件`);

  const partnerCount = SHOPS.filter((s) => s.sub === 'active').length;
  console.log(`  （工場内訳: 提携 ${partnerCount} / 未提携 ${SHOPS.length - partnerCount}）`);

  if (DRY_RUN) {
    console.log('\n--dry-run のため書き込んでいません。');
    console.log('前提: seed_personas.js を先に実行してください（uid / vehicleId を参照します）。');
    return;
  }

  await commitInChunks(admin.firestore(), entries, '書き込み');
  console.log('\n完了しました。');
  console.log('ログイン情報や確認手順は docs/TEST_DATA_GUIDE.md を参照してください。');
  console.log('後片付け: node scripts/seed_full_experience.js --delete' + (EMULATOR ? ' --emulator' : ''));
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
