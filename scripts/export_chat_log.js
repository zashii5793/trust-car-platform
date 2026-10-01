/**
 * export_chat_log.js — シードのチャットを docs/CHAT_LOG_SEED.md に書き出す
 *
 * Usage:
 *   firebase emulators:start --only auth,firestore
 *   （docs/TEST_DATA_GUIDE.md の順にシードを流す）
 *   node scripts/export_chat_log.js
 *
 * なぜ要るか:
 *   会話の中身はエミュレータの中にしか無く、消せば消える。画面を開かずに
 *   「どんなやりとりが入っているか」を読めるようにしておく。レビューのとき
 *   アプリを立ち上げずに中身を確かめられる。
 */

process.env.FIRESTORE_EMULATOR_HOST =
  process.env.FIRESTORE_EMULATOR_HOST || 'localhost:8080';
const path = require('path');
const admin = require('firebase-admin');
admin.initializeApp({projectId:'trust-car-platform'});
const db=admin.firestore();
const d=(t)=>t?new Date(t.toDate()).toISOString().slice(0,10):'-';
const STATUS={pending:'未対応',inProgress:'対応中',replied:'返信あり',closed:'完了',cancelled:'取消'};
(async()=>{
  const snap=await db.collection('inquiries').orderBy('createdAt').get();
  const users={}; (await db.collection('users').get()).docs.forEach(u=>users[u.id]=u.data().displayName||u.id);
  let out='# 店舗とお客様のチャット — シードに入っているやりとり\n\n';
  out+='> `scripts/seed_year_of_use.js` と `scripts/seed_full_experience.js` が投入する会話を、\n';
  out+='> エミュレータから書き出したもの。アプリを立ち上げなくても中身を確認できる。\n';
  out+='> 再生成: エミュレータにシードを流した状態で `node scripts/export_chat_log.js`\n\n';
  out+=`生成日: ${new Date().toISOString().slice(0,10)} / スレッド ${snap.size} 件\n\n---\n\n`;
  for(const doc of snap.docs){
    const x=doc.data();
    const msgs=(await doc.ref.collection('messages').orderBy('sentAt').get()).docs.map(m=>m.data());
    out+=`## ${x.subject}\n\n`;
    out+=`| | |\n|---|---|\n`;
    out+=`| お客様 | ${users[x.userId]||x.userId} |\n`;
    out+=`| 店舗 | ${x.shopName||x.shopId} |\n`;
    out+=`| 状態 | ${STATUS[x.status]||x.status} |\n`;
    out+=`| 期間 | ${d(x.createdAt)} 〜 ${d(x.updatedAt)} |\n`;
    out+=`| 通数 | ${x.messageCount} 通（お客様の未読 ${x.unreadCountUser||0} / 店舗の未読 ${x.unreadCountShop||0}） |\n\n`;
    out+=`**お客様**（${d(x.createdAt)}）\n> ${String(x.initialMessage).replace(/\n/g,'\n> ')}\n\n`;
    for(const m of msgs){
      out+=`**${m.isFromShop?'店舗':'お客様'}**（${d(m.sentAt)}${m.isRead===false?' ・未読':''}）\n> ${String(m.content).replace(/\n/g,'\n> ')}\n\n`;
    }
    if(msgs.length===0) out+='_（店舗からの返信はまだありません）_\n\n';
    out+='---\n\n';
  }
  const dest = path.resolve(__dirname, '../docs/CHAT_LOG_SEED.md');
  require('fs').writeFileSync(dest, out);
  console.log('wrote docs/CHAT_LOG_SEED.md —', snap.size, 'threads');
})();
