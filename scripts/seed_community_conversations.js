/**
 * seed_community_conversations.js
 *
 * 「みんなの投稿」タブを、ペルソナ A〜I が実際に会話している状態にする。
 *
 * seed_full_experience.js が作る 9 投稿は各ペルソナの「代表的な1件」で、
 * フィードを流し読みすると会話が続いている感じがしない。こちらは同じ
 * コレクション（posts / comments / post_likes / comment_likes）に、
 * ペルソナ同士が質問し合い・答え合う流れを 30 スレッド分投入する。
 *
 * 書き込み先:
 *   posts          コミュニティ投稿（docId: post-cv-*）
 *   comments       コメント・返信（docId: cmt-cv-*）
 *   post_likes     投稿いいね（docId: `${postId}_${uid}`）
 *   comment_likes  コメントいいね（docId: `${commentId}_${uid}`）
 *
 * seed_full_experience.js とは docId プレフィックスが違うので共存できる。
 *
 * 使い方:
 *   node seed_community_conversations.js --emulator     # Emulator へ投入
 *   node seed_community_conversations.js --dry-run      # 件数だけ確認
 *   node seed_community_conversations.js --delete --emulator   # 後片付け
 *
 *   本番へ入れる場合は GOOGLE_APPLICATION_CREDENTIALS を設定して
 *   フラグなしで実行する（デモデータなので通常は不要）。
 */

const admin = require('firebase-admin');

const has = (f) => process.argv.includes(f);
const EMULATOR = has('--emulator');
const DRY_RUN = has('--dry-run');
const DELETE = has('--delete');

if (EMULATOR) {
  process.env.FIRESTORE_EMULATOR_HOST =
    process.env.FIRESTORE_EMULATOR_HOST || 'localhost:8080';
  process.env.FIREBASE_AUTH_EMULATOR_HOST =
    process.env.FIREBASE_AUTH_EMULATOR_HOST || 'localhost:9099';
}

const SEED_TAG = 'community-conversations';
const META = { isSeed: true, seedTag: SEED_TAG };

const DAY = 24 * 60 * 60 * 1000;
const HOUR = 60 * 60 * 1000;
const NOW = Date.now();

// 決定的な乱数（実行のたびに顔ぶれが変わると動作確認にならない）
let _seed = 20260818;
function rand() {
  _seed = (_seed * 1103515245 + 12345) % 2147483648;
  return _seed / 2147483648;
}
const between = (a, b) => a + Math.floor(rand() * (b - a + 1));
const ts = (ms) => admin.firestore.Timestamp.fromMillis(ms);

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
const ALL = Object.values(P);

function pickLikers(authorUid, n, offset) {
  const others = ALL.filter((p) => p.uid !== authorUid);
  const out = [];
  for (let k = 0; k < Math.min(n, others.length); k++) {
    out.push(others[(offset + k) % others.length].uid);
  }
  return out;
}

// 車両タグ（seed_personas.js の vehicles と ID を揃える）
const V = {
  aSports: { vehicleId: 'veh-a-sports', makerName: 'Mazda', modelName: 'Roadster', year: 2019 },
  aCargo: { vehicleId: 'veh-a-cargo', makerName: 'Toyota', modelName: 'Hiace', year: 2018 },
  aLease: { vehicleId: 'veh-a-lease', makerName: 'Nissan', modelName: 'Note', year: 2023 },
  dPrius: { vehicleId: 'veh-d-prius', makerName: 'Toyota', modelName: 'Prius', year: 2022 },
  eNbox: { vehicleId: 'veh-e-nbox', makerName: 'Honda', modelName: 'N-BOX', year: 2023 },
  gLeaf: { vehicleId: 'veh-g-leaf', makerName: 'Nissan', modelName: 'Leaf', year: 2021 },
  hBeat: { vehicleId: 'veh-h-beat', makerName: 'Honda', modelName: 'Beat', year: 1994 },
};

// ---------------------------------------------------------------------------
// 会話スレッド
// ---------------------------------------------------------------------------
//
// replyTo は同じ投稿内のコメント index（0 始まり）を指す。
// daysAgo が大きいほど古い投稿。フィードは新しい順に並ぶ。

