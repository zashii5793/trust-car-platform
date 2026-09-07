#!/usr/bin/env node
/**
 * ペルソナA（user-a）のドライブログを増やす。
 *
 * なぜ要るか:
 *   drive_log_screen は `where('userId', ==, ログイン中のuid)` でしか引かない
 *   （getPublicDriveLogs はどの画面からも呼ばれていない）。既存のシードは
 *   user-a に1件しか作らないため、「たびの記録が溜まっている状態」を
 *   実機で確認できなかった。
 *
 *   あわせて drive_waypoints も入れる。**2点以上ないと詳細画面の地図が
 *   描かれない**。firestore.rules は waypoint の read に userId を要求する
 *   のに、アプリの addWaypoint は userId を書いていないため、ここでは必ず
 *   入れる。
 *
 * Usage:
 *   node seed_drive_logs_persona_a.js --emulator [--delete]
 */
const admin = require('firebase-admin');

const useEmulator = process.argv.includes('--emulator');
const doDelete = process.argv.includes('--delete');

if (useEmulator) {
  process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || 'localhost:8080';
}
admin.initializeApp({ projectId: 'trust-car-platform' });
const db = admin.firestore();

const USER_ID = 'user-a';
const SEED_TAG = 'drive-persona-a';

const ts = (iso) => admin.firestore.Timestamp.fromDate(new Date(iso));

/** 2点間を直線で刻んだ経路。地図に線が出れば十分なので密度は粗くてよい。 */
function route(from, to, steps, startIso, minutes) {
  const out = [];
  const t0 = new Date(startIso).getTime();
  for (let i = 0; i <= steps; i++) {
    const r = i / steps;
    out.push({
      latitude: from[0] + (to[0] - from[0]) * r,
      longitude: from[1] + (to[1] - from[1]) * r,
      at: new Date(t0 + (minutes * 60000 * r)),
    });
  }
  return out;
}

const LOGS = [
  {
    id: 'dl-pa-hakone',
    title: '箱根までワインディング',
    description: '峠の途中で雨。タイヤを替えたばかりで良かった。帰りは渋滞だったけれど、屋根を開けられたので気にならず。',
    vehicleId: 'veh-a-roadster',
    start: '2026-09-05T07:10:00+09:00',
    minutes: 160,
    startAddress: '東京都世田谷区',
    endAddress: '神奈川県足柄下郡箱根町',
    from: [35.6465, 139.6533],
    to: [35.2324, 139.1069],
    distance: 128.4,
    maxSpeed: 92.0,
    weather: 'rainy',
    roadTypes: ['highway', 'mountainRoad'],
    isPublic: true,
  },
  {
    id: 'dl-pa-zushi',
    title: '海沿いを流す',
    description: '朝の134号。空いていて気持ちが良い。',
    vehicleId: 'veh-a-roadster',
    start: '2026-08-29T06:40:00+09:00',
    minutes: 80,
    startAddress: '東京都世田谷区',
    endAddress: '神奈川県逗子市',
    from: [35.6465, 139.6533],
    to: [35.2955, 139.5803],
    distance: 64.2,
    maxSpeed: 78.0,
    weather: 'sunny',
    roadTypes: ['coastalRoad', 'nationalRoad'],
    isPublic: true,
  },
  {
    id: 'dl-pa-costco',
    title: '買い出し（多摩）',
    description: '',
    vehicleId: 'veh-a-hiace',
    start: '2026-08-23T10:20:00+09:00',
    minutes: 55,
    startAddress: '東京都世田谷区',
    endAddress: '東京都多摩市',
    from: [35.6465, 139.6533],
    to: [35.6369, 139.4463],
    distance: 31.8,
    maxSpeed: 62.0,
    weather: 'cloudy',
    roadTypes: ['cityRoad'],
    isPublic: false,
  },
  {
    id: 'dl-pa-karuizawa',
    title: '軽井沢へ family trip',
    description: '往路は関越。渋滞を避けて早朝に出たのが正解だった。燃費は 14.2km/L。',
    vehicleId: 'veh-a-hiace',
    start: '2026-08-11T05:30:00+09:00',
    minutes: 195,
    startAddress: '東京都世田谷区',
    endAddress: '長野県北佐久郡軽井沢町',
    from: [35.6465, 139.6533],
    to: [36.3418, 138.6357],
    distance: 172.6,
    maxSpeed: 100.0,
    weather: 'sunny',
    roadTypes: ['highway'],
    isPublic: true,
  },
  {
    id: 'dl-pa-commute',
    title: '',
    description: '',
    vehicleId: 'veh-a-note',
    start: '2026-08-05T08:05:00+09:00',
    minutes: 38,
    startAddress: '東京都世田谷区',
    endAddress: '東京都港区',
    from: [35.6465, 139.6533],
    to: [35.6581, 139.7516],
    distance: 12.4,
    maxSpeed: 48.0,
    weather: 'sunny',
    roadTypes: ['cityRoad'],
    isPublic: false,
  },
];