const THREADS = [
  {
    id: 'q-first-inspection',
    author: P.e,
    category: 'question',
    daysAgo: 1,
    content:
      '初めての12ヶ月点検が近づいてきました。ディーラーだと2万円くらいと言われたのですが、'
      + 'これって普通ですか？ 何を見てもらえるのかもよく分かっていません…'
      + ' #点検 #初心者',
    hashtags: ['点検', '初心者'],
    vehicleTag: V.eNbox,
    likes: 5,
    comments: [
      { author: P.d, content: '法定12ヶ月点検なら妥当な金額です。26項目の点検で、下回りやブレーキも見てもらえます。' },
      { author: P.a, content: '見積書に「点検料」と「交換部品代」が分かれて書いてあるか確認するといいですよ。' },
      { author: P.e, content: 'ありがとうございます！ 見積もり、部品代が別で書いてありました。安心しました。', replyTo: 1 },
      { author: P.c, content: '2社で相見積もりを取ると相場感が掴めます。私はいつもそうしています。' },
      { author: P.b, content: '記録を残しておくと売却時に効いてきます。アプリに入れておくのをおすすめします。' },
      { author: P.e, content: '売却まで考えていませんでした…！ 記録つけます。', replyTo: 4 },
    ],
  },
  {
    id: 'ev-winter-efficiency',
    author: P.g,
    category: 'review',
    daysAgo: 2,
    content:
      'リーフで真冬の電費を1シーズン記録してみました。夏 7.2km/kWh に対して冬は 5.1km/kWh。'
      + '暖房を使うと3割落ちます。シートヒーター中心にすると 6.0 くらいまで戻ります。'
      + ' #EV #電費',
    hashtags: ['EV', '電費'],
    vehicleTag: V.gLeaf,
    likes: 6,
    comments: [
      { author: P.d, content: '3割は大きいですね。ハイブリッドも冬は燃費落ちますが、ここまでではないです。' },
      { author: P.i, content: 'EVも検討しているので参考になります。航続距離は実際どのくらいですか？' },
      { author: P.g, content: '公称より2割ほど短く見ています。冬の長距離は充電計画を立てる感じです。', replyTo: 1 },
      { author: P.e, content: 'シートヒーターの方が効率いいんですね。知らなかったです。' },
      { author: P.a, content: 'データを取って比較するの、いいですね。うちも燃費記録つけようかな。' },
    ],
  },
  {
    id: 'q-used-suv-mileage',
    author: P.i,
    category: 'question',
    daysAgo: 3,
    content:
      '中古SUVを探しています。走行距離8万kmと5万kmで価格が40万円違うのですが、'
      + '距離が短い方を選ぶべきでしょうか。年式は同じです。 #中古車 #購入相談',
    hashtags: ['中古車', '購入相談'],
    likes: 7,
    comments: [
      { author: P.f, content: '距離より整備記録の有無だと思います。8万kmでも記録がしっかりしている個体の方が安心です。' },
      { author: P.d, content: '同意です。オイル交換の履歴が飛んでいる車は、距離が短くても避けます。' },
      { author: P.i, content: 'なるほど…記録簿を見せてもらうよう頼んでみます。', replyTo: 0 },
      { author: P.a, content: 'あと下回りの錆は必ず見てください。融雪剤を使う地域の車は差が出ます。' },
      { author: P.h, content: '旧車の世界だと距離より保管状態です。屋根付きかどうかで全然違います。' },
      { author: P.c, content: '購入前に第三者機関の車両チェックを入れるのも手ですよ。' },
    ],
  },
  {
    id: 'oil-change-interval',
    author: P.d,
    category: 'maintenance',
    daysAgo: 4,
    content:
      'オイル交換、メーカー推奨は15,000kmですが私は5,000kmで替えています。'
      + '4年28,000kmでエンジン内部は綺麗なままでした。過剰かもしれませんが安心料ですね。'
      + ' #オイル交換 #メンテナンス',
    hashtags: ['オイル交換', 'メンテナンス'],
    vehicleTag: V.dPrius,
    likes: 6,
    comments: [
      { author: P.h, content: 'Beat は3,000kmで替えています。旧車は特に神経質になりますね。' },
      { author: P.a, content: 'ハイエースは仕事で使うので距離が伸びるのが早く、5,000kmは同じです。' },
      { author: P.e, content: '軽自動車もそのくらいの方がいいですか？' },
      { author: P.d, content: 'ターボ車なら短めが安心です。NAなら7,000〜10,000kmでも十分だと思います。', replyTo: 2 },
      { author: P.g, content: 'EVはオイル交換がないので、この話題を羨ましく眺めています。' },
      { author: P.b, content: '20台分だと交換周期の管理だけで大仕事です。まとめて業者に頼んでいます。' },
    ],
  },
  {
    id: 'fleet-expiry-management',
    author: P.b,
    category: 'general',
    daysAgo: 5,
    content:
      '社用車20台の車検期限管理、Excelから卒業しました。貨物車は毎年車検なので'
      + '乗用車と同じ感覚でいると危ないです。今は期限の近い順に一覧で見ています。'
      + ' #法人 #車検管理',
    hashtags: ['法人', '車検管理'],
    likes: 5,
    comments: [
      { author: P.a, content: '個人でも4台あると同じ問題が起きます。ハイエースだけ毎年で混乱しました。' },
      { author: P.c, content: '20台まとめて整備工場に出すと単価交渉できるものですか？' },
      { author: P.b, content: 'できます。年間契約にすると1台あたり1〜2割は下がりました。', replyTo: 1 },
      { author: P.f, content: '期限切れは本当に怖いので、通知があるのは助かりますね。' },
    ],
  },
  {
    id: 'beat-parts-hunting',
    author: P.h,
    category: 'customization',
    daysAgo: 6,
    content:
      '30年前の軽オープン、部品の廃番との戦いです。今回は幌の骨組みを探して3ヶ月。'
      + '結局オークションで程度のいい中古を見つけました。 #ビート #旧車 #部品探し',
    hashtags: ['ビート', '旧車', '部品探し'],
    vehicleTag: V.hBeat,
    likes: 6,
    comments: [
      { author: P.a, content: '3ヶ月…！ その根気には頭が下がります。' },
      { author: P.d, content: '廃番部品はリプロダクト品も出ているんですか？' },
      { author: P.h, content: '人気車種なら出ます。Beat は少しずつ増えてきました。', replyTo: 1 },
      { author: P.i, content: '旧車を買うならこういう覚悟が要るんですね。勉強になります。' },
      { author: P.f, content: '手放すときに部品取り車として探している人もいますよ。' },
    ],
  },
  {
    id: 'sold-with-records',
    author: P.f,
    category: 'general',
    daysAgo: 7,
    content:
      '10年12万kmのプリウスを売却しました。整備記録を全部揃えて出したら、'
      + '査定が想定より18万円高くつきました。記録は資産だと実感しています。'
      + ' #売却 #整備記録',
    hashtags: ['売却', '整備記録'],
    likes: 8,
    comments: [
      { author: P.i, content: '買う側としても、記録がある車は安心して買えます。' },
      { author: P.d, content: '18万は大きいですね。地道に記録をつけてきた甲斐がありました。' },
      { author: P.a, content: 'これは説得力があります。うちも4台分きちんと残しておきます。' },
      { author: P.e, content: '新車を買ったばかりですが、今から記録つけ始めます！' },
      { author: P.f, content: 'それが一番です。最初からやっておくと後が楽ですよ。', replyTo: 3 },
      { author: P.b, content: '法人でも同じで、売却時の残価が変わってきます。' },
    ],
  },
  {
    id: 'q-winter-tire-storage',
    author: P.e,
    category: 'question',
    daysAgo: 8,
    content:
      '冬タイヤに履き替えたのですが、夏タイヤの保管場所に困っています。'
      + 'ベランダに置いておいて大丈夫でしょうか？ #タイヤ #保管',
    hashtags: ['タイヤ', '保管'],
    likes: 4,
    comments: [
      { author: P.d, content: '直射日光と雨はゴムを傷めます。カバーをかけて日陰に置いてください。' },
      { author: P.a, content: '横積みで、空気圧を少し抜いておくといいですよ。' },
      { author: P.h, content: 'ホイール付きなら横積み、タイヤ単体なら縦置きが基本です。' },
      { author: P.e, content: 'ホイール付きなので横積みにします。カバーも買ってきます。', replyTo: 2 },
      { author: P.c, content: 'タイヤ保管サービスを使う手もあります。年6,000円くらいからありますよ。' },
    ],
  },
  {
    id: 'shop-selection-criteria',
    author: P.c,
    category: 'general',
    daysAgo: 9,
    content:
      '整備工場を選ぶとき、私は「見積もりの内訳を細かく出してくれるか」を一番見ています。'
      + '一式いくら、という見積もりのところは避けるようになりました。 #整備工場 #工場選び',
    hashtags: ['整備工場', '工場選び'],
    likes: 6,
    comments: [
      { author: P.a, content: '同感です。作業内容を説明してくれるかどうかで信頼度が違います。' },
      { author: P.h, content: '旧車を持ち込むと断られることも多いので、受けてくれる工場は大事にしています。' },
      { author: P.b, content: '法人だと納期の正確さも重視します。車が止まると仕事が止まるので。' },
      { author: P.c, content: '納期の観点は抜けていました。確かに大事ですね。', replyTo: 2 },
      { author: P.e, content: '初心者だと何を聞けばいいか分からないのですが、質問しても嫌がられませんか？' },
      { author: P.c, content: '嫌がる工場なら、そこはやめた方がいいという判断材料になります。', replyTo: 4 },
    ],
  },
  {
    id: 'user-inspection-diy',
    author: P.h,
    category: 'maintenance',
    daysAgo: 10,
    content:
      'ユーザー車検に行ってきました。費用は法定費用のみで約35,000円。'
      + '光軸調整だけ事前にテスター屋さんでやってもらいました。 #ユーザー車検 #DIY',
    hashtags: ['ユーザー車検', 'DIY'],
    vehicleTag: V.hBeat,
    likes: 7,
    comments: [
      { author: P.d, content: '一度やってみたいのですが、落ちたときが不安で踏み切れません。' },
      { author: P.a, content: '平日に行く必要があるのがネックですよね。自営業でも半日は潰れます。' },
      { author: P.h, content: '再検査はその日のうちなら2回まで無料です。意外と気楽ですよ。', replyTo: 0 },
      { author: P.b, content: '20台では現実的ではないですが、個人なら選択肢ですね。' },
      { author: P.e, content: '35,000円…！ ディーラーの見積もりと全然違います。' },
      { author: P.h, content: '整備をどこまで自分でやるかの差です。安心を買うと考えれば工場も妥当です。', replyTo: 4 },
    ],
  },
  {
    id: 'dashcam-recommendation',
    author: P.e,
    category: 'question',
    daysAgo: 11,
    content:
      'ドライブレコーダーを付けたいのですが、前後2カメラで1万円台と3万円台、'
      + 'そんなに違うものですか？ #ドラレコ #カー用品',
    hashtags: ['ドラレコ', 'カー用品'],
    likes: 5,
    comments: [
      { author: P.a, content: '夜間の画質とナンバーの読み取りやすさが違います。事故時に効くのはそこです。' },
      { author: P.g, content: '駐車監視を使うなら電源の取り方も確認してください。バッテリーに負担がかかります。' },
      { author: P.d, content: 'HDR対応かどうかで逆光時の見え方が変わります。3万円台ならまず入っています。' },
      { author: P.e, content: '夜間の画質は考えていませんでした。もう少し予算を上げてみます。', replyTo: 0 },
      { author: P.h, content: '旧車だと配線を隠すのに苦労します。取り付け工賃も見ておくといいですよ。' },
    ],
  },
  {
    id: 'lease-return-check',
    author: P.a,
    category: 'general',
    daysAgo: 12,
    content:
      'リースのノート、返却まであと8ヶ月。傷のチェック基準を確認したら'
      + '10cm以上の擦り傷は査定対象とのこと。今のうちに直しておくか悩みます。'
      + ' #リース #返却',
    hashtags: ['リース', '返却'],
    vehicleTag: V.aLease,
    likes: 4,
    comments: [
      { author: P.b, content: '法人リースも同じです。返却前に見積もりを取って、直すか払うか比較しています。' },
      { author: P.c, content: '板金に出す方が安いことも多いですよ。2社で見積もり取ってみては。' },
      { author: P.a, content: '比較してみます。返却時精算だと言い値になりそうで怖いので。', replyTo: 0 },
      { author: P.i, content: 'リースって最終的にどのくらいかかるものなんでしょう。' },
    ],
  },
  {
    id: 'hiace-camping',
    author: P.a,
    category: 'drive',
    daysAgo: 13,
    content:
      'ハイエースで車中泊しながら仕事道具を運ぶ生活も5年目。'
      + '荷室にベッドキットを組んでから腰痛が減りました。 #ハイエース #車中泊',
    hashtags: ['ハイエース', '車中泊'],
    vehicleTag: V.aCargo,
    likes: 5,
    comments: [
      { author: P.i, content: '車中泊、SUVでもできますか？ 候補に入れているのですが。' },
      { author: P.e, content: '軽でもやっている人いますよね。憧れます。' },
      { author: P.a, content: 'SUVなら後席を倒してフラットになる車種を選ぶといいですよ。', replyTo: 0 },
      { author: P.h, content: 'Beat は2人乗りなので車中泊は諦めています…' },
      { author: P.g, content: 'EVだと電源が使えるので車中泊と相性がいいです。' },
    ],
  },
  {
    id: 'battery-dead',
    author: P.h,
    category: 'maintenance',
    daysAgo: 14,
    content:
      '2週間乗らなかったらバッテリーが上がっていました。旧車は電装が弱いので'
      + '充電器を繋ぎっぱなしにするようにしています。 #バッテリー #旧車',
    hashtags: ['バッテリー', '旧車'],
    likes: 5,
    comments: [
      { author: P.d, content: 'ハイブリッドも補機バッテリーが上がることがあります。油断できません。' },
      { author: P.a, content: 'ロードスターも冬場は乗る頻度が落ちるので、同じ悩みです。' },
      { author: P.g, content: 'EVも12Vバッテリーは普通に上がります。意外と知られていないですね。' },
      { author: P.e, content: 'バッテリーって何年くらいで交換ですか？' },
      { author: P.d, content: '3〜5年が目安です。エンジンのかかりが悪くなったら早めに。', replyTo: 3 },
    ],
  },
  {
    id: 'coating-worth-it',
    author: P.c,
    category: 'review',
    daysAgo: 15,
    content:
      'ガラスコーティングを入れて1年経ちました。洗車が水洗いだけで済むようになり、'
      + '結果的に洗車の頻度が上がりました。8万円の価値はあったと思います。'
      + ' #コーティング #洗車',
    hashtags: ['コーティング', '洗車'],
    likes: 6,
    comments: [
      { author: P.a, content: '洗車が楽になるのは大きいですね。ロードスターに入れようか迷っています。' },
      { author: P.h, content: '旧車の塗装は弱いので、施工前に下地の状態を見てもらった方がいいです。' },
      { author: P.g, content: '白系の車だと効果が分かりにくいという話も聞きますが、どうですか？' },
      { author: P.c, content: '濃色の方が差は出ますね。ただ汚れの落ちやすさは色に関係なく効きます。', replyTo: 2 },
      { author: P.e, content: 'ディーラーで勧められて断ったのですが、入れておけばよかったかも。' },
    ],
  },
  {
    id: 'recall-notice',
    author: P.d,
    category: 'general',
    daysAgo: 16,
    content:
      'リコールの通知が来たので入庫してきました。無償で部品交換。'
      + '通知が来なくても、車台番号でメーカーサイトから確認できます。 #リコール',
    hashtags: ['リコール'],
    likes: 5,
    comments: [
      { author: P.a, content: '中古で買った車は通知が届かないことがあるので、自分で確認は大事ですね。' },
      { author: P.i, content: '中古車を買うとき、リコール未対応かどうかも確認した方がいいですか？' },
      { author: P.d, content: 'はい。未実施なら納車前に対応してもらえるか聞いてみてください。', replyTo: 1 },
      { author: P.b, content: '20台分の確認は骨が折れますが、年1回まとめてやっています。' },
    ],
  },
  {
    id: 'spring-drive-izu',
    author: P.a,
    category: 'drive',
    daysAgo: 17,
    content:
      '伊豆スカイラインを走ってきました。桜と海が同時に見えるこの時期が一番好きです。'
      + ' #ドライブ #伊豆スカイライン',
    hashtags: ['ドライブ', '伊豆スカイライン'],
    vehicleTag: V.aSports,
    likes: 7,
    comments: [
      { author: P.h, content: '同じ日に近くを走っていました。すれ違っていたかもしれませんね。' },
      { author: P.g, content: 'EVで行くと充電スポットが限られるのが悩みどころです。' },
      { author: P.e, content: '運転に慣れたら行ってみたいです。初心者でも大丈夫な道ですか？' },
      { author: P.a, content: '道幅も広くて走りやすいですよ。景色がいいので無理せずゆっくりで。', replyTo: 2 },
      { author: P.d, content: '燃費を気にせず走りたくなる道ですね。' },
    ],
  },
  {
    id: 'charging-infra',
    author: P.g,
    category: 'general',
    daysAgo: 18,
    content:
      '自宅充電がないEV生活は正直しんどいです。逆に自宅で充電できるなら'
      + 'ガソリン車より圧倒的に楽。ここが分かれ目だと思います。 #EV #充電',
    hashtags: ['EV', '充電'],
    vehicleTag: V.gLeaf,
    likes: 6,
    comments: [
      { author: P.i, content: 'マンションなので自宅充電は難しそうです。EVは見送りかな…' },
      { author: P.a, content: '正直な意見ありがたいです。営業車をEVにする話が出ていたので参考になります。' },
      { author: P.b, content: '法人だと事業所に充電器を置く前提になりますね。補助金も出ます。' },
      { author: P.g, content: '事業所設置なら相性いいと思います。日中に充電できるのは強いです。', replyTo: 2 },
      { author: P.d, content: 'ハイブリッドが現実解になっている理由がよく分かります。' },
    ],
  },
  {
    id: 'q-wiper-timing',
    author: P.e,
    category: 'question',
    daysAgo: 19,
    content:
      'ワイパーが少し拭き残すようになりました。まだ1年経っていないのですが'
      + '交換した方がいいですか？ #消耗品',
    hashtags: ['消耗品'],
    likes: 3,
    comments: [
      { author: P.d, content: 'ゴムだけなら1,000円程度です。拭き残しが出たら交換のサインですよ。' },
      { author: P.h, content: '青空駐車だと劣化が早いです。半年〜1年が目安ですね。' },
      { author: P.e, content: 'ゴムだけ替えられるんですね！ やってみます。', replyTo: 0 },
      { author: P.a, content: '撥水コートを併用すると、雨の日の視界がかなり変わりますよ。' },
    ],
  },
  {
    id: 'fleet-tire-bulk',
    author: P.b,
    category: 'maintenance',
    daysAgo: 20,
    content:
      '20台分のタイヤ交換を1社にまとめて発注。1台あたり単価が18%下がりました。'
      + '入庫スケジュールを2週間に分散させたのがポイントです。 #法人 #タイヤ',
    hashtags: ['法人', 'タイヤ'],
    likes: 5,
    comments: [
      { author: P.c, content: '18%は大きいですね。個人でも家族の車をまとめると効きそうです。' },
      { author: P.a, content: '4台分まとめて相談してみます。同じ工場に出しているので。' },
      { author: P.b, content: 'まとめる前提で見積もりを取ると反応が違いますよ。', replyTo: 1 },
      { author: P.f, content: '業者側も予定が立てやすいので、win-winなんでしょうね。' },
    ],
  },
  {
    id: 'scrapping-procedure',
    author: P.f,
    category: 'general',
    daysAgo: 21,
    content:
      '廃車の手続きをまとめておきます。永久抹消登録は自分でもできて、'
      + '自動車税と重量税の還付も受けられます。書類さえ揃えば難しくないです。'
      + ' #廃車 #手続き',
    hashtags: ['廃車', '手続き'],
    likes: 6,
    comments: [
      { author: P.a, content: '還付があるのを知らずに業者任せにしていました。次は自分でやります。' },
      { author: P.i, content: '事故車でも還付は受けられるんですか？' },
      { author: P.f, content: '受けられます。抹消の時期によって金額が変わるので早めに。', replyTo: 1 },
      { author: P.h, content: '旧車は部品取りとして引き取られることも多いので、そちらも検討の価値ありです。' },
      { author: P.b, content: '法人だと減価償却の処理も絡むので、経理と相談ですね。' },
    ],
  },
  {
    id: 'fuel-log-habit',
    author: P.d,
    category: 'general',
    daysAgo: 22,
    content:
      '給油のたびに燃費を記録して4年。季節変動やタイヤ交換の影響が数字で見えるので、'
      + '異常にも早く気づけます。先月は急に燃費が落ちて、空気圧不足でした。'
      + ' #燃費 #記録',
    hashtags: ['燃費', '記録'],
    vehicleTag: V.dPrius,
    likes: 7,
    comments: [
      { author: P.g, content: '電費でも同じことをしています。数字で見ると発見が多いですよね。' },
      { author: P.e, content: '空気圧って燃費に影響するんですね。月1で見るようにします。' },
      { author: P.a, content: '4台分やるとなると大変ですが、価値はありそうです。' },
      { author: P.d, content: '給油時にレシートを撮っておくだけでも違いますよ。', replyTo: 2 },
      { author: P.c, content: '異常の早期発見という視点がいいですね。' },
    ],
  },
  {
    id: 'q-child-seat',
    author: P.b,
    category: 'question',
    daysAgo: 23,
    content:
      '社員から社用車にチャイルドシートを付けたいと相談がありました。'
      + '業務利用の車に取り付ける場合、何か注意点はありますか？ #チャイルドシート',
    hashtags: ['チャイルドシート'],
    likes: 4,
    comments: [
      { author: P.a, content: 'ISOFIX対応かどうかで固定方法が変わります。車種ごとの確認が要りますね。' },
      { author: P.e, content: '取り付け位置は後席が推奨と聞きました。助手席はエアバッグが危ないと。' },
      { author: P.b, content: 'ISOFIXの有無、車両台帳に項目を足しておきます。ありがとうございます。', replyTo: 0 },
      { author: P.c, content: '着脱を頻繁にするなら、シートベルト固定式の方が扱いやすいこともあります。' },
    ],
  },
  {
    id: 'body-shop-quote-gap',
    author: P.c,
    category: 'maintenance',
    daysAgo: 24,
    content:
      'リアバンパーの擦り傷、3社で見積もりを取ったら 4.5万 / 7.2万 / 11万でした。'
      + '同じ作業でここまで開くとは。安い所は中古部品、高い所は新品交換の前提でした。'
      + ' #板金塗装 #見積もり',
    hashtags: ['板金塗装', '見積もり'],
    likes: 7,
    comments: [
      { author: P.a, content: '前提が違うと金額も変わりますよね。何を交換するかまで確認が要ります。' },
      { author: P.h, content: '旧車だと中古部品一択のことも多いです。程度の見極めが重要ですが。' },
      { author: P.f, content: '売却予定があるなら、修理歴の付き方も気にした方がいいですよ。' },
      { author: P.c, content: '修理歴は考えていませんでした。バンパーだけなら修復歴にはならないはずですが確認します。', replyTo: 2 },
      { author: P.i, content: '買う側としては、修復歴の定義をちゃんと知っておきたいです。' },
      { author: P.b, content: '法人車は稼働を止めたくないので、代車の有無も選定基準にしています。' },
    ],
  },
  {
    id: 'kei-running-cost',
    author: P.e,
    category: 'general',
    daysAgo: 25,
    content:
      '軽自動車を1年維持してみた費用をまとめました。税金10,800円、任意保険6万、'
      + 'ガソリン9万、点検2万、駐車場14.4万。年間約32万円でした。 #軽自動車 #維持費',
    hashtags: ['軽自動車', '維持費'],
    vehicleTag: V.eNbox,
    likes: 6,
    comments: [
      { author: P.h, content: '駐車場が一番大きいですね。うちも同じくらいです。' },
      { author: P.a, content: '4台だと駐車場だけで恐ろしい額になります…' },
      { author: P.i, content: 'SUVだとこれにいくら上乗せになるか、参考にさせてください。' },
      { author: P.d, content: '普通車だと税金と保険で年10万くらい上がる感覚です。' },
      { author: P.e, content: '思ったより差がありますね。軽にしてよかったかも。', replyTo: 3 },
    ],
  },
  {
    id: 'q-warning-light',
    author: P.i,
    category: 'question',
    daysAgo: 26,
    content:
      '試乗した中古車で、エンジンチェックランプが一瞬点いて消えました。'
      + 'これは避けた方がいい個体でしょうか？ #中古車 #警告灯',
    hashtags: ['中古車', '警告灯'],
    likes: 6,
    comments: [
      { author: P.d, content: '一瞬でも点いたなら診断機でエラーコードを読んでもらうべきです。' },
      { author: P.a, content: '販売店に伝えて、コードの内容を開示してもらいましょう。' },
      { author: P.h, content: '消えても履歴は残ります。読み取れば原因が分かりますよ。' },
      { author: P.i, content: '診断機の話、知りませんでした。聞いてみます。', replyTo: 0 },
      { author: P.c, content: '曖昧にされるようなら、その販売店は避けた方がいいと思います。' },
      { author: P.f, content: '売る側にいたので分かりますが、正直に答える店の方が結果的に信用されます。' },
    ],
  },
  {
    id: 'highway-fuel-economy',
    author: P.a,
    category: 'drive',
    daysAgo: 27,
    content:
      '同じ区間を80km/hと100km/hで走り比べたら、ハイエースで燃費が2.3km/L違いました。'
      + '時間差は12分。急がない日は80で走るようになりました。 #燃費 #高速道路',
    hashtags: ['燃費', '高速道路'],
    vehicleTag: V.aCargo,
    likes: 6,
    comments: [
      { author: P.d, content: '箱型の車は空気抵抗の影響が大きいですね。数字が分かりやすい。' },
      { author: P.g, content: 'EVはもっと顕著です。100km/h超えると電費が一気に落ちます。' },
      { author: P.b, content: '社用車の燃料費を考えると、この差は無視できないです。速度指導を検討します。' },
      { author: P.a, content: '20台分だと年間でかなりの額になりそうですね。', replyTo: 2 },
      { author: P.e, content: '12分しか変わらないんですね。急ぐ意味を考えてしまいます。' },
    ],
  },
  {
    id: 'inspection-cost-breakdown',
    author: P.a,
    category: 'maintenance',
    daysAgo: 28,
    content:
      '車検の見積もり、法定費用と整備費用を分けて考えると比較しやすいです。'
      + '法定費用はどこでも同じなので、差が出るのは整備と手数料の部分だけ。'
      + ' #車検 #費用',
    hashtags: ['車検', '費用'],
    likes: 7,
    comments: [
      { author: P.c, content: 'これは本当にそうで、総額だけ見ていると比較になりません。' },
      { author: P.e, content: '法定費用ってどこまでが含まれるんですか？' },
      { author: P.a, content: '重量税・自賠責・印紙代の3つです。合計は車種と重量で決まります。', replyTo: 1 },
      { author: P.h, content: 'ユーザー車検だとその3つだけで済むので、差が見えやすいです。' },
      { author: P.b, content: '見積書のフォーマットを揃えてもらうと、20台分の比較が一気に楽になりました。' },
      { author: P.d, content: '整備の内訳で「要交換」と「推奨」を分けてもらうのも有効です。' },
    ],
  },
  {
    id: 'first-car-anxiety',
    author: P.e,
    category: 'carLife',
    daysAgo: 30,
    content:
      '納車から半年。最初は洗車の仕方すら分からなかったのに、'
      + '今は自分で空気圧を見られるようになりました。ここで教えてもらったおかげです。'
      + ' #初心者 #カーライフ',
    hashtags: ['初心者', 'カーライフ'],
    vehicleTag: V.eNbox,
    likes: 8,
    comments: [
      { author: P.a, content: '成長が早い！ 空気圧を自分で見られる人は意外と少ないですよ。' },
      { author: P.d, content: '次はオイル量の点検にも挑戦してみてください。' },
      { author: P.h, content: 'こういう投稿を見ると、この場所の価値を感じます。' },
      { author: P.e, content: 'オイル量、やってみます！ また質問させてください。', replyTo: 1 },
      { author: P.c, content: '分からないことを聞ける相手がいるのは大きいですよね。' },
      { author: P.f, content: '半年でそこまでいけば十分です。無理せず楽しんでください。' },
    ],
  },
  {
    id: 'garage-4cars',
    author: P.a,
    category: 'carLife',
    daysAgo: 32,
    content:
      '用途で車を分けて4台持ちになりました。仕事はハイエース、家族はアルファード、'
      + '通勤はリースのノート、趣味はロードスター。維持は大変ですが後悔はないです。'
      + ' #愛車紹介',
    hashtags: ['愛車紹介'],
    likes: 8,
    comments: [
      { author: P.h, content: '用途で分ける贅沢、憧れます。趣味車があるのは大事ですよね。' },
      { author: P.i, content: '4台の維持費、差し支えなければ年間どのくらいですか？' },
      { author: P.a, content: '駐車場込みで年200万は超えます。仕事の経費になる分もありますが。', replyTo: 1 },
      { author: P.b, content: '法人化して社用車にできる部分もありそうですね。' },
      { author: P.g, content: '通勤用をEVにすると燃料費はかなり下がりますよ。' },
      { author: P.e, content: '1台でも大変なのに4台…！ 尊敬します。' },
    ],
  },
];