async function wipe() {
  for (const c of ['drive_logs', 'drive_waypoints']) {
    const snap = await db.collection(c).where('seedTag', '==', SEED_TAG).get();
    const batch = db.batch();
    snap.forEach((d) => batch.delete(d.ref));
    await batch.commit();
    console.log(`[DELETE] ${c}: ${snap.size} 件`);
  }
}

async function main() {
  if (doDelete) {
    await wipe();
    console.log('\n削除しました。');
    return;
  }

  let logCount = 0;
  let wpCount = 0;

  for (const l of LOGS) {
    const startAt = new Date(l.start);
    const endAt = new Date(startAt.getTime() + l.minutes * 60000);
    const seconds = l.minutes * 60;

    await db.collection('drive_logs').doc(l.id).set({
      userId: USER_ID,
      vehicleId: l.vehicleId,
      status: 'completed',
      title: l.title,
      description: l.description,
      startLocation: { latitude: l.from[0], longitude: l.from[1] },
      endLocation: { latitude: l.to[0], longitude: l.to[1] },
      startAddress: l.startAddress,
      endAddress: l.endAddress,
      startTime: admin.firestore.Timestamp.fromDate(startAt),
      endTime: admin.firestore.Timestamp.fromDate(endAt),
      statistics: {
        totalDistance: l.distance,
        totalDuration: seconds,
        averageSpeed: Number((l.distance / (l.minutes / 60)).toFixed(1)),
        maxSpeed: l.maxSpeed,
        stopCount: 2,
        totalStopDuration: 600,
      },
      weather: l.weather,
      roadTypes: l.roadTypes,
      photoUrls: [],
      isPublic: l.isPublic,
      likeCount: 0,
      commentCount: 0,
      tags: [],
      createdAt: admin.firestore.Timestamp.fromDate(endAt),
      updatedAt: admin.firestore.Timestamp.fromDate(endAt),
      isSeed: true,
      seedTag: SEED_TAG,
    }, { merge: true });
    logCount++;
    console.log(`[LOG] ${l.id} — ${l.title || '(無題)'} / ${l.distance}km`);

    // 経路。20点あれば線として読める。
    const pts = route(l.from, l.to, 20, l.start, l.minutes);
    let batch = db.batch();
    pts.forEach((p, i) => {
      const ref = db.collection('drive_waypoints').doc(`${l.id}-wp-${String(i).padStart(3, '0')}`);
      batch.set(ref, {
        driveLogId: l.id,
        userId: USER_ID, // ルール要件。アプリ側の addWaypoint は書いていない
        location: { latitude: p.latitude, longitude: p.longitude },
        timestamp: admin.firestore.Timestamp.fromDate(p.at),
        speed: l.maxSpeed * 0.7,
        isSeed: true,
        seedTag: SEED_TAG,
      }, { merge: true });
      wpCount++;
    });
    await batch.commit();
  }

  console.log(`\n[SUCCESS] drive_logs ${logCount} 件 / drive_waypoints ${wpCount} 件`);
  console.log('確認: persona.a@example.com でログイン → ホームの「たびの記録」');
  console.log(`後片付け: node seed_drive_logs_persona_a.js --delete${useEmulator ? ' --emulator' : ''}`);
}

main().catch((e) => { console.error(e); process.exit(1); });