// ---------------------------------------------------------------------------
// エントリ組み立て
// ---------------------------------------------------------------------------

function build() {
  const entries = [];
  const counts = { posts: 0, comments: 0, post_likes: 0, comment_likes: 0 };

  THREADS.forEach((thread, pi) => {
    const postId = `post-cv-${thread.id}`;
    const postCreated = NOW - thread.daysAgo * DAY;

    // ---- コメント（返信を含む）----
    const commentIds = [];
    thread.comments.forEach((c, ci) => {
      const cid = `cmt-cv-${thread.id}-${ci}`;
      commentIds.push(cid);
      const parentId = c.replyTo != null ? commentIds[c.replyTo] : null;
      const createdMs = postCreated + (ci + 1) * between(20, 200) * 60 * 1000;
      const replyCount = thread.comments.filter((x) => x.replyTo === ci).length;

      // 会話らしさを出すため、有用なコメント（先頭2件）にいいねを付ける
      const likerUids = ci < 2 ? pickLikers(c.author.uid, between(1, 3), pi + ci) : [];

      entries.push({
        col: 'comments',
        id: cid,
        data: {
          postId,
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
          id: `${cid}_${uid}`,
          data: {
            commentId: cid,
            userId: uid,
            createdAt: ts(createdMs + HOUR),
            ...META,
          },
        });
        counts.comment_likes++;
      });
    });

    // ---- 投稿いいね ----
    const postLikers = pickLikers(thread.author.uid, thread.likes, pi);
    postLikers.forEach((uid, li) => {
      entries.push({
        col: 'post_likes',
        id: `${postId}_${uid}`,
        data: {
          postId,
          userId: uid,
          createdAt: ts(postCreated + (li + 1) * 2 * HOUR),
          ...META,
        },
      });
      counts.post_likes++;
    });

    // ---- 投稿本体 ----
    entries.push({
      col: 'posts',
      id: postId,
      data: {
        userId: thread.author.uid,
        userDisplayName: thread.author.name,
        userPhotoUrl: null,
        category: thread.category,
        visibility: 'public',
        content: thread.content,
        media: [],
        ...(thread.vehicleTag ? { vehicleTag: thread.vehicleTag } : {}),
        hashtags: thread.hashtags || [],
        mentionedUserIds: [],
        likeCount: postLikers.length,
        commentCount: thread.comments.length,
        shareCount: 0,
        viewCount: between(20, 400),
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
// 実行
// ---------------------------------------------------------------------------

async function commitInChunks(db, entries, label) {
  const CHUNK = 400;
  for (let i = 0; i < entries.length; i += CHUNK) {
    const batch = db.batch();
    for (const e of entries.slice(i, i + CHUNK)) {
      batch.set(db.collection(e.col).doc(e.id), e.data, { merge: true });
    }
    await batch.commit();
    console.log(`  ${label}: ${Math.min(i + CHUNK, entries.length)}/${entries.length}`);
  }
}

async function deleteInChunks(db, entries) {
  const CHUNK = 400;
  for (let i = 0; i < entries.length; i += CHUNK) {
    const batch = db.batch();
    for (const e of entries.slice(i, i + CHUNK)) {
      batch.delete(db.collection(e.col).doc(e.id));
    }
    await batch.commit();
    console.log(`  削除: ${Math.min(i + CHUNK, entries.length)}/${entries.length}`);
  }
}

async function main() {
  const { entries, counts } = build();

  console.log('');
  console.log('コミュニティ会話シード');
  console.log('----------------------------------------');
  console.log(`  スレッド        : ${counts.posts}`);
  console.log(`  コメント        : ${counts.comments}`);
  console.log(`  投稿いいね      : ${counts.post_likes}`);
  console.log(`  コメントいいね  : ${counts.comment_likes}`);
  console.log(`  合計ドキュメント: ${entries.length}`);
  console.log('');

  // 参加者ごとの発言数（会話の偏りを確認するため）
  const byAuthor = {};
  THREADS.forEach((t) => {
    byAuthor[t.author.name] = (byAuthor[t.author.name] || 0) + 1;
    t.comments.forEach((c) => {
      byAuthor[c.author.name] = (byAuthor[c.author.name] || 0) + 1;
    });
  });
  console.log('  発言数（投稿＋コメント）:');
  Object.entries(byAuthor)
    .sort((x, y) => y[1] - x[1])
    .forEach(([name, n]) => console.log(`    ${String(n).padStart(3)} 件  ${name}`));
  console.log('');

  if (DRY_RUN) {
    console.log('[DRY-RUN] 書き込みは行いませんでした。');
    return;
  }

  admin.initializeApp({ projectId: 'trust-car-platform' });
  const db = admin.firestore();

  if (DELETE) {
    await deleteInChunks(db, entries);
    console.log('');
    console.log(`[DONE] ${entries.length} 件を削除しました。`);
    return;
  }

  await commitInChunks(db, entries, '投入');
  console.log('');
  console.log(`[SUCCESS] ${entries.length} 件を Firestore に登録しました。`);
  console.log('');
  console.log('確認: アプリの「みんなの投稿」タブを開いてください。');
  console.log('後片付け: node seed_community_conversations.js --delete' + (EMULATOR ? ' --emulator' : ''));
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
